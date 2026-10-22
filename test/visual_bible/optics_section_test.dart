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
import 'package:iris_dp/features/visual_bible/widgets/bible_equipment_widget.dart';
import 'package:iris_dp/features/visual_bible/widgets/sections/optics_section.dart';
import 'package:iris_dp/shared/visual_bible/bible_equipment.dart';
import 'package:iris_dp/shared/visual_bible/bible_optics_context.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/optics_points.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/snapshot.dart';

Lense _lens(int id, String model, double focal, {bool anam = false}) => Lense(
  id: id,
  brand: 'Atlas',
  model: model,
  focalLength: focal,
  minTStop: 2,
  formatCoverage: 'S35',
  isAnamorphic: anam,
  squeezeRatio: anam ? 2 : null,
  isCustom: false,
  vintage: false,
  lukaCompatible: false,
);

void main() {
  test('las lentes del catálogo se agrupan en juegos por serie', () {
    final sets = BibleLensSet.group([
      _lens(1, 'Orion 40mm', 40, anam: true),
      _lens(2, 'Orion 32mm', 32, anam: true),
      _lens(3, 'Mercury 36mm', 36),
    ]);
    expect(sets.map((s) => s.name), ['Atlas Mercury', 'Atlas Orion']);
    final orion = sets.last;
    expect(orion.lenses.map((l) => l.id), [2, 1]);
    expect(orion.facts['Tipo'], 'Anamórfica');
    expect(orion.facts['Factor anamórfico'], '2x');
    expect(orion.facts['Focales'], '32, 40 mm');
    expect(sets.first.facts.containsKey('Factor anamórfico'), isFalse);
  });

  test('los juegos de la biblia son los que lee Formato', () {
    final sets = OpticsPoints.lensSetsFor([
      const BibleEquipmentItem(
        role: 'A',
        name: 'Atlas Orion',
        facts: {'Tipo': 'Anamórfica', 'Factor anamórfico': '2x'},
      ),
      const BibleEquipmentItem(role: 'B', name: 'Cooke S4'),
    ]);
    expect(sets.first['isAnamorphic'], true);
    expect(sets.first['squeezeRatio'], 2.0);
    expect(sets.last['isAnamorphic'], false);
    expect(sets.last['squeezeRatio'], 1.0);
    final context = BibleOpticsContext.resolve(activeLensSet: sets.first);
    expect(context.isAnamorphic, isTrue);
    expect(context.squeezeRatio, 2.0);
  });

  for (final width in [900.0, 1500.0]) {
    testWidgets('Óptica a $width px: lo antiguo en los puntos nuevos y sin '
        'ejemplos', (tester) async {
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
                      d.id.equals(BibleSectionId.optics),
                ))
                .getSingle();
        return def.contentJson;
      }

      await tester.runAsync(() async {
        final projectId = await db.insertProject(
          ProjectsCompanion.insert(name: 'Óptica'),
        );
        final bible = await db.ensureVisualBibleForProject(projectId);
        await db.addBuiltinBibleSection(
          bibleId: bible.id,
          sectionId: BibleSectionId.optics,
        );
        data = VisualBibleData.fromRow(bible)
          ..lensPhilosophy = 'Centro nítido, bordes que se deshacen'
          ..primaryFocalLengths = [32, 40]
          // Contenido guardado con la pantalla de antes.
          ..opticsConfigJson = jsonEncode({
            'primarySetName': 'Atlas Orion',
            'tStop': 'T2.8',
            'bokehCharacteristic': 'Óvalos verticales',
            'filtrationStack': [
              {
                'name': 'Black Pro-Mist',
                'density': '1/8',
                'justification': 'Base para todo el rodaje',
              },
            ],
            'maintenanceLog': [
              {'date': '12/10', 'title': 'Colimación', 'description': 'OK'},
            ],
            'lensSets': [
              {
                'name': 'B-Cam',
                'isAnamorphic': true,
                'squeezeRatio': 1.8,
                'aspectRatio': '2.39:1',
              },
            ],
          });
        contentJson = await stored();
      });

      var changes = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: OpticsSection(
                data: data,
                projectId: data.projectId,
                sectionContentJson: contentJson,
                onChanged: (_) => changes++,
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

      // Lo de antes, cada cosa en su punto.
      expect(find.text('Atlas Orion'), findsOneWidget);
      expect(find.text('B-Cam'), findsOneWidget);
      expect(find.textContaining('Factor anamórfico: 1.80x'), findsOneWidget);
      expect(find.text('Centro nítido, bordes que se deshacen'), findsOneWidget);
      expect(find.text('T2.8'), findsOneWidget);
      expect(find.text('Óvalos verticales'), findsOneWidget);
      expect(find.text('Black Pro-Mist'), findsOneWidget);
      expect(find.text('Base para todo el rodaje'), findsOneWidget);
      expect(find.text('32 mm'), findsOneWidget);
      expect(find.text('Colimación'), findsOneWidget);
      // 1/8 cae en la escala de densidades: lleva barra.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Nada de ejemplos ni de inglés.
      for (final example in [
        'Minimalist Character',
        'Hollywood Black Magic',
        'Tiffen',
        'Lens sets',
        'Maintenance',
      ]) {
        expect(find.textContaining(example), findsNothing, reason: example);
      }

      // El juego principal pasa a definitivo; Formato sigue leyendo los
      // juegos de la configuración.
      await tester.tap(find.text('DEFINITIVO').first);
      await settle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(changes, greaterThan(0));
      late String? after;
      await tester.runAsync(() async => after = await stored());
      final items = BibleEquipmentItem.listFrom(
        BibleSectionFieldsConfig.parseValues(after)[OpticsPoints.kit],
      );
      expect(items.first.status, BibleEquipmentStatus.definitive);
      expect(items.length, 2);
      final sets = BibleOpticsContext.lensSetsFromJson(data.opticsConfigJson);
      expect(sets.last['name'], 'B-Cam');
      expect(sets.last['squeezeRatio'], 1.8);
      expect(sets.last['aspectRatio'], '2.39:1');

      await saveSnapshot(tester, 'optica_${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  }
}
