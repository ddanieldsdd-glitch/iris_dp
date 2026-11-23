import 'dart:math' as math;
import 'dart:ui';

import '../camera_plan_element_model.dart';
import '../light_overrides.dart';
import '../rig/plan_rig.dart';
import 'arch_material.dart';

/// Forma de una escalera (AM.6).
enum StairShape {
  straight('Recta'),
  l('En L'),
  u('En U'),
  spiral('De caracol'),
  ramp('Rampa');

  const StairShape(this.label);
  final String label;

  static StairShape byName(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => straight);
}

/// Un peldaño (o la rampa entera, o la meseta): su huella en metros del
/// elemento, sin girar; lo alto de cada esquina y de dónde arranca.
class StairStep {
  final List<Offset> poly;
  final List<double> tops;
  final double bottom;

  const StairStep(this.poly, this.tops, this.bottom);

  double get top => tops.reduce(math.max);
}

/// Escaleras y rampas del motor arquitectónico (AM.6), como en Revit o
/// ArchiCAD: una pieza con medidas que se dibuja del arranque a la llegada
/// y saca sus peldaños de la altura que salva.
///
/// El elemento guarda el arranque en `position` y hacia dónde sube en
/// `rotation` (grados del lienzo: 0 = hacia la derecha). En sus metros, x
/// va hacia donde sube e y hacia su derecha. De caracol, `position` es el
/// centro y el tramo dibujado, el radio.
abstract final class ArchStair {
  static const shapeKey = 'stairShape';

  /// Ancho de paso, en metros.
  static const widthKey = 'widthM';

  /// Largo del tramo dibujado (el primero, en L y en U; el radio, de
  /// caracol), en metros.
  static const runKey = 'runM';

  /// Altura que salva, en metros.
  static const riseKey = 'riseM';

  /// Hacia dónde gira (en L, en U y de caracol): `left` o `right`.
  static const turnKey = 'turn';

  /// Lo que gira una de caracol, en grados.
  static const sweepKey = 'sweepDeg';

  static const double defaultWidthM = 1.0;
  static const double defaultRiseM = 2.8;
  static const double defaultRampRiseM = 0.3;
  static const double defaultSweepDeg = 360;

  /// Contrahuella de partida: 17,5 cm, la cómoda (CTE: de 13 a 18,5).
  static const double idealRiserM = 0.175;

  /// Lo que hay entre los dos tramos de una en U, en metros.
  static const double wellM = 0.1;

  /// El núcleo de una de caracol, de radio, en metros.
  static const double coreM = 0.08;

  static const defaultMat = 'wood-floor-oak';
  static const defaultRampMat = 'concrete-smooth';

  static bool isStair(PlanElement el) => RigTypeCodec.of(el) == RigType.stair;

  /// Una escalera de [from] (abajo) a [to] (hacia donde sube), en el
  /// lienzo. De caracol, de su centro a su borde.
  static PlanElement create(
    Offset from,
    Offset to,
    double metersPerUnit, {
    StairShape shape = StairShape.straight,
  }) {
    final d = to - from;
    final el = RigTypeCodec.create(
      RigType.stair,
      from,
      props: {
        shapeKey: shape.name,
        widthKey: defaultWidthM,
        runKey: _r(math.max(0.3, d.distance * metersPerUnit)),
        riseKey: shape == StairShape.ramp ? defaultRampRiseM : defaultRiseM,
        ArchMaterials.key: shape == StairShape.ramp
            ? defaultRampMat
            : defaultMat,
      },
    );
    el.rotation = d.distance == 0
        ? 0
        : _r(math.atan2(d.dy, d.dx) * 180 / math.pi);
    LightOverrides.ensureUids([el]);
    return el;
  }

  static StairShape shape(PlanElement el) =>
      StairShape.byName(el.props[shapeKey] as String?);

  static double widthM(PlanElement el) =>
      (el.props[widthKey] as num?)?.toDouble() ?? defaultWidthM;

  static double runM(PlanElement el) =>
      (el.props[runKey] as num?)?.toDouble() ?? 3;

  static double riseM(PlanElement el) =>
      (el.props[riseKey] as num?)?.toDouble() ??
      (shape(el) == StairShape.ramp ? defaultRampRiseM : defaultRiseM);

  static bool turnsLeft(PlanElement el) => el.props[turnKey] == 'left';

  static double sweepDeg(PlanElement el) =>
      (el.props[sweepKey] as num?)?.toDouble() ?? defaultSweepDeg;

  static ArchMaterial material(PlanElement el) =>
      ArchMaterials.byId(el.props[ArchMaterials.key] as String?) ??
      ArchMaterials.byId(
        shape(el) == StairShape.ramp ? defaultRampMat : defaultMat,
      )!;

