import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/features/camera_plan/rig/scan_walls.dart';

/// Un tramo recto troceado en pedazos de 5 cm con un poco de ruido, como
/// sale del corte de una malla.
List<(Offset, Offset)> chopped(Offset a, Offset b, math.Random rnd) {
  final out = <(Offset, Offset)>[];
  final len = (b - a).distance;
  final steps = (len / 0.05).ceil();
  Offset at(int i) {
    final p = Offset.lerp(a, b, i / steps)!;
    return p + Offset(rnd.nextDouble() - 0.5, rnd.nextDouble() - 0.5) * 0.01;
  }

  for (var i = 0; i < steps; i++) {
    out.add((at(i), at(i + 1)));
  }
  return out;
}

void main() {
  test('sliceSegments lee la lista plana', () {
    final s = sliceSegments([0, 0, 1, 0, 2, 2, 3, 3]);
    expect(s, hasLength(2));
    expect(s[1].$2, const Offset(3, 3));
  });

  test('habitación de 4 × 3 con puerta: cuatro paredes y una partida', () {
    final rnd = math.Random(1);
    final segs = [
      // Pared de arriba entera.
      ...chopped(const Offset(0, 0), const Offset(4, 0), rnd),
      // Derecha.
      ...chopped(const Offset(4, 0), const Offset(4, 3), rnd),
      // Abajo con una puerta de 0,9 m entre 1,5 y 2,4.
      ...chopped(const Offset(0, 3), const Offset(1.5, 3), rnd),
      ...chopped(const Offset(2.4, 3), const Offset(4, 3), rnd),
      // Izquierda.
      ...chopped(const Offset(0, 0), const Offset(0, 3), rnd),
      // Una mesa pequeña: no es pared.
      ...chopped(const Offset(1.8, 1.4), const Offset(2.2, 1.4), rnd),
    ];
    final walls = proposeWalls(segs);
    expect(walls, hasLength(5));
    expect(walls.first.length, closeTo(4, 0.05));
    final lengths = walls.map((w) => w.length).toList();
    expect(lengths.where((l) => (l - 3).abs() < 0.05), hasLength(2));
    expect(lengths.where((l) => (l - 1.5).abs() < 0.05), hasLength(1));
    expect(lengths.where((l) => (l - 1.6).abs() < 0.05), hasLength(1));
  });

  test('las dos caras de una pared dan una sola, en medio y con grosor', () {
    final rnd = math.Random(2);
    final walls = proposeWalls([
      ...chopped(const Offset(0, 0), const Offset(3, 0), rnd),
      ...chopped(const Offset(0, 0.15), const Offset(3, 0.15), rnd),
    ]);
    expect(walls, hasLength(1));
    expect(walls.single.start.dy, closeTo(0.075, 0.01));
    expect(walls.single.thickness, closeTo(0.15, 0.01));
  });

  test('una habitación girada 30° también sale', () {
    final rnd = math.Random(3);
    const rot = 30 * math.pi / 180;
    Offset r(double x, double y) => Offset(
      x * math.cos(rot) - y * math.sin(rot),
      x * math.sin(rot) + y * math.cos(rot),
    );
    final walls = proposeWalls([
      ...chopped(r(0, 0), r(4, 0), rnd),
      ...chopped(r(4, 0), r(4, 3), rnd),
      ...chopped(r(4, 3), r(0, 3), rnd),
      ...chopped(r(0, 3), r(0, 0), rnd),
    ]);
    expect(walls, hasLength(4));
    final d = walls.first.end - walls.first.start;
    final angle = (math.atan2(d.dy, d.dx) * 180 / math.pi) % 180;
    expect(angle, closeTo(30, 1));
  });

  test('sin tramos, sin paredes', () {
    expect(proposeWalls(const []), isEmpty);
  });
}
