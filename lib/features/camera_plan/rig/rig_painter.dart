import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../arch/arch_roof.dart';
import '../arch/arch_solid.dart';
import '../arch/arch_stair.dart';
import '../arch/plan_section.dart';
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

    /// Un forjado que es el suelo del nivel que se ve (AM.6): relleno,
    /// aunque esté por encima de la cabeza del de abajo.
    bool asFloor = false,
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
        drawScan(canvas, el.position, metersPerUnit, color: color);
      case RigType.slab || RigType.volume:
        drawSolid(
          canvas,
          el,
          metersPerUnit,
          selected: selected,
          ink: color,
          asFloor: asFloor,
        );
      case RigType.stair:
        drawStair(canvas, el, metersPerUnit, selected: selected, ink: color);
      case RigType.section:
        drawSection(canvas, el, metersPerUnit, selected: selected);
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

  /// Un escaneo: su origen, para cogerlo y moverlo en la planta.
  static void drawScan(
    Canvas canvas,
    Offset at,
    double mpu, {
    Color color = ink,
  }) {
    final r = math.max(0.5 / mpu, 10.0);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas
      ..drawCircle(at, r, paint)
      ..drawLine(at - Offset(r * 0.6, 0), at + Offset(r * 0.6, 0), paint)
      ..drawLine(at - Offset(0, r * 0.6), at + Offset(0, r * 0.6), paint);
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
      // Girado como el elemento, igual que lo ven la luz y el 3D (AM.4).
      canvas
        ..save()
        ..translate(el.position.dx, el.position.dy)
        ..rotate(el.rotation * math.pi / 180)
        ..drawRect(
          Rect.fromCenter(center: Offset.zero, width: size, height: size),
          fill,
        )
        ..restore();
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

  /// Forjado o volumen (AM.2): su contorno relleno del color de su
  /// material y, dentro, su altura. Un forjado por encima de la cabeza va
  /// a trazos, como lo que queda por encima del corte de la planta.
  static void drawSolid(
    Canvas canvas,
    PlanElement el,
    double mpu, {
    bool selected = false,
    Color ink = RigPainter.ink,
    bool asFloor = false,
  }) {
    final pts = ArchSolid.outline(el, mpu);
    if (pts.length < 3) return;
    final path = Path()..addPolygon(pts, true);
    final overhead = ArchSolid.isOverhead(el) && !asFloor;
    final rgb = ArchSolid.material(el).albedoRgb;
    int srgb(int c) {
      final v = c / 255;
      final s = v <= 0.0031308 ? v * 12.92 : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
      return (s.clamp(0.0, 1.0) * 255).round();
    }

    final fill = Color.fromARGB(
      255,
      srgb(rgb >> 16 & 255),
      srgb(rgb >> 8 & 255),
      srgb(rgb & 255),
    );
    if (!overhead) {
      canvas.drawPath(path, Paint()..color = fill.withValues(alpha: 0.55));
    }
    final stroke = Paint()
      ..color = selected ? rigColor : ink.withValues(alpha: 0.85)
      ..strokeWidth = selected ? 2 : 1.2
      ..style = PaintingStyle.stroke;
    if (overhead) {
      for (var i = 0; i < pts.length; i++) {
        _dashed(canvas, pts[i], pts[(i + 1) % pts.length], stroke);
      }
    } else {
      canvas.drawPath(path, stroke);
    }
    // La cumbrera de su cubierta (AM.3), a trazos largos.
    final roof = ArchSolid.roof(el);
    if (roof != null) {
      final ridge = roof.ridge(ArchSolid.outlineM(el));
      final linePaint = Paint()
        ..color = ink.withValues(alpha: 0.6)
        ..strokeWidth = 1;
      if (ridge != null) {
        final a = ArchSolid.toCanvas(el, ridge.$1, mpu);
        final b = ArchSolid.toCanvas(el, ridge.$2, mpu);
        _dashed(canvas, a, b, linePaint, dash: 12, gap: 4);
        // A cuatro aguas, las limatesas: de cada esquina a la cumbrera.
        if (roof.kind == ArchRoofKind.hip) {
          for (final p in pts) {
            final near = (p - a).distance < (p - b).distance ? a : b;
            canvas.drawLine(p, near, linePaint);
          }
        }
      }
    }
    // La altura en el centro: «+0,40» la cota de un forjado, «1,10 m» el
    // alto de un volumen y, con cubierta, «2,60 · 4,10» alero y cumbrera.
    String m(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
    final text = ArchSolid.isSlab(el)
        ? '+${m(ArchSolid.topM(el))}'
        : roof != null
        ? '${m(ArchSolid.heightM(el))} · ${m(ArchSolid.topM(el))} m'
        : '${m(ArchSolid.topM(el))} m';
    var c = Offset.zero;
    for (final p in pts) {
      c += p;
    }
    c /= pts.length.toDouble();
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: ink,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          backgroundColor: _fillFor(ink).withValues(alpha: 0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  /// Una escalera o una rampa (AM.6), como en los planos: cada peldaño,
  /// la línea por la que se sube con un círculo en el arranque y la flecha
  /// en la llegada, y cuántos peldaños y de cuánto.
  /// Una línea de sección (AM.6): trazo y punto, y en cada punta una
  /// flecha hacia donde se mira con su letra, como en un plano.
  static void drawSection(
    Canvas canvas,
    PlanElement el,
    double mpu, {
    bool selected = false,
  }) {
    const color = Color(0xFFC8102E);
    final a = PlanSection.start(el), b = PlanSection.end(el);
    final len = (b - a).distance;
    if (len < 1) return;
    final u = (b - a) / len;
    final look = PlanSection.look(el);
    // Del tamaño de un rótulo, sea cual sea la escala.
    final size = math.max(10.0, 0.45 / mpu);
    final line = Paint()
      ..color = color
      ..strokeWidth = selected ? 2.2 : 1.4
      ..style = PaintingStyle.stroke;
    // Trazo y punto.
    final dash = size * 0.9, gap = size * 0.3, dot = size * 0.1;
    var s = 0.0;
    while (s < len) {
      final e = math.min(len, s + dash);
      canvas.drawLine(a + u * s, a + u * e, line);
      s = e + gap;
      if (s < len) {
        canvas.drawLine(a + u * s, a + u * math.min(len, s + dot), line);
      }
      s += dot + gap;
    }
    final fill = Paint()..color = color;
    for (final p in [a, b]) {
      canvas.drawLine(p, p + look * size, line..strokeWidth = 2);
      final tip = p + look * size * 1.3;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(
            (p + look * size * 0.8 + u * size * 0.3).dx,
            (p + look * size * 0.8 + u * size * 0.3).dy,
          )
          ..lineTo(
            (p + look * size * 0.8 - u * size * 0.3).dx,
            (p + look * size * 0.8 - u * size * 0.3).dy,
          )
          ..close(),
        fill,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: PlanSection.name(el),
          style: TextStyle(
            color: color,
            fontSize: size * 0.9,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final at = p - u * size * 0.9;
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  static void drawStair(
    Canvas canvas,
    PlanElement el,
    double mpu, {
    bool selected = false,
    Color ink = RigPainter.ink,
  }) {
    Offset c(Offset m) => ArchStair.toCanvas(el, m, mpu);
    final rgb = ArchStair.material(el).albedoRgb;
    int srgb(int v) {
      final x = v / 255;
      final s = x <= 0.0031308 ? x * 12.92 : 1.055 * math.pow(x, 1 / 2.4) - 0.055;
      return (s.clamp(0.0, 1.0) * 255).round();
    }

    final fill = Paint()
      ..color = Color.fromARGB(
        140,
        srgb(rgb >> 16 & 255),
        srgb(rgb >> 8 & 255),
        srgb(rgb & 255),
      );
    final stroke = Paint()
      ..color = selected ? rigColor : ink.withValues(alpha: 0.85)
      ..strokeWidth = selected ? 2 : 1
      ..style = PaintingStyle.stroke;
    for (final step in ArchStair.steps(el)) {
      final path = Path()..addPolygon([for (final p in step.poly) c(p)], true);
      canvas
        ..drawPath(path, fill)
        ..drawPath(path, stroke);
    }
    if (ArchStair.post(el) case (final poly, _)) {
      canvas.drawPath(
        Path()..addPolygon([for (final p in poly) c(p)], true),
        Paint()..color = ink,
      );
    }
    // Por dónde se sube.
    final walk = [for (final p in ArchStair.walkLine(el)) c(p)];
    if (walk.length >= 2) {
      final line = Paint()
        ..color = ink
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawPath(Path()..addPolygon(walk, false), line);
      canvas.drawCircle(walk.first, 3.5, line);
      final end = walk.last, d = end - walk[walk.length - 2];
      if (d.distance > 0) {
        final u = d / d.distance, n = Offset(-u.dy, u.dx);
        canvas.drawPath(
          Path()
            ..moveTo(end.dx, end.dy)
            ..lineTo((end - u * 9 + n * 4.5).dx, (end - u * 9 + n * 4.5).dy)
            ..lineTo((end - u * 9 - n * 4.5).dx, (end - u * 9 - n * 4.5).dy)
            ..close(),
          Paint()..color = ink,
        );
      }
    }
    // «16 × 17,5» o «Rampa 8 %», junto al arranque.
    String cm(double m) =>
        (m * 100).toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '');
    final text = ArchStair.shape(el) == StairShape.ramp
        ? 'Rampa ${ArchStair.slopePct(el).round()} %'
        : '${ArchStair.risers(el)} × ${cm(ArchStair.riserM(el))}';
    final warn = ArchStair.warning(el) != null;
    final tp = TextPainter(
      text: TextSpan(
        text: warn ? '$text !' : text,
        style: TextStyle(
          color: warn ? const Color(0xFFE0A030) : ink,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          backgroundColor: _fillFor(ink).withValues(alpha: 0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final at = walk.isEmpty ? el.position : walk.first;
    tp.paint(canvas, at + const Offset(6, 4));
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
