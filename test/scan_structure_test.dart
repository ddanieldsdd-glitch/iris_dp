import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/features/camera_plan/rig/scan_structure.dart';

/// Una caja de la escena de prueba: planta (centro, lados, giro) y alturas.
class Box {
  final Offset c;
  final double sx, sz, rotDeg, y0, y1;
  const Box(this.c, this.sx, this.sz, this.y0, this.y1, {this.rotDeg = 0});

  /// De esquina a esquina, sin girar.
  factory Box.span(
    double x0,
    double z0,
    double x1,
    double z1,
    double y0,
    double y1,
  ) => Box(
    Offset((x0 + x1) / 2, (z0 + z1) / 2),
    (x1 - x0).abs(),
    (z1 - z0).abs(),
    y0,
    y1,
  );

  /// Una pared de [a] a [b] con grosor [t], que asoma t/2 por los extremos
  /// para cerrar las esquinas.
  factory Box.wall(
    Offset a,
    Offset b,
    double y0,
    double y1, {
    double t = 0.12,
    double rotDeg = 0,
  }) {
    final len = (b - a).distance + t;
    final ang = math.atan2(b.dy - a.dy, b.dx - a.dx) * 180 / math.pi;
    return Box((a + b) / 2, len, t, y0, y1, rotDeg: ang + rotDeg);
  }

  List<Offset> get corners {
    final r = rotDeg * math.pi / 180;
    final d = Offset(math.cos(r), math.sin(r));
    final n = Offset(-d.dy, d.dx);
    return [
      c - d * (sx / 2) - n * (sz / 2),
      c + d * (sx / 2) - n * (sz / 2),
      c + d * (sx / 2) + n * (sz / 2),
      c - d * (sx / 2) + n * (sz / 2),
    ];
  }

  bool contains(Offset p) {
    final r = rotDeg * math.pi / 180;
    final d = Offset(math.cos(r), math.sin(r));
    final q = p - c;
    final u = q.dx * d.dx + q.dy * d.dy;
    final v = -q.dx * d.dy + q.dy * d.dx;
    return u.abs() <= sx / 2 && v.abs() <= sz / 2;
  }
}

/// Lo que mediría el visor de una escena de cajas, con algo de ruido.
ScanProfile profileOf(List<Box> boxes, {int seed = 1}) {
  final rnd = math.Random(seed);
  const step = 0.1, bin = 0.02;
  final y0 = boxes.map((b) => b.y0).reduce(math.min);
  final y1 = boxes.map((b) => b.y1).reduce(math.max);
  final heights = [for (var h = y0 + step / 2; h < y1; h += step) h];
  final slices = [
    for (final h in heights)
      [
        for (final b in boxes)
          if (h > b.y0 && h < b.y1)
            for (var e = 0; e < 4; e++)
              ...chopped(b.corners[e], b.corners[(e + 1) % 4], rnd),
      ],
  ];
  final bins = ((y1 - y0) / bin).ceil() + 1;
  final up = List<double>.filled(bins, 0), down = List<double>.filled(bins, 0);
  for (final b in boxes) {
    up[((b.y1 - y0) / bin).floor().clamp(0, bins - 1)] += b.sx * b.sz;
    down[((b.y0 - y0) / bin).floor().clamp(0, bins - 1)] += b.sx * b.sz;
  }
  // Rejilla de 10 cm, por debajo del techo.
  final floor = boxes.first;
  final xs = floor.corners.map((p) => p.dx),
      zs = floor.corners.map((p) => p.dy);
  const cell = 0.1;
  final gx0 = xs.reduce(math.min), gz0 = zs.reduce(math.min);
  final cols = ((xs.reduce(math.max) - gx0) / cell).ceil();
  final rows = ((zs.reduce(math.max) - gz0) / cell).ceil();
  final cap = y1 - 0.2;
  final top = List<double?>.filled(cols * rows, null);
  // Lo más bajo que se ve en cada celda desde arriba: se sube desde el suelo
  // por las cajas apoyadas unas en otras (escalones, una papelera…).
  final bottom = List<double?>.filled(cols * rows, null);
  final byBase = [...boxes]..sort((a, b) => a.y0.compareTo(b.y0));
  for (var j = 0; j < rows; j++) {
    for (var i = 0; i < cols; i++) {
      final p = Offset(gx0 + (i + 0.5) * cell, gz0 + (j + 0.5) * cell);
      double? seen;
      for (final b in byBase) {
        if (!b.contains(p) || b.y0 >= cap) continue;
        if (seen == null || b.y0 <= seen + 1e-6) {
          seen = math.max(seen ?? b.y1, b.y1);
        }
      }
      bottom[j * cols + i] = seen;
      for (final b in boxes.skip(1)) {
        if (b.y0 >= cap || !b.contains(p)) continue;
        final t = math.min(b.y1, cap - 0.01);
        final k = j * cols + i;
        if (top[k] == null || t > top[k]!) top[k] = t;
      }
    }
  }
  return ScanProfile(
    bin: bin,
    y0: y0,
    up: up,
    down: down,
    heights: heights,
    slices: slices,
    grid: ScanGrid(
      x0: gx0,
      y0: gz0,
      cell: cell,
      cols: cols,
      rows: rows,
      top: top,
      bottom: bottom,
    ),
  );
}

