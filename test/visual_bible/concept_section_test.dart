import 'dart:convert';

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/widgets/sections/concept_section.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_text_specs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/snapshot.dart';

void main() {
  for (final width in [900.0, 1500.0]) {
    testWidgets('Concepto a $width px: lo antiguo se lee en los puntos '
        'nuevos, sin ejemplos ni diálogos', (tester) async {
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
                      d.id.equals(BibleSectionId.concept),
                ))
                .getSingle();
        return def.contentJson;
      }

      await tester.runAsync(() async {
        final projectId = await db.insertProject(
          ProjectsCompanion.insert(name: 'Concepto'),
        );
        final bible = await db.ensureVisualBibleForProject(projectId);
        await db.addBuiltinBibleSection(
          bibleId: bible.id,
          sectionId: BibleSectionId.concept,
        );
        data = VisualBibleData.fromRow(bible)
          ..lightingPhilosophy = 'Luz direccional dura'
          ..contrastStyle = 'Alto (4:1)';
        // Contenido guardado con la pantalla de antes.
        await db.saveBibleSectionFieldValue(
          bible.id,
          BibleSectionId.concept,
          'conceptData',
          jsonEncode({
            'colorSymbols': [
              {
                'poeticName': 'Azul profundo',
                'hex': '#0F1C2E',
                'narrativeMeaning': 'Soledad institucional',
              },
            ],
            'lightingMetrics': {'motivation': 'Prácticos visibles'},
            'masterPalette': [
              {'hex': '#112233', 'name': 'Noche'},
            ],
            'shadowTreatment': 'Negros densos',
            'composition': 'Personaje pequeño',
            'act2Intent': 'Contrastes agresivos',
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
              body: ConceptSection(
                data: data,
                projectId: data.projectId,
                sectionContentJson: contentJson,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);

      // Lo escrito antes está en su punto.
      expect(find.text('Luz direccional dura'), findsOneWidget);
      expect(find.text('Alto (4:1)'), findsOneWidget);
      expect(find.text('Prácticos visibles'), findsOneWidget);
      expect(find.text('Negros densos'), findsOneWidget);
      expect(find.text('Personaje pequeño'), findsOneWidget);
      expect(find.text('Contrastes agresivos'), findsOneWidget);
      expect(find.textContaining('AZUL PROFUNDO'), findsWidgets);
      expect(find.text('Soledad institucional'), findsOneWidget);

      // Nada de ejemplos ni de inglés.
      expect(find.text('El Orden Frágil'), findsNothing);
      expect(find.textContaining('Key Frame'), findsNothing);
      expect(find.textContaining('Fill Light'), findsNothing);
      expect(find.textContaining('Symmetrical'), findsNothing);

      // Los ocho puntos, cada uno con su menú.
      expect(find.byTooltip('Opciones del punto'), findsNWidgets(8));

      // Escribir un dato lo guarda en el punto, sin diálogo.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Alto (4:1)'),
        'Medio (2:1)',
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(AlertDialog), findsNothing);
      late String? after;
      await tester.runAsync(() async => after = await stored());
      final light = BibleTextSpecsValue.decode(
        BibleSectionFieldsConfig.parseValues(after)['lightPhilosophy'],
      );
      expect(light.text, 'Luz direccional dura');
      expect(light.rows.first, ('Contraste', 'Medio (2:1)'));

      await saveSnapshot(tester, 'concepto_${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  }
}
