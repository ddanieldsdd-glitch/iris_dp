import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/plan_light.dart';
import 'light/street_lamp.dart';
import 'light/wall_mount.dart';
import 'light_beam.dart';
import 'plan_segment.dart';

/// Perfil de una calle (CA.6): calzada, aceras, bordillo, fachadas y
/// farolas, en metros. Se guarda en las `props` del tramo «Calle», que es
/// su eje.
///
/// La izquierda es la de quien recorre el eje desde su inicio.
class StreetProfile {
  final double roadM;
  final double walkLeftM;
  final double walkRightM;

  /// Altura del bordillo. 0 = plataforma única (todo a un nivel).
  final double kerbM;

  /// Altura de las fachadas. 0 = sin fachada por ese lado.
  final double facadeLeftM;
  final double facadeRightM;

  final double lampEveryM;
  final double lampHeightM;
  final double lampKelvin;

  /// `both`, `left`, `right` o `none`.
  final String lampSide;

  /// `arm` (en la fachada) o `pole` (báculo en la acera).
  final String lampStyle;

  const StreetProfile({
    this.roadM = 6,
    this.walkLeftM = 2,
    this.walkRightM = 2,
    this.kerbM = 0.15,
    this.facadeLeftM = 0,
    this.facadeRightM = 0,
    this.lampEveryM = 18,
    this.lampHeightM = StreetLamp.defaultHeightM,
    this.lampKelvin = StreetLamp.defaultKelvin,
    this.lampSide = 'both',
    this.lampStyle = StreetLamp.styleArm,
  });

  static const roadKey = 'roadM';
  static const walkLeftKey = 'walkLeftM';
  static const walkRightKey = 'walkRightM';
  static const kerbKey = 'kerbM';
  static const facadeLeftKey = 'facadeLeftM';
  static const facadeRightKey = 'facadeRightM';
  static const lampEveryKey = 'lampEveryM';
  static const lampHeightKey = 'lampHeightM';
  static const lampKelvinKey = 'lampKelvin';
  static const lampSideKey = 'lampSide';
  static const lampStyleKey = 'lampStyle';

  /// Grosor con que se levantan las fachadas.
  static const double facadeThicknessM = 0.3;

  double get widthM => roadM + walkLeftM + walkRightM;
  bool get singleLevel => kerbM <= 0.005;

  static bool isStreet(PlanElement el) =>
      PlanSegment.isSegment(el) &&
      PlanSegment.kind(el) == PlanSegment.kindStreet;

  static StreetProfile of(PlanElement el) {
    double num0(String k, double d) => (el.props[k] as num?)?.toDouble() ?? d;
    const d = StreetProfile();
    return StreetProfile(
      roadM: num0(roadKey, d.roadM),
      walkLeftM: num0(walkLeftKey, d.walkLeftM),
      walkRightM: num0(walkRightKey, d.walkRightM),
      kerbM: num0(kerbKey, d.kerbM),
      facadeLeftM: num0(facadeLeftKey, d.facadeLeftM),
      facadeRightM: num0(facadeRightKey, d.facadeRightM),
      lampEveryM: num0(lampEveryKey, d.lampEveryM),
      lampHeightM: num0(lampHeightKey, d.lampHeightM),
      lampKelvin: num0(lampKelvinKey, d.lampKelvin),
      lampSide: el.props[lampSideKey] as String? ?? d.lampSide,
      lampStyle: el.props[lampStyleKey] as String? ?? d.lampStyle,
    );
  }

  void writeTo(PlanElement el) => el.props.addAll({
    roadKey: roadM,
    walkLeftKey: walkLeftM,
    walkRightKey: walkRightM,
    kerbKey: kerbM,
    facadeLeftKey: facadeLeftM,
    facadeRightKey: facadeRightM,
    lampEveryKey: lampEveryM,
    lampHeightKey: lampHeightM,
    lampKelvinKey: lampKelvin,
    lampSideKey: lampSide,
    lampStyleKey: lampStyle,
  });

  // ── Geometría, en unidades de la planta ──────────────────────────────────

  /// El eje muestreado: un tramo recto son dos puntos.
  static List<Offset> axis(PlanElement el) {
    final steps = PlanSegment.curve(el) == 0 ? 1 : 16;
    return [
      for (var k = 0; k <= steps; k++) PlanSegment.pointAt(el, k / steps),
    ];
  }

  /// La izquierda en cada punto del eje (y abajo en la planta).
  static List<Offset> _lefts(List<Offset> pts) => [
    for (var k = 0; k < pts.length; k++)
      () {
        final a = pts[math.max(0, k - 1)];
        final b = pts[math.min(pts.length - 1, k + 1)];
        final d = b - a;
        final len = d.distance;
        return len == 0 ? Offset.zero : Offset(d.dy / len, -d.dx / len);
      }(),
  ];

  /// El eje desplazado [offsetM] metros a la izquierda (negativo: a la
  /// derecha).
  static List<Offset> offsetLine(PlanElement el, double offsetM, double mpu) {
    final pts = axis(el);
    final lefts = _lefts(pts);
    final d = offsetM / mpu;
    return [for (var k = 0; k < pts.length; k++) pts[k] + lefts[k] * d];
  }

