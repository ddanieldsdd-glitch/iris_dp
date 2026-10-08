import 'dart:convert';

import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/widgets/sections/exposure_section.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_table.dart';
import 'package:iris_dp/shared/visual_bible/exposure_points.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/snapshot.dart';

void main() {
  test('la exposición por localización pone nombre a los sets de antes', () {
    final table = ExposurePoints.byLocationValue(
      const {},
      {
        'byLocation': {
          '7': {'iso': '1280', 'approach': 'Contraluz'},
          '9': <String, dynamic>{},
        },
      },
      setNames: {7: 'CALLE RAVAL'},
    );
    // El set sin nada escrito no ocupa fila.
    expect(table.rows.length, 1);
    expect(table.rows.single.first, 'CALLE RAVAL');
    expect(table.rows.single[1], '1280');
    expect(table.rows.single[5], 'Contraluz');

    final more = ExposurePoints.withLocations(table, [
      'calle raval',
      'KEBAB KHALED',
    ]);
    expect(more.rows.map((r) => r.first), ['CALLE RAVAL', 'KEBAB KHALED']);
  });

  for (final width in [900.0, 1500.0]) {
    testWidgets('Exposición a $width px: lo antiguo en los puntos nuevos y '
        'sin ejemplos', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await loadSnapshotFonts();
      tester.view.physicalSize = Size(width, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      late VisualBibleData data;
      String? contentJson;
      Future<String?> stored() async {
        final def =
            await (db.select(db.bibleSectionDefinitions)..where(
                  (d) =>
                      d.bibleId.equals(data.id) &
                      d.id.equals(BibleSectionId.exposure),
                ))
                .getSingle();
        return def.contentJson;
      }

      await tester.runAsync(() async {
        final projectId = await db.insertProject(
          ProjectsCompanion.insert(name: 'Exposición'),
        );
        final bible = await db.ensureVisualBibleForProject(projectId);
        await db.addBuiltinBibleSection(
          bibleId: bible.id,
          sectionId: BibleSectionId.exposure,
        );
        await db.insertExposureBlock(
          ExposureBlocksCompanion.insert(
            bibleId: bible.id,
            blockName: 'Noches de reparto',
            keyFillRatio: const Value('8:1'),
            shadowStrategy: const Value('Sombras cerradas'),
          ),
        );
        data = VisualBibleData.fromRow(bible)
          ..nativeIso = 800
          ..defaultTStop = 'T2.8'
          ..highlightBehavior = 'Se dejan quemar los prácticos';
        // Contenido guardado con la pantalla de antes.
        await db.saveBibleSectionFieldValue(
          bible.id,
          BibleSectionId.exposure,
          'exposureData',
          jsonEncode({
            'shutterAngle': 172.8,
            'lumaPeak': 85,
            'sourceIntensity': 'Farolas de sodio',
            'intentTags': ['Clave baja'],
          }),
        );
        contentJson = await stored();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: ExposureSection(
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

      expect(find.text('T2.8'), findsOneWidget);
      expect(find.text('172.8°'), findsOneWidget);
      expect(find.text('Se dejan quemar los prácticos'), findsOneWidget);
      expect(find.text('85 IRE'), findsOneWidget);
      expect(find.text('Farolas de sodio'), findsOneWidget);
      expect(find.text('CLAVE BAJA'), findsOneWidget);
      expect(find.text('Noches de reparto'), findsOneWidget);
      expect(find.text('8:1'), findsOneWidget);
      expect(find.text('Sombras cerradas'), findsOneWidget);
      // 85 IRE cae en la escala: lleva barra. El suelo de sombras, vacío, no.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      for (final example in [
        'Harsh Daylight',
        'Wide Open',
        'LOW-KEY',
        'SHADOW DETAIL CRITICAL',
        'EXPOSURE',
        'PRIMARY SPECS',
        'Clear',
      ]) {
        expect(find.textContaining(example), findsNothing, reason: example);
      }

      // Editar un bloque lo guarda como tabla de la pantalla.
      await tester.enterText(
        find.widgetWithText(TextFormField, '8:1'),
        '4:1',
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(AlertDialog), findsNothing);
      late String? after;
      await tester.runAsync(() async => after = await stored());
      final table = BibleTableValue.decode(
        BibleSectionFieldsConfig.parseValues(after)[ExposurePoints.blocks],
      );
      expect(table.rows.single, [
        'Noches de reparto',
        '',
        '4:1',
        '',
        'Sombras cerradas',
      ]);

      await saveSnapshot(tester, 'exposicion_${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  }
}
