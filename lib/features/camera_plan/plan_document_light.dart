import 'dart:math' as math;
import 'dart:ui';

import 'light/light_scene.dart';
import 'light_beam.dart';

/// Cómo se dibuja un foco en la planta de luz de un documento (P.4).
enum DocumentLightKind {
  /// Un cono desde el aparato, con su apertura y su dirección.
  cone,

  /// Alumbra a todos lados: un anillo alrededor.
  ring,

  /// Cuelga del techo: la huella que deja en el suelo.
  footprint,
}

/// El haz de un foco en papel: un contorno en su color, no la mancha de
/// luz de la pantalla, para que se lea hacia dónde apunta y qué abarca.
///
/// Todo va en unidades de la planta.
class DocumentLightShape {
  final DocumentLightKind kind;

  /// Vértice del cono, centro del anillo o centro de la huella.
  final Offset center;

  /// Eje del haz (unitario). Solo cuenta en el cono.
  final Offset aim;

  /// Media apertura, en radianes. Solo cuenta en el cono.
  final double halfAngle;

  /// Largo del cono o radio del anillo y la huella.
  final double length;

  const DocumentLightShape({
    required this.kind,
    required this.center,
    required this.length,
    this.aim = const Offset(0, -1),
    this.halfAngle = 0,
  });

  /// Desde esta apertura un foco alumbra a todos lados: anillo y sin
  /// flecha (lo mismo que decide la flecha de la planta).
  static const omniDeg = 300.0;

  /// Tope del cono: más allá no se dibuja aunque llegue la luz.
  static const maxLengthM = 4.5;
  static const minLengthM = 1.0;

  /// Lo que pasa de lo iluminado: el cono no se corta en la cara del actor.
  static const pastTargetM = 0.6;

  /// Hasta dónde se busca a quién alumbra: un foco lejos del actor sigue
  /// llegando a él aunque pase del tope.
  static const maxTargetM = 15.0;

  /// Radio del anillo de un foco que alumbra a todos lados.
  static const maxRingM = 1.8;
  static const minRingM = 0.5;

  /// Lux con los que se mide el largo cuando no ilumina a nadie.
  static const reachLux = 60.0;

  /// La forma del haz de [light] en una planta de [metersPerUnit]. El cono
  /// llega hasta lo más lejano de [targets] (actores, sus posiciones) que
  /// caiga dentro de él, algo más allá; si no ilumina a nadie, hasta donde
  /// su luz aún cuenta, con tope ([maxLengthM]). `null` si no emite.
  static DocumentLightShape? of(
    SceneLight light, {
    required double metersPerUnit,
    Iterable<Offset> targets = const [],
  }) {
    final source = light.source;
    if (source.candela <= 0 || metersPerUnit <= 0) return null;
    final mpu = metersPerUnit;
    final drop = light.overheadM;
    final beamDeg = light.frontOnly
        ? math.min(source.beamDeg, 180.0)
        : source.beamDeg;
    final aim = _unit(light.aim);
    if (drop != null) {
      // Del techo: el charco bajo el aparato, corrido hacia donde se
      // inclina.
      final tilt = light.tiltDeg.clamp(0.0, 75.0) * math.pi / 180;
      final half = math.min(beamDeg / 2, 60.0) * math.pi / 180;
      final radiusM = (drop * math.tan(half)).clamp(minRingM, maxLengthM);
      return DocumentLightShape(
        kind: DocumentLightKind.footprint,
        center: light.position + aim * (drop * math.tan(tilt) / mpu),
        length: radiusM / mpu,
        aim: aim,
      );
    }
    final reachM = source.distanceFor(reachLux);
    if (source.beamDeg >= omniDeg && !light.frontOnly) {
      return DocumentLightShape(
        kind: DocumentLightKind.ring,
        center: light.position,
        length: reachM.clamp(minRingM, maxRingM) / mpu,
      );
    }
    final halfAngle = beamDeg / 2 * math.pi / 180;
    final far = maxTargetM / mpu;
    double? lit;
    for (final t in targets) {
      final to = t - light.position;
      final along = to.dx * aim.dx + to.dy * aim.dy;
      if (along <= 0 || along > far) continue;
      final cos = along / math.max(to.distance, 1e-6);
      if (cos < math.cos(halfAngle)) continue;
      lit = math.max(lit ?? 0, along);
    }
    final length = lit != null
        ? lit + pastTargetM / mpu
        : reachM.clamp(minLengthM, maxLengthM) / mpu;
    return DocumentLightShape(
      kind: DocumentLightKind.cone,
      center: light.position,
      length: length,
      aim: aim,
      halfAngle: halfAngle,
    );
  }