  static List<Offset> _band(
    PlanElement el,
    double fromM,
    double toM,
    double mpu,
  ) => [...offsetLine(el, fromM, mpu), ...offsetLine(el, toM, mpu).reversed];

  /// Calzada y aceras: contorno y cota de arriba.
  List<StreetBand> bands(PlanElement el, double mpu) {
    final half = roadM / 2;
    final walkTop = singleLevel ? 0.0 : kerbM;
    return [
      StreetBand('road', _band(el, -half, half, mpu), 0),
      if (walkLeftM > 0)
        StreetBand('walk', _band(el, half, half + walkLeftM, mpu), walkTop),
      if (walkRightM > 0)
        StreetBand('walk', _band(el, -half - walkRightM, -half, mpu), walkTop),
    ];
  }

  /// Las fachadas, por la línea exterior de cada acera (su cara hacia la
  /// calle), con su altura.
  List<StreetFacade> facades(PlanElement el, double mpu) {
    final half = roadM / 2;
    const t = facadeThicknessM / 2;
    return [
      if (facadeLeftM > 0)
        StreetFacade(
          'left',
          offsetLine(el, half + walkLeftM + t, mpu),
          facadeLeftM,
        ),
      if (facadeRightM > 0)
        StreetFacade(
          'right',
          offsetLine(el, -half - walkRightM - t, mpu).reversed.toList(),
          facadeRightM,
        ),
    ];
  }

  /// Las farolas que pone «Poner farolas»: de brazo en la fachada o, sin
  /// fachada (o de báculo), en el borde de la acera. La de la derecha va
  /// al tresbolillo.
  List<PlanElement> lamps(PlanElement el, double mpu) {
    if (lampSide == 'none' || lampEveryM <= 0) return const [];
    final pts = axis(el);
    final lefts = _lefts(pts);
    final cum = <double>[0];
    for (var k = 1; k < pts.length; k++) {
      cum.add(cum.last + (pts[k] - pts[k - 1]).distance);
    }
    final total = cum.last * mpu;
    (Offset, Offset) at(double sM) {
      final s = sM / mpu;
      var k = 1;
      while (k < pts.length - 1 && cum[k] < s) {
        k++;
      }
      final span = cum[k] - cum[k - 1];
      final t = span == 0 ? 0.0 : ((s - cum[k - 1]) / span).clamp(0.0, 1.0);
      return (
        Offset.lerp(pts[k - 1], pts[k], t)!,
        Offset.lerp(lefts[k - 1], lefts[k], t)!,
      );
    }

    final out = <PlanElement>[];
    for (final side in const [1, -1]) {
      if (lampSide == 'left' && side < 0) continue;
      if (lampSide == 'right' && side > 0) continue;
      final walk = side > 0 ? walkLeftM : walkRightM;
      final facade = side > 0 ? facadeLeftM : facadeRightM;
      final onFacade = lampStyle == StreetLamp.styleArm && facade > 0;
      final style = onFacade ? StreetLamp.styleArm : StreetLamp.stylePole;
      // Distancia al eje: pegada a la fachada o a medio metro del bordillo.
      final dM = onFacade
          ? roadM / 2 + walk - LightWallMount.gapM
          : roadM / 2 + math.min(0.5, walk / 2);
      final start = side > 0 ? lampEveryM / 2 : lampEveryM;
      for (var s = start; s <= total - 0.5; s += lampEveryM) {
        final (p, left) = at(s);
        final out0 = left * side.toDouble();
        final lamp = PlanElement(
          id: 0,
          type: ElementType.light,
          position: p + out0 * (dM / mpu),
        );
        StreetLamp.apply(lamp, style: style);
        // Mira hacia la calle (0° = arriba en la planta).
        final n = -out0;
        lamp.rotation = (math.atan2(n.dx, -n.dy) * 180 / math.pi + 360) % 360;
        lamp.props[PlanLight.heightKey] = lampHeightM;
        lamp.props[LightBeam.cctKey] = lampKelvin;
        out.add(lamp);
      }
    }
    return out;
  }
}

class StreetBand {
  /// `road` o `walk`.
  final String kind;
  final List<Offset> outline;
  final double topM;
  const StreetBand(this.kind, this.outline, this.topM);
}

class StreetFacade {
  final String side;

  /// Línea media de la fachada, en unidades de la planta.
  final List<Offset> line;
  final double heightM;
  const StreetFacade(this.side, this.line, this.heightM);
}

/// Plantillas de calle.
const kStreetPresets = <(String, StreetProfile)>[
  (
    'Calle del Raval',
    StreetProfile(
      roadM: 3,
      walkLeftM: 2,
      walkRightM: 2,
      kerbM: 0,
      facadeLeftM: 16,
      facadeRightM: 16,
      lampEveryM: 15,
    ),
  ),
  ('Calle con aceras', StreetProfile(facadeLeftM: 16, facadeRightM: 16)),
  (
    'Avenida',
    StreetProfile(
      roadM: 12,
      walkLeftM: 4,
      walkRightM: 4,
      facadeLeftM: 22,
      facadeRightM: 22,
      lampEveryM: 25,
      lampHeightM: 8,
      lampKelvin: 4000,
      lampStyle: StreetLamp.stylePole,
    ),
  ),
  (
    'Solo calzada',
    StreetProfile(walkLeftM: 0, walkRightM: 0, lampSide: 'none'),
  ),
];
