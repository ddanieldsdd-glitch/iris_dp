import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/camera_links.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_guide.dart';

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

  test('una cámara del esquema va a varios planos y un plano lleva A y B', () async {
    final setup = await repo.createLightSetup(
      projectId: projectId,
      setId: setId,
    );
    final camA = camera('A', 10);
    final camB = camera('B', 90);
    await repo.saveElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setup.id,
      elements: [camA, camB],
    );
    final p1 = await newShot(1);
    final p2 = await newShot(2);

    final options = await links.linkableShots(setup, 'camA');
    expect(options.map((o) => o.shot.id), [p1.id, p2.id]);
    expect(options.any((o) => o.linked), isFalse);

    await links.setLinks(setup, camA, {p1.id, p2.id}, [p1, p2]);
    await links.setLinks(setup, camB, {p1.id}, [p1, p2]);

    final p1Cams = await shotCameras(p1.id);
    expect(p1Cams.map((e) => e.cameraLetter).toSet(), {'A', 'B'});
    expect(p1Cams.map(CameraLinks.setupCameraOf).toSet(), {'camA', 'camB'});
    // Las copias tienen identidad propia.
    expect(p1Cams.map(LightOverrides.uidOf), isNot(contains('camA')));
    expect((await shotCameras(p2.id)).single.cameraLetter, 'A');
    // Los planos vinculados usan esta luz.
    expect((await db.getShotById(p1.id))!.lightSetupId, setup.id);
    expect((await db.getShotById(p2.id))!.lightSetupId, setup.id);

    final again = await links.linkableShots(setup, 'camA');
    expect(again.every((o) => o.linked), isTrue);

    // Desvincular quita solo esa copia.
    await links.setLinks(setup, camA, {p2.id}, [p1, p2]);
    expect((await shotCameras(p1.id)).single.cameraLetter, 'B');
    expect((await shotCameras(p2.id)).single.cameraLetter, 'A');
  });

  test('las copias siguen a su cámara salvo si el plano la movió', () async {
    final setup = await repo.createLightSetup(
      projectId: projectId,
      setId: setId,
    );
    final camA = camera('A', 10);
    await repo.saveElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setup.id,
      elements: [camA],
    );
    final p1 = await newShot(1);
    final p2 = await newShot(2);
    await links.setLinks(setup, camA, {p1.id, p2.id}, [p1, p2]);

    // P2 mueve su cámara a mano.
    final own = await repo.loadElements(
      scope: FloorPlanScope.shot,
      shotId: p2.id,
    );
    own.single.position = const Offset(300, 300);
    await repo.saveElements(
      scope: FloorPlanScope.shot,
      shotId: p2.id,
      elements: own,
    );

    // En la planta de luz se mueve la cámara A.
    final setupNow = (await db.getLightSetupById(setup.id))!;
    final moved = FloorPlanJson.decode(setupNow.planJson).single
      ..position = const Offset(40, 5)
      ..lens = '50mm';
    await repo.saveElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setup.id,
      elements: [moved],
    );

    final c1 = (await shotCameras(p1.id)).single;
    expect(c1.position, const Offset(40, 5));
    expect(c1.lens, '50mm');
    expect((await shotCameras(p2.id)).single.position, const Offset(300, 300));
  });

  test('al llevar un plano al set, toma su único esquema de luz', () async {
    final setup = await repo.createLightSetup(
      projectId: projectId,
      setId: setId,
    );
    final p1 = await newShot(1);
    final set = (await db.getLocationById(setId))!;
    await associateShotsToSet(db, set, [p1]);
    expect((await db.getShotById(p1.id))!.lightSetupId, setup.id);
    // Y lleva cámara, que se ve en esa planta de luz.
    expect(await shotCameras(p1.id), hasLength(1));
  });

  test('con dos esquemas en el set, no elige ninguno', () async {
    await repo.createLightSetup(projectId: projectId, setId: setId);
    await repo.createLightSetup(projectId: projectId, setId: setId);
    final p1 = await newShot(1);
    final set = (await db.getLocationById(setId))!;
    await associateShotsToSet(db, set, [p1]);
    expect((await db.getShotById(p1.id))!.lightSetupId, isNull);
  });
}