/// Un tramo en pedazos de 5 cm con un poco de ruido, como el corte de una
/// malla.
List<(Offset, Offset)> chopped(Offset a, Offset b, math.Random rnd) {
  final len = (b - a).distance;
  final steps = math.max(1, (len / 0.05).ceil());
  Offset at(int i) =>
      Offset.lerp(a, b, i / steps)! +
      Offset(rnd.nextDouble() - 0.5, rnd.nextDouble() - 0.5) * 0.01;
  return [for (var i = 0; i < steps; i++) (at(i), at(i + 1))];
}

const ceiling = 2.6;

/// Habitación en L de 5 × 4 con techo a 2,6 m:
/// - ventana en la pared de arriba (x 2–3,2, alféizar 0,9, dintel 2,1);
/// - puerta en la de abajo (x 1–1,9, dintel 2,05);
/// - armario de 2 m pegado a la pared izquierda, que tapa la pared detrás;
/// - cama de 0,55 m.
List<Box> lRoom() {
  const h = ceiling;
  return [
    Box.span(-0.3, -0.3, 5.3, 4.3, -0.05, 0), // suelo
    Box.span(-0.3, -0.3, 5.3, 4.3, h, h + 0.05), // techo
    // Arriba (z = 0) con ventana.
    Box.span(-0.06, -0.06, 2, 0.06, 0, h),
    Box.span(2, -0.06, 3.2, 0.06, 0, 0.9),
    Box.span(2, -0.06, 3.2, 0.06, 2.1, h),
    Box.span(3.2, -0.06, 5.06, 0.06, 0, h),
    Box.wall(const Offset(5, 0), const Offset(5, 2.5), 0, h),
    Box.wall(const Offset(5, 2.5), const Offset(3, 2.5), 0, h),
    Box.wall(const Offset(3, 2.5), const Offset(3, 4), 0, h),
    // Abajo (z = 4) con puerta.
    Box.span(1.9, 3.94, 3.06, 4.06, 0, h),
    Box.span(1, 3.94, 1.9, 4.06, 2.05, h),
    Box.span(-0.06, 3.94, 1, 4.06, 0, h),
    // Izquierda (x = 0): detrás del armario solo se ve por encima.
    Box.span(-0.06, 2.2, 0.06, 4.06, 0, h),
    Box.span(-0.06, 1, 0.06, 2.2, 2.0, h),
    Box.span(-0.06, -0.06, 0.06, 1, 0, h),
    // Armario y cama.
    Box.span(0.06, 1, 0.66, 2.2, 0, 2.0),
    Box.span(3.4, 0.2, 4.8, 2.2, 0, 0.55),
  ];
}

