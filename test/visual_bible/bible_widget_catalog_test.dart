import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/bible_widget_catalog.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:iris_dp/shared/visual_bible/bible_stitch_module_registry.dart';

void main() {
  test('cada widget tiene un identificador único y una familia', () {
    final ids = BibleWidgetCatalog.entries.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final category in BibleWidgetCategory.values) {
      expect(
        BibleWidgetCatalog.inCategory(category),
        isNotEmpty,
        reason: category.label,
      );
    }
  });

  test('un punto se pinta con el widget que se eligió al crearlo', () {
    const master = BibleSectionField(
      key: 'a',
      label: 'Paleta',
      type: BibleSectionFieldType.palette,
      widget: 'palette_master',
    );
    expect(BibleWidgetCatalog.forField(master)!.id, 'palette_master');

    // Un punto anterior a las variantes usa la de su tipo.
    const old = BibleSectionField(
      key: 'b',
      label: 'Paleta',
      type: BibleSectionFieldType.palette,
    );
    expect(BibleWidgetCatalog.forField(old)!.id, 'palette');

    // Un identificador de otro tipo no cambia cómo se pinta.
    const wrong = BibleSectionField(
      key: 'c',
      label: 'Actos',
      type: BibleSectionFieldType.acts,
      widget: 'palette_master',
    );
    expect(BibleWidgetCatalog.forField(wrong)!.id, 'acts');
  });

  test('las referencias antiguas se nombran por su preajuste', () {
    const deck = BibleSectionField(
      key: 'r',
      label: 'Referencias',
      type: BibleSectionFieldType.referenceDeck,
    );
    expect(
      BibleWidgetCatalog.forField(
        deck,
        value: '{"preset":"technical","items":[]}',
      )!.id,
      'references_technical',
    );
  });

  test('el widget elegido sobrevive a guardar y leer', () {
    final json = BibleSectionFieldsConfig.encode(const [
      BibleSectionField(
        key: 'field_1',
        label: 'Pilares',
        type: BibleSectionFieldType.cards,
        widget: 'cards_pillars',
      ),
    ]);
    final field = BibleSectionFieldsConfig.parse(json, 'custom_1').single;
    expect(field.widget, 'cards_pillars');
    expect(field.copyWith(label: 'Otro').widget, 'cards_pillars');
  });

  test('Dirección y Concepto proponen primero sus widgets', () {
    final direction = BibleWidgetCatalog.recommendedFor(
      BibleSectionId.direction,
    ).map((e) => e.id);
    expect(direction, containsAll(['acts', 'cards_pillars', 'cards', 'tags']));

    final concept = BibleWidgetCatalog.recommendedFor(
      BibleSectionId.concept,
    ).map((e) => e.id);
    expect(
      concept,
      containsAll(['palette_master', 'palette_symbolism', 'acts']),
    );
  });

  test('los puntos de fábrica apuntan a widgets que existen', () {
    for (final sectionId in [BibleSectionId.direction, BibleSectionId.concept]) {
      for (final module in BibleStitchModuleRegistry.modulesFor(sectionId)) {
        if (module.widgetId == null) continue;
        expect(
          BibleWidgetCatalog.byId(module.widgetId),
          isNotNull,
          reason: '$sectionId/${module.key}',
        );
      }
    }
    expect(
      BibleStitchModuleRegistry.module(
        BibleSectionId.direction,
        'acts',
      )!.widgetId,
      'acts',
    );
  });
}
