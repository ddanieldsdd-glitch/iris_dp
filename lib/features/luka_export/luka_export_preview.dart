import 'dart:async';

import '../../core/database/app_database.dart';
import '../../core/utils/location_scan_metadata.dart';
import 'luka_camera_plan_export.dart';

/// Vista previa de lo que se exportará a Unreal / LUKA.
class LukaExportPreview {
  final int shotCount;
  final int cameraCount;
  final int lightCount;
  final int lukaLightCount;
  final int fallbackLightCount;
  final int actorCount;
  final int propCount;
  final int camerasWithMovement;
  final int totalPathPoints;
  final String? setName;
  final String? siteName;
  final bool hasScan;
  final String? scanSource;
  final bool hasTopDown;
  final double? suggestedScale;
  final String scaleSource;
  final List<LukaExportShotPreview> shots;

  const LukaExportPreview({
    required this.shotCount,
    required this.cameraCount,
    required this.lightCount,
    required this.lukaLightCount,
    required this.fallbackLightCount,
    required this.actorCount,
    required this.propCount,
    required this.camerasWithMovement,
    required this.totalPathPoints,
    this.setName,
    this.siteName,
    required this.hasScan,
    this.scanSource,
    required this.hasTopDown,
    this.suggestedScale,
    required this.scaleSource,
    required this.shots,
  });

  static const empty = LukaExportPreview(
    shotCount: 0,
    cameraCount: 0,
    lightCount: 0,
    lukaLightCount: 0,
    fallbackLightCount: 0,
    actorCount: 0,
    propCount: 0,
    camerasWithMovement: 0,
    totalPathPoints: 0,
    hasScan: false,
    hasTopDown: false,
    scaleSource: 'default',
    shots: [],
  );
}

class LukaExportShotPreview {
  final int number;
  final String planSource;
  final int cameras;
  final int lights;
  final int lukaLights;
  final String? movement;
  final String? movementKind;
  final bool hasPath;
  final int pathPoints;
  final String? primaryCameraLabel;
  final String? lensMm;

  const LukaExportShotPreview({
    required this.number,
    required this.planSource,
    required this.cameras,
    required this.lights,
    required this.lukaLights,
    this.movement,
    this.movementKind,
    required this.hasPath,
    required this.pathPoints,
    this.primaryCameraLabel,
    this.lensMm,
  });
}

class LukaExportPreviewService {
  final AppDatabase db;

  LukaExportPreviewService(this.db);

  Future<({double scale, String source})> resolveScaleForScene(
    Scene scene,
  ) async {
    if (scene.locationId == null) {
      return (scale: 0.01, source: 'default');
    }
    final set = await db.getLocationById(scene.locationId!);
    if (set == null) {
      return (scale: 0.01, source: 'default');
    }
    final meta = LocationScanMetadata.fromJson(set.scanMetadataJson);
    if (meta.metersPerPixel > 0 &&
        (meta.hasTopDown || set.scanPath != null)) {
      return (scale: meta.metersPerPixel, source: 'scan');
    }
    return (scale: 0.01, source: 'default');
  }

