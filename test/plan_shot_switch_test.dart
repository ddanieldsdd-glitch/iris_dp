import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_editor.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/plan_target.dart';
import 'package:iris_dp/features/camera_plan/plan_workspace_screen.dart';

/// FL.6: pasar de un plano a otro no desmonta el editor; solo lee el nuevo.
void main() {
  late AppDatabase db;
  late int projectId;
  late int shot1;
  late int shot2;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('de un plano a otro con el mismo editor', (tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Corto de prueba'),
      );
      final siteId = await db.insertSite(
        LocationSitesCompanion.insert(projectId: projectId, name: 'Taller'),
      );
      final setup = await FloorPlanRepository(
        db,
      ).createLightSetup(projectId: projectId, siteId: siteId);
      final scene = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 7,
          name: 'La llamada',
          locationCanonical: 'INT. TALLER - DÍA',
          locationPureName: 'TALLER',
          locationSiteId: Value(siteId),
        ),
      );
      shot1 = await db.insertShot(
        ShotsCompanion.insert(sceneId: scene, projectId: projectId, number: 3),
      );
      shot2 = await db.insertShot(
        ShotsCompanion.insert(sceneId: scene, projectId: projectId, number: 4),
      );
      await db.assignLightSetupToShot(shot1, setup.id);
      await db.assignLightSetupToShot(shot2, setup.id);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: PlanWorkspaceScreen(
            projectId: projectId,
            initial: PlanTarget.shot(shot1, 'Plano 3'),
          ),
        ),
      ),
    );
    await settle(tester);

    final editor = find.byType(CameraPlanEditor);
    final state = tester.state(editor);
    final title = find.descendant(
      of: find.byType(AppBar),
      matching: find.textContaining('La llamada'),
    );
    expect(title, findsOneWidget);
    expect(tester.widget<CameraPlanEditor>(editor).shotId, shot1);

    // Al plano 4 y, sin esperar a que termine de leerlo, de vuelta al 3: lo
    // que llega tarde del 4 no pisa al 3.
    await tester.tap(find.byKey(ValueKey('strip-shot-$shot2')));
    await tester.pump();
    expect(tester.widget<CameraPlanEditor>(editor).shotId, shot2);
    await tester.tap(find.byKey(ValueKey('strip-shot-$shot1')));
    await settle(tester);

    expect(tester.state(editor), same(state));
    expect(tester.widget<CameraPlanEditor>(editor).shotId, shot1);
    expect(title, findsOneWidget);

    await tester.tap(find.byKey(ValueKey('strip-shot-$shot2')));
    await settle(tester);
    expect(tester.state(editor), same(state));
    expect(tester.widget<CameraPlanEditor>(editor).shotId, shot2);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
