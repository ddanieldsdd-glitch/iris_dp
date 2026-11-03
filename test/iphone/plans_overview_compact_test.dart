import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_screen.dart';

/// «Plantas de luz y cámara» en el iPhone: la tarjeta de cada localización
/// pone «+ Set», el plano maestro y el menú debajo del nombre.
void main() {
  late AppDatabase db;
  late int projectId;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'iPhone'),
      );
      await db.insertSite(
        LocationSitesCompanion.insert(projectId: projectId, name: 'BOSQUE'),
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: CameraPlanScreen(projectId: projectId),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  for (final (name, size) in [
    ('iPhone 390', const Size(390, 844)),
    ('iPad', const Size(1024, 768)),
  ]) {
    testWidgets('$name: el nombre de la localización se lee en una línea', (
      tester,
    ) async {
      await pumpAt(tester, size);
      final error = tester.takeException();
      expect(error, isNull, reason: 'sin desbordes: $error');

      final title = find.text('BOSQUE');
      expect(title, findsWidgets);
      // Antes, a 390, el nombre se partía letra a letra (un rótulo vertical).
      final rect = tester.getRect(title.first);
      expect(rect.width, greaterThan(rect.height));
      expect(find.text('Plano maestro'), findsOneWidget);
      expect(find.text('Set'), findsOneWidget);

      await unmount(tester);
    });
  }
}
