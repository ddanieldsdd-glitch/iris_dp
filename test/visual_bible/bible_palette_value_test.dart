import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/visual_bible/bible_cards.dart';
import 'package:iris_dp/shared/visual_bible/bible_palette.dart';

void main() {
  test('una paleta antigua (lista de colores) muestra solo la paleta', () {
    final value = BiblePaletteValue.decode('[{"hex":"#112233","name":"Azul"}]');
    expect(value.colors.single.hex, '#112233');
    expect(value.show, {BiblePalettePart.palette});
    expect(value.imageIds, isEmpty);
  });

  test('guardar y leer conserva colores, imágenes, texto y lo que se ve', () {
    const value = BiblePaletteValue(
      colors: [BiblePaletteColor(hex: '#8A1C1C', name: 'Óxido', note: 'Culpa')],
      imageIds: [4, 9],
      text: 'El rojo solo aparece cuando miente',
      show: {BiblePalettePart.images, BiblePalettePart.text},
    );
    final back = BiblePaletteValue.decode(value.encode());
    expect(back.colors.single.note, 'Culpa');
    expect(back.imageIds, [4, 9]);
    expect(back.text, 'El rojo solo aparece cuando miente');
    expect(back.show, {BiblePalettePart.images, BiblePalettePart.text});
    // Los lectores de colores entienden también el formato nuevo.
    expect(BiblePaletteColor.listFrom(value.encode()).single.hex, '#8A1C1C');
  });

  test('ocultar una parte no borra su contenido', () {
    const value = BiblePaletteValue(
      colors: [BiblePaletteColor(hex: '#112233')],
      show: {BiblePalettePart.palette, BiblePalettePart.text},
    );
    final hidden = value.toggled(BiblePalettePart.palette);
    expect(hidden.shows(BiblePalettePart.palette), isFalse);
    expect(hidden.colors, hasLength(1));
    expect(
      BiblePaletteValue.decode(hidden.encode()).colors.single.hex,
      '#112233',
    );
  });

  test('siempre queda al menos una parte visible', () {
    const value = BiblePaletteValue();
    expect(value.toggled(BiblePalettePart.palette).show, {
      BiblePalettePart.palette,
    });
  });

  test('una paleta vacía que solo muestra la paleta no guarda nada', () {
    expect(const BiblePaletteValue().encode(), isNull);
    expect(
      const BiblePaletteValue(show: {BiblePalettePart.text}).encode(),
      isNotNull,
    );
  });

  test('un acto guarda sus imágenes y lee los actos sin ellas', () {
    const act = BibleCard(title: 'Orden', imageIds: [3]);
    expect(BibleCard.listFrom(BibleCard.encode([act])).single.imageIds, [3]);
    expect(
      BibleCard.listFrom('[{"title":"Viejo","body":""}]').single.imageIds,
      isEmpty,
    );
  });
}
