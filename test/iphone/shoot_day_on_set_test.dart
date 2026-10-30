import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_on_set.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_screen.dart';
import 'package:iris_dp/features/technical_script/technical_script_screen.dart';

/// La jornada en el set y el guion en lectura, en el iPhone a 390 × 844 pt
/// (docs/PLAN_IPHONE.md, IP.2).
void main() {
  late AppDatabase db;
  late int projectId;
  late int dayId;

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
        ProjectsCompanion.insert(name: 'Rodaje'),
      );
      Future<int> scene(int n, String place) => db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: n,
          name: place,
          locationCanonical: 'INT. $place - NOCHE',
          locationPureName: place,
          sortOrder: Value(n),
        ),
      );
      final a = await scene(1, 'COCINA');
      final b = await scene(2, 'SALÓN CON UN NOMBRE MUY LARGO DE VERDAD');
      final shots = <(int, int)>[];
      for (final (sceneId, n) in [(a, 1), (a, 2), (b, 1)]) {
        final id = await db.insertShot(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: n,
            sortOrder: Value(n),
            framing: const Value('PP de **ALI** mirando a cámara'),
            lens: const Value('35mm'),
            movement: const Value('Steadicam lateral muy largo'),
            action: const Value(
              'ALI entra, abre la nevera y se queda quieto. La luz de la '
              'nevera le baña la cara.',
            ),
          ),
        );
        shots.add((sceneId, id));
      }
      dayId = await db.insertShootDocument(
        ShootDocumentsCompanion.insert(
          projectId: projectId,
          name: 'Jornada 1',
          kind: const Value(kShootDayKind),
        ),
      );
      // Orden de rodaje: la del salón primero.
      for (final (i, (sceneId, shotId)) in [
        shots[2],
        shots[0],
        shots[1],
      ].indexed) {
        await db.insertShootDocumentBlock(
          ShootDocumentBlocksCompanion.insert(
            documentId: dayId,
            sortOrder: Value(i),
            blockType: 'shot',
            sceneId: Value(sceneId),
            shotId: Value(shotId),
          ),
        );
      }
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
  }

  test('la marca del set se guarda sin perder lo demás del bloque', () {
    const mark = OnSetMark(status: OnSetStatus.done, note: ' toma 3 ');
    final json = mark.writeInto('{"otra":1}');
    expect(json, contains('"otra":1'));
    final block = ShootDocumentBlock(
      id: 1,
      documentId: 1,
      sortOrder: 0,
      blockType: 'shot',
      contentOverridesJson: json,
    );
    final read = OnSetMark.of(block);
    expect(read.status, OnSetStatus.done);
    expect(read.note, 'toma 3');
    // Volver a pendiente y sin nota la quita.
    expect(const OnSetMark().writeInto(json), '{"otra":1}');
  });

  testWidgets('en set: tarjetas en orden de rodaje, sin desbordes, y marcar '
      'un plano hecho', (tester) async {
    iphone(tester);
    await seed(tester);
    await tester.pumpWidget(
      host(
        ShootDayOnSetScreen(
          projectId: projectId,
          documentId: dayId,
          title: 'Jornada 1',
        ),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'sin desbordes');
    expect(find.text('0 de 3 hechos'), findsOneWidget);
    final salon = tester.getTopLeft(find.textContaining('ESC 2 ·'));
    final cocina = tester.getTopLeft(find.textContaining('ESC 1 ·'));
    expect(salon.dy, lessThan(cocina.dy));

    await tester.tap(find.text('Hecho').first);
    await settle(tester);
    expect(find.text('1 de 3 hechos'), findsOneWidget);
    final blocks = await db.getBlocksForShootDocument(dayId);
    expect(OnSetMark.of(blocks.first).status, OnSetStatus.done);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('la jornada cabe a 390 con «En set» y «Exportar» arriba', (
    tester,
  ) async {
    iphone(tester);
    await seed(tester);
    await tester.pumpWidget(
      host(ShootDayScreen(projectId: projectId, documentId: dayId)),
    );
    await settle(tester);
    expect(find.byTooltip('En set'), findsOneWidget);
    expect(find.byTooltip('Exportar'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'sin desbordes');
    await unmount(tester);
  });

  testWidgets('el guion técnico se abre en lectura en el iPhone', (
    tester,
  ) async {
    iphone(tester);
    await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);
    expect(find.text('Lectura'), findsOneWidget);
    expect(find.textContaining('ESC 1 ·'), findsOneWidget);
    // Sin chips de marcar: es solo lectura.
    expect(find.text('Hecho'), findsNothing);
    expect(tester.takeException(), isNull, reason: 'sin desbordes');
    await unmount(tester);
  });
}
