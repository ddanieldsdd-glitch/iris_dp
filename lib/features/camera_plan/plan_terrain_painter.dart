import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/light_scene.dart';
import 'plan_segment.dart';

/// El suelo de la planta: calles, taludes y colinas. Se pinta antes que la
/// luz, que cae encima.
class PlanTerrainPainter {
  PlanTerrainPainter._();

  static const earth = Color(0xFFB08968);

  static bool isTerrain(PlanElement el) {
    if (PlanSegment.isSegment(el)) {
      final kind = PlanSegment.kind(el);
      return kind == PlanSegment.kindStreet || kind == PlanSegment.kindRelief;
    }
    return el.type == ElementType.prop && el.propType == PropType.hill;
  }

  /// Contorno irregular y cerrado alrededor del origen: una copa, una
  /// roca, una curva de nivel. Siempre el mismo para la misma semilla.
  static Path blob(double radius, int seed, {double rough = 0.12}) {
    final random = math.Random(seed);
    const points = 14;
    final radii = [
      for (var i = 0; i < points; i++)
        radius * (1 - rough + random.nextDouble() * rough * 2),
    ];
    Offset at(int i) {
      final angle = (i % points) * 2 * math.pi / points;
      return Offset(math.cos(angle), math.sin(angle)) * radii[i % points];
    }

    final path = Path();
    final start = (at(0) + at(points - 1)) / 2;
    path.moveTo(start.dx, start.dy);
    for (var i = 0; i < points; i++) {
      final mid = (at(i) + at(i + 1)) / 2;
      path.quadraticBezierTo(at(i).dx, at(i).dy, mid.dx, mid.dy);
    }
    return path..close();
  }

  static void _text(
    Canvas canvas,
    String text,
    Offset centre, {
    required double scale,
    Color color = earth,
    bool bold = false,
  }) {
    final zoom = math.min(1.0, scale);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11 / zoom,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          backgroundColor: const Color(0xCC0C0C0F),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  static String _meters(double m) =>
      m == m.roundToDouble() ? '${m.round()} m' : '${m.toStringAsFixed(1)} m';

  /// Un talud: la línea de la cresta y, hacia el lado que baja, las
  /// rayitas de pendiente de los planos topográficos, más largas cuanto
  /// más alto es. En el centro, su altura.
  static void slope(Canvas canvas, PlanElement el, {required double scale}) {
    final path = PlanSegment.path(el);
    final height = LightScene.propHeightM(el);
    final down = el.props['flip'] == true ? -1.0 : 1.0;
    final skirt = (10 + height * 7).clamp(12.0, 90.0);
    final tick = Paint()
      ..color = earth.withValues(alpha: 0.75)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      final band = Path();
      final foot = <Offset>[];
      var i = 0;
      for (var d = 0.0; d <= metric.length; d += 9, i++) {
        final t = metric.getTangentForOffset(d);
        if (t == null) continue;
        final normal = Offset(-t.vector.dy, t.vector.dx) * down;
        if (i == 0) {
          band.moveTo(t.position.dx, t.position.dy);
        } else {
          band.lineTo(t.position.dx, t.position.dy);
        }
        foot.add(t.position + normal * skirt);
        canvas.drawLine(
          t.position,
          t.position + normal * (i.isEven ? skirt : skirt * 0.55),
          tick,
        );
      }
      for (final p in foot.reversed) {
        band.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        band..close(),
        Paint()..color = earth.withValues(alpha: 0.16),
      );
      final mid = metric.getTangentForOffset(metric.length / 2);
      if (mid != null) {
        final normal = Offset(-mid.vector.dy, mid.vector.dx) * down;
        _text(
          canvas,
          'talud ${_meters(height)}',
          mid.position + normal * (skirt + 12 / math.min(1.0, scale)),
          scale: scale,
        );
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = earth
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Cada cuántos metros va una curva de nivel. Una colina más alta lleva
  /// más curvas y más juntas: se ve que es más empinada.
  static double contourInterval(double heightM) => heightM <= 15
      ? 1
      : heightM <= 30
      ? 2
      : heightM <= 75
      ? 5
      : 10;

  /// Una colina: curvas de nivel a intervalo fijo (más altura, más
  /// curvas), tinte más claro cuanto más alto, la ladera contraria al sol
  /// en sombra y la cota de la cima.
  static void hill(
    Canvas canvas,
    PlanElement el, {
    required double metersPerUnit,
    required double scale,
    Offset? towardSun,
  }) {
    final radius = LightScene.propSizeM(el) / metersPerUnit;
    final height = LightScene.propHeightM(el);
    final seed = el.id.hashCode + 21;
    final lit = towardSun ?? const Offset(-0.7, -0.7);
    final step = contourInterval(height);
    final levels = (height / step).floor();

    canvas.save();
    canvas.translate(el.position.dx, el.position.dy);

    // Tinte por altura absoluta: una loma de 3 m queda oscura; una de 30,
    // clara en la cima.
    Color tintAt(double elevation) => Color.lerp(
      const Color(0xFF4A382B),
      const Color(0xFFE2C79C),
      (elevation / 30).clamp(0.0, 1.0),
    )!;
    for (var k = 0; k <= levels; k++) {
      final elevation = k * step;
      final r = radius * (1 - elevation / height);
      if (r < 2) break;
      canvas.drawPath(
        blob(r, seed),
        Paint()..color = tintAt(elevation).withValues(alpha: k == 0 ? 0.55 : 1),
      );
    }
    // La ladera que no mira al sol, en sombra.
    canvas.save();
    canvas.clipPath(blob(radius, seed));
    canvas.drawRect(
      Rect.fromCircle(center: Offset.zero, radius: radius * 1.3),
      Paint()
        ..shader = ui.Gradient.linear(lit * radius, lit * -radius, [
          const Color(0x00000000),
          const Color(0x8C000000),
        ]),
    );
    canvas.restore();

    final zoom = math.min(1.0, scale);
    for (var k = 0; k <= levels; k++) {
      final elevation = k * step;
      final r = radius * (1 - elevation / height);
      if (r < 2) break;
      final index = k % 5 == 0;
      canvas.drawPath(
        blob(r, seed),
        Paint()
          ..color = const Color(
            0xFF2A1F17,
          ).withValues(alpha: index ? 0.95 : 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (index ? 1.8 : 0.9) / zoom,
      );
      // Las curvas maestras llevan su cota.
      if (index && k > 0 && r > 24 / zoom) {
        _text(
          canvas,
          _meters(elevation),
          Offset(r, 0),
          scale: scale,
          color: const Color(0xFFE9D9BF),
        );
      }
    }
    canvas.drawPath(
      Path()
        ..moveTo(0, -5 / zoom)
        ..lineTo(4.5 / zoom, 3 / zoom)
        ..lineTo(-4.5 / zoom, 3 / zoom)
        ..close(),
      Paint()..color = const Color(0xFF1B140F),
    );
    _text(
      canvas,
      'cima ${_meters(height)}',
      Offset(0, 14 / zoom),
      scale: scale,
      color: const Color(0xFFF3E7D2),
      bold: true,
    );
    canvas.restore();
  }
}
