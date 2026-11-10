import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El visor 3D carga un único script clásico (sin módulos, que fallan en
/// `file://`) y depende de dos parches sobre los shaders de three.js. Si al
/// actualizar three cambia ese texto, la luz dejaría de cuadrar en silencio.
void main() {
  final html = File('assets/viewer3d/index.html').readAsStringSync();
  final viewer = File('assets/viewer3d/viewer.js').readAsStringSync();
  final bundle = File(
    'assets/viewer3d/vendor/three.iris.js',
  ).readAsStringSync();

  test('index.html carga scripts clásicos que existen', () {
    final sources = RegExp(
      r'<script src="([^"]+)"',
    ).allMatches(html).map((m) => m[1]!).toList();
    expect(sources, ['vendor/three.iris.js', 'viewer.js']);
    for (final src in sources) {
      expect(File('assets/viewer3d/$src').existsSync(), isTrue, reason: src);
    }
    expect(html, isNot(contains('type="module"')));
  });

  test('el paquete trae lo que usa el visor', () {
    for (final name in [
      'OrbitControls',
      'GLTFExporter',
      'GLTFLoader',
      'OBJLoader',
      'PLYLoader',
      'RectAreaLightUniformsLib',
    ]) {
      expect(viewer, contains('THREE.$name'), reason: name);
      expect(bundle, contains(name), reason: name);
    }
  });

  test('sin las API retiradas de three', () {
    for (final old in [
      'sRGBEncoding',
      'outputEncoding',
      'physicallyCorrectLights',
      'PCFSoftShadowMap',
    ]) {
      expect(viewer, isNot(contains(old)), reason: old);
    }
  });

  test('los textos que parchea la calibración siguen en three', () {
    for (final name in ['FALLOFF_HEAD', 'AMBIENT_LOSS']) {
      final patched = RegExp("const $name = '([^']+)'").firstMatch(viewer)?[1];
      expect(patched, isNotNull, reason: name);
      expect(bundle, contains(patched), reason: name);
    }
  });
}
