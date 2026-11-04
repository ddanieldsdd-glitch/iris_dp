import 'dart:math' as math;
import 'dart:ui';

import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/light_scene.dart';
import 'plan_segment.dart';

/// Formas del «Rectángulo» (CA.7, CA.8): una caja a medida, un poyete,
/// la barra de un bar o una estantería con botellas de cristal. Todas son
/// una caja para la luz; en el 3D y en Unreal se dibujan con su forma.
class PropBox {
  PropBox._();

  static const shapeKey = 'boxShape';
  static const bottlesKey = 'bottles';

  static const box = 'box';
  static const ledge = 'ledge';
  static const bar = 'bar';
  static const shelf = 'shelf';

  /// Nombre, forma, ancho, fondo, alto y si lleva botellas.
  static const presets = <(String, String, double, double, double, bool)>[
    ('Caja', box, 1, 1, 1, false),
    ('Poyete', ledge, 1, 1, 1, false),
    ('Barra de bar', bar, 3, 0.6, 1.1, false),
    ('Estantería con botellas', shelf, 2, 0.3, 2, true),
  ];

  /// Medidas máximas en el panel: un poyete o una barra pueden ser largos.
  static const double maxLengthM = 30;

  static bool isBox(PlanElement el) =>
      el.type == ElementType.prop && el.propType == PropType.rectangle;

  static String shapeOf(PlanElement el) => el.props[shapeKey] as String? ?? box;

  static bool hasBottles(PlanElement el) => el.props[bottlesKey] == true;

  // ── Barra curva (CA.8) ───────────────────────────────────────────────
  // Los extremos de la barra giran un cuarto de vuelta hacia atrás (el
  // lado contrario al que mira, donde está el camarero) y siguen rectos
  // hasta tocar la pared que haya detrás.

  static const curveKey = 'barCurve';
  static const curveRadiusKey = 'barCurveRadiusM';
  static const curveNone = 'none';
  static const curveLeft = 'left';
  static const curveRight = 'right';
  static const curveBoth = 'both';
  static const double defaultCurveRadiusM = 0.6;

  /// Hasta dónde se busca la pared detrás de la curva.
  static const double maxReachM = 6;

  static const curveOptions = <(String, String)>[
    ('Recta', curveNone),
    ('Izquierda', curveLeft),
    ('Derecha', curveRight),
    ('Las dos', curveBoth),
  ];

  static String curveOf(PlanElement el) => shapeOf(el) == bar
      ? el.props[curveKey] as String? ?? curveNone
      : curveNone;

  static bool curvesLeft(PlanElement el) =>
      curveOf(el) == curveLeft || curveOf(el) == curveBoth;

  static bool curvesRight(PlanElement el) =>
      curveOf(el) == curveRight || curveOf(el) == curveBoth;

  /// Radio de la curva por el eje de la barra, recortado para que quepa.
  static double curveRadiusM(PlanElement el) {
    final size = LightScene.furnitureSizeM(el);
    final r =
        (el.props[curveRadiusKey] as num?)?.toDouble() ?? defaultCurveRadiusM;
    final ends = curvesLeft(el) && curvesRight(el) ? 2 : 1;
    final room = (size.width - size.depth) / ends;
    return r.clamp(
      size.depth / 2 + 0.05,
      math.max(size.depth / 2 + 0.05, room),
    );
  }

