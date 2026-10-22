import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/technical_script/import/docx_technical_script_reader.dart';
import 'package:iris_dp/features/technical_script/import/technical_script_import_plan.dart';
import 'package:iris_dp/features/technical_script/import/technical_script_import_review.dart';

import '../support/snapshot.dart';

/// Captura la capa del diálogo (la de la página de debajo no sirve).
Future<void> snapDialog(WidgetTester tester, String name) async {
  final dir = snapshotDir;
  if (dir == null) return;
  RenderObject? node = tester.renderObject(find.byType(Dialog));
  while (node != null && node is! RenderRepaintBoundary) {
    node = node.parent;
  }
  if (node is! RenderRepaintBoundary) return;
  final boundary = node;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

final _kebab = File(
  '${Platform.environment['HOME']}/Downloads/'
  'GUION TECNICO KEBAB KHALED - Manu Roma (1).docx',
);

void main() {
  late AppDatabase db;

  setUpAll(loadSnapshotFonts);
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Proyecto con parte del guion ya hecho: escena 1 con una lente
  /// distinta, escena 7 con un plano de más y una escena que el documento
  /// no tiene.
  Future<TechnicalScriptImportPlan> seededPlan(
    WidgetTester tester,
    ImportedTechnicalScript doc,
  ) async {
    late TechnicalScriptImportPlan plan;
    await tester.runAsync(() async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Kebab'),
      );
      Future<int> scene(int n, String location) => db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: n,
          name: location,
          locationCanonical: 'EXT. $location - NOCHE',
          locationPureName: location,
          dayNight: const Value('NOCHE'),
        ),
      );
      final s1 = await scene(1, 'CALLE RAVAL');
      for (var i = 1; i <= 2; i++) {
        await db.insertShot(
          ShotsCompanion.insert(
            sceneId: s1,
            projectId: projectId,
            number: i,
            lens: const Value('85mm'),
            framing: Value('PP de ALI $i'),
          ),
        );
      }
      final s7 = await scene(7, 'RAMBLA DEL RAVAL');
      for (var i = 1; i <= 6; i++) {
        await db.insertShot(
          ShotsCompanion.insert(
            sceneId: s7,
            projectId: projectId,
            number: i,
            lens: const Value('35mm'),
          ),
        );
      }
      await scene(16, 'AZOTEA');
      final scenes = await db.watchScenesForProject(projectId).first;
      plan = buildTechnicalScriptImportPlan(
        document: doc,
        scenes: scenes,
        shotsByScene: {
          for (final s in scenes) s.id: await db.watchShotsForScene(s.id).first,
        },
      );
    });
    return plan;
  }

  Future<(TechnicalScriptImportPlan, ImportDecisions)?> open(
    WidgetTester tester,
    TechnicalScriptImportPlan plan, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    (TechnicalScriptImportPlan, ImportDecisions)? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await showTechnicalScriptImportReview(
                      context,
                      fileName: 'GUION TECNICO KEBAB KHALED.docx',
                      plan: plan,
                      replan: (_) async => plan,
                    );
                  },
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return result;
  }

  for (final size in [const Size(1440, 900), const Size(820, 1100)]) {
    testWidgets(
      'revisión con el guion de Kebab a ${size.width.toInt()} px',
      (tester) async {
        final doc = DocxTechnicalScriptReader.read(_kebab.readAsBytesSync());
        final plan = await seededPlan(tester, doc);
        await open(tester, plan, size: size);

        expect(find.text('Importar guion técnico'), findsOneWidget);
        expect(find.text('Fusionar'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await snapDialog(tester, 'import_review_${size.width.toInt()}');

        // Escena 7: un plano solo en la app y la planta compartida.
        await tester.tap(find.textContaining('7 · RAMBLA').first);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Planta de la escena'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await snapDialog(tester, 'import_review_s7_${size.width.toInt()}');

        await tester.tap(find.text('Sobrescribir todo'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await snapDialog(
          tester,
          'import_review_overwrite_${size.width.toInt()}',
        );

        await tester.tap(find.text('Cancelar'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
      skip: !_kebab.existsSync(),
    );
  }

  testWidgets('Aplicar devuelve las decisiones; en vacío no hay modo', (
    tester,
  ) async {
    late TechnicalScriptImportPlan plan;
    await tester.runAsync(() async {
      plan = buildTechnicalScriptImportPlan(
        document: const ImportedTechnicalScript(
          scenes: [
            ImportedScene(
              number: 13,
              suffix: 'A',
              intExt: 'INT',
              location: 'KEBAB',
              dayNight: 'NOCHE',
              shots: [ImportedShot(number: 1, framing: 'PD')],
            ),
          ],
        ),
        scenes: const [],
        shotsByScene: const {},
      );
    });
    (TechnicalScriptImportPlan, ImportDecisions)? result;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result =
                  await showTechnicalScriptImportReview(
                    context,
                    fileName: 'x.docx',
                    plan: plan,
                    replan: (_) async => plan,
                  ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Fusionar'), findsNothing);
    expect(find.text('1 escenas · 1 planos'), findsOneWidget);
    await tester.tap(find.text('Aplicar'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(result, isNotNull);
    expect(result!.$2.mode, ImportMode.merge);
  });
}
