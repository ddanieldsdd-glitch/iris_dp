import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/widgets/sections/color_image_section.dart';
import 'package:iris_dp/shared/visual_bible/bible_palette.dart';
import 'package:iris_dp/shared/visual_bible/color_points.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/snapshot.dart';

void main() {
  test('los colores de un bloque conservan su nombre al ir y volver', () {
    final colors = ColorPoints.swatches(
      ['Sodio|#f5b841', '0f1c2e', '#112233'],
      names: {'#112233': 'Noche'},
    );
    expect(colors.map((c) => c.hex), ['#F5B841', '#0F1C2E', '#112233']);
    expect(colors.map((c) => c.name), ['Sodio', '', 'Noche']);
    expect(ColorPoints.storeSwatches(colors), [
      'Sodio|#F5B841',
      '#0F1C2E',
      'Noche|#112233',
    ]);
    expect(
      ColorPoints.storeSwatches([const BiblePaletteColor(hex: '#FFFFFF')]),
      ['#FFFFFF'],
    );
  });

  for (final width in [900.0, 1500.0]) {
    testWidgets('Color a $width px: LUT, temperatura y bloques en el sitio, '
        'sin ejemplos', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await loadSnapshotFonts();
      tester.view.physicalSize = Size(width, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      late VisualBibleData data;
      String? contentJson;

      await tester.runAsync(() async {
        final projectId = await db.insertProject(
          ProjectsCompanion.insert(name: 'Color'),
        );
        final bible = await db.ensureVisualBibleForProject(projectId);
        await db.addBuiltinBibleSection(
          bibleId: bible.id,
          sectionId: BibleSectionId.colorImage,
        );
        await db.insertColorBlock(
          VisualBibleColorBlocksCompanion.insert(
            bibleId: bible.id,
            blockName: 'Noches del Raval',
            emotionalIntent: const Value('Sodio contra azul de pantalla'),
            dominantColors: jsonEncode(['Sodio|#F5B841', '#0F1C2E']),
            colorTempKelvin: const Value(3200),
          ),
        );
        data = VisualBibleData.fromRow(bible)..creativeLutName = 'KK_Noche_v2';
        final def = await db.select(db.bibleSectionDefinitions).get();
        contentJson = def
            .firstWhere((d) => d.id == BibleSectionId.colorImage)
            .contentJson;
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: ColorImageSection(
                data: data,
                projectId: data.projectId,
                bibleId: data.id,
                sectionContentJson: contentJson,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await settle();
      expect(tester.takeException(), isNull);

      expect(find.text('KK_Noche_v2'), findsOneWidget);
      // La temperatura base sale del primer bloque, como antes.
      expect(find.text('3200 K'), findsOneWidget);
      expect(find.text('Noches del Raval'), findsOneWidget);
      expect(find.text('Sodio contra azul de pantalla'), findsOneWidget);
      expect(find.text('DOMINANTES'), findsOneWidget);
      expect(find.text('SE EVITAN'), findsOneWidget);
      expect(find.textContaining('#F5B841'), findsWidgets);

      for (final example in [
        'LogC4',
        'Rec.709',
        'Contraste Alto',
        'Tint Cyan',
        'Monitoring',
        'Creative LUT',
      ]) {
        expect(find.textContaining(example), findsNothing, reason: example);
      }

      // El nombre del bloque se escribe en el sitio y va a la base.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Noches del Raval'),
        'Noches',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await settle();
      expect(find.byType(AlertDialog), findsNothing);
      late List<VisualBibleColorBlock> blocks;
      await tester.runAsync(
        () async => blocks = await db.select(db.visualBibleColorBlocks).get(),
      );
      expect(blocks.single.blockName, 'Noches');
      expect(blocks.single.colorTempKelvin, 3200);

      await saveSnapshot(tester, 'color_${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  }
}