  /// Cuántas contrahuellas: las que dejan cada una cerca de 17,5 cm.
  static int risers(PlanElement el) {
    if (shape(el) == StairShape.ramp) return 1;
    return math.max(1, (riseM(el) / idealRiserM).round());
  }

  /// Lo que mide cada contrahuella, en metros.
  static double riserM(PlanElement el) => riseM(el) / risers(el);

  /// Lo que mide cada huella, en metros (en una de caracol, a la mitad
  /// del ancho, por donde se pisa).
  static double treadM(PlanElement el) {
    final n = risers(el);
    switch (shape(el)) {
      case StairShape.ramp:
        return runM(el);
      case StairShape.straight:
        return runM(el) / n;
      case StairShape.l || StairShape.u:
        return runM(el) / math.max(1, _firstFlight(n));
      case StairShape.spiral:
        final walk = math.max(coreM, runM(el) - widthM(el) / 2);
        return walk * sweepDeg(el) * math.pi / 180 / n;
    }
  }

  /// Pendiente de una rampa, en tanto por ciento.
  static double slopePct(PlanElement el) => riseM(el) / runM(el) * 100;

  /// Escalones del primer tramo de una en L o en U (lo demás, la meseta y
  /// el segundo tramo).
  static int _firstFlight(int n) => math.max(1, (n - 1) ~/ 2);

  /// Si la escalera es cómoda: la regla de Blondel (2 contrahuellas + 1
  /// huella entre 60 y 66 cm) y la contrahuella del CTE; en una rampa, la
  /// pendiente. `null` si está bien; si no, qué le pasa.
  static String? warning(PlanElement el) {
    if (shape(el) == StairShape.ramp) {
      final p = slopePct(el);
      if (p > 12) return 'Pendiente del ${p.round()} %: más de lo que se sube a pie con un carro (12 %).';
      return null;
    }
    final r = riserM(el), t = treadM(el);
    final step = 2 * r + t;
    if (t < 0.22) return 'Huella de ${(t * 100).round()} cm: muy empinada. Alarga el tramo.';
    if (step > 0.70) return 'Paso de ${(step * 100).round()} cm (2C + H): muy largo. Acorta el tramo.';
    if (r > 0.185) return 'Contrahuella de ${(r * 100).toStringAsFixed(1)} cm: más de 18,5 cm.';
    return null;
  }

  /// Los peldaños (y mesetas) en metros del elemento, de abajo arriba.
  static List<StairStep> steps(PlanElement el) {
    final n = risers(el);
    final r = riserM(el);
    final w = widthM(el);
    final run = runM(el);
    final side = turnsLeft(el) ? -1.0 : 1.0;
    List<Offset> rect(double x0, double x1, double y0, double y1) => [
      Offset(x0, y0),
      Offset(x1, y0),
      Offset(x1, y1),
      Offset(x0, y1),
    ];
    StairStep block(List<Offset> poly, double top) =>
        StairStep(poly, List.filled(poly.length, top), 0);
    switch (shape(el)) {
      case StairShape.ramp:
        final rise = riseM(el);
        return [
          StairStep(rect(0, run, -w / 2, w / 2), [0, rise, rise, 0], 0),
        ];
      case StairShape.straight:
        final t = run / n;
        return [
          for (var i = 0; i < n; i++)
            block(rect(i * t, (i + 1) * t, -w / 2, w / 2), (i + 1) * r),
        ];
      case StairShape.l:
        final n1 = _firstFlight(n), n2 = n - n1 - 1;
        final t = run / n1;
        double y(double v) => v * side;
        return [
          for (var i = 0; i < n1; i++)
            block(rect(i * t, (i + 1) * t, -w / 2, w / 2), (i + 1) * r),
          // La meseta, en la esquina.
          block(rect(run, run + w, y(-w / 2), y(w / 2)), (n1 + 1) * r),
          for (var j = 0; j < n2; j++)
            block(
              rect(run, run + w, y(w / 2 + j * t), y(w / 2 + (j + 1) * t)),
              (n1 + 2 + j) * r,
            ),
        ];
      case StairShape.u:
        final n1 = _firstFlight(n), n2 = n - n1 - 1;
        final t = run / n1;
        double y(double v) => v * side;
        final y2 = w / 2 + wellM;
        return [
          for (var i = 0; i < n1; i++)
            block(rect(i * t, (i + 1) * t, -w / 2, w / 2), (i + 1) * r),
          // La meseta, de lado a lado de los dos tramos.
          block(rect(run, run + w, y(-w / 2), y(y2 + w)), (n1 + 1) * r),
          // El segundo tramo vuelve al lado del primero.
          for (var j = 0; j < n2; j++)
            block(
              rect(run - (j + 1) * t, run - j * t, y(y2), y(y2 + w)),
              (n1 + 2 + j) * r,
            ),
        ];
      case StairShape.spiral:
        final outer = math.max(coreM + 0.2, run);
        final inner = math.max(coreM, outer - w);
        final a = sweepDeg(el) * math.pi / 180 / n;
        Offset at(double radius, double angle) =>
            Offset(math.cos(angle), math.sin(angle) * side) * radius;
        return [
          for (var i = 0; i < n; i++)
            () {
              final a0 = i * a, a1 = (i + 1) * a;
              final poly = [
                at(inner, a0),
                at(outer, a0),
                at(outer, (a0 + a1) / 2),
                at(outer, a1),
                at(inner, a1),
              ];
              final top = (i + 1) * r;
              // Peldaños volados: una losa de 5 cm.
              return StairStep(
                poly,
                List.filled(poly.length, top),
                math.max(0.0, top - 0.05),
              );
            }(),
        ];
    }
  }

