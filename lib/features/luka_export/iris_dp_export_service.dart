import 'dart:convert';

import '../../core/database/app_database.dart';
import '../../core/utils/location_scan_metadata.dart';
import '../camera_plan/camera_plan_grouping.dart';
import 'luka_camera_plan_export.dart';
import 'luka_light_mapping.dart';
import 'unreal_coords.dart';

/// Exporta datos del proyecto IRIS DP a JSON para Unreal Engine 5 + LUKA.
class IrisDpExportService {
  final AppDatabase db;

  IrisDpExportService(this.db);

  /// Export del proyecto completo (todas las escenas + catálogo de localizaciones).
  Future<Map<String, dynamic>> buildProjectExport({
    required Project project,
    double canvasScale = 0.01,
  }) async {
    final scenes = scenesInScriptOrder(
      await db.watchScenesForProject(project.id).first,
    );

    final scenePayloads = <Map<String, dynamic>>[];
    for (final scene in scenes) {
      scenePayloads.add(
        await _buildScenePayload(
          project: project,
          scene: scene,
          canvasScale: canvasScale,
        ),
      );
    }

    return {
      'iris_dp_version': '1.1',
      'export_type': 'project',
      'export_timestamp': DateTime.now().toIso8601String(),
      'project': _projectBlock(project),
      'locations': await _buildLocationCatalog(project.id),
      'scenes': scenePayloads,
      'meta': _metaBlock(canvasScale),
    };
  }

  /// Export de una sola escena (formato compatible con iris_dp_import.py).
  Future<Map<String, dynamic>> buildSceneExport({
    required Project project,
    required Scene scene,
    double canvasScale = 0.01,
  }) async {
    final payload = await _buildScenePayload(
      project: project,
      scene: scene,
      canvasScale: canvasScale,
    );

    return {
      'iris_dp_version': '1.1',
      'export_type': 'scene',
      'export_timestamp': DateTime.now().toIso8601String(),
      'project': _projectBlock(project),
      'locations': await _buildLocationCatalog(project.id),
      ...payload,
      'meta': _metaBlock(canvasScale),
    };
  }

  Map<String, dynamic> _projectBlock(Project project) => {
        'id': project.id,
        'name': project.name,
        'director': project.director,
      };

  Map<String, dynamic> _metaBlock(double canvasScale) => {
        'canvas_scale': canvasScale,
        'coordinate_system': 'unreal_zup_lefthanded',
        'units': 'cm',
        'gaussian_splat_orientation_fix': {
          'rotation': [-90, 0, 0],
          'scale_z': -1,
          'note': 'Aplicar al actor Luma si la escena aparece invertida',
        },
        'notes':
            'Importar con tools/unreal/iris_dp_import.py en UE5. '
            'Incluye camera_plan v1.1: focos LUKA, cámaras con trayectoria y '
            'datos técnicos por plano. Requiere plugin Luma AI y ARRI LUKA (Windows). '
            'Renders: iris_dp_s{sceneId}_p{shotNumber}.png',
      };

  Future<List<Map<String, dynamic>>> _buildLocationCatalog(int projectId) async {
    final catalog = <Map<String, dynamic>>[];
    final sites = await db.watchSitesForProject(projectId).first;
    final sets = await db.watchLocationsForProject(projectId).first;

    for (final site in sites) {
      catalog.add({
        'kind': 'site',
        'id': site.id,
        'name': site.name,
        'description': site.description,
        'notes': site.notes,
        'gaussian_splat': {
          'recommended_capture': 'luma_ai',
          'file_path': null,
          'formats': ['.luma', '.ply'],
          'unreal_plugin': 'LumaAI',
        },
        'floor_plan_json': site.floorPlanJson,
      });
    }

    for (final set in sets) {
      final scanMeta = LocationScanMetadata.fromJson(set.scanMetadataJson);
      catalog.add({
        'kind': 'set',
        'id': set.id,
        'site_id': set.siteId,
        'name': set.locationName,
        'color': set.color,
        'description': set.description,
        'notes': set.notes,
        'model_glb_path': set.model3dPath,
        'scan_path': set.scanPath,
        'scan_source': set.scanSource,
        'top_down_image': scanMeta.topDownImagePath,
        'gaussian_splat': {
          'recommended_capture': 'luma_ai',
          'file_path': set.scanPath,
          'formats': ['.luma', '.ply'],
          'model_glb_fallback': set.model3dPath,
        },
        'floor_plan_json': set.floorPlanJson,
      });
    }

    return catalog;
  }

