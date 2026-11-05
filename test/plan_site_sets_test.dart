import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_screen.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/plan_data.dart';
import 'package:iris_dp/shared/pdf_export/camera_plan_pdf.dart';

/// SG.2: la localización con sus sets, por grupo y en orden de rodaje.
void main() {
  late AppDatabase db;
  late int projectId;
  late int siteId;
  late LightSetup setA;
  late LightSetup setB;
  late LightSetup setC;

  String light(double x, double y) =>
      '{"type":"light","x":$x,"y":$y,"rotation":0,"label":"L",'
      '"lightType":"fresnel","pathPoints":[]}';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'KK'));
    siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Calle'),
    );
    final repo = FloorPlanRepository(db);
    setA = await repo.createLightSetup(projectId: projectId, siteId: siteId);
    setB = await repo.createLightSetup(projectId: projectId, siteId: siteId);
    setC = await repo.createLightSetup(projectId: projectId, siteId: siteId);
    await db.updateLightSetup(
      setA.copyWith(
        planJson: Value('{"version":2,"elements":[${light(100, 100)}]}'),
      ),
    );
    // Escena 1 se rueda en B; escena 2 en A. C no tiene planos.
    for (final (number, setup) in [(1, setB), (2, setA)]) {
      final scene = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: number,
          name: 'Escena $number',
          locationCanonical: 'EXT. CALLE - NOCHE',
          locationPureName: 'CALLE',
          locationSiteId: Value(siteId),
        ),
      );
      final shot = await db.insertShot(
        ShotsCompanion.insert(sceneId: scene, projectId: projectId, number: 1),
      );
      await db.assignLightSetupToShot(shot, setup.id);
    }
  });

  tearDown(() => db.close());

  Future<PlanProjectData> load() async => PlanProjectData(
    sites: await db.watchSitesForProject(projectId).first,
    sets: await db.watchLocationsForProject(projectId).first,
    setups: await db.getLightSetupsForProject(projectId),
    scenes: await db.watchScenesForProject(projectId).first,
    shots: await db.getShotsForProject(projectId),
    groups: await db.getSetGroupsForProject(projectId),
  );

  test('los sets se ordenan por grupo, por el guion o a mano', () async {
    final group = await db.insertSetGroup(
      SetGroupsCompanion.insert(
        projectId: projectId,
        locationSiteId: Value(siteId),
        name: 'Fondo fachada',
      ),
    );
    await db.assignLightSetupToGroup(setC.id, group);

    var data = await load();
    var parts = data.orderedSets(siteId);
    expect(parts.first.group?.name, 'Fondo fachada');
    expect(parts.first.sets.map((s) => s.id), [setC.id]);
    expect(parts.last.group, isNull);
    expect(parts.last.sets.map((s) => s.id), [setA.id, setB.id]);

    // Narrativo: B (escena 1), A (escena 2) y C, sin planos, al final.
    parts = data.orderedSets(siteId, mode: 'narrative');
    expect(parts.single.sets.map((s) => s.id), [setB.id, setA.id, setC.id]);

    // A mano: el orden de rodaje guardado manda.
    await db.setLightSetupShootOrder(setC.id, 0);
    await db.setLightSetupShootOrder(setA.id, 1);
    await db.setLightSetupShootOrder(setB.id, 2);
    data = await load();
    parts = data.orderedSets(siteId, mode: 'manual');
    expect(parts.single.sets.map((s) => s.id), [setC.id, setA.id, setB.id]);
  });

  test('el PDF sale en orden de rodaje: localización, grupo y set', () async {
    final group = await db.insertSetGroup(
      SetGroupsCompanion.insert(
        projectId: projectId,
        locationSiteId: Value(siteId),
        name: 'Fondo fachada',
      ),
    );
    await db.assignLightSetupToGroup(setB.id, group);
    // Un plano sin set va al final.
    final scene3 = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 3,
        name: 'Escena 3',
        locationCanonical: 'INT. BAR - NOCHE',
        locationPureName: 'BAR',
      ),
    );
    await db.insertShot(
      ShotsCompanion.insert(sceneId: scene3, projectId: projectId, number: 1),
    );

    var sections = CameraPlanPdfExporter.shootingOrder(await load());
    expect(sections.map((s) => (s.level, s.title)), [
      (0, 'Calle'),
      (1, 'Grupo Fondo fachada'),
      (2, '1. Setup B · Esc 1'),
      (2, '2. Setup A · Esc 2'),
      (0, 'Sin set'),
      (2, 'Esc 3 · INT. BAR - NOCHE'),
    ]);
    expect(sections[2].shots, hasLength(1));

    // En orden narrativo, sin cabeceras de grupo.
    await db.setSiteSetOrderMode(siteId, 'narrative');
    sections = CameraPlanPdfExporter.shootingOrder(await load());
    expect(sections.map((s) => s.title).take(3), [
      'Calle',
      '1. Setup B · Esc 1',
      '2. Setup A · Esc 2',
    ]);
  });

  testWidgets('la localización enseña sus sets, se agrupan y se reordenan', (
    tester,
  ) async {
    // Un plano de la localización aún sin set.
    final loose = (await tester.runAsync(() async {
      final scene = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 3,
          name: 'Escena 3',
          locationCanonical: 'EXT. CALLE - NOCHE',
          locationPureName: 'CALLE',
          locationSiteId: Value(siteId),
        ),
      );
      return db.insertShot(
        ShotsCompanion.insert(sceneId: scene, projectId: projectId, number: 4),
      );
    }))!;
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> settle() async {
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: CameraPlanScreen(projectId: projectId),
        ),
      ),
    );
    await settle();

    // El índice lleva a la localización: sus sets, sin zonas.
    expect(find.text('3 sets'), findsOneWidget);
    await tester.tap(find.text('CALLE').first);
    await settle();
    expect(find.text('Nuevo set'), findsOneWidget);
    expect(find.text('Por fondo'), findsNothing);
    expect(find.byKey(ValueKey('set-${setA.id}')), findsOneWidget);
    // Los planos van como tarjetas, con su escena y su cámara.
    expect(find.text('1·P1'), findsOneWidget);
    expect(find.text('2·P1'), findsOneWidget);
    expect(find.text('SIN CÁMARA'), findsNWidgets(2));
    expect(find.text('Planos sin set'), findsOneWidget);

    Future<void> dragTo(Finder from, Finder to) async {
      final g = await tester.startGesture(tester.getCenter(from));
      await g.moveBy(const Offset(0, 20));
      await tester.pump();
      await g.moveTo(tester.getCenter(to));
      await tester.pump();
      await g.up();
      await settle();
    }

    // El plano sin set se arrastra al set C.
    await dragTo(
      find.byKey(ValueKey('site-shot-$loose')),
      find.byKey(ValueKey('set-${setC.id}')),
    );
    final moved = (await tester.runAsync(() => db.getShotById(loose)))!;
    expect(moved!.lightSetupId, setC.id);
    expect(find.text('Planos sin set'), findsNothing);

    // Agrupar A y C: la luz de A pasa a ser la del grupo.
    await tester.tap(find.text('Agrupar sets…'));
    await settle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Setup A'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Setup C'));
    await tester.pump();
    await tester.tap(find.text('Siguiente'));
    await settle();
    await tester.enterText(find.byType(TextField), 'Fondo fachada');
    expect(find.text('La de «Setup A» (1 luces)'), findsOneWidget);
    await tester.tap(find.text('Crear grupo'));
    await settle();

    final groups = (await tester.runAsync(
      () => db.getSetGroupsForProject(projectId),
    ))!;
    expect(groups.single.name, 'Fondo fachada');
    expect(groups.single.locationSiteId, siteId);
    expect(
      FloorPlanJson.decode(
        groups.single.planJson,
      ).where((e) => e.type == ElementType.light),
      hasLength(1),
    );
    final setups = (await tester.runAsync(
      () => db.getLightSetupsForProject(projectId),
    ))!;
    LightSetup byId(int id) => setups.firstWhere((s) => s.id == id);
    expect(byId(setA.id).groupId, groups.single.id);
    expect(byId(setC.id).groupId, groups.single.id);
    expect(byId(setB.id).groupId, isNull);
    // La luz ya no está en el set: está en el grupo.
    expect(FloorPlanJson.decode(byId(setA.id).planJson), isEmpty);
    expect(find.text('Fondo fachada · luz compartida'), findsNWidgets(2));

    // C se arrastra por su asa al sitio de A: el orden pasa a ser a mano.
    await dragTo(
      find.byKey(ValueKey('set-grip-${setC.id}')),
      find.byKey(ValueKey('set-${setA.id}')),
    );
    final site = (await tester.runAsync(() => db.getSiteById(siteId)))!;
    expect(site.setOrderMode, 'manual');
    final data = (await tester.runAsync(load))!;
    final order = [
      for (final part in data.orderedSets(siteId))
        ...part.sets.map((s) => s.id),
    ];
    expect(order.indexOf(setC.id), lessThan(order.indexOf(setA.id)));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
