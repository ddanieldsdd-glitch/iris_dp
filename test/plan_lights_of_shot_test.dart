import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/light_beam.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_renderer.dart';

/// B.1: los focos que ve un plano, con sus ajustes propios, salen igual en
/// el editor y en la planta del documento.
void main() {
  late AppDatabase db;
  late FloorPlanRepository repo;

  PlanElement light(double x, int intensity) => PlanElement(
    id: 0,
    type: ElementType.light,
    position: Offset(x, 100),
    lightType: LightType.fresnelMedium,
    props: {LightBeam.intensityKey: intensity},
  )..layer = PlanLayer.light;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FloorPlanRepository(db);
  });
  tearDown(() => db.close());

  test('un foco ajustado o apagado solo en un plano sale igual en el editor '
      'y en el PDF', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Prueba'),
    );
    final siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Nave'),
    );
    final setup = await repo.createLightSetup(
      projectId: projectId,
      siteId: siteId,
    );
    final groupId = await db.insertSetGroup(
      SetGroupsCompanion.insert(
        projectId: projectId,
        locationSiteId: Value(siteId),
        name: 'Fondo',
      ),
    );
    await db.assignLightSetupToGroup(setup.id, groupId);

    final env = [light(0, 60)];
    final group = [light(100, 80)];
    final own = [light(200, 90), light(300, 70)];
    LightOverrides.ensureUids([...env, ...group, ...own]);
    await repo.saveElements(
      scope: FloorPlanScope.site,
      siteId: siteId,
      elements: env,
    );
    await repo.saveGroupElements(groupId, group);
    await repo.saveElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setup.id,
      elements: own,
    );

    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'E1',
        locationCanonical: 'INT. NAVE',
        locationPureName: 'NAVE',
        locationSiteId: Value(siteId),
      ),
    );
    final one = await db.insertShot(
      ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: 1),
    );
    final two = await db.insertShot(
      ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: 2),
    );
    await db.assignLightSetupToShot(one, setup.id);
    await db.assignLightSetupToShot(two, setup.id);

    String uid(PlanElement el) => LightOverrides.uidOf(el)!;
    // Solo en el plano 1: el foco del grupo baja al 20 % y se mueve, uno
    // del esquema se apaga y el del entorno también.
    await repo.saveLightOverrides(one, {
      uid(group.single): LightOverrides.clone(group.single)
        ..position = const Offset(120, 140)
        ..props[LightBeam.intensityKey] = 20,
      uid(own.first): LightOverrides.clone(own.first)
        ..props[LightBeam.offKey] = true,
      uid(env.single): LightOverrides.clone(env.single)
        ..props[LightBeam.offKey] = true,
    });

    // Lo que ve cada foco: posición, intensidad y si está apagado.
    Map<String, (Offset, int, bool)> seen(Iterable<PlanElement> list) => {
      for (final el in list)
        if (el.type == ElementType.light)
          uid(el): (
            el.position,
            LightBeam.of(el)!.intensity.round(),
            LightBeam.of(el)!.off,
          ),
    };

    final renderer = await PlanRenderer.load(db, projectId);
    final data = renderer.data;
    for (final shotId in [one, two]) {
      final shot = data.shots.firstWhere((s) => s.id == shotId);
      final layers = await repo.layersForShot(shot);
      final editor = seen([
        ...layers.environment,
        ...layers.set,
        ...layers.groupLight,
        ...layers.light,
      ]);
      final picture = await renderer.shotPicture(shot);
      expect(seen(picture.elements), editor, reason: 'plano $shotId');
      expect(seen(data.lightsOfShot(shot)), editor, reason: 'plano $shotId');
    }

    final shotOne = data.shots.firstWhere((s) => s.id == one);
    final shotTwo = data.shots.firstWhere((s) => s.id == two);
    final inOne = seen(data.lightsOfShot(shotOne));
    expect(inOne, hasLength(4));
    expect(inOne[uid(group.single)], (const Offset(120, 140), 20, false));
    expect(inOne[uid(own.first)]!.$3, isTrue);
    expect(inOne[uid(env.single)]!.$3, isTrue);
    // El plano 2 no lleva los ajustes del 1.
    final inTwo = seen(data.lightsOfShot(shotTwo));
    expect(inTwo[uid(group.single)], (const Offset(100, 100), 80, false));
    expect(inTwo[uid(own.first)]!.$3, isFalse);
  });
}
