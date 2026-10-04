import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_editor.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_screen.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('proyecto sin escenas devuelve lista vacía', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Vacío'),
    );

    final scenes = await (db.select(
      db.scenes,
    )..where((s) => s.projectId.equals(projectId))).get();
    expect(scenes, isEmpty);
  });

  test('listado de planos y elementos de planta en base de datos', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Planta Test'),
    );
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena 1',
        locationCanonical: 'INT. SALA - DÍA',
        locationPureName: 'SALA',
      ),
    );
    final shotId = await db.insertShot(
      ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: 1),
    );

    final shots = await db.getShotsForScene(sceneId);
    expect(shots.single.id, shotId);

    await db.insertCameraPlanElement(
      CameraPlanElementsCompanion.insert(
        shotId: shotId,
        type: 'camera',
        cameraLetter: const Value('A'),
        cameraNumber: const Value(1),
      ),
    );

    final elements = await db.getCameraPlanElementsForShot(shotId);
    expect(elements, hasLength(1));
    expect(elements.first.type, 'camera');
  });

  Widget host(Widget child) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );

  /// Deja que Drift responda y la pantalla se repinte.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('sin escenas se pueden crear plantas', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late int projectId;
    await tester.runAsync(() async {
      projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Sin guion'),
      );
      final siteId = await db.insertSite(
        LocationSitesCompanion.insert(projectId: projectId, name: 'Bosque'),
      );
      final setId = await db.insertLocation(
        LocationBasePlansCompanion.insert(
          projectId: projectId,
          siteId: Value(siteId),
          locationName: 'Cabaña',
        ),
      );
      await FloorPlanRepository(
        db,
      ).createLightSetup(projectId: projectId, setId: setId);
    });

    await tester.pumpWidget(host(CameraPlanScreen(projectId: projectId)));
    await settle(tester);

    expect(find.text('Sin escenas todavía.'), findsNothing);
    expect(find.text('Bosque'), findsWidgets);
    expect(find.text('Cabaña'), findsWidgets);
    expect(find.text('Setup A'), findsOneWidget);
    expect(find.text('Plantas libres'), findsOneWidget);
    expect(find.text('Esquema de luz'), findsWidgets);
    expect(find.text('Entorno'), findsOneWidget);
    expect(find.text('Boceto'), findsWidgets);
    expect(tester.takeException(), isNull);

    // Tocar una miniatura abre la pantalla de trabajo en esa planta.
    await tester.tap(find.text('Setup A'));
    await settle(tester);
    expect(find.text('Esquema de luz · Cabaña'), findsOneWidget);
    expect(find.text('Plano del set'), findsOneWidget);
    expect(find.text('Esquema siguiente'), findsNothing);
    expect(find.byTooltip('Esquema siguiente'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Desde el navegador se cambia de planta sin volver al mapa.
    await tester.tap(find.text('Plano del set'));
    await settle(tester);
    expect(find.text('Plano de set'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('el plano enseña su esquema de luz', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late int projectId;
    late int shotId;
    await tester.runAsync(() async {
      projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Capas'),
      );
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 1,
          name: 'Escena 1',
          locationCanonical: 'INT. SALA - DÍA',
          locationPureName: 'SALA',
        ),
      );
      shotId = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: 1,
        ),
      );
      final setup = await FloorPlanRepository(
        db,
      ).createLightSetup(projectId: projectId, name: 'Noche');
      await db.assignLightSetupToShot(shotId, setup.id);
    });

    await tester.pumpWidget(
      host(
        CameraPlanEditor.shot(
          projectId: projectId,
          shotId: shotId,
          shotLabel: 'Esc 1 · Plano 1',
        ),
      ),
    );
    await settle(tester);

    expect(find.text('Noche · Boceto'), findsOneWidget);
    expect(find.text('Editar luz'), findsOneWidget);
    expect(find.text('Cambiar'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  });
}
