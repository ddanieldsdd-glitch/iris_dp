import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../camera_plan/camera_plan_constants.dart';
import '../camera_plan/camera_plan_element_model.dart';
import '../camera_plan/floor_plan_json.dart';
import '../camera_plan/floor_plan_repository.dart';
import '../camera_plan/plan_element_compat.dart';
import 'luka_light_mapping.dart';
import 'unreal_coords.dart';

/// Resultado del export de planta de cámara + luz para LUKA / Unreal.
class LukaCameraPlanExport {
  final List<Map<String, dynamic>> cameras;
  final List<Map<String, dynamic>> lights;
  final List<Map<String, dynamic>> actors;
  final List<Map<String, dynamic>> props;
  final Map<String, dynamic> cameraPlan;

  const LukaCameraPlanExport({
    required this.cameras,
    required this.lights,
    required this.actors,
    required this.props,
    required this.cameraPlan,
  });
}

/// Construye el bloque completo de planta de cámara y focos para export LUKA.
class LukaCameraPlanExporter {
  final AppDatabase db;

  LukaCameraPlanExporter(this.db);

  Future<LukaCameraPlanExport> buildForScene({
    required Scene scene,
    required List<Shot> shots,
    LocationBasePlan? set,
    LocationSite? site,
    required double canvasScale,
  }) async {
    final catalog = await db.watchAllLights().first;
    final cameras = await db.watchAllCameras().first;
    final lenses = await db.watchAllLenses().first;
    final repo = FloorPlanRepository(db);
    final setElements = set?.floorPlanJson != null
        ? FloorPlanJson.decode(set!.floorPlanJson)
        : <PlanElement>[];
    final siteElements = site?.floorPlanJson != null
        ? FloorPlanJson.decode(site!.floorPlanJson)
        : <PlanElement>[];

    final locationContext = {
      'scene_id': scene.id,
      'scene_number': scene.number,
      'scene_name': scene.name,
      'slugline': scene.locationCanonical,
      'int_ext': scene.intExt,
      'day_night': scene.dayNight,
      'set_id': set?.id,
      'set_name': set?.locationName,
      'site_id': site?.id,
      'site_name': site?.name,
    };

    final flatCameras = <Map<String, dynamic>>[];
    final flatLights = <Map<String, dynamic>>[];
    final flatActors = <Map<String, dynamic>>[];
    final flatProps = <Map<String, dynamic>>[];
    final shotBlocks = <Map<String, dynamic>>[];

    for (final shot in shots) {
      final resolved = await _resolveShotElements(shot, scene, repo);
      final block = _buildShotBlock(
        shot: shot,
        elements: resolved.elements,
        source: resolved.source,
        canvasScale: canvasScale,
        locationContext: locationContext,
        catalog: catalog,
        cameraCatalog: cameras,
        lensCatalog: lenses,
      );
      shotBlocks.add(block);

      for (final cam in block['elements']['cameras'] as List) {
        flatCameras.add(cam as Map<String, dynamic>);
      }
      for (final light in block['elements']['lights'] as List) {
        flatLights.add(light as Map<String, dynamic>);
      }
      for (final actor in block['elements']['actors'] as List) {
        flatActors.add(actor as Map<String, dynamic>);
      }
      for (final prop in block['elements']['props'] as List) {
        flatProps.add(prop as Map<String, dynamic>);
      }
    }

    final cameraPlan = {
      'version': 1,
      'canvas_scale': canvasScale,
      'location': locationContext,
      'set_floor_plan': _floorPlanBlock(
        setElements,
        canvasScale,
        'set',
        catalog: catalog,
        cameraCatalog: cameras,
        lensCatalog: lenses,
      ),
      'site_floor_plan': _floorPlanBlock(
        siteElements,
        canvasScale,
        'site',
        catalog: catalog,
        cameraCatalog: cameras,
        lensCatalog: lenses,
      ),
      'shots': shotBlocks,
    };

    return LukaCameraPlanExport(
      cameras: flatCameras,
      lights: flatLights,
      actors: flatActors,
      props: flatProps,
      cameraPlan: cameraPlan,
    );
  }

