import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_screen.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_compact_section_bar.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_sidebar.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

/// La biblia en el iPhone: sin lateral fijo; el índice va en una hoja y el
/// moodboard ocupa todo el ancho.
void main() {
  late AppDatabase db;
  late int projectId;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Prueba captura'),
      );
    });
    SharedPreferences.setMockInitialValues({
      'iris_bible_tutorial_done_$projectId': true,
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: VisualBibleScreen(
            projectId: projectId,
            initialSectionId: BibleSectionId.moodboard,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('iPhone 390: moodboard a todo el ancho y el índice en una hoja', (
    tester,
  ) async {
    await pumpAt(tester, const Size(390, 844));
    final error = tester.takeException();
    expect(error, isNull, reason: 'sin desbordes: $error');

    expect(find.byType(BibleCompactSectionBar), findsOneWidget);
    expect(find.byType(BibleSidebar), findsNothing);
    expect(find.text('Moodboard'), findsWidgets);

    await tester.tap(find.byType(BibleCompactSectionBar));
    await settle(tester);
    expect(find.byType(BibleSidebar), findsOneWidget);
    expect(tester.takeException(), isNull);

    await unmount(tester);
  });

  testWidgets('iPad: el lateral sigue fijo', (tester) async {
    await pumpAt(tester, const Size(1024, 768));
    expect(find.byType(BibleSidebar), findsOneWidget);
    expect(find.byType(BibleCompactSectionBar), findsNothing);
    await unmount(tester);
  });
}
