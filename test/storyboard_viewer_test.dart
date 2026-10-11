import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/storyboard/storyboard_viewer.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('el visor pasa de plano en plano, enseña y edita el título y '
      'se cierra', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late int projectId;
    final shotIds = <int>[];
    await tester.runAsync(() async {
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
      for (var s = 1; s <= 2; s++) {
        final sceneId = await db.insertScene(
          ScenesCompanion.insert(
            projectId: projectId,
            number: s,
            name: 'Escena $s',
            locationCanonical: 'INT. BAR $s - NOCHE',
            locationPureName: 'BAR $s',
            sortOrder: Value(s),
          ),
        );
        shotIds.add(
          await db.insertShot(
            ShotsCompanion.insert(
              sceneId: sceneId,
              projectId: projectId,
              number: 1,
              framing: Value('PP de ALI $s'),
            ),
          ),
        );
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StoryboardViewer(
                      projectId: projectId,
                      initialShotId: shotIds.first,
                    ),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await settle(tester);

    expect(find.text('Esc 1 · Plano 1'), findsOneWidget);
    expect(find.text('PP de ALI 1'), findsOneWidget);
    expect(find.text('Este plano aún no tiene imagen'), findsOneWidget);

    // La flecha pasa al plano de la escena siguiente, no se queda en este.
    await tester.tap(find.byTooltip('Plano siguiente (→)'));
    await settle(tester);
    expect(find.text('Esc 2 · Plano 1'), findsOneWidget);
    expect(find.text('PP de ALI 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(find.text('Esc 1 · Plano 1'), findsOneWidget);

    // El título es el encuadre del guion técnico.
    await tester.enterText(find.byType(TextField), 'General del bar');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    // La escritura necesita tiempo de verdad, sin esperas que disparen la
    // descarga de fuentes.
    late Shot shot;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() async {
        shot = (await db.getShotById(shotIds.first))!;
      });
      if (shot.framing == 'General del bar') break;
    }
    expect(shot.framing, 'General del bar');

    // Un plano nuevo desde aquí: queda en la escena y se salta a él.
    await tester.tap(find.text('Plano nuevo'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => db.getShotsForProject(projectId));
    }
    await settle(tester);
    expect(find.text('Esc 1 · Plano 2'), findsOneWidget);
    late List<Shot> all;
    await tester.runAsync(() async {
      all = await db.getShotsForProject(projectId);
    });
    expect(all, hasLength(3));

    // «Cerrar» está en la barra, lejos de las flechas.
    final close = tester.getCenter(find.text('Cerrar'));
    final arrow = tester.getRect(find.byTooltip('Plano siguiente (→)'));
    expect(arrow.inflate(20).contains(close), isFalse);
    await tester.tap(find.text('Cerrar'));
    await settle(tester);
    expect(find.text('abrir'), findsOneWidget);
    expect(find.text('Esc 1 · Plano 1'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
