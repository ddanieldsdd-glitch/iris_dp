import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/location_scan_metadata.dart';
import '../camera_plan/camera_plan_constants.dart';
import '../camera_plan/camera_plan_element_model.dart';
import '../camera_plan/camera_plan_grouping.dart';
import '../camera_plan/floor_plan_json.dart';
import '../camera_plan/plan_element_compat.dart';
import '../luka_export/unreal_coords.dart';

/// Exporta datos de escena para Cine Tracer (Unreal-based previs).
class CineTracerExportService {
  final AppDatabase db;

  CineTracerExportService(this.db);

  Future<Map<String, dynamic>> buildSetExport({
    required Project project,
    required LocationBasePlan set,
    required List<Scene> scenes,
    double canvasScale = 0.01,
  }) async {
    final meta = LocationScanMetadata.fromJson(set.scanMetadataJson);
    final catalog = await db.watchAllLights().first;
    final cameras = await db.watchAllCameras().first;
    final lenses = await db.watchAllLenses().first;
    final setElements = set.floorPlanJson != null
        ? FloorPlanJson.decode(set.floorPlanJson)
        : <PlanElement>[];

    final scenePayloads = <Map<String, dynamic>>[];

    for (final scene in scenesInScriptOrder(scenes)) {
      final shots = await db.getShotsForScene(scene.id);
      shots.sort((a, b) => a.number.compareTo(b.number));

      final sceneCameras = <Map<String, dynamic>>[];
      final sceneLights = <Map<String, dynamic>>[];
      final sceneActors = <Map<String, dynamic>>[];
      final sceneProps = <Map<String, dynamic>>[];

      for (final shot in shots) {
        final rows = await db.getCameraPlanElementsForShot(shot.id);
        final elements = <PlanElement>[];
        for (final row in rows) {
          final pathRows = await db.getPathPointsForElement(row.id);
          elements.add(PlanElement.fromDb(row, pathRows: pathRows));
        }

        for (final el in elements) {
          final block = _elementBlock(
            el,
            shot: shot,
            canvasScale: canvasScale,
            catalog: catalog,
            cameras: cameras,
            lenses: lenses,
          );
          switch (el.type) {
            case ElementType.camera:
              sceneCameras.add(block);
            case ElementType.light:
              sceneLights.add(block);
            case ElementType.actor:
              sceneActors.add(block);
            case ElementType.prop:
            case ElementType.wall:
              sceneProps.add(block);
          }
        }
      }

      scenePayloads.add({
        'scene_id': scene.id,
        'scene_number': scene.number,
        'location': scene.locationCanonical,
        'shots': shots.length,
        'cameras': sceneCameras,
        'lights': sceneLights,
        'actors': sceneActors,
        'props': sceneProps,
      });
    }

    return {
      'iris_dp_version': '1.1',
      'export_type': 'cinetracer',
      'export_timestamp': DateTime.now().toIso8601String(),
      'project': {'id': project.id, 'name': project.name},
      'set': {
        'id': set.id,
        'name': set.locationName,
        'scan_path': set.scanPath,
        'model_glb_path': set.model3dPath,
        'scan_source': set.scanSource,
      },
      'environment': {
        'gaussian_splat_path': set.scanPath,
        'model_glb_path': set.model3dPath,
        'top_down_image': meta.topDownImagePath,
        'meters_per_pixel': meta.metersPerPixel,
        'width_meters': meta.widthMeters,
        'height_meters': meta.heightMeters,
        'note':
            'Importa el scan en Cine Tracer como entorno. '
            'Usa la planta cenital como referencia de escala.',
      },
      'set_floor_plan': _floorPlanPayload(setElements, canvasScale, catalog, cameras, lenses),
      'scenes': scenePayloads,
      'meta': {
        'canvas_scale': canvasScale,
        'coordinate_system': 'unreal_zup_lefthanded',
        'units': 'cm',
        'platforms': ['cinetracer', 'unreal'],
      },
    };
  }

  Map<String, dynamic> _floorPlanPayload(
    List<PlanElement> elements,
    double canvasScale,
    List<Light> catalog,
    List<Camera> cameras,
    List<Lense> lenses,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{
      'cameras': [],
      'lights': [],
      'actors': [],
      'props': [],
    };
    for (final el in elements) {
      final block = _elementBlock(
        el,
        canvasScale: canvasScale,
        catalog: catalog,
        cameras: cameras,
        lenses: lenses,
      );
      switch (el.type) {
        case ElementType.camera:
          grouped['cameras']!.add(block);
        case ElementType.light:
          grouped['lights']!.add(block);
        case ElementType.actor:
          grouped['actors']!.add(block);
        case ElementType.prop:
        case ElementType.wall:
          grouped['props']!.add(block);
      }
    }
    return {
      'element_count': elements.length,
      'elements': grouped,
    };
  }

  Map<String, dynamic> _elementBlock(
    PlanElement el, {
    Shot? shot,
    required double canvasScale,
    required List<Light> catalog,
    required List<Camera> cameras,
    required List<Lense> lenses,
  }) {
    final cam = cameras
        .where((c) => c.id == el.externalMapping.catalogCameraId)
        .firstOrNull;
    final lens = lenses
        .where((l) => l.id == el.externalMapping.catalogLensId)
        .firstOrNull;
    final light = catalog
        .where((l) => l.id == el.externalMapping.catalogLightId)
        .firstOrNull;
    final profile = PlanElementCompat.resolve(
      el,
      catalog: catalog,
      catalogCamera: cam,
      catalogLens: lens,
      catalogLight: light,
    );

    return {
      if (shot != null) 'shot_number': shot.number,
      'type': el.type.dbValue,
      'label': el.displayLabel,
      'cinetracer_type': profile.cinetracerType,
      'position': canvasToUnrealCoords(
        el.position,
        canvasScale: canvasScale,
        elementKind: el.type.dbValue,
      ),
      'rotation_y': el.rotation,
      if (el.type == ElementType.camera) ...{
        'lens_mm': parseFocalLengthMm(el.lens ?? shot?.lens),
        't_stop': parseTStop(shot?.fStop),
        'movement_kind': profile.movementKind,
      },
      if (el.type == ElementType.light) ...{
        'intensity': profile.intensity,
        'color_temp_k': profile.colorTempK,
        'luka_fixture_id': profile.lukaFixtureId,
      },
      'unreal_mesh_path': profile.unrealMeshPath,
      'compat': profile.toExportJson(),
    };
  }

  String encodePretty(Map<String, dynamic> data) =>
      const JsonEncoder.withIndent('  ').convert(data);

  Future<String?> saveSetExport({
    required Project project,
    required LocationBasePlan set,
    required List<Scene> scenes,
    double canvasScale = 0.01,
  }) async {
    final payload = await buildSetExport(
      project: project,
      set: set,
      scenes: scenes,
      canvasScale: canvasScale,
    );
    final json = encodePretty(payload);

    final slug = set.locationName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(' ', '_')
        .toLowerCase();

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Exportar para Cine Tracer',
      fileName: 'iris_dp_ct_$slug.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return null;

    final file = File(path.endsWith('.json') ? path : '$path.json');
    await file.writeAsString(json);
    return file.path;
  }
}
