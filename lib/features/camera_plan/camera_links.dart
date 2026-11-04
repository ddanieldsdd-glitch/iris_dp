import '../../core/database/app_database.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
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
  Future<void> setLinks(
    LightSetup setup,
    PlanElement camera,
    Iterable<int> shotIds,
    Iterable<Shot> candidates,
  ) async {
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
        if (old[uid] case final was? when !_samePlace(was, now[uid]!)) uid,
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
        if (!_samePlace(el, old[uid]!)) continue;
        final cam = now[uid]!;
        el
          ..position = cam.position
          ..rotation = cam.rotation
          ..lens = cam.lens
          ..stabilization = cam.stabilization
          ..pathPoints = [...cam.pathPoints];
        touched = true;
      }
      if (touched) await _saveShot(shot.id, own);
    }
  }

  static bool _samePlace(PlanElement a, PlanElement b) =>
      a.position == b.position &&
      a.rotation == b.rotation &&
      a.lens == b.lens &&
      a.stabilization == b.stabilization &&
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
