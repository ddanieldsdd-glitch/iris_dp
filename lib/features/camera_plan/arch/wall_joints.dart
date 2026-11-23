import 'dart:math' as math;
import 'dart:ui';

import '../camera_plan_element_model.dart';
import '../plan_segment.dart';

/// El contorno de una pared con su grosor (AM.4): sus dos caras, en el
/// lienzo, a lo largo del tramo. `left` es la cara de la normal
/// `(−dy, dx)` del sentido en que se dibujó.
class WallOutline {
  final List<Offset> left;
  final List<Offset> right;

  /// Lo que se alarga (o se acorta) cada cara en cada extremo para unirse
  /// a la pared vecina, en metros: `[inicio izquierda, inicio derecha,
  /// final izquierda, final derecha]`. Lo usa el 3D.
  final List<double> extendM;

  const WallOutline(this.left, this.right, this.extendM);

  List<Offset> get polygon => [...left, ...right.reversed];

  Path get path => Path()..addPolygon(polygon, true);
}

/// Las paredes de una planta con sus esquinas unidas, como en Revit o
/// ArchiCAD: dos paredes que se tocan por un extremo se cortan a inglete;
/// tres o más que se juntan en un punto se alargan hasta taparse.
abstract final class WallJoints {
  /// A cuánto (en el lienzo) dos extremos se dan por unidos.
  static const double tolerance = 6;

  static bool isWall(PlanElement el) =>
      PlanSegment.isSegment(el) &&
      PlanSegment.kind(el) == PlanSegment.kindWall;

  static Map<PlanElement, WallOutline> of(
    Iterable<PlanElement> elements,
    double metersPerUnit,
  ) {
    final walls = elements.where(isWall).toList();
    final data = <_Wall>[
      for (final w in walls) _Wall.of(w, metersPerUnit),
    ];
    // Extremos de todas las paredes; se agrupan los que coinciden.
    final ends = <_End>[
      for (final w in data)
        if (w.centre.length >= 2) ...[_End(w, true), _End(w, false)],
    ];
    final used = <_End>{};
    for (final e in ends) {
      if (used.contains(e)) continue;
      final group = [
        for (final o in ends)
          if (!used.contains(o) &&
              (o.point - e.point).distance <= tolerance &&
              (o == e || o.wall != e.wall))
            o,
      ];
      used.addAll(group);
      if (group.length == 2) {
        _miter(group[0], group[1]);
      } else if (group.length > 2) {
        for (final g in group) {
          final others = group.where((o) => o != g).map((o) => o.wall.half);
          g.extendBoth(others.reduce(math.max));
        }
      }
    }
    return {
      for (final w in data)
        w.element: WallOutline(w.left, w.right, [
          for (final v in w.ext) v * metersPerUnit,
        ]),
    };
  }

  /// Dos paredes que se tocan: cada cara hasta donde corta la cara de la
  /// otra. Si son casi paralelas o el inglete se va muy lejos, se dejan
  /// a escuadra.
  static void _miter(_End e1, _End e2) {
    final p = (e1.point + e2.point) / 2;
    final d1 = e1.away, d2 = e2.away;
    final m1 = Offset(-d1.dy, d1.dx), m2 = Offset(-d2.dy, d2.dx);
    final h1 = e1.wall.half, h2 = e2.wall.half;
    // La cara + de una se une con la − de la otra (vistas desde el
    // punto común hacia fuera).
    final x = _cross(p + m1 * h1, d1, p - m2 * h2, d2);
    final y = _cross(p - m1 * h1, d1, p + m2 * h2, d2);
    if (x == null || y == null) return;
    final limit = 4 * math.max(h1, h2);
    if ((x - p).distance > limit || (y - p).distance > limit) return;
    e1.setCorners(plus: x, minus: y);
    e2.setCorners(plus: y, minus: x);
  }

  /// Corte de dos rectas `a + s·da` y `b + t·db`.
  static Offset? _cross(Offset a, Offset da, Offset b, Offset db) {
    final den = da.dx * db.dy - da.dy * db.dx;
    if (den.abs() < 0.05) return null;
    final v = b - a;
    final s = (v.dx * db.dy - v.dy * db.dx) / den;
    return a + da * s;
  }
}

class _Wall {
  final PlanElement element;
  final List<Offset> centre;
  final List<Offset> left;
  final List<Offset> right;
  final double half;

  /// Alargue de cada cara en el lienzo: inicio izq./der., final izq./der.
  final List<double> ext = [0, 0, 0, 0];

  _Wall(this.element, this.centre, this.left, this.right, this.half);

  factory _Wall.of(PlanElement el, double mpu) {
    final steps = PlanSegment.curve(el) == 0 ? 1 : 16;
    final pts = [
      for (var k = 0; k <= steps; k++) PlanSegment.pointAt(el, k / steps),
    ];
    final half = PlanSegment.thicknessM(el) / 2 / mpu;
    final left = <Offset>[], right = <Offset>[];
    for (var k = 0; k < pts.length; k++) {
      final a = pts[math.max(0, k - 1)], b = pts[math.min(pts.length - 1, k + 1)];
      final d = b - a;
      final len = d.distance;
      final n = len == 0 ? Offset.zero : Offset(-d.dy / len, d.dx / len);
      left.add(pts[k] + n * half);
      right.add(pts[k] - n * half);
    }
    return _Wall(el, pts, left, right, half);
  }
}

class _End {
  final _Wall wall;
  final bool start;

  _End(this.wall, this.start);

  Offset get point => start ? wall.centre.first : wall.centre.last;

  /// Dirección desde el extremo hacia dentro de la pared.
  Offset get away {
    final c = wall.centre;
    final d = start ? c[1] - c[0] : c[c.length - 2] - c.last;
    final len = d.distance;
    return len == 0 ? Offset.zero : d / len;
  }

  int get _i => start ? 0 : wall.centre.length - 1;

  /// Pone las esquinas de este extremo. `plus` es la de la normal de
  /// [away]: al inicio, la cara izquierda; al final, la derecha.
  void setCorners({required Offset plus, required Offset minus}) {
    final l = start ? plus : minus, r = start ? minus : plus;
    final out = away * -1;
    double along(Offset from, Offset to) =>
        (to - from).dx * out.dx + (to - from).dy * out.dy;
    final k = start ? 0 : 2;
    wall.ext[k] = along(wall.left[_i], l);
    wall.ext[k + 1] = along(wall.right[_i], r);
    wall.left[_i] = l;
    wall.right[_i] = r;
  }

  /// Alarga las dos caras [by] hacia fuera.
  void extendBoth(double by) {
    final out = away * -1;
    final k = start ? 0 : 2;
    wall.left[_i] += out * by;
    wall.right[_i] += out * by;
    wall.ext[k] += by;
    wall.ext[k + 1] += by;
  }
}
