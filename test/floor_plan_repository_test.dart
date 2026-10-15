import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';

void main() {
  late AppDatabase db;
  late FloorPlanRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FloorPlanRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('un set se copia con su planta y sus esquemas, y al borrarlo sus '
      'planos vuelven al set de su escena', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Copias'),
    );
    final siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Bosque'),
    );
    final otherSite = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Playa'),
    );
    final setId = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: 'Río',
        floorPlanJson: const Value('{"version":2,"elements":[]}'),
        sitePlacementJson: const Value('{"x":1}'),
      ),
    );
    final setup = await repo.createLightSetup(
      projectId: projectId,
      setId: setId,
    );
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena 1',
        locationCanonical: 'EXT. RÍO - DÍA',
        locationPureName: 'RÍO',
        locationSiteId: Value(siteId),
      ),
    );
    final shotId = await db.insertShot(
      ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: 1),
    );
    await db.moveShot(shotId, setId: setId, lightSetupId: setup.id);

    // Duplicado en su localización: nombre nuevo, misma zona.
    final source = (await db.getLocationById(setId))!;
    final twin = await repo.copySet(source);
    expect(twin.locationName, 'Río (copia)');
    expect(twin.siteId, siteId);
    expect(twin.floorPlanJson, source.floorPlanJson);
    expect(twin.sitePlacementJson, source.sitePlacementJson);
    // Pegado en otra: conserva el nombre y pierde la zona.
    final pasted = await repo.copySet(
      source,
      siteId: otherSite,
      keepSite: false,
    );
    expect(pasted.locationName, 'Río');
    expect(pasted.siteId, otherSite);
    expect(pasted.sitePlacementJson, isNull);
    final setups = await db.getLightSetupsForProject(projectId);
    expect(
      setups.where((s) => s.locationBasePlanId == pasted.id).single.name,
      'Setup A',
    );

    // Un esquema pegado en las plantas libres no es de ningún set.
    final free = await repo.copyLightSetup(setup);
    expect(free.locationBasePlanId, isNull);
    expect(free.locationSiteId, isNull);
    expect(free.name, 'Setup A');

    await repo.deleteSet(source);
    expect(await db.getLocationById(setId), isNull);
    final shot = (await db.getShotById(shotId))!;
    expect(shot.locationBasePlanId, isNull);
    expect(shot.lightSetupId, isNull);
    expect(await db.getLightSetupById(setup.id), isNull);
  });

  test('el plano vacío ve la planta del set', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Jerarquía'),
    );
    final siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Bosque'),
    );
    final setId = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: 'Río',
      ),
    );
    await db.saveFloorPlanToSet(
      setId,
      '{"version":1,"elements":[{"type":"wall","x":100,"y":100,"rotation":0,"label":"wall","cameraLetter":"A","cameraNumber":1,"pathPoints":[]}]}',
    );

    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena 1',
        locationCanonical: 'EXT. RÍO - DÍA',
        locationPureName: 'RÍO',
        locationSiteId: Value(siteId),
        locationId: Value(setId),
      ),
    );
    final shotId = await db.insertShot(
      ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: 1),
    );

    final shot = await (db.select(
      db.shots,
    )..where((s) => s.id.equals(shotId))).getSingle();

    // El plano ve la planta del set por referencia, sin copiarla.
    final layers = await repo.layersForShot(shot);
    expect(layers.set, hasLength(1));
    expect(layers.set.first.type, ElementType.wall);

    final own = await repo.loadElements(
      scope: FloorPlanScope.shot,
      shotId: shotId,
    );
    expect(own, isEmpty);
  });

  test('resolveTemplateJsonForScene prefiere set sobre sitio', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Prioridad'),
    );
    final siteId = await db.insertSite(
      LocationSitesCompanion.insert(
        projectId: projectId,
        name: 'Sitio',
        floorPlanJson: const Value(
          '{"version":1,"elements":[{"type":"wall","x":0,"y":0,"rotation":0,"cameraLetter":"A","cameraNumber":1,"pathPoints":[]}]}',
        ),
      ),
    );
    final setId = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: 'Set A',
        floorPlanJson: const Value(
          '{"version":1,"elements":[{"type":"prop","x":10,"y":10,"rotation":0,"label":"table","cameraLetter":"A","cameraNumber":1,"pathPoints":[]}]}',
        ),
      ),
    );
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'E1',
        locationCanonical: 'INT. SET - DÍA',
        locationPureName: 'SET',
        locationSiteId: Value(siteId),
        locationId: Value(setId),
      ),
    );
    final scene = await (db.select(
      db.scenes,
    )..where((s) => s.id.equals(sceneId))).getSingle();

    final json = await repo.resolveTemplateJsonForScene(scene);
    expect(json, contains('"prop"'));
  });
}