  Future<({List<PlanElement> elements, String source})> _resolveShotElements(
    Shot shot,
    Scene scene,
    FloorPlanRepository repo,
  ) async {
    final rows = await db.getCameraPlanElementsForShot(shot.id);
    if (rows.isNotEmpty) {
      final elements = <PlanElement>[];
      for (final row in rows) {
        final pathRows = await db.getPathPointsForElement(row.id);
        elements.add(PlanElement.fromDb(row, pathRows: pathRows));
      }
      return (elements: elements, source: 'shot');
    }

    if (scene.locationId != null) {
      final linkedSet = await db.getLocationById(scene.locationId!);
      if (linkedSet?.floorPlanJson != null &&
          linkedSet!.floorPlanJson!.isNotEmpty) {
        return (
          elements: FloorPlanJson.decode(linkedSet.floorPlanJson),
          source: 'set_template',
        );
      }
    }

    final templateJson = await repo.resolveTemplateJsonForScene(scene);
    if (templateJson != null) {
      final source =
          scene.locationId != null ? 'set_template' : 'site_template';
      return (elements: FloorPlanJson.decode(templateJson), source: source);
    }

    return (elements: <PlanElement>[], source: 'empty');
  }

  Map<String, dynamic> _floorPlanBlock(
    List<PlanElement> elements,
    double canvasScale,
    String scope, {
    required List<Light> catalog,
    required List<Camera> cameraCatalog,
    required List<Lense> lensCatalog,
  }) {
    if (elements.isEmpty) {
      return {'scope': scope, 'element_count': 0, 'elements': <String, dynamic>{}};
    }

    final grouped = _groupElements(
      elements,
      canvasScale,
      locationContext: {'scope': scope},
      shot: null,
      catalog: catalog,
      cameraCatalog: cameraCatalog,
      lensCatalog: lensCatalog,
    );

    return {
      'scope': scope,
      'element_count': elements.length,
      'elements': {
        'cameras': grouped.cameras,
        'lights': grouped.lights,
        'actors': grouped.actors,
        'props': grouped.props,
      },
    };
  }

  Map<String, dynamic> _buildShotBlock({
    required Shot shot,
    required List<PlanElement> elements,
    required String source,
    required double canvasScale,
    required Map<String, dynamic> locationContext,
    required List<Light> catalog,
    required List<Camera> cameraCatalog,
    required List<Lense> lensCatalog,
  }) {
    final grouped = _groupElements(
      elements,
      canvasScale,
      locationContext: locationContext,
      shot: shot,
      catalog: catalog,
      cameraCatalog: cameraCatalog,
      lensCatalog: lensCatalog,
    );

    final primaryCamera = grouped.cameras.isNotEmpty
        ? grouped.cameras.first
        : null;

    return {
      'shot_id': shot.id,
      'shot_number': shot.number,
      'plan_source': source,
      'technical': {
        'framing': shot.framing ?? '',
        'lens_mm': parseFocalLengthMm(shot.lens),
        'lens_raw': shot.lens ?? '',
        'movement': shot.movement ?? 'STEADY',
        'movement_kind': movementKind(shot.movement),
        'angle': shot.angle ?? 'normal',
        't_stop': parseTStop(shot.fStop),
        'shutter_angle': shot.shutterAngle ?? '180',
        'fps': shot.fps ?? 24,
        'action': shot.action ?? '',
        'notes': shot.notes ?? '',
      },
      'primary_camera': primaryCamera,
      'elements': {
        'cameras': grouped.cameras,
        'lights': grouped.lights,
        'actors': grouped.actors,
        'props': grouped.props,
      },
      'counts': {
        'cameras': grouped.cameras.length,
        'lights': grouped.lights.length,
        'actors': grouped.actors.length,
        'props': grouped.props.length,
      },
    };
  }

