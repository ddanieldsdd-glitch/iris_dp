import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/bible_widget_catalog.dart';
import 'package:iris_dp/shared/visual_bible/bible_palette.dart';
import 'package:iris_dp/shared/visual_bible/bible_reference.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';

void main() {
  group('catálogo de widgets', () {
    test('cada entrada tiene un id único', () {
      final ids = BibleWidgetCatalog.entries.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('cubre todos los tipos que el usuario puede añadir', () {
      for (final type in [
        BibleSectionFieldType.text,
        BibleSectionFieldType.list,
        BibleSectionFieldType.specs,
        BibleSectionFieldType.palette,
        BibleSectionFieldType.gallery,
        BibleSectionFieldType.referenceDeck,
      ]) {
        expect(BibleWidgetCatalog.forType(type), isNotNull, reason: '$type');
      }
      // Los puntos propios de una sección no salen del catálogo.
      expect(BibleWidgetCatalog.forType(BibleSectionFieldType.blocks), isNull);
    });

    test('las referencias se ofrecen con sus tres preajustes', () {
      for (final (id, preset) in [
        ('references_narrative', BibleReferencePreset.narrative),
        ('references_visual', BibleReferencePreset.visual),
        ('references_technical', BibleReferencePreset.technical),
      ]) {
        final entry = BibleWidgetCatalog.byId(id)!;
        expect(entry.type, BibleSectionFieldType.referenceDeck);
        expect(
          BibleReferenceDeckValue.decode(entry.initialValue).preset,
          preset,
        );
      }
    });
  });

  test('valor de un punto de referencias: ida y vuelta', () {
    const value = BibleReferenceDeckValue(
      preset: BibleReferencePreset.technical,
      items: [BibleReference(title: 'Plano secuencia', why: 'Steadicam')],
    );
    final copy = BibleReferenceDeckValue.decode(value.encode());
    expect(copy.preset, BibleReferencePreset.technical);
    expect(copy.items.single.title, 'Plano secuencia');
    expect(copy.preset.kinds, kTechnicalReferenceKinds);
    // Un valor ilegible no rompe: mazo visual vacío.
    expect(BibleReferenceDeckValue.decode('no es json').items, isEmpty);
  });

  group('BiblePaletteColor', () {
    test('lee de lista y de JSON, y descarta entradas sin código', () {
      final fromList = BiblePaletteColor.listFrom([
        {'hex': '#112233', 'name': 'Noche'},
        {'name': 'sin código'},
        'ruido',
      ]);
      expect(fromList.single.name, 'Noche');
      final encoded = BiblePaletteColor.encode(fromList);
      expect(BiblePaletteColor.listFrom(encoded).single.hex, '#112233');
    });

    test('una paleta vacía no deja valor', () {
      expect(BiblePaletteColor.encode(const []), isNull);
      expect(BiblePaletteColor.listFrom(null), isEmpty);
      expect(BiblePaletteColor.listFrom('{mal'), isEmpty);
    });
  });
}
