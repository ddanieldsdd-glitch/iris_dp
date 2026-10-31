import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/storyboard/storyboard_screen.dart';
import 'package:iris_dp/features/storyboard/storyboard_viewer.dart';

/// El storyboard en el iPhone, 390 × 844 pt (docs/PLAN_IPHONE.md, IP.2.2).
void main() {
  late AppDatabase db;
  late int projectId;
  late List<int> shotIds;
  late Directory tmp;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('iris_sb');
  });

  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  void iphone(WidgetTester tester) {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390, 844) * 3;
    addTearDown(tester.view.reset);
  }

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      final image = img.Image(width: 320, height: 180);
      img.fill(image, color: img.ColorRgb8(40, 90, 140));
      final path = '${tmp.path}/sb.png';
      File(path).writeAsBytesSync(img.encodePng(image));
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'SB'));
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 1,
          name: 'COCINA',
          locationCanonical: 'INT. COCINA - NOCHE',
          locationPureName: 'COCINA',
        ),
      );
      shotIds = [
        for (var n = 1; n <= 3; n++)
          await db.insertShot(
            ShotsCompanion.insert(
              sceneId: sceneId,
              projectId: projectId,
              number: n,
              sortOrder: Value(n),
              framing: Value('Plano $n de ALI'),
              lens: const Value('35mm'),
              action: const Value('ALI abre la nevera.'),
              storyboardImagePath: Value(path),
            ),
          ),
      ];
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

  testWidgets('la cuadrícula cabe a 390', (tester) async {
    iphone(tester);
    await seed(tester);
    await tester.pumpWidget(host(StoryboardScreen(projectId: projectId)));
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'sin desbordes');
    await unmount(tester);
  });

  testWidgets('el visor: ficha debajo, deslizar pasa de plano', (
    tester,
  ) async {
    iphone(tester);
    await seed(tester);
    await tester.pumpWidget(
      host(StoryboardViewer(projectId: projectId, initialShotId: shotIds[0])),
    );
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'sin desbordes');
    expect(find.text('Esc 1 · Plano 1'), findsOneWidget);
    expect(find.text('35mm'), findsOneWidget);
    expect(find.text('ALI abre la nevera.'), findsOneWidget);

    await tester.fling(find.byType(InteractiveViewer), const Offset(-300, 0), 1500);
    await settle(tester);
    expect(find.text('Esc 1 · Plano 2'), findsOneWidget);

    await tester.tap(find.text('Anterior'));
    await settle(tester);
    expect(find.text('Esc 1 · Plano 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
