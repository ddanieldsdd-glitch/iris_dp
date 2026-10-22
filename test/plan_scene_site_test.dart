import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/core/utils/shot_reference_import.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/plan_guide.dart';

void main() {
  late AppDatabase db;
  late int projectId;
  late int wrongSite;
  late int rightSite;
  late int wrongSet;
  late int setupId;
  late int sceneId;
  late int shotId;

  Future<Scene> scene() =>
      (db.select(db.scenes)..where((s) => s.id.equals(sceneId))).getSingle();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'L'));
    wrongSite = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Hospital'),
    );
    rightSite = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Casa'),
    );
    wrongSet = await db.insertSetUnderSite(
      projectId: projectId,
      siteId: wrongSite,
      name: 'Urgencias',
    );
    setupId = (await FloorPlanRepository(
      db,
    ).createLightSetup(projectId: projectId, setId: wrongSet)).id;
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 4,
        name: 'Escena 4',
        locationCanonical: 'INT. CASA - NOCHE',
        locationPureName: 'CASA',
        locationSiteId: Value(wrongSite),
        locationId: Value(wrongSet),
      ),
    );
    shotId = await db.insertShot(
      ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: 1,
        locationBasePlanId: Value(wrongSet),
        lightSetupId: Value(setupId),
      ),
    );
    await db.insertCameraPlanElement(
      CameraPlanElementsCompanion.insert(shotId: shotId, type: 'camera'),
    );
  });

  tearDown(() => db.close());

  test('cambiar la localización deja el set y la luz de la anterior, y se '
      'puede deshacer', () async {
    final change = await applySceneSite(db, await scene(), rightSite);
    var s = await scene();
    expect(s.locationSiteId, rightSite);
    expect(s.locationId, isNull);
    var shot = (await db.getShotById(shotId))!;
    expect(shot.locationBasePlanId, isNull);
    expect(shot.lightSetupId, isNull);
    // Las cámaras se quedan.
    expect(await db.getCameraPlanElementsForShot(shotId), hasLength(1));
    expect(await siteIsUnused(db, wrongSite), isTrue);
    expect(await siteIsUnused(db, rightSite), isFalse);

    await change.undo(db);
    s = await scene();
    expect(s.locationSiteId, wrongSite);
    expect(s.locationId, wrongSet);
    shot = (await db.getShotById(shotId))!;
    expect(shot.locationBasePlanId, wrongSet);
    expect(shot.lightSetupId, setupId);
  });

  test('los bocetos que enseña un plano llegan al boceto correcto en otro '
      'equipo', () async {
    final repo = FloorPlanRepository(db);
    // Uno antes, para que los ids no coincidan al importar.
    await repo.createLightSetup(projectId: projectId, name: 'Otro');
    final sketch = await repo.createLightSetup(
      projectId: projectId,
      name: 'Boceto · Esc 4',
      kind: LightSetupKind.sketchFreehand,
      sceneId: sceneId,
    );
    await addShotPlanSketchSetup(
      db: db,
      shot: (await db.getShotById(shotId))!,
      setupId: sketch.id,
    );
    final bundle = await ProjectContentBundle.export(db, projectId);
    final target = await db.insertProject(ProjectsCompanion.insert(name: 'o'));
    // En el otro equipo ya hay esquemas: los ids no coinciden.
    await repo.createLightSetup(projectId: target, name: 'De antes');
    await ProjectContentBundle.importBundle(db, target, bundle);

    final imported = (await db.getLightSetupsForProject(
      target,
    )).singleWhere((s) => s.name == 'Boceto · Esc 4');
    final shot = (await db.getShotsForProject(target)).single;
    expect(planSketchEntriesOf(shot), ['setup:${imported.id}']);
  });

  testWidgets('la guía ofrece cambiar la localización en su primer paso', (
    tester,
  ) async {
    var asked = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: PlanGuideBar(
            step: PlanGuideStep.location,
            siteName: 'Hospital',
            sets: const [],
            zonedSetIds: const {},
            setsWithShots: const {},
            shotLabel: 'Esc 4 · Plano 1',
            shotReady: false,
            onStep: (_) {},
            onNewSet: () {},
            onMarkZone: (_) {},
            onAssociate: (_) {},
            onFinish: () {},
            onClose: () {},
            onChangeSite: () => asked++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('No es esta localización'));
    expect(asked, 1);
  });
}
