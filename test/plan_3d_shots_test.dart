import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/camera_links.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_data.dart';
import 'package:iris_dp/features/camera_plan/plan_target.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_3d_shots.dart';

/// ED.3: la tira de planos del 3D sabe qué cámara del visor es la de cada
/// plano y adónde se puede saltar.
void main() {
  late AppDatabase db;
  late FloorPlanRepository repo;
  late int projectId, siteId, setId, sceneId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FloorPlanRepository(db);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'KK'));
    siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Bar'),
    );
    setId = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: 'Bar',
      ),
    );
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 4,
        name: 'Escena 4',
        locationCanonical: 'INT. BAR - NOCHE',
        locationPureName: 'BAR',
        locationSiteId: Value(siteId),
        locationId: Value(setId),
      ),
    );
  });
  tearDown(() => db.close());

  Future<Shot> shot(int n) async => (await db.getShotById(
    await db.insertShot(
      ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: n),
    ),
  ))!;

  PlanElement camera(String letter, double x) => PlanElement(
    id: 0,
    type: ElementType.camera,
    position: Offset(x, 0),
    cameraLetter: letter,
    props: {LightOverrides.uidKey: 'cam$letter'},
  )..layer = PlanLayer.light;

  test(
    'en el set, cada plano salta a su cámara; sin cámara, a su planta',
    () async {
      final setup = await repo.createLightSetup(
        projectId: projectId,
        setId: setId,
      );
      final a = camera('A', 10), b = camera('B', 90);
      await repo.saveElements(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: setup.id,
        elements: [a, b],
      );
      final p1 = await shot(1), p2 = await shot(2), p3 = await shot(3);
      final links = CameraLinks(db);
      await links.setLinks(setup, a, {p1.id}, [p1, p2, p3]);
      await links.setLinks(setup, b, {p2.id}, [p1, p2, p3]);
      // El plano 3 también es del set, aunque aún sin cámara.
      await db.updateShotFields(
        p3.id,
        ShotsCompanion(lightSetupId: Value(setup.id)),
      );

      final data = await PlanProjectData.load(db, projectId);
      final setElements = await repo.loadElements(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: setup.id,
      );
      final nav = Plan3dNav.of(
        data,
        PlanTarget.lightSetup(setup.id, 'Set'),
        setElements,
      )!;
      expect([for (final s in nav.shots) s.tag], ['4·1', '4·2', '4·3']);
      expect(nav.shots[0].cameraIds, ['camA']);
      expect(nav.shots[0].letters, ['A']);
      expect(nav.shots[1].cameraIds, ['camB']);
      expect(nav.shots[2].cameraIds, isEmpty);
      expect(nav.shots.any((s) => s.open), isFalse);
      expect(nav.sets.single.current, isTrue);
      expect(nav.scenes.single.label, 'Esc 4');

      // En la planta del plano 1, su cámara es la de su copia; las de los
      // demás planos no están en este 3D.
      final own = await repo.loadElements(
        scope: FloorPlanScope.shot,
        shotId: p1.id,
      );
      final inShot = Plan3dNav.of(data, PlanTarget.shot(p1.id, 'P1'), own)!;
      expect(inShot.title, 'Esc 4');
      expect(inShot.shots.first.open, isTrue);
      expect(inShot.shots.first.cameraIds, hasLength(1));
      expect(inShot.shots[1].cameraIds, isEmpty);
      expect(inShot.scenes.single.current, isTrue);
    },
  );

  test('fuera de un set o un plano no hay tira', () async {
    final data = await PlanProjectData.load(db, projectId);
    expect(
      Plan3dNav.of(data, PlanTarget.site(siteId, 'Bar'), const []),
      isNull,
    );
  });
}
