import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/artemis_import/artemis_import_screen.dart';

/// Reparto de una tanda de Artemis en el iPhone y el iPad: cabe, salta de
/// foto y cambia de destino. Lo que guarda cada destino, en
/// `artemis_import_test`.
void main() {
  late AppDatabase db;
  late int projectId;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Artemis'),
      );
      await db.insertSite(
        LocationSitesCompanion.insert(projectId: projectId, name: 'BOSQUE'),
      );
      final sceneId = await db.insertScene(ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Claro',
        locationCanonical: 'EXT. BOSQUE - DÍA',
        locationPureName: 'BOSQUE',
      ));
      for (var n = 1; n <= 2; n++) {
        await db.insertShot(ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: n,
          lens: Value('${n * 25}mm'),
          sortOrder: Value(n),
        ));
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: ArtemisImportScreen(
            projectId: projectId,
            // Sin archivo: la vista previa enseña el icono de imagen rota.
            paths: const ['/no/existe/1.jpg', '/no/existe/2.jpg', '/no/existe/3.jpg'],
          ),
        ),
      ),
    );
    await settle(tester);
  }

  for (final (name, size) in [
    ('iPhone 390', const Size(390, 844)),
    ('iPad', const Size(1180, 820)),
  ]) {
    testWidgets('$name: cabe, salta de foto y cambia de destino', (
      tester,
    ) async {
      await pumpAt(tester, size);
      final error = tester.takeException();
      expect(error, isNull, reason: 'sin desbordes: ${error is FlutterError ? error.toStringDeep() : error}');
      expect(find.text('Artemis · 1 de 3'), findsOneWidget);
      expect(find.text('Plano 1 · 25mm'), findsOneWidget);
      expect(find.text('Repartir las 3 en planos seguidos'), findsOneWidget);

      await tester.tap(find.text('Saltar'));
      await settle(tester);
      expect(find.text('Artemis · 2 de 3'), findsOneWidget);

      await tester.tap(find.text('Moodboard'));
      await settle(tester);
      expect(find.text('Luz'), findsOneWidget);
      expect(find.text('Asignar las 2 aquí'), findsOneWidget);

      await tester.tap(find.text('Localiz.'));
      await settle(tester);
      expect(find.text('También en su moodboard'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  }
}
