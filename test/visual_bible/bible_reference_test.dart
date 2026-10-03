import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/visual_bible/bible_reference.dart';

void main() {
  test('una ficha antigua conserva sus notas como «por qué»', () {
    final reference = BibleReference.fromJson({
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
    const original = BibleReference(
      work: 'Se7en · David Fincher',
      title: 'El peso del entorno',
      kind: 'Puesta en escena',
      why: 'El decorado oprime al personaje',
      purpose: 'Que la ciudad sea un antagonista',
      scene: 'La llegada al piso',
      imageId: 12,
    );
    final copy = BibleReference.fromJson(original.toJson());
    expect(copy.kind, 'Puesta en escena');
    expect(copy.purpose, 'Que la ciudad sea un antagonista');
    expect(copy.imageId, 12);
    expect(copy.legacyPairing, isFalse);
  });

  test('imagen de cada ficha: vinculada, por posición en antiguas, o ninguna',
      () {
    final references = [
      BibleReference.fromJson({'title': 'Antigua'}),
      const BibleReference(title: 'Con imagen', imageId: 30),
      const BibleReference(title: 'Solo emoción'),
      const BibleReference(title: 'Imagen borrada', imageId: 99),
    ];
    expect(BibleReference.resolveImages(references, [10, 20, 30]), [
      10,
      30,
      null,
      null,
    ]);
  });

  test('una ficha antigua de Concepto se lee con sus campos', () {
    final reference = BibleReference.fromJson({
      'film': 'Blade Runner 2049',
      'dp': 'Roger Deakins',
      'tone': 'Melancolía brutalista',
      'intent': 'Aislamiento del sujeto',
    });
    expect(reference.work, 'Blade Runner 2049 · Roger Deakins');
    expect(reference.title, 'Blade Runner 2049');
    expect(reference.why, 'Melancolía brutalista');
    expect(reference.purpose, 'Aislamiento del sujeto');
  });

  test('una ficha sin contenido se considera vacía', () {
    expect(const BibleReference(kind: 'Tema').isEmpty, isTrue);
    expect(const BibleReference(why: 'Algo').isEmpty, isFalse);
  });
}