  ({
    List<Map<String, dynamic>> cameras,
    List<Map<String, dynamic>> lights,
    List<Map<String, dynamic>> actors,
    List<Map<String, dynamic>> props,
  }) _groupElements(
    List<PlanElement> elements,
    double canvasScale, {
    required Map<String, dynamic> locationContext,
    required Shot? shot,
    required List<Light> catalog,
    required List<Camera> cameraCatalog,
    required List<Lense> lensCatalog,
  }) {
    final cameras = <Map<String, dynamic>>[];
    final lights = <Map<String, dynamic>>[];
    final actors = <Map<String, dynamic>>[];
    final props = <Map<String, dynamic>>[];

    for (final el in elements) {
      switch (el.type) {
        case ElementType.camera:
          cameras.add(_cameraBlock(
            el,
            shot,
            canvasScale,
            locationContext,
            catalogCameras: cameraCatalog,
            catalogLenses: lensCatalog,
          ));
        case ElementType.light:
          lights.add(_lightBlock(
            el,
            shot,
            canvasScale,
            locationContext,
            catalog: catalog,
          ));
        case ElementType.actor:
          actors.add(_actorBlock(el, shot, canvasScale, locationContext));
        case ElementType.prop:
        case ElementType.wall:
          props.add(_propBlock(el, shot, canvasScale, locationContext));
      }
    }

    return (
      cameras: cameras,
      lights: lights,
      actors: actors,
      props: props,
    );
  }

  Map<String, dynamic> _cameraBlock(
    PlanElement el,
    Shot? shot,
    double canvasScale,
    Map<String, dynamic> locationContext, {
    required List<Camera> catalogCameras,
    required List<Lense> catalogLenses,
  }) {
    final movement = el.stabilization ?? shot?.movement ?? 'STEADY';
    final pathPoints = _pathPoints(el, canvasScale);
    final pathLengthM = _pathLengthMeters(el, canvasScale);
    final cam = _findCamera(catalogCameras, el.externalMapping.catalogCameraId);
    final lens = _findLens(catalogLenses, el.externalMapping.catalogLensId);
    final profile = PlanElementCompat.resolve(
      el,
      catalogCamera: cam,
      catalogLens: lens,
    );

    return {
      'element_id': el.id,
      if (shot != null) ...{
        'shot_id': shot.id,
        'shot_number': shot.number,
      },
      'type': 'camera',
      'label': el.cameraLabel,
      'letter': el.cameraLetter,
      'number': el.cameraNumber,
      'canvas_position': _canvasPoint(el.position),
      'position': canvasToUnrealCoords(
        el.position,
        canvasScale: canvasScale,
        elementKind: 'camera',
      ),
      'rotation_y': el.rotation,
      'rotation_deg': el.rotation,
      'lens_mm': parseFocalLengthMm(el.lens ?? shot?.lens),
      'lens_raw': el.lens ?? shot?.lens ?? '',
      't_stop': parseTStop(shot?.fStop),
      'movement': movement,
      'movement_kind': movementKind(movement),
      'stabilization': el.stabilization ?? movement,
      'has_movement': hasCameraMovement(movement, el.pathPoints.length),
      'path_point_count': el.pathPoints.length,
      'path_length_m': pathLengthM,
      'path_points': pathPoints,
      'framing': shot?.framing ?? '',
      'angle': shot?.angle ?? 'normal',
      'fps': shot?.fps ?? 24,
      'shutter_angle': shot?.shutterAngle ?? '180',
      'location': locationContext,
      'external_mapping': el.externalMapping.toJson(),
      ...profile.toExportJson(),
    };
  }

