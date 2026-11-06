import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/shoot_documents/shoot_days_board.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
  }

  testWidgets('de sin asignar a una jornada, arrastrando la escena', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late int projectId;
    await tester.runAsync(() async {
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 5,
          name: 'Calle',
          locationCanonical: 'EXT. RAMBLA - NOCHE',
          locationPureName: 'RAMBLA',
        ),
      );
      for (var i = 0; i < 2; i++) {
        await db.insertShot(
          ShotsCompanion.insert(
            projectId: projectId,
            sceneId: sceneId,
            number: i + 1,
            sortOrder: Value(i),
          ),
        );
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: ShootDaysBoardScreen(projectId: projectId),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Sin asignar'), findsOneWidget);
    expect(find.text('2 planos'), findsOneWidget);

    await tester.tap(find.text('Añadir jornada').first);
    await settle(tester);
    expect(find.text('Jornada 1'), findsOneWidget);

    // Del título de la escena al final de la jornada.
    final from = tester.getCenter(find.textContaining('Esc 5').first);
    final to = tester.getCenter(find.text('Jornada 1')) + const Offset(0, 120);
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(from + const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(to);
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await settle(tester);

    expect(find.text('Todo el guion tiene su día.'), findsOneWidget);
    // La cabecera de la jornada y la escena dentro de ella.
    expect(find.text('2 planos'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
