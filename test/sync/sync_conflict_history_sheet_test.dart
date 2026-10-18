import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/sync/sync_merge_store.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/core/widgets/sync/sync_conflict_history_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/snapshot.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('enseña lo descartado por proyecto y deja copiarlo', (tester) async {
    await loadSnapshotFonts();
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      final kebab = await db.insertProject(
        ProjectsCompanion.insert(name: 'KEBAB KHALED', cloudId: const Value('c1')),
      );
      final invento = await db.insertProject(
        ProjectsCompanion.insert(name: 'invento 1', cloudId: const Value('c2')),
      );
      final now = DateTime.now();
      await SyncConflictLog.addAll(db, [
        SyncConflictEntry(
          projectId: kebab,
          collection: 'shots',
          elementUid: 'a',
          elementLabel: 'Plano 3/2',
          field: 'lens',
          keptValue: '85mm',
          discardedValue: '35mm',
          discardedSide: 'local',
          discardedDevice: 'Mac',
          createdAt: now,
        ),
        SyncConflictEntry(
          projectId: kebab,
          collection: 'biblia',
          elementLabel: 'biblia',
          keptValue: '{"moodboardImages":[]}',
          discardedValue: '{"moodboardImages":[{"caption":"x"}]}',
          discardedSide: 'cloud',
          discardedDevice: 'iPad',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        SyncConflictEntry(
          projectId: invento,
          collection: 'scenes',
          elementUid: 's4',
          elementLabel: 'Escena 4 · EXT. PLAYA',
          field: 'name',
          keptValue: 'EXT. PLAYA',
          discardedValue: 'EXT. COSTA',
          discardedSide: 'cloud',
          discardedDevice: 'iPad',
          createdAt: now,
        ),
      ]);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => SyncConflictHistorySheet.show(context),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await settle(tester);

    expect(find.text('KEBAB KHALED'), findsOneWidget);
    expect(find.text('invento 1'), findsOneWidget);
    expect(find.text('Plano 3/2 · óptica'), findsOneWidget);
    expect(find.text('biblia (bloque entero)'), findsOneWidget);
    expect(find.textContaining('descartado «35mm» (Mac)'), findsOneWidget);
    expect(find.byTooltip('Copiar lo descartado'), findsNWidgets(3));
    await saveSnapshot(tester, 'historial_conflictos');
  });

  testWidgets('sin nada descartado lo dice', (tester) async {
    await tester.runAsync(() => db.select(db.projects).get());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: SyncConflictHistorySheet()),
        ),
      ),
    );
    await settle(tester);
    expect(find.textContaining('No se ha descartado nada'), findsOneWidget);
  });
}