  Map<String, dynamic> _lightBlock(
    PlanElement el,
    Shot? shot,
    double canvasScale,
    Map<String, dynamic> locationContext, {
    required List<Light> catalog,
  }) {
    final resolved = LukaLightMapping.resolve(el, catalog: catalog);
    final catalogLight =
        _findLight(catalog, el.externalMapping.catalogLightId);
    final profile = PlanElementCompat.resolve(
      el,
      catalog: catalog,
      catalogLight: catalogLight,
    );

    return {
      'element_id': el.id,
      if (shot != null) ...{
        'shot_id': shot.id,
        'shot_number': shot.number,
      },
      'type': 'light',
      'label': el.displayLabel,
      'iris_light_type': el.lightType?.dbValue,
      'light_type': profile.unrealLightType,
      'light_type_label': el.lightType?.label,
      'unreal_light_type': profile.unrealLightType,
      'canvas_position': _canvasPoint(el.position),
      'position': canvasToUnrealCoords(
        el.position,
        canvasScale: canvasScale,
        elementKind: 'light',
      ),
      'rotation_y': el.rotation,
      'rotation_deg': el.rotation,
      'intensity': profile.intensity,
      'color_temp_k': profile.colorTempK,
      'luka_fixture_id': resolved.fixtureId ?? profile.lukaFixtureId,
      'luka_compatible': resolved.compatible || profile.luka,
      'luka_fixture_source': resolved.source,
      'luka_fixture_label': LukaLightMapping.labelForFixtureId(
            resolved.fixtureId ?? profile.lukaFixtureId,
            catalog: catalog,
          ) ??
          profile.lukaFixtureLabel,
      'location': locationContext,
      'external_mapping': el.externalMapping.toJson(),
      ...profile.toExportJson(),
    };
  }

  Map<String, dynamic> _actorBlock(
    PlanElement el,
    Shot? shot,
    double canvasScale,
    Map<String, dynamic> locationContext,
  ) {
    return {
      'element_id': el.id,
      if (shot != null) ...{
        'shot_id': shot.id,
        'shot_number': shot.number,
      },
      'type': 'actor',
      'name': el.label ?? 'Actor',
      'canvas_position': _canvasPoint(el.position),
      'position': canvasToUnrealCoords(
        el.position,
        canvasScale: canvasScale,
        elementKind: 'actor',
      ),
      'rotation_y': el.rotation,
      'color': '#${el.actorColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      'source': 'camera_plan',
      'location': locationContext,
    };
  }

  Map<String, dynamic> _propBlock(
    PlanElement el,
    Shot? shot,
    double canvasScale,
    Map<String, dynamic> locationContext,
  ) {
    final profile = PlanElementCompat.resolve(el);
    return {
      'element_id': el.id,
      if (shot != null) ...{
        'shot_id': shot.id,
        'shot_number': shot.number,
      },
      'type': el.type.dbValue,
      'label': el.displayLabel,
      'canvas_position': _canvasPoint(el.position),
      'position': canvasToUnrealCoords(
        el.position,
        canvasScale: canvasScale,
        elementKind: 'prop',
      ),
      'rotation_y': el.rotation,
      'location': locationContext,
      'external_mapping': el.externalMapping.toJson(),
      ...profile.toExportJson(),
    };
  }

  Camera? _findCamera(List<Camera> list, int? id) {
    if (id == null) return null;
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  Lense? _findLens(List<Lense> list, int? id) {
    if (id == null) return null;
    for (final l in list) {
      if (l.id == id) return l;
    }
    return null;
  }

  Light? _findLight(List<Light> list, int? id) {
    if (id == null) return null;
    for (final l in list) {
      if (l.id == id) return l;
    }
    return null;
  }

  List<Map<String, dynamic>> _pathPoints(PlanElement el, double canvasScale) {
    final points = <Map<String, dynamic>>[];
    var index = 1;
    for (final pt in el.pathPoints) {
      points.add({
        'index': index,
        'canvas_position': _canvasPoint(pt),
        'position': canvasToUnrealCoords(
          pt,
          canvasScale: canvasScale,
          elementKind: 'camera',
        ),
      });
      index++;
    }
    return points;
  }

  Map<String, double> _canvasPoint(Offset p) => {'x': p.dx, 'y': p.dy};

  double _pathLengthMeters(PlanElement el, double canvasScale) {
    if (el.pathPoints.isEmpty) return 0;
    final all = [el.position, ...el.pathPoints];
    var totalPx = 0.0;
    for (var i = 1; i < all.length; i++) {
      totalPx += (all[i] - all[i - 1]).distance;
    }
    return totalPx * canvasScale;
  }
}