  /// La barra curva: su eje en metros, en el marco de la pieza (x a lo
  /// ancho, y hacia atrás), y lo que mide cada vuelta hasta la pared.
  /// `null` si es recta.
  static BarCurve? curve(
    PlanElement el,
    Iterable<PlanElement> elements,
    double metersPerUnit,
  ) {
    if (curveOf(el) == curveNone) return null;
    final size = LightScene.furnitureSizeM(el);
    final r = curveRadiusM(el);
    final edge = size.width / 2 - size.depth / 2;
    final rad = el.rotation * math.pi / 180;
    final ux = Offset(math.cos(rad), math.sin(rad));
    final back = Offset(-math.sin(rad), math.cos(rad));
    double? reach(double sign) {
      final endLocal = Offset(sign * edge, r);
      final from =
          el.position + (ux * endLocal.dx + back * endLocal.dy) / metersPerUnit;
      return _wallBehind(from, back, elements, metersPerUnit);
    }

    final left = curvesLeft(el) ? reach(-1) ?? 0.0 : null;
    final right = curvesRight(el) ? reach(1) ?? 0.0 : null;
    // El eje: vuelta izquierda, tramo recto, vuelta derecha.
    final pts = <Offset>[];
    const steps = 8;
    if (left != null) {
      pts.add(Offset(-edge, r + left));
      for (var i = 0; i <= steps; i++) {
        final a = math.pi / 2 * (1 - i / steps);
        pts.add(Offset(-edge + r - r * math.sin(a), r - r * math.cos(a)));
      }
    } else {
      pts.add(Offset(-size.width / 2, 0));
    }
    if (right != null) {
      for (var i = 0; i <= steps; i++) {
        final a = math.pi / 2 * i / steps;
        pts.add(Offset(edge - r + r * math.sin(a), r - r * math.cos(a)));
      }
      pts.add(Offset(edge, r + right));
    } else {
      pts.add(Offset(size.width / 2, 0));
    }
    return BarCurve(
      radiusM: r,
      leftReachM: left,
      rightReachM: right,
      centerline: [
        for (var i = 0; i < pts.length; i++)
          if (i == 0 || (pts[i] - pts[i - 1]).distance > 1e-6) pts[i],
      ],
    );
  }

  /// Metros desde [from] hasta la cara de la pared más cercana en la
  /// dirección [dir]; `null` si no hay ninguna a [maxReachM].
  static double? _wallBehind(
    Offset from,
    Offset dir,
    Iterable<PlanElement> elements,
    double mpu,
  ) {
    double? best;
    for (final w in elements) {
      if (!PlanSegment.isSegment(w) ||
          PlanSegment.kind(w) != PlanSegment.kindWall) {
        continue;
      }
      final pieces = PlanSegment.curve(w) == 0 ? 1 : 24;
      var a = PlanSegment.pointAt(w, 0);
      for (var i = 1; i <= pieces; i++) {
        final b = PlanSegment.pointAt(w, i / pieces);
        final e = b - a;
        final den = dir.dx * e.dy - dir.dy * e.dx;
        if (den.abs() > 1e-9) {
          final q = a - from;
          final t = (q.dx * e.dy - q.dy * e.dx) / den;
          final s = (q.dx * dir.dy - q.dy * dir.dx) / den;
          if (t >= 0 && s >= 0 && s <= 1) {
            final m = t * mpu - PlanSegment.thicknessM(w) / 2;
            if (m <= maxReachM && (best == null || m < best)) best = m;
          }
        }
        a = b;
      }
    }
    return best == null ? null : math.max(0, best);
  }

  /// Pone la forma [shape] con sus medidas de partida y su nombre (si no
  /// tenía uno propio o era el de otra forma).
  static void apply(PlanElement el, String shape) {
    final p = presets.firstWhere((p) => p.$2 == shape);
    final names = {for (final q in presets) q.$1};
    el.props
      ..[shapeKey] = shape
      ..[LightScene.widthKey] = p.$3
      ..[LightScene.depthKey] = p.$4
      ..[LightScene.heightKey] = p.$5
      ..[bottlesKey] = p.$6;
    final own = el.customName;
    if (own == null || names.contains(own)) {
      el.customName = shape == box ? null : p.$1;
    }
  }
}

/// El eje de una barra curva (ver [PropBox.curve]).
class BarCurve {
  const BarCurve({
    required this.radiusM,
    required this.centerline,
    this.leftReachM,
    this.rightReachM,
  });

  final double radiusM;

  /// Metros, en el marco de la pieza: x a lo ancho, y hacia atrás.
  final List<Offset> centerline;

  /// Tramo recto de cada vuelta hasta la pared (`null` = sin vuelta).
  final double? leftReachM;
  final double? rightReachM;

  /// El contorno de la barra con fondo [depthM] alrededor del eje.
  List<Offset> outline(double depthM) {
    final h = depthM / 2;
    final n = centerline.length;
    Offset normal(int i) {
      final a = centerline[math.max(0, i - 1)];
      final b = centerline[math.min(n - 1, i + 1)];
      final d = b - a;
      final len = d.distance;
      return len == 0 ? Offset.zero : Offset(d.dy, -d.dx) / len;
    }

    return [
      for (var i = 0; i < n; i++) centerline[i] + normal(i) * h,
      for (var i = n - 1; i >= 0; i--) centerline[i] - normal(i) * h,
    ];
  }
}
