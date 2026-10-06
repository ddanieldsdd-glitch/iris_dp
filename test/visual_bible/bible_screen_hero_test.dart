import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_screen_hero.dart';
import 'package:iris_dp/shared/visual_bible/bible_image_links.dart';
import 'package:iris_dp/shared/visual_bible/bible_point_extras.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';

void main() {
  test('la cabecera guarda imagen y color, y se vacía sin ninguno', () {
    final saved = const BibleScreenHeroValue(
      imageId: 12,
    ).withColor('#FF9F0A').encode()!;
    final read = BibleScreenHeroValue.read({BibleScreenHeroValue.key: saved});
    expect(read.imageId, 12);
    expect(read.colorHex, '#FF9F0A');
    expect(read.argb, 0xFFFF9F0A);
    expect(read.withImage(null).withColor(null).encode(), isNull);
    expect(BibleScreenHeroValue.read(const {}).imageId, isNull);
  });

  test('cabecera y complementos se reenlazan al descargar de la nube', () {
    final content = BibleSectionFieldsConfig.encode(
      BibleSectionFieldsConfig.defaultsFor(BibleSectionId.direction),
      values: {
        BibleScreenHeroValue.key: const BibleScreenHeroValue(
          imageId: 4,
          colorHex: '#34C759',
        ).encode()!,
        'tone__extra': const BiblePointExtras(imageIds: [4, 5]).encode(),
      },
    );
    final values = BibleSectionFieldsConfig.parseValues(
      BibleImageLinks.remap(content, {4: 40, 5: 50}),
    );
    expect(BibleScreenHeroValue.read(values).imageId, 40);
    expect(BibleScreenHeroValue.read(values).colorHex, '#34C759');
    expect(BiblePointExtras.read(values, 'tone').imageIds, [40, 50]);
    expect(jsonDecode(values['tone__extra']!)['images'], [40, 50]);
  });

  testWidgets('el menú de la cabecera: nombre, color y reiniciar con '
      'confirmación', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    var value = const BibleScreenHeroValue();
    var title = 'Dirección';
    var resets = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => BibleScreenHero(
                projectId: 1,
                bibleId: 1,
                sectionId: BibleSectionId.direction,
                title: title,
                value: value,
                onChanged: (next) => setState(() => value = next),
                onRename: (name) => setState(() => title = name),
                onReset: () => resets++,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Dirección'), findsOneWidget);
    expect(find.text('BIBLIA DE FOTOGRAFÍA'), findsOneWidget);

    Future<void> choose(String label) async {
      await tester.tap(find.byTooltip('Opciones de la pantalla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Opciones de la pantalla'));
    await tester.pumpAndSettle();
    expect(find.text('Elegir imagen'), findsOneWidget);
    expect(find.text('Quitar imagen'), findsNothing);
    await tester.tap(find.text('Cambiar nombre'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Puesta en escena');
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();
    expect(title, 'Puesta en escena');
    expect(find.text('Puesta en escena'), findsOneWidget);

    await choose('Color de la pantalla');
    await tester.tap(
      find.byKey(ValueKey('screen_color_${kBibleScreenColors.first}')),
    );
    await tester.pumpAndSettle();
    expect(value.colorHex, kBibleScreenColors.first);

    // Reiniciar pide confirmación: cancelar no hace nada.
    await choose('Reiniciar pantalla');
    expect(find.textContaining('No se puede deshacer'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(resets, 0);
    await choose('Reiniciar pantalla');
    await tester.tap(find.widgetWithText(FilledButton, 'Reiniciar pantalla'));
    await tester.pumpAndSettle();
    expect(resets, 1);
  });

  test('reiniciar una pantalla borra lo escrito y conserva su cabecera', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Reinicio'),
    );
    final bible = await db.ensureVisualBibleForProject(projectId);
    await db.addBuiltinBibleSection(
      bibleId: bible.id,
      sectionId: BibleSectionId.direction,
    );
    final defaults = BibleSectionFieldsConfig.defaultsFor(
      BibleSectionId.direction,
    );
    await db.saveBibleSectionFields(bible.id, BibleSectionId.direction, [
      defaults.first,
      const BibleSectionField(key: 'field_mio', label: 'Mío'),
    ]);
    const hero = BibleScreenHeroValue(imageId: 3, colorHex: '#FF453A');
    for (final entry in {
      'field_mio': 'Texto mío',
      'tone': '[{"title":"Frío","body":""}]',
      'tone__extra': const BiblePointExtras(text: 'Nota').encode(),
      'directionData': '{"emotionTags":["Tensión"]}',
      BibleScreenHeroValue.key: hero.encode()!,
    }.entries) {
      await db.saveBibleSectionFieldValue(
        bible.id,
        BibleSectionId.direction,
        entry.key,
        entry.value,
      );
    }

    await db.resetBibleSectionContent(
      bible.id,
      BibleSectionId.direction,
      keepValueKeys: const {BibleScreenHeroValue.key},
    );

    final def = await (db.select(
      db.bibleSectionDefinitions,
    )..where((d) => d.id.equals(BibleSectionId.direction))).getSingle();
    final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
    expect(values.keys, [BibleScreenHeroValue.key]);
    expect(BibleScreenHeroValue.read(values).imageId, 3);
    expect(
      BibleSectionFieldsConfig.parse(
        def.contentJson,
        BibleSectionId.direction,
      ).map((f) => f.key),
      defaults.map((f) => f.key),
    );
  });

  test('reiniciar vacía los textos de la pantalla y no los de otras', () {
    final data = VisualBibleData(projectId: 1)
      ..directionNarrativeIntent = 'Intención'
      ..tone = 'Frío'
      ..pointOfView = 'Subjetivo'
      ..conceptNarrativeIntent = 'Concepto'
      ..lensPhilosophy = 'Anamórficas'
      ..actVisualNotes = [
        {'id': 'act1', 'title': 'Orden'},
      ];
    data.clearSection(BibleSectionId.direction);
    expect(data.directionNarrativeIntent, isNull);
    expect(data.tone, isNull);
    expect(data.pointOfView, isNull);
    expect(data.conceptNarrativeIntent, 'Concepto');
    expect(data.lensPhilosophy, 'Anamórficas');
    expect(data.actVisualNotes, isNotEmpty, reason: 'los actos son del proyecto');
  });
}
