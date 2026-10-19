import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_editor.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/plan_guide.dart';

const _wall = '{"version":2,"elements":[{"type":"wall","x":100,"y":100}]}';

void main() {
  late AppDatabase db;
  late int projectId;
  late int sceneId;

  Future<Shot> shot(int id) =>
      (db.select(db.shots)..where((s) => s.id.equals(id))).getSingle();

  Future<int> addScene({int? siteId, int? setId}) => db.insertScene(
    ScenesCompanion.insert(
      projectId: projectId,
      number: 2,
      name: 'Escena 2',
      locationCanonical: 'INT. CASA - DÍA',
      locationPureName: 'CASA',
      locationSiteId: Value(siteId),
      locationId: Value(setId),
    ),
  );

  Future<int> addShot(int number) => db.insertShot(
    ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: number),
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
  });

  tearDown(() => db.close());

  group('qué le falta a un plano', () {
    test('sin localización', () async {
      sceneId = await addScene();
      final state = await PlanEntryState.resolve(db, await shot(await addShot(1)));
      expect(state.need, PlanEntryNeed.site);
      expect(state.missingLabel, 'Falta localización');
      expect(state.startStep, PlanGuideStep.location);
    });

    test('localización sin plano maestro', () async {
      final siteId = await db.insertSite(
        LocationSitesCompanion.insert(projectId: projectId, name: 'Casa'),
      );
      sceneId = await addScene(siteId: siteId);
      final state = await PlanEntryState.resolve(db, await shot(await addShot(1)));
      expect(state.need, PlanEntryNeed.sitePlan);
      expect(state.startStep, PlanGuideStep.location);
    });

    test('con plano maestro pero sin sets', () async {
      final siteId = await db.insertSite(
        LocationSitesCompanion.insert(
          projectId: projectId,
          name: 'Casa',
          floorPlanJson: const Value(_wall),
        ),
      );
      sceneId = await addScene(siteId: siteId);
      final state = await PlanEntryState.resolve(db, await shot(await addShot(1)));
      expect(state.need, PlanEntryNeed.sets);
      expect(state.missingLabel, 'Falta set');
      expect(state.startStep, PlanGuideStep.sets);
    });

    test('con sets pero el plano sin set, y luego listo', () async {
      final siteId = await db.insertSite(
        LocationSitesCompanion.insert(
          projectId: projectId,
          name: 'Casa',
          floorPlanJson: const Value(_wall),
        ),
      );
      final setId = await db.insertSetUnderSite(
        projectId: projectId,
        siteId: siteId,
        name: 'Cocina',
      );
      sceneId = await addScene(siteId: siteId);
      final shotId = await addShot(1);
      var state = await PlanEntryState.resolve(db, await shot(shotId));
      expect(state.need, PlanEntryNeed.shotSet);
      expect(state.startStep, PlanGuideStep.shots);

      final set = (await db.getLocationById(setId))!;
      await associateShotsToSet(db, set, [await shot(shotId)]);
      state = await PlanEntryState.resolve(db, await shot(shotId));
      expect(state.need, PlanEntryNeed.none);
      expect(state.missingLabel, isNull);
    });
  });

  test('asociar planos: la escena toma el set y cada plano su cámara', () async {
    final siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Casa'),
    );
    final kitchen = await db.insertSetUnderSite(
      projectId: projectId,
      siteId: siteId,
      name: 'Cocina',
    );
    final living = await db.insertSetUnderSite(
      projectId: projectId,
      siteId: siteId,
      name: 'Salón',
    );
    sceneId = await addScene(siteId: siteId);
    final a = await addShot(1);
    final b = await addShot(2);
    final c = await addShot(3);

    await associateShotsToSet(db, (await db.getLocationById(kitchen))!, [
      await shot(a),
      await shot(b),
    ]);
    final scene = await (db.select(
      db.scenes,
    )..where((s) => s.id.equals(sceneId))).getSingle();
    expect(scene.locationId, kitchen);
    // Van con su escena: no hace falta set propio.
    expect((await shot(a)).locationBasePlanId, isNull);
    for (final id in [a, b]) {
      final rows = await db.getCameraPlanElementsForShot(id);
      expect(rows.map((r) => r.type), ['camera']);
    }

    // Un plano de la misma escena puede rodarse en otro set.
    await associateShotsToSet(db, (await db.getLocationById(living))!, [
      await shot(c),
    ]);
    expect((await shot(c)).locationBasePlanId, living);

    // Asociar otra vez no duplica la cámara.
    await associateShotsToSet(db, (await db.getLocationById(kitchen))!, [
      await shot(a),
    ]);
    expect(await db.getCameraPlanElementsForShot(a), hasLength(1));
  });

  testWidgets('la guía lleva de los sets a los planos y abre su planta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late int siteId;
    late int shotId;
    await tester.runAsync(() async {
      siteId = await db.insertSite(
        LocationSitesCompanion.insert(
          projectId: projectId,
          name: 'Casa',
          floorPlanJson: const Value(_wall),
        ),
      );
      await db.insertSetUnderSite(
        projectId: projectId,
        siteId: siteId,
        name: 'Cocina',
      );
      sceneId = await addScene(siteId: siteId);
      shotId = await addShot(1);
    });

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
          home: CameraPlanEditor.site(
            projectId: projectId,
            siteId: siteId,
            siteName: 'Casa',
            guide: PlanGuide(
              sceneId: sceneId,
              shotId: shotId,
              shotLabel: 'Esc 2 · Plano 1',
              startStep: PlanGuideStep.sets,
            ),
          ),
        ),
      ),
    );
    await settle();

    expect(find.text('Cocina · marcar zona'), findsOneWidget);
    await tester.tap(find.text('Siguiente: planos'));
    await settle();

    // Aún sin set: no se puede abrir su planta.
    final open = find.widgetWithText(FilledButton, 'Abrir planta de Esc 2 · Plano 1');
    expect(tester.widget<FilledButton>(open).onPressed, isNull);

    await tester.tap(find.text('Cocina · asociar planos'));
    await settle();
    expect(find.text('Asociar planos a «Cocina»'), findsOneWidget);
    await tester.tap(find.text('Plano 1'));
    await tester.pump();
    await tester.tap(find.text('Asociar 1 plano'));
    await settle();

    final camera = await tester.runAsync(
      () => db.getCameraPlanElementsForShot(shotId),
    );
    expect(camera, hasLength(1));
    expect(tester.widget<FilledButton>(open).onPressed, isNotNull);

    await tester.tap(open);
    await settle();
    expect(find.text('Siguiente: planos'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('desde la guía se crea un set y se marca su zona en el plano '
      'maestro', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late int siteId;
    await tester.runAsync(() async {
      siteId = await db.insertSite(
        LocationSitesCompanion.insert(
          projectId: projectId,
          name: 'Casa',
          floorPlanJson: const Value(_wall),
        ),
      );
      sceneId = await addScene(siteId: siteId);
    });

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
          home: CameraPlanEditor.site(
            projectId: projectId,
            siteId: siteId,
            siteName: 'Casa',
            guide: PlanGuide(sceneId: sceneId),
          ),
        ),
      ),
    );
    await settle();
    expect(find.textContaining('Dibuja el entorno de «Casa»'), findsOneWidget);
    await tester.tap(find.text('Siguiente: sets'));
    await settle();

    await tester.tap(find.text('Nuevo set'));
    await settle();
    await tester.enterText(find.byType(TextField).last, 'Cocina');
    await tester.tap(find.text('Aceptar'));
    await settle();
    expect(find.textContaining('marcar la zona de «Cocina»'), findsOneWidget);

    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is CameraPlanPainter,
    );
    final origin = tester.getTopLeft(canvas);
    await tester.dragFrom(
      origin + const Offset(200, 200),
      const Offset(240, 160),
    );
    await settle();

    final sets = await tester.runAsync(
      () => db.watchSetsForSite(siteId).first,
    );
    expect(sets!.single.locationName, 'Cocina');
    expect(SetZone.decode(sets.single.sitePlacementJson), isNotNull);
    expect(find.text('Cocina'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