void main() {
  late ScanStructure s;
  setUpAll(() => s = solveStructure(profileOf(lRoom())));

  test('suelo y techo salen del histograma', () {
    expect(s.floorY, closeTo(0, 0.05));
    expect(s.heightM, closeTo(ceiling, 0.06));
    expect(s.heightEstimated, isFalse);
  });

  test('la L da seis paredes, con su grosor, y el armario no es pared', () {
    expect(s.walls, hasLength(6));
    for (final w in s.walls) {
      expect(w.thickness, closeTo(0.12, 0.03));
      // Ninguna pared en x = 0,66 (el frente del armario).
      final vertical = (w.start.dx - w.end.dx).abs() < 0.01;
      if (vertical) expect((w.start.dx - 0.66).abs(), greaterThan(0.2));
    }
    final lengths = s.walls.map((w) => w.length).toList()..sort();
    expect(lengths, [
      closeTo(1.5, 0.08),
      closeTo(2, 0.08),
      closeTo(2.5, 0.08),
      closeTo(3, 0.08),
      closeTo(4, 0.08),
      closeTo(5, 0.08),
    ]);
  });

  test('las esquinas quedan cerradas', () {
    for (final w in s.walls) {
      for (final e in [w.start, w.end]) {
        final shared = s.walls.where(
          (o) =>
              !identical(o, w) &&
              ((o.start - e).distance < 0.02 || (o.end - e).distance < 0.02),
        );
        expect(shared, isNotEmpty, reason: 'esquina suelta en $e');
      }
    }
  });

  test('la puerta y la ventana, con sus medidas; detrás del armario nada', () {
    final doors = s.openings.where((o) => o.kind == ScanOpeningKind.door);
    final windows = s.openings.where((o) => o.kind == ScanOpeningKind.window);
    expect(doors, hasLength(1));
    expect(windows, hasLength(1));
    final door = doors.single;
    expect(door.center.dx, closeTo(1.45, 0.1));
    expect(door.center.dy, closeTo(4, 0.05));
    expect(door.width, closeTo(0.9, 0.1));
    expect(door.head, closeTo(2.05, 0.1));
    final window = windows.single;
    expect(window.center.dx, closeTo(2.6, 0.1));
    expect(window.width, closeTo(1.2, 0.1));
    expect(window.sill, closeTo(0.9, 0.1));
    expect(window.head, closeTo(2.1, 0.1));
  });

  test('la cama y el armario salen como muebles', () {
    final bed = s.objects.firstWhere((o) => o.heightM < 1);
    expect(bed.center.dx, closeTo(4.1, 0.1));
    expect(bed.center.dy, closeTo(1.2, 0.1));
    expect(math.max(bed.width, bed.depth), closeTo(2, 0.15));
    expect(math.min(bed.width, bed.depth), closeTo(1.4, 0.15));
    expect(bed.heightM, closeTo(0.55, 0.05));
    expect(s.objects.where((o) => o.heightM > 1.8), hasLength(1));
  });

  test('paredes torcidas 2° salen rectas y a escuadra', () {
    const h = ceiling;
    final room = [
      Box.span(-0.3, -0.3, 4.3, 3.3, -0.05, 0),
      Box.span(-0.3, -0.3, 4.3, 3.3, h, h + 0.05),
      Box.wall(const Offset(0, 0), const Offset(4, 0), 0, h, rotDeg: 2),
      Box.wall(const Offset(4, 0), const Offset(4, 3), 0, h, rotDeg: -1.5),
      Box.wall(const Offset(4, 3), const Offset(0, 3), 0, h, rotDeg: 1),
      Box.wall(const Offset(0, 3), const Offset(0, 0), 0, h, rotDeg: -2),
    ];
    final r = solveStructure(profileOf(room, seed: 7));
    expect(r.walls, hasLength(4));
    for (final w in r.walls) {
      final a = math.atan2(w.end.dy - w.start.dy, w.end.dx - w.start.dx);
      final off = (a * 2 / math.pi - (a * 2 / math.pi).round()).abs();
      expect(off * 90, lessThan(0.2), reason: 'pared torcida: $w');
    }
  });

  test('los planos de ARKit mandan sobre la malla', () {
    // La malla pone la pared de arriba 6 cm más arriba que ARKit.
    const h = ceiling;
    final room = [
      Box.span(-0.3, -0.3, 4.3, 3.3, -0.05, 0),
      Box.span(-0.3, -0.3, 4.3, 3.3, h, h + 0.05),
      Box.wall(const Offset(0, 0), const Offset(4, 0), 0, h),
      Box.wall(const Offset(4, 0), const Offset(4, 3), 0, h),
      Box.wall(const Offset(4, 3), const Offset(0, 3), 0, h),
      Box.wall(const Offset(0, 3), const Offset(0, 0), 0, h),
    ];
    final r = solveStructure(
      profileOf(room),
      capture: const CaptureHints(
        // Cara de dentro según ARKit: en z = 0,12 (la malla dice 0,06).
        wallPlanes: [(Offset(0.5, 0.12), Offset(3.5, 0.12))],
      ),
    );
    final top = r.walls.firstWhere(
      (w) => (w.start.dy - w.end.dy).abs() < 0.01 && w.start.dy < 1,
    );
    expect(top.source, ScanSource.arkit);
    expect(top.start.dy, closeTo(0.06, 0.015));
  });

  group('locales (ES.1b)', () {
    /// Un kebab de 6 × 4 con techo a 2,8 m: barra de 1,1 m, campana
    /// extractora colgada del techo y escaparate de cristal de 3,6 m en la
    /// fachada (la malla no ve el cristal: solo el dintel encima).
    List<Box> kebab() {
      const h = 2.8;
      return [
        Box.span(-0.3, -0.3, 6.3, 4.3, -0.05, 0),
        Box.span(-0.3, -0.3, 6.3, 4.3, h, h + 0.05),
        // Fachada (z = 4) con el escaparate de x 1 a 4,6.
        Box.span(-0.06, 3.94, 1, 4.06, 0, h),
        Box.span(1, 3.94, 4.6, 4.06, 2.4, h),
        Box.span(4.6, 3.94, 6.06, 4.06, 0, h),
        Box.wall(const Offset(6, 4), const Offset(6, 0), 0, h),
        Box.wall(const Offset(6, 0), const Offset(0, 0), 0, h),
        Box.wall(const Offset(0, 0), const Offset(0, 4), 0, h),
        // Barra.
        Box.span(1, 1.4, 5, 2.0, 0, 1.1),
        // Campana sobre la plancha, de 1,9 m al techo.
        Box.span(1.5, 0.06, 3.5, 0.8, 1.9, h),
      ];
    }

    test('la barra y la campana no son paredes; el escaparate sí sale', () {
      final s = solveStructure(profileOf(kebab()));
      expect(s.walls, hasLength(4));
      for (final w in s.walls) {
        // Nada en z = 0,8 (la campana) ni en z = 1,4 / 2,0 (la barra).
        final horizontal = (w.start.dy - w.end.dy).abs() < 0.01;
        if (horizontal) {
          expect(
            [0.0, 4.0].any((z) => (w.start.dy - z).abs() < 0.1),
            isTrue,
            reason: 'pared de más en z = ${w.start.dy}',
          );
        }
      }
      final shop = s.openings.where(
        (o) => o.kind == ScanOpeningKind.storefront,
      );
      expect(shop, hasLength(1));
      expect(shop.single.width, closeTo(3.6, 0.1));
      expect(shop.single.center.dx, closeTo(2.8, 0.1));
      expect(shop.single.head, closeTo(2.4, 0.1));
      // La barra sale como mueble.
      expect(
        s.objects.where((o) => (o.heightM - 1.1).abs() < 0.1),
        hasLength(1),
      );
    });

    test('los toques en los bordes del escaparate mandan', () {
      final s = solveStructure(
        profileOf(kebab()),
        capture: const CaptureHints(
          storefronts: [Offset(1.05, 4.0), Offset(4.55, 3.95)],
        ),
      );
      final shop = s.openings.where(
        (o) => o.kind == ScanOpeningKind.storefront,
      );
      expect(shop, hasLength(1));
      expect(shop.single.width, closeTo(3.5, 0.02));
      expect(shop.single.confidence, greaterThanOrEqualTo(0.9));
    });
  });

  test('calle de noche: sin techo, en cuesta, con papelera y farola', () {
    // Calle de 30 × 8 entre dos fachadas de 6 m que sube 0,6 m en 30 m a
    // escalones de 10 cm (cada 5 m). Una papelera de 1 m arriba de la
    // cuesta.
    final boxes = <Box>[
      // Solo se ve la calle: nada detrás de las fachadas.
      Box.span(0, -0.06, 30, 8.06, -0.05, 0),
      for (var k = 1; k < 6; k++) Box.span(k * 5.0, 0.06, 30, 7.94, 0, k * 0.1),
      Box.wall(const Offset(0, 0), const Offset(30, 0), 0, 6),
      Box.wall(const Offset(0, 8), const Offset(30, 8), 0, 6),
      Box.span(26, 3, 26.6, 3.6, 0.5, 1.5),
    ];
    final s = solveStructure(
      profileOf(boxes),
      capture: const CaptureHints(
        exterior: true,
        lights: [ScanLight(Offset(12, 0.4), 4.5, 'farola')],
      ),
    );
    expect(s.exterior, isTrue);
    expect(s.heightEstimated, isTrue);
    expect(s.walls, hasLength(2));
    for (final w in s.walls) {
      expect(w.length, closeTo(30, 0.2));
    }
    final bin = s.objects.where((o) => (o.center.dx - 26.3).abs() < 0.3);
    expect(bin, hasLength(1));
    // Medida desde el suelo de al lado (0,5), no desde abajo de la calle.
    expect(bin.single.heightM, closeTo(1.0, 0.1));
    // Los escalones de la cuesta no son muebles.
    expect(s.objects, hasLength(1));
    expect(s.lights.single.y, closeTo(4.5, 0.05));
    expect(s.lights.single.label, 'farola');
  });
}
