import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';

void main() {
  test('el ancho del punto se guarda y un punto antiguo es completo', () {
    const field = BibleSectionField(
      key: 'k',
      label: 'Datos',
      width: BiblePointWidth.third,
    );
    final json = field.toJson();
    expect(json['width'], 'third');
    expect(BibleSectionField.fromJson(json).width, BiblePointWidth.third);

    // Los puntos guardados antes de existir el ancho no llevan la clave.
    final old = BibleSectionField.fromJson({'key': 'a', 'label': 'A'});
    expect(old.width, BiblePointWidth.full);
    expect(old.toJson().containsKey('width'), isFalse);
    expect(old.copyWith(width: BiblePointWidth.half).width,
        BiblePointWidth.half);
  });

  test('una fila son seis sextos', () {
    expect(
      BiblePointWidth.twoThirds.sixths + BiblePointWidth.third.sixths,
      BiblePointWidth.full.sixths,
    );
    expect(BiblePointWidth.half.sixths * 2, 6);
    expect(BiblePointWidth.third.sixths * 3, 6);
  });
}
