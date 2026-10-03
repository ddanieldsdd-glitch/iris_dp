import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/visual_bible/direction_reference.dart';

void main() {
  test('una ficha antigua conserva sus notas como «por qué»', () {
    final reference = DirectionReference.fromJson({
      'refLabel': 'FINCHER / SE7EN',
      'title': 'Espacio negativo',
      'body': 'Tercio inferior',
      'lens': '35mm',
    });
    expect(reference.work, 'FINCHER / SE7EN');
    expect(reference.why, 'Tercio inferior');
    expect(reference.purpose, isEmpty);
    expect(reference.legacyPairing, isTrue);
    expect(reference.toJson()['lens'], '35mm');
  });

  test('ida y vuelta de una ficha nueva', () {
    const original = DirectionReference(
      work: 'Se7en · David Fincher',
      title: 'El peso del entorno',
      kind: 'Puesta en escena',
      why: 'El decorado oprime al personaje',
      purpose: 'Que la ciudad sea un antagonista',
      scene: 'La llegada al piso',
      imageId: 12,
    );
    final copy = DirectionReference.fromJson(original.toJson());
    expect(copy.kind, 'Puesta en escena');
    expect(copy.purpose, 'Que la ciudad sea un antagonista');
    expect(copy.imageId, 12);
    expect(copy.legacyPairing, isFalse);
  });

  test('imagen de cada ficha: vinculada, por posición en antiguas, o ninguna',
      () {
    final references = [
      DirectionReference.fromJson({'title': 'Antigua'}),
      const DirectionReference(title: 'Con imagen', imageId: 30),
      const DirectionReference(title: 'Solo emoción'),
      const DirectionReference(title: 'Imagen borrada', imageId: 99),
    ];
    expect(DirectionReference.resolveImages(references, [10, 20, 30]), [
      10,
      30,
      null,
      null,
    ]);
  });

  test('una ficha sin contenido se considera vacía', () {
    expect(const DirectionReference(kind: 'Tema').isEmpty, isTrue);
    expect(const DirectionReference(why: 'Algo').isEmpty, isFalse);
  });
}
