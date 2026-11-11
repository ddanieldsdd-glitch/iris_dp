import '../../../core/database/app_database.dart';
import '../camera_links.dart';
import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../floor_plan_scope.dart';
import '../light_overrides.dart';
import '../plan_data.dart';
import '../plan_target.dart';
import 'plan_scene3d.dart';

/// Un plano en la tira del 3D (ED.3).
class Plan3dShot {
  final PlanTarget target;

  /// Rótulo corto: «3·2».
  final String tag;

  /// Letras de sus cámaras (A, B…).
  final List<String> letters;

  /// Cámaras suyas que están en este 3D, por su identificador del visor.
  /// Vacío: hay que abrir su planta para verlo.
  final List<String> cameraIds;

  /// Es el plano abierto.
  final bool open;

  const Plan3dShot({
    required this.target,
    required this.tag,
    required this.letters,
    required this.cameraIds,
    required this.open,
  });
}

/// Otro sitio al que saltar sin salir del 3D: un set de la localización o
/// una escena del set.
class Plan3dJump {
  final PlanTarget target;
  final String label;
  final bool current;

  const Plan3dJump(this.target, this.label, {this.current = false});
}

/// Lo que enseña la tira del 3D: los planos del set (o de la escena del
/// plano abierto), los sets de la localización y las escenas del set.
class Plan3dNav {
  final String title;
  final List<Plan3dShot> shots;
  final List<Plan3dJump> sets;
  final List<Plan3dJump> scenes;

  const Plan3dNav({
    required this.title,
    required this.shots,
    this.sets = const [],
    this.scenes = const [],
  });

  /// La tira para [target] con los [elements] que tiene el 3D. Nula fuera de
  /// un set o un plano.
  static Plan3dNav? of(
    PlanProjectData data,
    PlanTarget target,
    List<PlanElement> elements,
  ) {
    final LightSetup? setup;
    final List<Shot> shots;
    final String title;
    Scene? openScene;
    switch (target.scope) {
      case FloorPlanScope.lightSetup:
        setup = data.setup(target.id);
        if (setup == null) return null;
        shots = data.shotsOfSetup(setup.id);
        title = setup.name;
      case FloorPlanScope.shot:
        final shot = data.shots.where((s) => s.id == target.id).firstOrNull;
        openScene = data.scene(shot?.sceneId);
        if (shot == null || openScene == null) return null;
        setup = data.setup(shot.lightSetupId);
        shots = data.shotsOfScenes([openScene]);
        title = 'Esc ${openScene.label}';
      case FloorPlanScope.site || FloorPlanScope.set:
        return null;
    }

    // Identificador del visor de cada cámara de este 3D, por el de la
    // cámara del set (las copias de un plano lo llevan en `setupCamera`).
    final bySetupUid = <String, String>{};
    final shotCameras = <String>[];
    for (final (i, el) in elements.indexed) {
      if (el.type != ElementType.camera) continue;
      final id = PlanScene3d.idOf(el, i);
      final uid = LightOverrides.uidOf(el);
      if (uid != null) bySetupUid[uid] = id;
      final copyOf = CameraLinks.setupCameraOf(el);
      if (copyOf != null) bySetupUid.putIfAbsent(copyOf, () => id);
      shotCameras.add(id);
    }

    final list = <Plan3dShot>[];
    for (final shot in shots) {
      final open = target.scope == FloorPlanScope.shot && shot.id == target.id;
      final own = data
          .ownOfShot(shot)
          .where((e) => e.type == ElementType.camera);
      final ids = open
          ? shotCameras
          : [
              for (final cam in own)
                if (bySetupUid[CameraLinks.setupCameraOf(cam)] case final id?)
                  id,
            ];
      final sceneLabel = data.scene(shot.sceneId)?.label;
      list.add(
        Plan3dShot(
          target: PlanTarget.shot(shot.id, data.shotLabel(shot)),
          tag: sceneLabel == null
              ? 'P${shot.number}'
              : '$sceneLabel·${shot.number}',
          letters: data.camerasOfShot(shot),
          cameraIds: ids.toSet().toList(),
          open: open,
        ),
      );
    }

    final siteId = setup == null ? null : data.siteIdOfSetup(setup);
    final sets = setup == null
        ? const <LightSetup>[]
        : siteId == null
        ? [setup]
        : data.lightSetsOfSite(siteId);
    final scenes = setup == null
        ? const <Scene>[]
        : data.scenesOfSetup(setup.id);
    return Plan3dNav(
      title: title,
      shots: list,
      sets: [
        for (final s in sets)
          Plan3dJump(
            PlanTarget.lightSetup(s.id, s.name),
            s.name,
            current:
                target.scope == FloorPlanScope.lightSetup && s.id == target.id,
          ),
      ],
      scenes: [
        for (final sc in scenes)
          if (data
                  .shotsOfSetup(setup!.id)
                  .where((s) => s.sceneId == sc.id)
                  .firstOrNull
              case final first?)
            Plan3dJump(
              PlanTarget.shot(first.id, data.shotLabel(first)),
              'Esc ${sc.label}',
              current: sc.id == openScene?.id,
            ),
      ],
    );
  }
}
