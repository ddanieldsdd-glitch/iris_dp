import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/scan_jobs/scan_build_queue.dart';
import 'package:iris_dp/features/scan_jobs/scan_jobs_host.dart';

/// El aviso de capturas sin escaneo que se ve en el iPhone, el Mac y el PC.
void main() {
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<List<LocationCapture>> captures(WidgetTester tester) async {
    late List<LocationCapture> out;
    await tester.runAsync(() async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Hospital de noche'),
      );
      for (final (name, status) in [
        ('HOSPITAL con un nombre larguísimo de verdad', 'en_iphone'),
        ('Quirófano', 'error'),
      ]) {
        await db.insertCapture(
          LocationCapturesCompanion.insert(
            projectId: projectId,
            name: name,
            status: Value(status),
            photoCount: const Value(250),
            error: Value(status == 'error' ? 'No se alinearon' : null),
          ),
        );
      }
      out = await db.watchCapturesForProject(projectId).first;
    });
    return out;
  }

  Future<void> pumpChip(
    WidgetTester tester,
    List<LocationCapture> pending, {
    ScanQueueState? queue,
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390, 844) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => Align(
              alignment: Alignment.bottomLeft,
              child: CaptureStatusChip(
                pending: pending,
                queue: queue,
                onTap: () => showPendingCaptures(context, db, pending),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('una sola: su nombre y en qué va, sin desbordes', (tester) async {
    final all = await captures(tester);
    await pumpChip(tester, [all.firstWhere((c) => c.status == 'en_iphone')]);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('en el iPhone, esperando al PC'), findsOneWidget);
  });

  testWidgets('varias: cuántas, y la lista con proyecto y error', (
    tester,
  ) async {
    final all = await captures(tester);
    await pumpChip(tester, all);
    expect(find.text('2 capturas sin escaneo'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('2 capturas sin escaneo'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Quirófano · Hospital de noche'), findsOneWidget);
    expect(find.text('Error: No se alinearon'), findsOneWidget);
  });

  testWidgets('el PC construyendo: nombre, porcentaje y cola', (tester) async {
    await pumpChip(
      tester,
      const [],
      queue: const ScanQueueState(
        waiting: 1,
        building: 'HOSPITAL',
        fraction: 0.35,
      ),
    );
    expect(find.text('Escaneo: HOSPITAL · 35 % · 1 en cola'), findsOneWidget);
  });
}
