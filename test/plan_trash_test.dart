import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/plan_trash_service.dart';

const _plan = '{"version":2,"elements":[{"type":"wall","x":1,"y":1}]}';

void main() {
  late AppDatabase db;
  late PlanTrashService trash;
  late int projectId;
  late int siteId;
  late int kitchenId;
  late int gardenId;
  late int setupId;
  late int sceneId;
  late List<int> kitchenShots;
  late int gardenShot;

  Future<int> addShot(int number, {int? setId, int? lightSetupId}) =>
      db.insertShot(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: number,
          locationBasePlanId: Value(setId),
          lightSetupId: Value(lightSetupId),
        ),
      );

  Future<void> addCamera(int shotId) async {
    final id = await db.insertCameraPlanElement(
      CameraPlanElementsCompanion.insert(shotId: shotId, type: 'camera'),
    );
    await db
        .into(db.cameraPathPoints)
        .insert(
          CameraPathPointsCompanion.insert(
            elementId: id,
            pointNumber: 1,
            x: 2,
            y: 3,
          ),
        );
  }

  Future<List<CameraPlanElement>> elementsOf(int shotId) => (db.select(
    db.cameraPlanElements,
  )..where((e) => e.shotId.equals(shotId))).get();

  Future<Shot> shot(int id) =>
      (db.select(db.shots)..where((s) => s.id.equals(id))).getSingle();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    trash = PlanTrashService(db);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
    siteId = await db.insertSite(
      LocationSitesCompanion.insert(
        projectId: projectId,
        name: 'Casa',
        floorPlanJson: const Value(_plan),
      ),
    );
    kitchenId = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: 'Cocina',
        floorPlanJson: const Value(_plan),
        sitePlacementJson: const Value('{"x":0,"y":0,"w":10,"h":10}'),
      ),
    );
    gardenId = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: 'Jardín',
      ),
    );
    setupId = await db.insertLightSetup(
      LightSetupsCompanion.insert(
        projectId: projectId,
        name: 'Setup A',
        locationBasePlanId: Value(kitchenId),
        planJson: const Value(_plan),
      ),
    );
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 2,
        name: 'Escena 2',
        locationCanonical: 'INT. CASA - DÍA',
        locationPureName: 'COCINA',
        locationSiteId: Value(siteId),
        locationId: Value(kitchenId),
      ),
    );
    // Dos planos en la cocina por su escena (uno con esquema), uno con el
    // set puesto a mano, y uno en el jardín.
    kitchenShots = [
      await addShot(1, lightSetupId: setupId),
      await addShot(2),
      await addShot(3, setId: kitchenId, lightSetupId: setupId),
    ];
    gardenShot = await addShot(4, setId: gardenId);
    for (final id in [...kitchenShots, gardenShot]) {
      await addCamera(id);
    }
    await db.saveProjectAnnotationDocument(
      projectId: projectId,
      targetType: 'camera_plan_set',
      targetId: '$kitchenId',
      documentJson: '{"strokes":[]}',
      documentSchemaVersion: 1,
    );
  });

  tearDown(() => db.close());

  test('borrar un set deja sus planos sin planta, y restaurarlo los '
      'devuelve', () async {
    final impact = await trash.impactOfSet(kitchenId);
    expect(impact.setups, 1);
    expect(impact.shots, ['Esc 2 · Plano 1', 'Esc 2 · Plano 2', 'Esc 2 · Plano 3']);

    final trashId = await trash.deleteSet(kitchenId);
    expect(trashId, isNotNull);
    expect(await db.getLocationById(kitchenId), isNull);
    expect(await db.getLightSetupById(setupId), isNull);
    for (final id in kitchenShots) {
      final s = await shot(id);
      expect(s.locationBasePlanId, isNull);
      expect(s.lightSetupId, isNull);
      expect(await elementsOf(id), isEmpty);
    }
    final scene = await (db.select(
      db.scenes,
    )..where((s) => s.id.equals(sceneId))).getSingle();
    expect(scene.locationId, isNull);
    // El jardín no se toca.
    expect(await elementsOf(gardenShot), hasLength(1));
    expect(await db.select(db.cameraPathPoints).get(), hasLength(1));

    final result = await trash.restore(trashId!);
    expect(result.notice, isNull);
    final set = await db.getLocationById(kitchenId);
    expect(set?.locationName, 'Cocina');
    expect(set?.siteId, siteId);
    expect(set?.floorPlanJson, _plan);
    expect(set?.sitePlacementJson, isNotNull);
    expect((await db.getLightSetupById(setupId))?.planJson, _plan);
    expect((await shot(kitchenShots[0])).lightSetupId, setupId);
    expect((await shot(kitchenShots[2])).locationBasePlanId, kitchenId);
    for (final id in kitchenShots) {
      expect(await elementsOf(id), hasLength(1));
    }
    expect(await db.select(db.cameraPathPoints).get(), hasLength(4));
    final restoredScene = await (db.select(
      db.scenes,
    )..where((s) => s.id.equals(sceneId))).getSingle();
    expect(restoredScene.locationId, kitchenId);
    final drawing = await db.getProjectAnnotationDocument(
      projectId: projectId,
      targetType: 'camera_plan_set',
      targetId: '$kitchenId',
    );
    expect(drawing, isNotNull);
    expect(await db.select(db.planTrash).get(), isEmpty);
  });

  test('borrar la localización arrastra todos sus sets', () async {
    final impact = await trash.impactOfSite(siteId);
    expect(impact.sets, 2);
    expect(impact.shots, hasLength(4));

    final trashId = await trash.deleteSite(siteId);
    expect(await db.getSiteById(siteId), isNull);
    expect(await db.getLocationById(kitchenId), isNull);
    expect(await db.getLocationById(gardenId), isNull);
    expect(await db.select(db.cameraPlanElements).get(), isEmpty);
    expect(await db.select(db.planTrash).get(), hasLength(1));

    await trash.restore(trashId!);
    expect((await db.getSiteById(siteId))?.floorPlanJson, _plan);
    expect((await db.getLocationById(gardenId))?.siteId, siteId);
    expect((await shot(gardenShot)).locationBasePlanId, gardenId);
    expect(await db.select(db.cameraPlanElements).get(), hasLength(4));
  });

  test('un plano reasignado entretanto se queda como está', () async {
    final trashId = await trash.deleteSet(kitchenId);
    await db.moveShot(kitchenShots[1], setId: gardenId, lightSetupId: null);

    final result = await trash.restore(trashId!);
    expect(result.keptShots, ['Esc 2 · Plano 2']);
    expect(result.notice, contains('Esc 2 · Plano 2'));
    expect((await shot(kitchenShots[1])).locationBasePlanId, gardenId);
    expect(await elementsOf(kitchenShots[1]), isEmpty);
    expect(await elementsOf(kitchenShots[0]), hasLength(1));
  });

  test('un set restaurado sin su localización vuelve suelto', () async {
    final setTrash = await trash.deleteSet(gardenId);
    await trash.deleteSite(siteId);

    final result = await trash.restore(setTrash!);
    expect(result.orphanSets, ['Jardín']);
    expect((await db.getLocationById(gardenId))?.siteId, isNull);
  });

  test('vaciar una planta y devolverla', () async {
    final cleared = await trash.clearPlan(FloorPlanScope.set, kitchenId);
    expect(cleared, isNotNull);
    expect((await db.getLocationById(kitchenId))?.floorPlanJson, isNull);
    expect(
      await db.getProjectAnnotationDocument(
        projectId: projectId,
        targetType: 'camera_plan_set',
        targetId: '$kitchenId',
      ),
      isNull,
    );
    // Ya vacía: no hay nada que llevar a la papelera.
    expect(await trash.clearPlan(FloorPlanScope.set, kitchenId), isNull);

    // Se empieza de nuevo y luego se restaura: lo nuevo va a la papelera.
    await db.saveFloorPlanToSet(kitchenId, '{"version":2,"elements":[]}');
    await trash.restore(cleared!);
    expect((await db.getLocationById(kitchenId))?.floorPlanJson, _plan);
    final entries = await db.select(db.planTrash).get();
    expect(entries, hasLength(1));
    expect(entries.single.kind, PlanTrashService.kindPlanContents);
  });

  test('vaciar la planta de un plano quita sus cámaras', () async {
    final cleared = await trash.clearPlan(
      FloorPlanScope.shot,
      kitchenShots[0],
    );
    expect(await elementsOf(kitchenShots[0]), isEmpty);
    // Sigue en su set y con su esquema.
    expect((await shot(kitchenShots[0])).lightSetupId, setupId);
    await trash.restore(cleared!);
    expect(await elementsOf(kitchenShots[0]), hasLength(1));
  });

  test('borrar un esquema deja los planos sin luz pero con cámaras', () async {
    final trashId = await trash.deleteLightSetup(setupId);
    expect((await shot(kitchenShots[0])).lightSetupId, isNull);
    expect(await elementsOf(kitchenShots[0]), hasLength(1));
    await trash.restore(trashId!);
    expect((await shot(kitchenShots[0])).lightSetupId, setupId);
    expect((await shot(kitchenShots[2])).lightSetupId, setupId);
  });

  test('la papelera se vacía sola a los 30 días', () async {
    await trash.deleteSet(gardenId);
    await trash.purgeExpired(
      projectId,
      now: DateTime.now().add(const Duration(days: 31)),
    );
    expect(await db.select(db.planTrash).get(), isEmpty);
  });
}
