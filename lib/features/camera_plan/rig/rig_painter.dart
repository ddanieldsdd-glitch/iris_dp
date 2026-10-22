import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../camera_plan_element_model.dart';
import '../plan_segment.dart';
import 'plan_drape.dart';
import 'plan_hall.dart';
import 'plan_rig.dart';

/// Dibuja en planta las estructuras de una nave: truss con sus diagonales
/// y juntas, motores, ground support, pilares, telas con su onda y el
/// perímetro de la receta. En coordenadas del lienzo, sin trasladar al
/// elemento.
class RigPainter {
  RigPainter._();

  static const ink = Color(0xFF1E2933);
  static const rigColor = Color(0xFFC56A12);

  /// Dibuja el elemento si es una estructura o una tela. Devuelve si lo ha
  /// dibujado.
  static bool paint(
    Canvas canvas,
    PlanElement el,
    double metersPerUnit, {
    Color color = ink,
    bool selected = false,
  }) {
    if (PlanDrape.isDrape(el)) {
      drawDrape(canvas, el, metersPerUnit, selected: selected, ink: color);
      return true;
    }
    switch (RigTypeCodec.of(el)) {
      case RigType.truss:
        drawTruss(canvas, el, metersPerUnit, color: color, selected: selected);
      case RigType.motor:
        drawMotor(canvas, el.position, metersPerUnit, color: color);
      case RigType.groundSupport:
        drawGroundSupport(canvas, el.position, metersPerUnit, color: color);
      case RigType.pillar:
        drawPillar(canvas, el, metersPerUnit, color: color);
      case RigType.hall:
        drawHall(canvas, el, metersPerUnit, selected: selected, ink: color);
      case RigType.scan:
        return false;
      case null:
        return false;
    }
    return true;
  }