  /// El núcleo de una de caracol: su contorno y su alto (una barandilla
  /// encima), o `null`.
  static (List<Offset>, double)? post(PlanElement el) {
    if (shape(el) != StairShape.spiral) return null;
    return (
      [
        for (var k = 0; k < 12; k++)
          Offset(math.cos(k * math.pi / 6), math.sin(k * math.pi / 6)) *
              coreM,
      ],
      riseM(el) + 0.9,
    );
  }

  /// Un punto de los metros del elemento en el lienzo.
  static Offset toCanvas(PlanElement el, Offset m, double metersPerUnit) {
    final rad = el.rotation * math.pi / 180;
    final c = math.cos(rad), s = math.sin(rad);
    return el.position +
        Offset(m.dx * c - m.dy * s, m.dx * s + m.dy * c) / metersPerUnit;
  }

  /// El recorrido por el que se sube, en metros del elemento: por el
  /// centro de cada peldaño, del primero al último.
  static List<Offset> walkLine(PlanElement el) {
    if (shape(el) == StairShape.ramp) {
      return [Offset.zero, Offset(runM(el), 0)];
    }
    if (shape(el) == StairShape.spiral) {
      final outer = math.max(coreM + 0.2, runM(el));
      final mid = math.max(coreM, outer - widthM(el)) / 2 + outer / 2;
      final side = turnsLeft(el) ? -1.0 : 1.0;
      final total = sweepDeg(el) * math.pi / 180;
      return [
        for (var k = 0; k <= 24; k++)
          Offset(
                math.cos(total * k / 24),
                math.sin(total * k / 24) * side,
              ) *
              mid,
      ];
    }
    return [
      for (final s in steps(el))
        s.poly.reduce((a, b) => a + b) / s.poly.length.toDouble(),
    ];
  }

  /// El peldaño en el que cae un punto del lienzo, o `null`.
  static bool contains(PlanElement el, Offset p, double metersPerUnit) {
    final rad = -el.rotation * math.pi / 180;
    final c = math.cos(rad), s = math.sin(rad);
    final v = (p - el.position) * metersPerUnit;
    final m = Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
    for (final step in steps(el)) {
      if (_inside(step.poly, m)) return true;
    }
    return false;
  }

  /// La malla en metros del elemento (x, y como sus metros; z hacia
  /// arriba), en triángulos: cada peldaño como un prisma.
  static List<double> mesh(PlanElement el) {
    final out = <double>[];
    void tri(Offset a, double za, Offset b, double zb, Offset c, double zc) {
      out.addAll([a.dx, a.dy, za, b.dx, b.dy, zb, c.dx, c.dy, zc]);
    }

    void prism(List<Offset> p, List<double> tops, double bottom) {
      // El orden de las esquinas: que la cara de arriba mire arriba.
      var area = 0.0;
      for (var i = 0; i < p.length; i++) {
        final a = p[i], b = p[(i + 1) % p.length];
        area += a.dx * b.dy - b.dx * a.dy;
      }
      final idx = [for (var i = 0; i < p.length; i++) i];
      if (area > 0) {
        idx.setAll(0, idx.reversed.toList());
      }
      for (var k = 1; k + 1 < idx.length; k++) {
        final i0 = idx[0], i1 = idx[k], i2 = idx[k + 1];
        tri(p[i0], tops[i0], p[i1], tops[i1], p[i2], tops[i2]);
        tri(p[i0], bottom, p[i2], bottom, p[i1], bottom);
      }
      for (var k = 0; k < idx.length; k++) {
        final i = idx[k], j = idx[(k + 1) % idx.length];
        tri(p[i], bottom, p[j], bottom, p[j], tops[j]);
        tri(p[i], bottom, p[j], tops[j], p[i], tops[i]);
      }
    }

    for (final s in steps(el)) {
      prism(s.poly, s.tops, s.bottom);
    }
    if (post(el) case (final poly, final h)) {
      prism(poly, List.filled(poly.length, h), 0);
    }
    return out;
  }

  static bool _inside(List<Offset> poly, Offset p) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  static double _r(double v) => (v * 1000).round() / 1000;
}
