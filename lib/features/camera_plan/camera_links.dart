import '../../core/database/app_database.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'camera_shot_sync.dart';
import 'floor_plan_repository.dart';
import 'floor_plan_scope.dart';
import 'light_overrides.dart';

/// Un plano que se puede vincular a una cámara del esquema de luz.
class LinkableShot {
  final Shot shot;
  final Scene? scene;

  /// Ya lleva una copia de la cámara.
  final bool linked;

  /// Letras de las cámaras que tiene ya el plano (A, B…).
  final List<String> cameras;

  const LinkableShot({
    required this.shot,
    this.scene,
    this.linked = false,
    this.cameras = const [],
  });

  String get label {
    final s = scene?.label;
    return s == null ? 'P${shot.number}' : 'Esc $s · P${shot.number}';
  }
}

/// Cámaras del esquema de luz vinculadas a planos.
///
/// Una cámara colocada en la planta de luz puede ser la de varios planos: a
/// cada uno se le pone una copia (`props['setupCamera']` = identificador de
/// la cámara del esquema) y el esquema como su luz. Un plano puede tener
/// varias (cámara A y B). Mientras el plano no la mueva, la copia sigue a la
/// cámara del esquema.
class CameraLinks {
  final AppDatabase db;
  CameraLinks(this.db);

  static const setupCameraKey = 'setupCamera';

  /// Cámara del esquema de la que es copia un elemento del plano, o `null`.
  static String? setupCameraOf(PlanElement el) =>
      el.props[setupCameraKey] as String?;

  /// Planos que pueden llevar las cámaras de [setup]: los de las escenas de
  /// su set (o, en la luz general, los de la localización sin set) y los que
  /// ya lo usan.
  Future<List<LinkableShot>> linkableShots(
    LightSetup setup,
    String cameraUid,
  ) async {
    final scenes = {
      for (final s in await (db.select(
        db.scenes,
      )..where((s) => s.projectId.equals(setup.projectId))).get())
        s.id: s,
    };
    final shots = await db.getShotsForProject(setup.projectId);
    final result = <LinkableShot>[];
    for (final shot in shots) {
      final scene = scenes[shot.sceneId];
      final setId = shot.locationBasePlanId ?? scene?.locationId;
      final fits =
          shot.lightSetupId == setup.id ||
          (setup.locationBasePlanId != null
              ? setId == setup.locationBasePlanId
              : setup.locationSiteId != null &&
                    setId == null &&
                    scene?.locationSiteId == setup.locationSiteId);
      if (!fits) continue;
      final own = await _shotElements(shot.id);
      final cameras = own.where((e) => e.type == ElementType.camera).toList();
      result.add(
        LinkableShot(
          shot: shot,
          scene: scene,
          linked: cameras.any((e) => setupCameraOf(e) == cameraUid),
          cameras: [for (final c in cameras) c.cameraLetter],
        ),
      );
    }
    result.sort((a, b) {
      final byScene = (a.scene?.number ?? 0).compareTo(b.scene?.number ?? 0);
      return byScene != 0 ? byScene : a.shot.number.compareTo(b.shot.number);
    });
    return result;
  }

  /// Deja la cámara [camera] de [setup] vinculada exactamente a [shotIds]
  /// entre los [candidates]: pone copias donde faltan y las quita donde ya
  /// no van. Los planos vinculados pasan a usar [setup] como su luz.
  ///
  /// Cada copia nueva y su plano se juntan (SG.4): según [source] manda la
  /// focal y el movimiento del guion técnico o los de la planta, y lo que
  /// le falte a uno lo toma del otro.
  Future<void> setLinks(
    LightSetup setup,
    PlanElement camera,
    Iterable<int> shotIds,
    Iterable<Shot> candidates, {
    CameraShotSource source = CameraShotSource.script,
  }) async {
    LightOverrides.ensureUids([camera]);
    final uid = LightOverrides.uidOf(camera)!;
    final wanted = shotIds.toSet();
    for (final shot in candidates) {
      final own = await _shotElements(shot.id);
      final has = own.any((e) => setupCameraOf(e) == uid);
      final want = wanted.contains(shot.id);
      if (want && !has) {
        final copy = LightOverrides.clone(camera);
        LightOverrides.renewUids([copy]);
        copy.props[setupCameraKey] = uid;
        copy.layer = PlanLayer.shot;
        await CameraShotSync.link(db, copy, shot, source: source);
        await _saveShot(shot.id, [...own, copy]);
        if (shot.lightSetupId != setup.id) {
          await db.assignLightSetupToShot(shot.id, setup.id);
        }
      } else if (!want && has) {
        await _saveShot(shot.id, [
          for (final e in own)
            if (setupCameraOf(e) != uid) e,
        ]);
      }
    }
  }

  /// Pone en [toShotId] una copia de las cámaras de [fromShotId], en el mismo
  /// sitio. Las que eran de un set siguen vinculadas a él.
  Future<void> copyCameras(int fromShotId, int toShotId) async {
    final copies = [
      for (final el in await _shotElements(fromShotId))
        if (el.type == ElementType.camera) LightOverrides.clone(el),
    ];
    if (copies.isEmpty) return;
    LightOverrides.renewUids(copies);
    await _saveShot(toShotId, copies);
  }