  Future<LukaExportPreview> buildForScene({
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

    final scaleInfo = await resolveScaleForScene(scene);
    final scanMeta = set != null
        ? LocationScanMetadata.fromJson(set.scanMetadataJson)
        : const LocationScanMetadata();

    if (shots.isEmpty) {
      return LukaExportPreview(
        shotCount: 0,
        cameraCount: 0,
        lightCount: 0,
        lukaLightCount: 0,
        fallbackLightCount: 0,
        actorCount: 0,
        propCount: 0,
        camerasWithMovement: 0,
        totalPathPoints: 0,
        setName: set?.locationName,
        siteName: site?.name,
        hasScan: set?.scanPath != null,
        scanSource: set?.scanSource,
        hasTopDown: scanMeta.hasTopDown,
        suggestedScale: scaleInfo.scale,
        scaleSource: scaleInfo.source,
        shots: [],
      );
    }

    final export = await LukaCameraPlanExporter(db).buildForScene(
      scene: scene,
      shots: shots,
      set: set,
      site: site,
      canvasScale: canvasScale,
    );

    var lukaLights = 0;
    var fallbackLights = 0;
    var camerasWithMovement = 0;
    var totalPathPoints = 0;

    for (final light in export.lights) {
      if (light['luka_compatible'] == true) {
        lukaLights++;
      } else {
        fallbackLights++;
      }
    }

    for (final cam in export.cameras) {
      final pathCount = cam['path_point_count'] as int? ?? 0;
      totalPathPoints += pathCount;
      if (cam['has_movement'] == true || pathCount > 0) {
        camerasWithMovement++;
      }
    }

    final shotPreviews = <LukaExportShotPreview>[];
    final planShots = export.cameraPlan['shots'] as List? ?? [];
    for (final block in planShots) {
      if (block is! Map<String, dynamic>) continue;
      final elements = block['elements'] as Map<String, dynamic>? ?? {};
      final lights = elements['lights'] as List? ?? [];
      var shotLuka = 0;
      for (final l in lights) {
        if (l is Map && l['luka_compatible'] == true) shotLuka++;
      }
      final primary = block['primary_camera'] as Map<String, dynamic>?;
      final technical = block['technical'] as Map<String, dynamic>?;
      shotPreviews.add(LukaExportShotPreview(
        number: block['shot_number'] as int? ?? 0,
        planSource: block['plan_source'] as String? ?? 'empty',
        cameras: (elements['cameras'] as List?)?.length ?? 0,
        lights: lights.length,
        lukaLights: shotLuka,
        movement: technical?['movement'] as String?,
        movementKind: technical?['movement_kind'] as String?,
        hasPath: (primary?['path_point_count'] as int? ?? 0) > 0,
        pathPoints: primary?['path_point_count'] as int? ?? 0,
        primaryCameraLabel: primary?['label'] as String?,
        lensMm: primary?['lens_mm']?.toString(),
      ));
    }

    return LukaExportPreview(
      shotCount: shots.length,
      cameraCount: export.cameras.length,
      lightCount: export.lights.length,
      lukaLightCount: lukaLights,
      fallbackLightCount: fallbackLights,
      actorCount: export.actors.length,
      propCount: export.props.length,
      camerasWithMovement: camerasWithMovement,
      totalPathPoints: totalPathPoints,
      setName: set?.locationName,
      siteName: site?.name,
      hasScan: set?.scanPath != null || set?.model3dPath != null,
      scanSource: set?.scanSource,
      hasTopDown: scanMeta.hasTopDown,
      suggestedScale: scaleInfo.scale,
      scaleSource: scaleInfo.source,
      shots: shotPreviews,
    );
  }

  Future<LukaExportPreview> buildForProject({
    required int projectId,
    required double canvasScale,
  }) async {
    final scenes = await db.watchScenesForProject(projectId).first;
    if (scenes.isEmpty) return LukaExportPreview.empty;

    var shotCount = 0;
    var cameraCount = 0;
    var lightCount = 0;
    var lukaLightCount = 0;
    var fallbackLightCount = 0;
    var actorCount = 0;
    var propCount = 0;
    var camerasWithMovement = 0;
    var totalPathPoints = 0;
    var hasScan = false;
    var hasTopDown = false;
    final allShots = <LukaExportShotPreview>[];

    for (final scene in scenes) {
      final p = await buildForScene(scene: scene, canvasScale: canvasScale);
      shotCount += p.shotCount;
      cameraCount += p.cameraCount;
      lightCount += p.lightCount;
      lukaLightCount += p.lukaLightCount;
      fallbackLightCount += p.fallbackLightCount;
      actorCount += p.actorCount;
      propCount += p.propCount;
      camerasWithMovement += p.camerasWithMovement;
      totalPathPoints += p.totalPathPoints;
      hasScan = hasScan || p.hasScan;
      hasTopDown = hasTopDown || p.hasTopDown;
      allShots.addAll(p.shots);
    }

    return LukaExportPreview(
      shotCount: shotCount,
      cameraCount: cameraCount,
      lightCount: lightCount,
      lukaLightCount: lukaLightCount,
      fallbackLightCount: fallbackLightCount,
      actorCount: actorCount,
      propCount: propCount,
      camerasWithMovement: camerasWithMovement,
      totalPathPoints: totalPathPoints,
      hasScan: hasScan,
      hasTopDown: hasTopDown,
      scaleSource: 'default',
      shots: allShots,
    );
  }

  /// Emite cuando cambian planos del guion, planta cámara/luz o localización
  /// vinculada a la escena.
  static Stream<void> watchSceneExportTriggers(
    AppDatabase db, {
    required int sceneId,
    required int projectId,
  }) {
    StreamSubscription<List<Shot>>? shotsSub;
    StreamSubscription<List<Scene>>? scenesSub;
    StreamSubscription<List<LocationBasePlan>>? locationsSub;
    final elementSubs = <int, StreamSubscription<List<CameraPlanElement>>>{};

    late final StreamController<void> controller;

    void emit() {
      if (!controller.isClosed) controller.add(null);
    }

    void syncElementWatchers(List<Shot> shots) {
      final ids = shots.map((s) => s.id).toSet();
      for (final id in List<int>.from(elementSubs.keys)) {
        if (!ids.contains(id)) {
          elementSubs.remove(id)?.cancel();
        }
      }
      for (final shot in shots) {
        elementSubs.putIfAbsent(
          shot.id,
          () => db.watchCameraPlanElementsForShot(shot.id).listen((_) => emit()),
        );
      }
    }

    void disposeSubs() {
      shotsSub?.cancel();
      scenesSub?.cancel();
      locationsSub?.cancel();
      for (final sub in elementSubs.values) {
        sub.cancel();
      }
      elementSubs.clear();
    }

    controller = StreamController<void>(
      onListen: () {
        shotsSub = db.watchShotsForScene(sceneId).listen((shots) {
          syncElementWatchers(shots);
          emit();
        });
        scenesSub = db.watchScenesForProject(projectId).listen((scenes) {
          if (scenes.any((s) => s.id == sceneId)) emit();
        });
        locationsSub =
            db.watchLocationsForProject(projectId).listen((_) => emit());
      },
      onCancel: disposeSubs,
    );

    return controller.stream;
  }

  /// Emite cuando cambian escenas, planos o sets del proyecto.
  static Stream<void> watchProjectExportTriggers(
    AppDatabase db,
    int projectId,
  ) {
    StreamSubscription<List<Scene>>? scenesSub;
    StreamSubscription<List<LocationBasePlan>>? locationsSub;
    final shotSubs = <int, StreamSubscription<List<Shot>>>{};

    late final StreamController<void> controller;

    void emit() {
      if (!controller.isClosed) controller.add(null);
    }

    void syncShotWatchers(List<Scene> scenes) {
      final ids = scenes.map((s) => s.id).toSet();
      for (final id in List<int>.from(shotSubs.keys)) {
        if (!ids.contains(id)) {
          shotSubs.remove(id)?.cancel();
        }
      }
      for (final scene in scenes) {
        shotSubs.putIfAbsent(
          scene.id,
          () => db.watchShotsForScene(scene.id).listen((_) => emit()),
        );
      }
    }

    void disposeSubs() {
      scenesSub?.cancel();
      locationsSub?.cancel();
      for (final sub in shotSubs.values) {
        sub.cancel();
      }
      shotSubs.clear();
    }

    controller = StreamController<void>(
      onListen: () {
        scenesSub = db.watchScenesForProject(projectId).listen((scenes) {
          syncShotWatchers(scenes);
          emit();
        });
        locationsSub =
            db.watchLocationsForProject(projectId).listen((_) => emit());
      },
      onCancel: disposeSubs,
    );

    return controller.stream;
  }
}
