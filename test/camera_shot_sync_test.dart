import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/camera_links.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/camera_shot_sync.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_data.dart';
import 'package:iris_dp/features/camera_plan/plan_target.dart';
import 'package:iris_dp/features/camera_plan/plan_workspace_screen.dart';

void main() {
  late AppDatabase db;
  late FloorPlanRepository repo;
  late CameraLinks links;
  late int projectId;
  late int setId;
  late int sceneId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FloorPlanRepository(db);
    links = CameraLinks(db);
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Kebab Khaled'),
    );
    final siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Calle Raval'),
    );
    setId = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: 'Calle Raval',
      ),
    );
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena 1',
        locationCanonical: 'EXT. CALLE RAVAL - NOCHE',
        locationPureName: 'CALLE RAVAL',
        locationSiteId: Value(siteId),
        locationId: Value(setId),
      ),
    );
  });

  tearDown(() async => db.close());

  Future<Shot> newShot(int number) async {
    final id = await db.insertShot(
      ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: number,
      ),
    );
    return (await db.getShotById(id))!;
  }

  PlanElement camera(String letter, double x) => PlanElement(
    id: 0,
    type: ElementType.camera,
    position: Offset(x, 0),
    cameraLetter: letter,
    lens: '35mm',
    props: {LightOverrides.uidKey: 'cam$letter'},
  );

  Future<List<PlanElement>> shotCameras(int shotId) async => [
    for (final e in await repo.loadElements(
      scope: FloorPlanScope.shot,
      shotId: shotId,
    ))
      if (e.type == ElementType.camera) e,
  ];

  Future<Shot> shotWith(int number, {String? lens, String? movement}) async {
    final s = await newShot(number);
    await db.updateShotFields(
      s.id,
      ShotsCompanion(lens: Value(lens), movement: Value(movement)),
    );
    return (await db.getShotById(s.id))!;
  }

  Future<List<PlanElement>> setupCameras(int setupId) async => [
    for (final e in await repo.loadElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setupId,
    ))
      if (e.type == ElementType.camera) e,
  ];

  test(
    'focal y movimiento: se comparan por su número y sus palabras',
    () async {
      expect(CameraShotSync.focalOf('Mm 50'), 50);
      expect(CameraShotSync.lensLabel('35MM'), '35mm');
      expect(CameraShotSync.lensLabel('sss'), isNull);
      expect(CameraShotSync.isHandheld('mano'), isTrue);
      final cam = camera('A', 0)..stabilization = 'STEADY';
      final shot = await shotWith(1, lens: '35 mm', movement: 'MANO');
      expect(CameraShotSync.conflicts(cam, shot), isTrue);
      expect(CameraShotSync.cameraFromShot(cam, shot), isTrue);
      expect(cam.lens, '35mm');
      expect(cam.stabilization, 'MANO');
      expect(CameraShotSync.conflicts(cam, shot), isFalse);
    },
  );

  test(
    'al vincular, la cámara toma lo del guion y el plano lo que le falta',
    () async {
      final setup = await repo.createLightSetup(
        projectId: projectId,
        setId: setId,
      );
      final cam = camera('A', 10)..stabilization = 'TRÍPODE';
      await repo.saveElements(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: setup.id,
        elements: [cam],
      );
      final withData = await shotWith(1, lens: '85mm', movement: 'MANO');
      final empty = await shotWith(2);
      await links.setLinks(
        setup,
        cam,
        {withData.id, empty.id},
        [withData, empty],
      );
      final c1 = (await shotCameras(withData.id)).single;
      expect(c1.lens, '85mm');
      expect(c1.stabilization, 'MANO');
      final s2 = (await db.getShotById(empty.id))!;
      expect(s2.lens, '35mm');
      expect(s2.movement, 'TRÍPODE');
      // Con «la de la planta», el plano toma lo de la cámara.
      final other = await shotWith(3, lens: '50mm');
      await links.setLinks(
        setup,
        cam,
        {withData.id, empty.id, other.id},
        [withData, empty, other],
        source: CameraShotSource.plan,
      );
      expect((await db.getShotById(other.id))!.lens, '35mm');
    },
  );

  test(
    'cambiar la focal en el set la cambia en sus planos y en el guion',
    () async {
      final setup = await repo.createLightSetup(
        projectId: projectId,
        setId: setId,
      );
      final cam = camera('A', 10);
      await repo.saveElements(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: setup.id,
        elements: [cam],
      );
      final p1 = await shotWith(1);
      await links.setLinks(setup, cam, {p1.id}, [p1]);
      // El plano mueve su copia: aun así sigue la focal del set.
      final own = await repo.loadElements(
        scope: FloorPlanScope.shot,
        shotId: p1.id,
      );
      own.single.position = const Offset(500, 500);
      await repo.saveElements(
        scope: FloorPlanScope.shot,
        shotId: p1.id,
        elements: own,
      );
      final edited = (await setupCameras(setup.id)).single..lens = '50mm';
      await repo.saveElements(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: setup.id,
        elements: [edited],
      );
      final copy = (await shotCameras(p1.id)).single;
      expect(copy.lens, '50mm');
      expect(copy.position, const Offset(500, 500));
      expect((await db.getShotById(p1.id))!.lens, '50mm');
    },
  );

  test(
    'cambiar la focal en el guion mueve la cámara del plano y la del set',
    () async {
      final setup = await repo.createLightSetup(
        projectId: projectId,
        setId: setId,
      );
      final cam = camera('A', 10);
      await repo.saveElements(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: setup.id,
        elements: [cam],
      );
      final p1 = await shotWith(1, lens: '35mm');
      await links.setLinks(setup, cam, {p1.id}, [p1]);
      final before = (await db.getShotById(p1.id))!;
      await db.updateShotFields(
        p1.id,
        const ShotsCompanion(lens: Value('24mm'), movement: Value('MANO')),
      );
      await links.followShot(p1.id, before);
      final copy = (await shotCameras(p1.id)).single;
      expect(copy.lens, '24mm');
      expect(copy.stabilization, 'MANO');
      final inSet = (await setupCameras(setup.id)).single;
      expect(inSet.lens, '24mm');
    },
  );

  test('la tira del editor: los planos de la escena o los del set', () async {
    final setup = await repo.createLightSetup(
      projectId: projectId,
      setId: setId,
    );
    final p1 = await newShot(1);
    final p2 = await newShot(2);
    final p3 = await newShot(3);
    await db.assignLightSetupToShot(p1.id, setup.id);
    await db.assignLightSetupToShot(p3.id, setup.id);
    final data = PlanProjectData(
      sites: await db.watchSitesForProject(projectId).first,
      sets: await db.watchLocationsForProject(projectId).first,
      setups: await db.getLightSetupsForProject(projectId),
      scenes: await db.watchScenesForProject(projectId).first,
      shots: await db.watchShotsForProject(projectId).first,
    );
    final (sceneTitle, sceneShots) = PlanShotStrip.shotsFor(
      data,
      PlanTarget.shot(p2.id, 'P2'),
    );
    expect(sceneTitle, 'Esc 1');
    expect(sceneShots.map((s) => s.id), [p1.id, p2.id, p3.id]);
    final (_, setShots) = PlanShotStrip.shotsFor(
      data,
      PlanTarget.lightSetup(setup.id, 'Setup A'),
    );
    expect(setShots.map((s) => s.id), [p1.id, p3.id]);
  });
}
