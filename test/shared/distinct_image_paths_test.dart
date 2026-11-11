import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/utils/distinct_images.dart';
import 'package:path/path.dart' as p;

/// Una misma imagen con dos nombres salía dos veces en la planta de rodaje:
/// «Usar el dibujo del storyboard» la copia como referencia con otro nombre.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('iris_distinct_'));
  tearDown(() => dir.deleteSync(recursive: true));

  String file(String name, List<int> bytes) {
    final path = p.join(dir.path, name);
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  test('la copia del storyboard con otro nombre sale una vez', () async {
    final story = file('storyboard.png', [1, 2, 3, 4]);
    final copy = file('shot_7_1731.png', [1, 2, 3, 4]);
    final other = file('referencia.png', [9, 9, 9]);
    expect(await distinctImagePaths([story, copy, other]), [story, other]);
  });

  test('la misma ruta escrita de otra forma sale una vez', () async {
    final story = file('a.png', [5, 6]);
    final again = p.join(dir.path, '.', 'a.png');
    expect(await distinctImagePaths([story, again, null, '']), [story]);
  });

  test('lo que no está en disco se queda fuera', () async {
    final story = file('a.png', [5, 6]);
    expect(await distinctImagePaths([p.join(dir.path, 'no.png'), story]), [
      story,
    ]);
  });

  test('imágenes distintas del mismo tamaño se quedan las dos', () async {
    final a = file('a.png', [1, 2, 3]);
    final b = file('b.png', [1, 2, 4]);
    expect(await distinctImagePaths([a, b]), [a, b]);
  });
}