  Future<Map<String, dynamic>> _buildScenePayload({
    required Project project,
    required Scene scene,
    required double canvasScale,
  }) async {
    final shots = await db.getShotsForScene(scene.id);
    shots.sort((a, b) => a.number.compareTo(b.number));

    LocationBasePlan? set;
    LocationSite? site;
    if (scene.locationId != null) {
      set = await db.getLocationById(scene.locationId!);
      if (set?.siteId != null) {
        site = await db.getSiteById(set!.siteId!);
      }
    }

    final locationName = scene.locationPureName.isNotEmpty
        ? scene.locationPureName
        : scene.locationCanonical;

    final actorNames = detectActorNamesFromActions(
      shots.map((s) => s.action),
    );

    final planExport = await LukaCameraPlanExporter(db).buildForScene(
      scene: scene,
      shots: shots,
      set: set,
      site: site,
      canvasScale: canvasScale,
    );

    final actors = List<Map<String, dynamic>>.from(planExport.actors);
    for (final actor in planExport.actors) {
      final name = actor['name'] as String?;
      if (name != null) actorNames.remove(name);
    }
    for (final name in actorNames) {
      actors.add({
        'name': name,
        'position': {'x': 0, 'y': 0, 'z': 90},
        'rotation_y': 0.0,
        'color': '#FFFFFF',
        'source': 'script_detected',
        'location': planExport.cameraPlan['location'],
      });
    }

    return {
      'scene': {
        'id': scene.id,
        'number': scene.number,
        'name': scene.name,
        'location': locationName,
        'location_canonical': scene.locationCanonical,
        'int_ext': scene.intExt,
        'day_night': scene.dayNight,
      },
      'location': {
        'set_id': set?.id,
        'set_name': set?.locationName,
        'site_id': site?.id,
        'site_name': site?.name,
        'color': set?.color,
        'notes': set?.notes,
        'model_glb_path': set?.model3dPath,
        'floor_plan_json': set?.floorPlanJson,
        'scan_path': set?.scanPath,
        'scan_source': set?.scanSource,
        'gaussian_splat': {
          'recommended_capture': 'luma_ai',
          'file_path': set?.scanPath,
          'model_glb_fallback': set?.model3dPath,
        },
      },
      'shots': shots.map(_shotBlock).toList(),
      'camera_plan': planExport.cameraPlan,
      'cameras': planExport.cameras,
      'lights': planExport.lights,
      'actors': actors,
      'props': planExport.props,
      'render_sequence': _renderSequence(
        scene: scene,
        shots: shots,
        shotBlocks: planExport.cameraPlan['shots'] as List,
      ),
    };
  }

  List<Map<String, dynamic>> _renderSequence({
    required Scene scene,
    required List<Shot> shots,
    required List<dynamic> shotBlocks,
  }) {
    return shots.map((shot) {
      Map<String, dynamic>? shotPlan;
      for (final block in shotBlocks) {
        if (block is Map<String, dynamic> && block['shot_id'] == shot.id) {
          shotPlan = block;
          break;
        }
      }

      final primary = shotPlan?['primary_camera'] as Map<String, dynamic>?;
      final technical = shotPlan?['technical'] as Map<String, dynamic>?;

      return {
        'shot_id': shot.id,
        'shot_number': shot.number,
        'scene_id': scene.id,
        'lens_mm': primary?['lens_mm'] ?? parseFocalLengthMm(shot.lens),
        't_stop': primary?['t_stop'] ?? parseTStop(shot.fStop),
        'shutter_angle': shot.shutterAngle ?? '180',
        'fps': shot.fps ?? 24,
        'movement': technical?['movement'] ?? shot.movement ?? 'STEADY',
        'movement_kind': technical?['movement_kind'] ??
            movementKind(shot.movement),
        'framing_note': shot.framing ?? '',
        'angle': shot.angle ?? 'normal',
        'camera_label': primary?['label'],
        'has_camera_path': primary?['has_movement'] ?? false,
        'path_point_count': primary?['path_point_count'] ?? 0,
        'path_length_m': primary?['path_length_m'] ?? 0.0,
        'output_filename': 'iris_dp_s${scene.id}_p${shot.number}.png',
      };
    }).toList();
  }

  Map<String, dynamic> _shotBlock(Shot shot) => {
        'number': shot.number,
        'framing': shot.framing ?? '',
        'lens_mm': parseFocalLengthMm(shot.lens),
        'movement': shot.movement ?? 'STEADY',
        'angle': shot.angle ?? 'normal',
        't_stop': parseTStop(shot.fStop),
        'shutter_angle': shot.shutterAngle ?? '180',
        'fps': shot.fps ?? 24,
        'action': shot.action ?? '',
        'notes': shot.notes ?? '',
      };

  String encodePretty(Map<String, dynamic> data) =>
      const JsonEncoder.withIndent('  ').convert(data);

  String defaultFilename(Scene scene) {
    final slug = scene.locationCanonical
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(' ', '_')
        .toLowerCase();
    final safe = slug.isEmpty ? 'escena_${scene.number}' : slug;
    return 'iris_dp_$safe.json';
  }

  String defaultProjectFilename(Project project) {
    final slug = project.name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(' ', '_')
        .toLowerCase();
    return 'iris_dp_${slug.isEmpty ? 'proyecto' : slug}_completo.json';
  }
}