  /// Las copias siguen a sus cámaras: tras guardar el esquema [setupId],
  /// cada copia que estaba igual que la cámara de antes ([before]) toma
  /// cómo está ahora ([after]). Las que el plano ya movió se respetan.
  Future<void> followCameras(
    int setupId,
    List<PlanElement> before,
    List<PlanElement> after,
  ) async {
    Map<String, PlanElement> camerasOf(List<PlanElement> list) => {
      for (final e in list)
        if (e.type == ElementType.camera && LightOverrides.uidOf(e) != null)
          LightOverrides.uidOf(e)!: e,
    };
    final old = camerasOf(before);
    final now = camerasOf(after);
    final changed = {
      for (final uid in now.keys)
        if (old[uid] case final was?
            when !_samePlace(was, now[uid]!) ||
                CameraShotSync.gearChanged(was, now[uid]!))
          uid,
    };
    if (changed.isEmpty) return;
    final shots = await (db.select(
      db.shots,
    )..where((s) => s.lightSetupId.equals(setupId))).get();
    for (final shot in shots) {
      final own = await _shotElements(shot.id);
      var touched = false;
      for (final el in own) {
        final uid = setupCameraOf(el);
        if (uid == null || !changed.contains(uid)) continue;
        final was = old[uid]!, cam = now[uid]!;
        // El sitio y la focal se siguen por separado: un plano que movió su
        // copia sigue tomando la focal que se cambie en el set, y uno que
        // tiene otra focal sigue a la cámara cuando se mueve.
        if (_samePlace(el, was) && !_samePlace(el, cam)) {
          el
            ..position = cam.position
            ..rotation = cam.rotation
            ..pathPoints = [...cam.pathPoints];
          touched = true;
        }
        if (!CameraShotSync.gearChanged(el, was) &&
            CameraShotSync.gearChanged(el, cam)) {
          el
            ..lens = cam.lens
            ..stabilization = cam.stabilization;
          touched = true;
          // La focal y el movimiento del set van también al guion técnico.
          final write = CameraShotSync.shotFromCamera(el, shot);
          if (write != null) await db.updateShotFields(shot.id, write);
        }
      }
      if (touched) await _saveShot(shot.id, own);
    }
  }

  /// El guion técnico cambió la focal o el movimiento del plano [shotId]
  /// (antes era [before]): sus cámaras lo toman (SG.4). Si el plano tiene
  /// una sola cámara, esa; si tiene varias, las que decían lo de antes. Una
  /// cámara del set que solo es de este plano cambia también en el set.
  Future<void> followShot(int shotId, Shot before) async {
    final shot = await db.getShotById(shotId);
    if (shot == null) return;
    final own = await _shotElements(shotId);
    final cameras = own.where((e) => e.type == ElementType.camera).toList();
    if (cameras.isEmpty) return;
    final targets = cameras.length == 1
        ? cameras
        : [
            for (final c in cameras)
              if (!CameraShotSync.conflicts(c, before)) c,
          ];
    final touched = [
      for (final c in targets)
        if (CameraShotSync.cameraFromShot(c, shot)) c,
    ];
    if (touched.isEmpty) return;
    await _saveShot(shotId, own);
    final setupId = shot.lightSetupId;
    if (setupId == null) return;
    final repo = FloorPlanRepository(db);
    final setup = await repo.loadElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setupId,
    );
    var setupChanged = false;
    for (final copy in touched) {
      final uid = setupCameraOf(copy);
      if (uid == null) continue;
      if (await _copiesOf(uid, setupId) > 1) continue;
      for (final cam in setup) {
        if (LightOverrides.uidOf(cam) == uid &&
            CameraShotSync.gearChanged(cam, copy)) {
          cam
            ..lens = copy.lens
            ..stabilization = copy.stabilization;
          setupChanged = true;
        }
      }
    }
    if (setupChanged) {
      await repo.saveElements(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: setupId,
        elements: setup,
      );
    }
  }

  /// Cuántos planos del esquema [setupId] llevan una copia de [uid].
  Future<int> _copiesOf(String uid, int setupId) async {
    final shots = await (db.select(
      db.shots,
    )..where((s) => s.lightSetupId.equals(setupId))).get();
    var n = 0;
    for (final s in shots) {
      final own = await _shotElements(s.id);
      if (own.any((e) => setupCameraOf(e) == uid)) n++;
    }
    return n;
  }

  static bool _samePlace(PlanElement a, PlanElement b) =>
      a.position == b.position &&
      a.rotation == b.rotation &&
      a.pathPoints.length == b.pathPoints.length &&
      [
        for (var i = 0; i < a.pathPoints.length; i++)
          a.pathPoints[i] == b.pathPoints[i],
      ].every((x) => x);

  Future<List<PlanElement>> _shotElements(int shotId) =>
      FloorPlanRepository(db).loadElements(
        scope: FloorPlanScope.shot,
        shotId: shotId,
      );

  /// Guarda los elementos del plano (el repositorio avisa del cambio).
  Future<void> _saveShot(int shotId, List<PlanElement> elements) =>
      FloorPlanRepository(db).saveElements(
        scope: FloorPlanScope.shot,
        shotId: shotId,
        elements: elements,
      );
}