  static Offset _unit(Offset v) {
    final d = v.distance;
    return d < 1e-9 ? const Offset(0, -1) : v / d;
  }

  /// El contorno de la forma.
  Path get path {
    switch (kind) {
      case DocumentLightKind.ring:
      case DocumentLightKind.footprint:
        return Path()..addOval(Rect.fromCircle(center: center, radius: length));
      case DocumentLightKind.cone:
        final axis = math.atan2(aim.dy, aim.dx);
        final arc = Rect.fromCircle(center: center, radius: length);
        if (halfAngle >= math.pi * 0.99) return Path()..addOval(arc);
        return Path()
          ..moveTo(center.dx, center.dy)
          ..arcTo(arc, axis - halfAngle, halfAngle * 2, false)
          ..close();
    }
  }
}

/// La tinta de un foco en la planta (que va sobre negro): su color de
/// verdad, el de su temperatura o el RGB que lleva, aclarado lo justo para
/// que un azul o un rojo saturados se vean sobre el fondo oscuro.
Color documentLightInk(LightBeam beam) {
  final color = beam.color;
  if (beam.rgb == null) return color;
  final hsl = _Hsl.of(color);
  return hsl.l >= 0.55
      ? color
      : hsl.toColor(saturation: hsl.s, lightness: 0.65);
}

/// Pinta [shape] con el contorno de [ink] y un relleno muy suave.
/// [stroke] va en unidades de la planta.
void paintDocumentLight(
  Canvas canvas,
  DocumentLightShape shape,
  Color ink, {
  required double stroke,
  double fill = 0.10,
}) {
  final path = shape.path;
  canvas.drawPath(path, Paint()..color = ink.withValues(alpha: fill));
  final edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeJoin = StrokeJoin.round
    ..color = ink.withValues(alpha: 0.9);
  if (shape.kind == DocumentLightKind.footprint) {
    // La huella va a trazos: está en el suelo, no a la altura del foco.
    for (final metric in path.computeMetrics()) {
      final dash = stroke * 4;
      for (var d = 0.0; d < metric.length; d += dash * 1.8) {
        canvas.drawPath(metric.extractPath(d, d + dash), edge);
      }
    }
    return;
  }
  canvas.drawPath(path, edge);
}

/// El nombre corto de un foco junto a su número: «1 · Tubo 15X».
String documentLightTag(int number, String name) => '$number · $name';

class _Hsl {
  final double h;
  final double s;
  final double l;
  const _Hsl(this.h, this.s, this.l);

  factory _Hsl.of(Color c) {
    final r = c.r, g = c.g, b = c.b;
    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    final l = (maxC + minC) / 2;
    final d = maxC - minC;
    if (d == 0) return _Hsl(0, 0, l);
    final s = d / (1 - (2 * l - 1).abs());
    double h;
    if (maxC == r) {
      h = ((g - b) / d) % 6;
    } else if (maxC == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    return _Hsl(h * 60, s.clamp(0.0, 1.0), l);
  }

  Color toColor({required double saturation, required double lightness}) {
    final c = (1 - (2 * lightness - 1).abs()) * saturation;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = lightness - c / 2;
    final (r, g, b) = switch (h) {
      < 60 => (c, x, 0.0),
      < 120 => (x, c, 0.0),
      < 180 => (0.0, c, x),
      < 240 => (0.0, x, c),
      < 300 => (x, 0.0, c),
      _ => (c, 0.0, x),
    };
    return Color.from(alpha: 1, red: r + m, green: g + m, blue: b + m);
  }
}
