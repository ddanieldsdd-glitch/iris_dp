import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('create group, project, duplicate and delete', () async {
    final groupId = await db.insertGroup(
      ProjectGroupsCompanion.insert(name: 'Rodajes 2025'),
    );

    final projectId = await db.insertProject(
      ProjectsCompanion.insert(
        name: 'Proyecto Test',
        director: const Value('Director Test'),
        groupId: Value(groupId),
        iconCode: const Value(0xe3f4),
      ),
    );

    var projects = await db.watchProjects().first;
    expect(projects.length, 1);
    expect(projects.first.name, 'Proyecto Test');
    expect(projects.first.groupId, groupId);

    final copyId = await db.duplicateProject(projectId);
    expect(copyId, greaterThan(0));

    projects = await db.watchProjects().first;
    expect(projects.length, 2);
    expect(projects.any((p) => p.name.contains('copia')), isTrue);

    await db.deleteProject(projectId);
    await db.deleteProject(copyId);

    projects = await db.watchProjects().first;
    expect(projects, isEmpty);

    await db.deleteGroup(groupId);
    final groups = await db.watchAllGroups().first;
    expect(groups, isEmpty);
  });

  test('duplicateProject copies floor plans and camera elements', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Original'),
    );
    final siteId = await db.insertSite(
      LocationSitesCompanion.insert(
        projectId: projectId,
        name: 'Sitio',
        floorPlanJson: const Value('{"version":1,"elements":[]}'),
      ),
    );
    final setId = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: 'Set',
        floorPlanJson: const Value(
          '{"version":1,"elements":[{"type":"wall","x":1,"y":2,"rotation":0,"cameraLetter":"A","cameraNumber":1,"pathPoints":[]}]}',
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
    final shotId = await db.insertShot(
      ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: 1,
      ),
    );
    await db.insertCameraPlanElement(
      CameraPlanElementsCompanion.insert(
        shotId: shotId,
        type: 'camera',
        cameraLetter: const Value('A'),
      ),
    );

    final copyId = await db.duplicateProject(projectId);
    expect(copyId, greaterThan(0));

    final copySites = await db.watchSitesForProject(copyId).first;
    expect(copySites.single.floorPlanJson, isNotEmpty);

    final copySets = await db.watchLocationsForProject(copyId).first;
    expect(copySets.single.floorPlanJson, contains('"wall"'));

    final copyShots = await db.getShotsForProject(copyId);
    final elements =
        await db.getCameraPlanElementsForShot(copyShots.single.id);
    expect(elements, hasLength(1));
    expect(elements.single.type, 'camera');
  });

  test('deleteShot removes camera plan elements', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Delete test'),
    );
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'E1',
        locationCanonical: 'INT. A - DÍA',
        locationPureName: 'A',
      ),
    );
    final shotId = await db.insertShot(
      ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: 1,
      ),
    );
    await db.insertCameraPlanElement(
      CameraPlanElementsCompanion.insert(
        shotId: shotId,
        type: 'light',
        lightType: const Value('fresnel_small'),
      ),
    );

    await db.deleteShot(shotId);

    final elements = await db.getCameraPlanElementsForShot(shotId);
    expect(elements, isEmpty);
  });
}
