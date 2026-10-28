import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_editor.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/plan_target.dart';
import 'package:iris_dp/features/camera_plan/plan_workspace_screen.dart';

/// La planta en el iPhone, 390 × 844 pt (docs/PLAN_IPHONE.md, IP.4.1).
void main() {
  late AppDatabase db;
  late int projectId;
  late int shotId;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  void iphone(WidgetTester tester) {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390, 844) * 3;
    addTearDown(tester.view.reset);
  }

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'iPhone'),
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
    });
  }

  Widget host(Widget child) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('el editor cabe a 390: lo secundario va en «Más»', (
    tester,
  ) async {
    iphone(tester);
    await seed(tester);
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
    expect(tester.takeException(), isNull, reason: 'sin desbordes');

    // Arriba solo lo de consulta; el resto, en el menú.
    expect(find.byTooltip('3D'), findsOneWidget);
    expect(find.byTooltip('Mapa de exposición'), findsNothing);
    await tester.tap(find.byTooltip('Más'));
    await settle(tester);
    expect(find.text('Mapa de exposición'), findsOneWidget);
    expect(find.text('Alzado y perfil'), findsOneWidget);

    // Una opción del menú hace lo mismo que su botón.
    await tester.tap(find.text('Mapa de exposición'));
    await settle(tester);
    await tester.tap(find.byTooltip('Más'));
    await settle(tester);
    expect(find.text('Volver a los haces de luz'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await unmount(tester);
  });

  testWidgets('la pantalla de trabajo no lleva columna lateral: las plantas '
      'se abren en una hoja', (tester) async {
    iphone(tester);
    await seed(tester);
    await tester.pumpWidget(
      host(
        PlanWorkspaceScreen(
          projectId: projectId,
          initial: PlanTarget(
            scope: FloorPlanScope.shot,
            id: shotId,
            label: 'Esc 1 · Plano 1',
          ),
        ),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'sin desbordes');
    expect(find.byTooltip('Mostrar plantas'), findsNothing);

    // El editor ocupa todo el ancho.
    final editor = tester.getRect(find.byType(CameraPlanEditor));
    expect(editor.width, 390);

    await tester.tap(find.byTooltip('Plantas'));
    await settle(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);

    await unmount(tester);
  });
}
