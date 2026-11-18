import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/plan_path_separation.dart';

/// Los recorridos que van por el mismo sitio se separan en carriles; los
/// demás no se tocan.
void main() {
  test('dos recorridos encima uno de otro van en carriles', () {
    final out = separatePaths([
      [const Offset(0, 0), const Offset(100, 0)],
      [const Offset(100, 1), const Offset(0, 1)],
    ]);
    final a = out[0].single;
    final b = out[1].single;
    // Ya no se pisan: entre carriles, lo pedido.
    expect((a.a.dy - b.b.dy).abs(), closeTo(4.5, 1.1));
    // Siguen siendo paralelos y del mismo largo.
    expect(a.a.dy, a.b.dy);
    expect((a.b - a.a).distance, 100);
  });

  test('tres a la vez: tres carriles centrados', () {
    final out = separatePaths([
      for (var i = 0; i < 3; i++) [const Offset(0, 0), const Offset(80, 0)],
    ]);
    final ys = [for (final r in out) r.single.a.dy]..sort();
    expect(ys.first, closeTo(-4.5, 0.01));
    expect(ys[1], closeTo(0, 0.01));
    expect(ys.last, closeTo(4.5, 0.01));
  });

  test('lo que se cruza o va lejos no se mueve', () {
    final routes = [
      [const Offset(0, 0), const Offset(100, 0)],
      [const Offset(50, -50), const Offset(50, 50)],
      [const Offset(0, 40), const Offset(100, 40)],
    ];
    final out = separatePaths(routes);
    for (final (r, spans) in out.indexed) {
      expect(spans.single.a, routes[r][0]);
      expect(spans.single.b, routes[r][1]);
    }
  });

  test('solo se separa el tramo compartido', () {
    final out = separatePaths([
      [const Offset(0, 0), const Offset(100, 0), const Offset(100, 100)],
      [const Offset(0, 0), const Offset(100, 0), const Offset(200, 0)],
    ]);
    // El primer tramo de cada uno, apartado; el resto, en su sitio.
    expect(out[0][0].a.dy, isNot(0));
    expect(out[0][1].a, const Offset(100, 0));
    expect(out[1][0].a.dy, isNot(0));
    expect(out[0][0].a.dy, -out[1][0].a.dy);
  });
}