  static void drawTruss(
    Canvas canvas,
    PlanElement el,
    double mpu, {
    Color color = ink,
    bool selected = false,
  }) {
    final a = PlanTruss.start(el), b = PlanTruss.end(el);
    final length = (b - a).distance;
    if (length < 1) return;
    final u = (b - a) / length, n = Offset(-u.dy, u.dx);
    final half = math.max(
      PlanTruss.outerM(PlanTruss.sizeCm(el)) / 2 / mpu,
      2.0,
    );
    Offset p(double along, double across) => a + u * along + n * across;
    if (selected) {
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = rigColor.withValues(alpha: 0.25)
          ..strokeWidth = half * 2 + 8
          ..strokeCap = StrokeCap.round,
      );
    }
    final chord = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final lattice = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 0.7;
    canvas
      ..drawLine(p(0, -half), p(length, -half), chord)
      ..drawLine(p(0, half), p(length, half), chord);
    final steps = math.max(1, (length / (half * 2)).round());
    final profile = PlanTruss.profile(el);
    for (var k = 0; k < steps; k++) {
      final s0 = length * k / steps, s1 = length * (k + 1) / steps;
      final flip = k.isOdd;
      if (profile == TrussProfile.triangle) {
        canvas
          ..drawLine(p(s0, flip ? -half : 0), p(s1, flip ? 0 : -half), lattice)
          ..drawLine(p(s0, flip ? half : 0), p(s1, flip ? 0 : half), lattice);
      } else if (profile == TrussProfile.square) {
        canvas.drawLine(
          p(s0, flip ? half : -half),
          p(s1, flip ? -half : half),
          lattice,
        );
      } else {
        canvas.drawLine(p(s0, -half), p(s0, half), lattice);
      }
    }
    if (profile == TrussProfile.triangle) {
      _dashed(canvas, p(0, 0), p(length, 0), chord..strokeWidth = 0.9);
    }
    // Juntas de los tramos.
    final joint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    var along = 0.0;
    canvas.drawLine(p(0, -half * 1.5), p(0, half * 1.5), joint);
    final pieces = PlanTruss.pieces(el, mpu);
    for (final piece in pieces.pieces) {
      along += piece / mpu;
      canvas.drawLine(p(along, -half * 1.5), p(along, half * 1.5), joint);
    }
    if (pieces.rest > 0) {
      canvas.drawLine(p(length, -half * 1.5), p(length, half * 1.5), joint);
    }
  }

  static void drawMotor(
    Canvas canvas,
    Offset at,
    double mpu, {
    Color color = ink,
  }) {
    final r = math.max(0.2 / mpu, 6.0);
    canvas
      ..drawCircle(at, r, Paint()..color = _fillFor(color))
      ..drawCircle(
        at,
        r,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
    final tp = TextPainter(
      text: TextSpan(
        text: 'M',
        style: TextStyle(
          color: color,
          fontSize: r * 1.1,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  static void drawGroundSupport(
    Canvas canvas,
    Offset at,
    double mpu, {
    Color color = ink,
  }) {
    final tower = math.max(0.22 / mpu, 6.0);
    final base = math.max(0.6 / mpu, tower * 2);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final foot = Rect.fromCenter(center: at, width: base * 2, height: base * 2);
    for (final (from, to) in [
      (foot.topLeft, foot.topRight),
      (foot.topRight, foot.bottomRight),
      (foot.bottomRight, foot.bottomLeft),
      (foot.bottomLeft, foot.topLeft),
    ]) {
      _dashed(canvas, from, to, stroke..strokeWidth = 0.7);
    }
    final box = Rect.fromCenter(
      center: at,
      width: tower * 2,
      height: tower * 2,
    );
    canvas
      ..drawRect(box, Paint()..color = _fillFor(color))
      ..drawRect(box, stroke..strokeWidth = 1.3)
      ..drawLine(box.topLeft, box.bottomRight, stroke)
      ..drawLine(box.topRight, box.bottomLeft, stroke);
  }

  static void drawPillar(
    Canvas canvas,
    PlanElement el,
    double mpu, {
    Color color = ink,
  }) {
    final size = math.max(PlanPillar.sizeM(el) / mpu, 7.0);
    final fill = Paint()..color = color;
    if (PlanPillar.isRound(el)) {
      canvas.drawCircle(el.position, size / 2, fill);
    } else {
      canvas.drawRect(
        Rect.fromCenter(center: el.position, width: size, height: size),
        fill,
      );
    }
  }

  /// La tela: la onda de cortina de teatro a lo largo del tramo, con la
  /// amplitud del frunce.
  static void drawDrape(
    Canvas canvas,
    PlanElement el,
    double mpu, {
    bool selected = false,
    Color ink = RigPainter.ink,
  }) {
    final length = PlanSegment.length(el);
    if (length < 1) return;
    final wave = 0.35 / mpu;
    final amp = (0.04 + 0.06 * PlanDrape.fullness(el)) / mpu;
    final steps = math.max(12, (length / 1.5).ceil());
    final path = Path();
    for (var k = 0; k <= steps; k++) {
      final t = k / steps;
      final p = PlanSegment.pointAt(el, t);
      final ahead = PlanSegment.pointAt(el, math.min(1, t + 0.001));
      final behind = PlanSegment.pointAt(el, math.max(0, t - 0.001));
      final d = ahead - behind;
      final len = d.distance;
      final n = len == 0 ? Offset.zero : Offset(-d.dy / len, d.dx / len);
      final q = p + n * (amp * math.sin(2 * math.pi * t * length / wave));
      k == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    final color = PlanDrape.color(el);
    if (selected) {
      canvas.drawPath(
        PlanSegment.path(el),
        Paint()
          ..color = rigColor.withValues(alpha: 0.25)
          ..strokeWidth = amp * 2 + 10
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    // Una tela del color del fondo se perfila para que se vea.
    if ((color.computeLuminance() - ink.computeLuminance()).abs() > 0.5) {
      canvas.drawPath(
        path,
        Paint()
          ..color = ink.withValues(alpha: 0.6)
          ..strokeWidth = 3.4
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke,
    );
    for (final end in [PlanSegment.start(el), PlanSegment.end(el)]) {
      canvas
        ..drawCircle(end, 3.2, Paint()..color = Colors.white)
        ..drawCircle(
          end,
          3.2,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
    }
  }

  /// La receta de la nave: el perímetro en trazo fino y la cumbrera.
  static void drawHall(
    Canvas canvas,
    PlanElement hall,
    double mpu, {
    bool selected = false,
    Color ink = RigPainter.ink,
  }) {
    final recipe = PlanHall.recipeOf(hall);
    if (recipe == null) return;
    final pts = [for (final p in recipe.polygon()) hall.position + p / mpu];
    final paint = Paint()
      ..color = (selected ? rigColor : ink).withValues(
        alpha: selected ? 0.9 : 0.35,
      )
      ..strokeWidth = selected ? 1.6 : 0.8
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < pts.length; i++) {
      _dashed(canvas, pts[i], pts[(i + 1) % pts.length], paint);
    }
    if (recipe.roof != HallRoof.flat) {
      final c = hall.position + recipe.centroid / mpu;
      final r = recipe.ridgeDeg * math.pi / 180;
      final dir = Offset(math.cos(r), math.sin(r));
      var lo = 0.0, hi = 0.0;
      for (final p in pts) {
        final v = p - c;
        final along = v.dx * dir.dx + v.dy * dir.dy;
        lo = math.min(lo, along);
        hi = math.max(hi, along);
      }
      _dashed(
        canvas,
        c + dir * lo,
        c + dir * hi,
        Paint()
          ..color = ink.withValues(alpha: 0.3)
          ..strokeWidth = 0.8,
        dash: 14,
        gap: 4,
      );
    }
    // El origen: el asa de la nave.
    canvas.drawCircle(
      hall.position,
      selected ? 6 : 4,
      Paint()..color = rigColor.withValues(alpha: selected ? 1 : 0.6),
    );
  }

  /// Relleno de un símbolo: claro sobre papel, oscuro sobre la planta
  /// oscura, para que su trazo siempre se lea.
  static Color _fillFor(Color ink) =>
      ink.computeLuminance() > 0.5 ? const Color(0xFF1A1A20) : Colors.white;

  static void _dashed(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, {
    double dash = 6,
    double gap = 4,
  }) {
    final length = (b - a).distance;
    if (length == 0) return;
    final u = (b - a) / length;
    for (var s = 0.0; s < length; s += dash + gap) {
      canvas.drawLine(a + u * s, a + u * math.min(length, s + dash), paint);
    }
  }
}
