import 'package:drift/drift.dart';
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

  test('hereda planta del set al plano vacío', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Jerarquía'),
    );
    final siteId = await db.insertSite(
      LocationSitesCompanion.insert(
        projectId: projectId,
        name: 'Bosque',
      ),
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
      ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: 1,
      ),
    );

    final scene = await (db.select(db.scenes)
          ..where((s) => s.id.equals(sceneId)))
        .getSingle();

    final seeded = await repo.seedShotFromSceneTemplate(shotId, scene);
    expect(seeded, isTrue);

    final elements = await repo.loadElements(
      scope: FloorPlanScope.shot,
      shotId: shotId,
    );
    expect(elements, hasLength(1));
    expect(elements.first.type, ElementType.wall);
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
    final scene = await (db.select(db.scenes)
          ..where((s) => s.id.equals(sceneId)))
        .getSingle();

    final json = await repo.resolveTemplateJsonForScene(scene);
    expect(json, contains('"prop"'));
  });
}
