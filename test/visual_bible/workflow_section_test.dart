import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/widgets/sections/workflow_section.dart';
import 'package:iris_dp/shared/visual_bible/workflow_points.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/snapshot.dart';

void main() {
  test('la tabla de pasos nace con sus nombres y sin programas de ejemplo', () {
    final table = WorkflowPoints.stepsValue(const {});
    expect(table.rows.map((r) => r.first), WorkflowPoints.stepNames);
    expect(WorkflowPoints.stepsFilled(table), isFalse);
    expect(
      WorkflowPoints.stepsFilled(table.withCell(1, 1, 'Silverstack')),
      isTrue,
    );
  });

  test('la entrega toma códec y cadencia de Cámara si no se escriben', () {
    final value = WorkflowPoints.withFacts(
      WorkflowPoints.deliveryValue(const {}, resolutionNotes: '4K DCI'),
      WorkflowPoints.fromCamera(codec: 'ARRIRAW', frameRate: '24'),
    );
    expect(WorkflowPoints.row(value, WorkflowPoints.rowCodec), 'ARRIRAW');
    expect(WorkflowPoints.row(value, WorkflowPoints.rowFrameRate), '24');
    expect(WorkflowPoints.row(value, WorkflowPoints.rowResolution), '4K DCI');
  });

  testWidgets('Workflow: se rellena en el sitio y no trae un flujo inventado', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await loadSnapshotFonts();
    tester.view.physicalSize = const Size(1500, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    late VisualBibleData data;
    String? contentJson;
    await tester.runAsync(() async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Workflow'),
      );
      final bible = await db.ensureVisualBibleForProject(projectId);
      await db.addBuiltinBibleSection(
        bibleId: bible.id,
        sectionId: BibleSectionId.workflow,
      );
      data = VisualBibleData.fromRow(bible)..codec = 'ARRIRAW';
      final defs = await db.select(db.bibleSectionDefinitions).get();
      contentJson = defs
          .firstWhere((d) => d.id == BibleSectionId.workflow)
          .contentJson;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: WorkflowSection(
              data: data,
              projectId: data.projectId,
              sectionContentJson: contentJson,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);

    expect(find.text('Copias'), findsOneWidget);
    expect(find.text('Entrega'), findsOneWidget);
    expect(find.text('DEL RODAJE A LA ENTREGA'), findsOneWidget);
    expect(find.text('EQUIPO DE DATOS'), findsOneWidget);
    for (final example in [
      'YoYotta',
      'DaVinci',
      'Aspera',
      'ARRI Alexa / RED',
      'Clone x3',
      'BACKUP',
      'DAILIES',
    ]) {
      expect(find.textContaining(example), findsNothing, reason: example);
    }

    await saveSnapshot(tester, 'workflow_1500');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
