import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/technical_script/technical_script_screen.dart';

/// Base de datos que tarda en guardar el orden, como la de verdad.
class _SlowDb extends AppDatabase {
  _SlowDb() : super.forTesting(NativeDatabase.memory());

  bool slow = true;

  @override
  Future<void> reorderShotsInScene(int sceneId, List<int> ids) async {
    if (slow) await Future<void>.delayed(const Duration(milliseconds: 120));
    return super.reorderShotsInScene(sceneId, ids);
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = _SlowDb();
  });

  tearDown(() async {
    await db.close();
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

  /// Desmonta la pantalla para que Drift cierre sus consultas dentro del test.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<int> seed(WidgetTester tester) async {
    late int projectId;
    await tester.runAsync(() async {
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 1,
          name: 'Escena',
          locationCanonical: 'EXT. CALLE RAVAL - NOCHE',
          locationPureName: 'CALLE RAVAL',
        ),
      );
      for (var i = 0; i < 3; i++) {
        await db.insertShot(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: i + 1,
            sortOrder: Value(i),
            framing: Value('PML de ALI ${i + 1}'),
            fStop: const Value('T2.8'),
            notes: const Value('mirar planta cam y corregir'),
          ),
        );
      }
    });
    return projectId;
  }

  for (final width in [900.0, 1146.0, 2000.0]) {
    testWidgets('la tabla no desborda a $width px y enseña los planos', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final projectId = await seed(tester);
      await tester.pumpWidget(
        host(TechnicalScriptScreen(projectId: projectId)),
      );
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('PML de ALI 2'), findsOneWidget);
      expect(find.byTooltip('Eliminar plano'), findsNWidgets(3));
      expect(find.byTooltip('Eliminar escena'), findsOneWidget);

      // A todo el ancho, la tabla llega al borde derecho de la ventana.
      if (width >= 1146) {
        final header = tester.getRect(find.text('APUNTES'));
        expect(header.right, lessThanOrEqualTo(width));
        expect(header.left, greaterThan(width * 0.75));
      }
      await unmount(tester);
    });
  }

  testWidgets('eliminar un plano pide confirmación y renumera', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    await tester.tap(find.byTooltip('Eliminar plano').first);
    await settle(tester);
    expect(find.text('Eliminar el plano 1'), findsOneWidget);
    await tester.tap(find.text('Eliminar'));
    await settle(tester);

    expect(find.text('PML de ALI 1'), findsNothing);
    expect(find.byTooltip('Eliminar plano'), findsNWidgets(2));
    final shots = await db.getShotsForProject(projectId);
    expect(shots.map((s) => s.number), [1, 2]);
    await unmount(tester);
  });

  for (final focusFirst in [false, true]) {
    testWidgets(
      'arrastrar un plano lo reordena sin romper la pantalla '
      '(${focusFirst ? 'con' : 'sin'} una celda en edición)',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final projectId = await seed(tester);
        await tester.pumpWidget(
          host(TechnicalScriptScreen(projectId: projectId)),
        );
        await settle(tester);

        if (focusFirst) {
          await tester.tap(find.text('PML de ALI 1'));
          await tester.pump();
        }

        final handles = find.byIcon(Icons.drag_indicator);
        final from = tester.getCenter(handles.at(0));
        // Soltar bajo la última fila lo lleva al final de la escena.
        final to = tester.getCenter(find.text('Añadir plano'));
        final gesture = await tester.startGesture(from);
        await tester.pump(const Duration(milliseconds: 50));
        for (var i = 1; i <= 10; i++) {
          await gesture.moveTo(
            Offset(from.dx, from.dy + (to.dy - from.dy) * i / 10),
          );
          await tester.pump(const Duration(milliseconds: 30));
        }
        await gesture.up();
        await settle(tester);

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.drag_indicator), findsNWidgets(3));
        final shots = await db.getShotsForProject(projectId);
        expect(shots.map((s) => s.framing), [
          'PML de ALI 2',
          'PML de ALI 3',
          'PML de ALI 1',
        ]);
        expect(shots.map((s) => s.number), [1, 2, 3]);
        await unmount(tester);
      },
    );
  }

  testWidgets('arrastrar con ratón, con el aviso del asa a la vista', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    final handles = find.byIcon(Icons.drag_indicator);
    // Soltar sobre una fila coloca el plano delante de ella.
    final from = tester.getCenter(handles.at(2));
    final to = tester.getCenter(handles.at(0));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: from - const Offset(0, 4));
    await mouse.moveTo(from);
    await settle(tester);

    await mouse.down(from);
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 1; i <= 10; i++) {
      await mouse.moveTo(
        Offset(from.dx, from.dy + (to.dy - from.dy) * i / 10),
      );
      await tester.pump(const Duration(milliseconds: 30));
    }
    await mouse.up();
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(3));
    final shots = await db.getShotsForProject(projectId);
    expect(shots.map((s) => s.framing), [
      'PML de ALI 3',
      'PML de ALI 1',
      'PML de ALI 2',
    ]);
    expect(shots.map((s) => s.number), [1, 2, 3]);
    await mouse.removePointer();
    await unmount(tester);
  });

  testWidgets('editar una celda tras reordenar no devuelve el orden antiguo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    // El plano 1 queda en edición; mientras, se mueve el plano 3 al principio.
    await tester.tap(find.text('PML de ALI 1'));
    await tester.pump();
    await tester.enterText(find.text('PML de ALI 1'), 'PP de ALI');
    (db as _SlowDb).slow = false;
    final before = await db.getShotsForProject(projectId);
    await db.reorderShotsInScene(before.first.sceneId, [
      before[2].id,
      before[0].id,
      before[1].id,
    ]);
    await settle(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);

    expect(tester.takeException(), isNull);
    final shots = await db.getShotsForProject(projectId);
    expect(shots.map((s) => s.framing), [
      'PML de ALI 3',
      'PP de ALI',
      'PML de ALI 2',
    ]);
    expect(shots.map((s) => s.number), [1, 2, 3]);
    await unmount(tester);
  });

  testWidgets('referencia y planta ocupan el ancho de su columna', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    final header = tester.getSize(
      find.ancestor(
        of: find.text('REFERENCIA'),
        matching: find.byType(Container),
      ).first,
    );
    final ref = tester.getSize(
      find.ancestor(
        of: find.text('Ref.').first,
        matching: find.byType(Container),
      ).first,
    );
    expect(ref.width, closeTo(header.width - 8, 0.5));
    await unmount(tester);
  });

  for (final target in ['Arrastra para cambiar el orden', 'Eliminar plano']) {
    testWidgets('el orden cambia con el ratón sobre «$target»', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      (db as _SlowDb).slow = false;

      final projectId = await seed(tester);
      await tester.pumpWidget(
        host(TechnicalScriptScreen(projectId: projectId)),
      );
      await settle(tester);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final at = tester.getCenter(find.byTooltip(target).at(1));
      await mouse.addPointer(location: at - const Offset(0, 3));
      await mouse.moveTo(at);
      await settle(tester);
      expect(find.text(target), findsOneWidget, reason: 'aviso a la vista');

      final before = await db.getShotsForProject(projectId);
      await db.reorderShotsInScene(before.first.sceneId, [
        before[2].id,
        before[1].id,
        before[0].id,
      ]);
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(3));
      await mouse.removePointer();
      await unmount(tester);
    });
  }
}
