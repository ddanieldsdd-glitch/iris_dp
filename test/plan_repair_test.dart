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
import 'package:iris_dp/features/camera_plan/plan_repair.dart';

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

  PlanElement light(double x) =>
      PlanElement(id: 0, type: ElementType.light, position: Offset(x, 50));

  test('Madame Jasmine: un esquema por plano se junta en un set', () async {
    final setups = <LightSetup>[];
    final shots = <Shot>[];
    for (var i = 0; i < 4; i++) {
      final setup = await repo.createLightSetup(
        projectId: projectId,
        setId: setId,
      );
      final cam = camera('A', 10.0 * i)..props[LightOverrides.uidKey] = 'cam$i';
      await repo.saveElements(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: setup.id,
        elements: [
          cam,
          if (i == 2) ...[light(5), light(80)],
        ],
      );
      final shot = await newShot(i + 1);
      await links.setLinks(setup, cam, {shot.id}, [shot]);
      setups.add(setup);
      shots.add(shot);
    }
    final report = await PlanRepair(db).analyze(projectId);
    expect(report.assigns, isEmpty);
    final m = report.merges.single;
    expect(m.target.id, setups[2].id, reason: 'se queda el que tiene luz');
    expect(m.sources, hasLength(3));
    expect(m.shots, 4);

    await PlanRepair(db).merge(m.target.id, [for (final s in m.sources) s.id]);
    final left = await db.getLightSetupsForProject(projectId);
    expect(left.map((s) => s.id), [setups[2].id]);
    for (final shot in shots) {
      expect((await db.getShotById(shot.id))!.lightSetupId, setups[2].id);
    }
    final els = await repo.loadElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setups[2].id,
    );
    expect(els.where((e) => e.type == ElementType.light), hasLength(2));
    final cams = els.where((e) => e.type == ElementType.camera).toList();
    expect(cams.map((e) => e.cameraLetter).toSet(), {'A', 'B', 'C', 'D'});
    // Cada plano sigue con su cámara vinculada, con la letra nueva.
    for (final (i, shot) in shots.indexed) {
      final copy = (await shotCameras(shot.id)).single;
      expect(CameraLinks.setupCameraOf(copy), 'cam$i');
      final inSet = cams.firstWhere((c) => LightOverrides.uidOf(c) == 'cam$i');
      expect(copy.cameraLetter, inSet.cameraLetter);
    }
    // Lo quitado está en la papelera.
    final trash = await db.select(db.planTrash).get();
    expect(trash, hasLength(3));
  });

  test(
    'Calle Raval: un esquema dibujado sin planos se asigna a los sin luz',
    () async {
      final lit = await repo.createLightSetup(
        projectId: projectId,
        setId: setId,
      );
      await repo.saveElements(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: lit.id,
        elements: [light(0), light(40), camera('A', 10)],
      );
      final p1 = await newShot(1);
      final p2 = await newShot(2);
      final report = await PlanRepair(db).analyze(projectId);
      expect(report.merges, isEmpty);
      final a = report.assigns.single;
      expect(a.setup.id, lit.id);
      expect(a.shots.map((s) => s.id), [p1.id, p2.id]);
      await PlanRepair(db).assign(lit.id, [p1.id, p2.id]);
      expect((await db.getShotById(p2.id))!.lightSetupId, lit.id);
      expect((await PlanRepair(db).analyze(projectId)).isEmpty, isTrue);
    },
  );

  test('lo dibujado en la zona pasa al entorno de la localización', () async {
    final wall = PlanElement(
      id: 0,
      type: ElementType.wall,
      position: const Offset(100, 100),
    );
    await repo.saveElements(
      scope: FloorPlanScope.set,
      setId: setId,
      elements: [wall, light(10)],
    );
    final report = await PlanRepair(db).analyze(projectId);
    final z = report.zones.single;
    expect(z.zone.id, setId);
    expect(z.elements, 2);
    expect(z.alone, isTrue);

    await PlanRepair(db).foldZone(setId);
    final zone = await db.getLocationById(setId);
    expect(FloorPlanJson.decode(zone!.floorPlanJson), isEmpty);
    final env = await repo.loadElements(
      scope: FloorPlanScope.site,
      siteId: zone.siteId,
    );
    expect(env.map((e) => e.type), [ElementType.wall, ElementType.light]);
    expect(env.every((e) => LightOverrides.uidOf(e) != null), isTrue);
    expect((await PlanRepair(db).analyze(projectId)).zones, isEmpty);
  });
}
