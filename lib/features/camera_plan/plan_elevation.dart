import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/light_scene.dart';
import 'light/plan_light.dart';
import 'light_beam.dart';
import 'plan_opening.dart';
import 'plan_segment.dart';
import 'plan_terrain_painter.dart';

/// Desde dónde se mira la planta para levantarla en altura.
enum ElevationSide {
  /// Alzado: desde el sur, mirando al norte. Izquierda = oeste.
  front,

  /// Perfil: desde el este, mirando al oeste. Izquierda = sur.
  side,
}

extension ElevationSideLabel on ElevationSide {
  String get label => switch (this) {
    ElevationSide.front => 'Alzado',
    ElevationSide.side => 'Perfil',
  };

  String get hint => switch (this) {
    ElevationSide.front => 'desde el sur, mirando al norte',
    ElevationSide.side => 'desde el este, mirando al oeste',
  };
}

enum ElevationKind { wall, opening, light, actor, camera, prop }

/// Una pieza de la planta vista de lado: dónde cae a lo ancho, a qué
/// altura y a qué distancia del que mira.
class ElevationItem {
  final ElevationKind kind;
  final PlanElement element;

  /// A lo ancho de la vista, en metros.
  final double from;
  final double to;

  /// Altura, en metros.
  final double bottom;
  final double top;

  /// Distancia al que mira, en metros: lo lejano se pinta detrás.
  final double depth;
  final String label;

  /// Luces: hacia dónde apunta en el plano de la vista (radianes desde la
  /// horizontal hacia la derecha; positivo hacia arriba), apertura y
  /// alcance en metros. `aim` es `null` si apunta hacia el que mira o en
  /// sentido contrario.
  final double? aim;
  final double beamDeg;
  final double reachM;
  final double cct;

  const ElevationItem({
    required this.kind,
    required this.element,
    required this.from,
    required this.to,
    required this.bottom,
    required this.top,
    required this.depth,
    this.label = '',
    this.aim,
    this.beamDeg = 0,
    this.reachM = 0,
    this.cct = 5600,
  });

  double get centre => (from + to) / 2;
}

/// La planta levantada en altura desde un lado: paredes con sus huecos,
/// luces a su altura con su haz, personas, cámaras y atrezo.
class PlanElevation {
  final ElevationSide side;
  final List<ElevationItem> items;

  const PlanElevation(this.side, this.items);

  /// Altura de una persona de pie y del objetivo de una cámara en mano o en
  /// trípode, en metros.
  static const double personM = 1.7;
  static const double lensM = 1.5;

  /// Altura de una luz en pie si no dice otra.
  static const double standM = 2.0;

  double get left =>
      items.isEmpty ? 0 : items.map((i) => i.from).reduce(math.min);
  double get right =>
      items.isEmpty ? 1 : items.map((i) => i.to).reduce(math.max);
  double get height => math.max(
    3,
    items.isEmpty ? 3 : items.map((i) => i.top).reduce(math.max) + 0.5,
  );

  /// Posición de un punto de la planta en la vista: a lo ancho y en
  /// profundidad, en metros.
  static ({double across, double depth}) project(
    Offset p,
    double metersPerUnit,
    ElevationSide side,
  ) => switch (side) {
    ElevationSide.front => (
      across: p.dx * metersPerUnit,
      depth: -p.dy * metersPerUnit,
    ),
    ElevationSide.side => (
      across: -p.dy * metersPerUnit,
      depth: -p.dx * metersPerUnit,
    ),
  };

  /// Una dirección de la planta en la vista: cuánto va a lo ancho.
  static double acrossOf(Offset dir, ElevationSide side) => switch (side) {
    ElevationSide.front => dir.dx,
    ElevationSide.side => -dir.dy,
  };

  factory PlanElevation.of(
    List<PlanElement> elements, {
    required double metersPerUnit,
    required ElevationSide side,

    /// La planta vista por la luz, si ya está hecha. Si no, se hace sin
    /// rebotes: aquí solo hacen falta los recintos y sus techos.
    LightScene? scene,
  }) {
    final mpu = metersPerUnit;
    scene ??= LightScene.from(elements, metersPerUnit: mpu, wallBounce: false);
    final items = <ElevationItem>[];
    ({double across, double depth}) at(Offset p) => project(p, mpu, side);

    for (final el in elements) {
      if (PlanSegment.isSegment(el)) {
        if (PlanSegment.kind(el) != PlanSegment.kindWall) continue;
        final a = at(el.position), b = at(PlanSegment.end(el));
        final top =
            (el.props[LightScene.heightKey] as num?)?.toDouble() ??
            scene.wallTopAt(
              Offset.lerp(el.position, PlanSegment.end(el), 0.5)!,
            );
        items.add(
          ElevationItem(
            kind: ElevationKind.wall,
            element: el,
            from: math.min(a.across, b.across),
            to: math.max(a.across, b.across) + 0.02,
            bottom: 0,
            top: top,
            depth: (a.depth + b.depth) / 2,
            label: el.label ?? '',
          ),
        );
        continue;
      }
      if (PlanOpening.isOpening(el)) {
        final (s, e) = PlanOpening.span(el);
        final a = at(s), b = at(e);
        items.add(
          ElevationItem(
            kind: ElevationKind.opening,
            element: el,
            from: math.min(a.across, b.across),
            to: math.max(a.across, b.across) + 0.02,
            bottom: PlanOpening.sill(el),
            top: PlanOpening.head(el),
            depth: (a.depth + b.depth) / 2,
          ),
        );
        continue;
      }
      final p = at(el.position);
      switch (el.type) {
        case ElementType.light:
          final light = PlanLight.of(el);
          final beam = LightBeam.of(el);
          if (light == null || beam == null) continue;
          final overhead = PlanLight.isOverhead(el);
          final z = overhead
              ? PlanLight.heightOf(el)
              : (el.props[PlanLight.heightKey] as num?)?.toDouble() ?? standM;
          final dir = LightScene.aimOf(el);
          final across = acrossOf(dir, side);
          double? aim;
          if (overhead) {
            // Cuelga y mira abajo; inclinada, hacia donde apunta.
            final tilt = PlanLight.tiltOf(el) * math.pi / 180;
            aim = -math.pi / 2 + (across >= 0 ? tilt : -tilt);
          } else if (across.abs() > 0.2) {
            aim = across > 0 ? 0 : math.pi;
          }
          items.add(
            ElevationItem(
              kind: ElevationKind.light,
              element: el,
              from: p.across - 0.15,
              to: p.across + 0.15,
              bottom: z - 0.15,
              top: z + 0.15,
              depth: p.depth,
              label: (el.props['name'] as String?) ?? el.displayLabel,
              aim: aim,
              beamDeg: beam.spread,
              reachM: light.source.distanceFor(20).clamp(0.5, 8.0),
              cct: beam.cct,
            ),
          );
        case ElementType.actor:
          items.add(
            ElevationItem(
              kind: ElevationKind.actor,
              element: el,
              from: p.across - 0.25,
              to: p.across + 0.25,
              bottom: 0,
              top: personM,
              depth: p.depth,
              label: el.displayLabel,
            ),
          );
        case ElementType.camera:
          final z =
              (el.props[PlanLight.heightKey] as num?)?.toDouble() ?? lensM;
          final across = acrossOf(LightScene.aimOf(el), side);
          items.add(
            ElevationItem(
              kind: ElevationKind.camera,
              element: el,
              from: p.across - 0.2,
              to: p.across + 0.2,
              bottom: z - 0.12,
              top: z + 0.12,
              depth: p.depth,
              label: el.cameraLabel,
              aim: across.abs() > 0.2 ? (across > 0 ? 0 : math.pi) : null,
            ),
          );
        case ElementType.prop:
          if (PlanTerrainPainter.isTerrain(el) ||
              el.propType == PropType.meter) {
            continue;
          }
          final half = LightScene.propSizeM(el);
          items.add(
            ElevationItem(
              kind: ElevationKind.prop,
              element: el,
              from: p.across - half,
              to: p.across + half,
              bottom: 0,
              top: LightScene.propHeightM(el),
              depth: p.depth,
              label: el.displayLabel,
            ),
          );
        case ElementType.wall:
          break;
      }
    }
    // Lo lejano primero: lo cercano se pinta encima.
    items.sort((a, b) => b.depth.compareTo(a.depth));
    return PlanElevation(side, items);
  }
}

/// Pinta un [PlanElevation]: suelo, regla de alturas y cada pieza, más
/// tenue cuanto más lejos.
class PlanElevationPainter extends CustomPainter {
  final PlanElevation elevation;
  final Color ink;
  final Color faint;
  final Color background;
  final Color accent;

  PlanElevationPainter({
    required this.elevation,
    required this.ink,
    required this.faint,
    required this.background,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    const margin = EdgeInsets.fromLTRB(56, 24, 24, 40);
    final e = elevation;
    final spanM = math.max(1.0, e.right - e.left + 1);
    final scale = math.min(
      (size.width - margin.horizontal) / spanM,
      (size.height - margin.vertical) / e.height,
    );
    final floorY = size.height - margin.bottom;
    final leftX = margin.left + 0.5 * scale - e.left * scale;
    Offset to(double across, double z) =>
        Offset(leftX + across * scale, floorY - z * scale);

    // Regla de alturas y suelo.
    final rule = Paint()
      ..color = faint
      ..strokeWidth = 0.5;
    for (var z = 0; z <= e.height; z++) {
      final y = floorY - z * scale;
      canvas.drawLine(Offset(margin.left, y), Offset(size.width - 8, y), rule);
      _text(canvas, '$z m', Offset(10, y - 6), faint, 10);
    }
    canvas.drawLine(
      Offset(margin.left, floorY),
      Offset(size.width - 8, floorY),
      Paint()
        ..color = ink
        ..strokeWidth = 1.2,
    );

    final depths = e.items.map((i) => i.depth);
    final near = depths.isEmpty ? 0.0 : depths.reduce(math.min);
    final far = depths.isEmpty ? 0.0 : depths.reduce(math.max);
    for (final item in e.items) {
      // Lo de más lejos, a la mitad de tinta.
      final t = far - near < 0.01 ? 1.0 : (far - item.depth) / (far - near);
      final alpha = 0.45 + 0.55 * t;
      final color = ink.withValues(alpha: alpha);
      final rect = Rect.fromPoints(
        to(item.from, item.bottom),
        to(item.to, item.top),
      );
      switch (item.kind) {
        case ElevationKind.wall:
          canvas.drawRect(
            rect,
            Paint()..color = faint.withValues(alpha: 0.18 * alpha),
          );
          canvas.drawRect(
            rect,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        case ElevationKind.opening:
          canvas.drawRect(rect, Paint()..color = background);
          canvas.drawRect(
            rect,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );
        case ElevationKind.light:
          final c = to(item.centre, (item.bottom + item.top) / 2);
          final aim = item.aim;
          if (aim != null && item.beamDeg < 359) {
            final half = item.beamDeg / 2 * math.pi / 180;
            final r = item.reachM * scale;
            final beam = Path()
              ..moveTo(c.dx, c.dy)
              ..lineTo(
                c.dx + r * math.cos(aim - half),
                c.dy - r * math.sin(aim - half),
              )
              ..lineTo(
                c.dx + r * math.cos(aim + half),
                c.dy - r * math.sin(aim + half),
              )
              ..close();
            final tint = LightBeam.colorForCct(item.cct);
            // La luz no pasa del suelo.
            canvas.save();
            canvas.clipRect(
              Rect.fromLTRB(margin.left, margin.top, size.width - 8, floorY),
            );
            canvas.drawPath(
              beam,
              Paint()
                ..shader = RadialGradient(
                  colors: [
                    tint.withValues(alpha: 0.45 * alpha),
                    tint.withValues(alpha: 0),
                  ],
                ).createShader(Rect.fromCircle(center: c, radius: r)),
            );
            canvas.restore();
          } else if (item.beamDeg >= 359) {
            canvas.drawCircle(
              c,
              0.6 * scale,
              Paint()
                ..color = LightBeam.colorForCct(
                  item.cct,
                ).withValues(alpha: 0.18 * alpha),
            );
          }
          // El pie hasta el suelo, si no cuelga.
          if (!PlanLight.isOverhead(item.element)) {
            canvas.drawLine(
              c,
              to(item.centre, 0),
              Paint()
                ..color = color
                ..strokeWidth = 1,
            );
          }
          canvas.drawCircle(c, 0.13 * scale, Paint()..color = accent);
          _text(canvas, item.label, c + const Offset(8, -14), color, 10);
        case ElevationKind.actor:
          final head = to(item.centre, item.top - 0.12);
          final paint = Paint()
            ..color = color
            ..strokeWidth = 1.4
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(head, 0.12 * scale, paint);
          canvas.drawLine(
            to(item.centre, item.top - 0.24),
            to(item.centre, 0.9),
            paint,
          );
          canvas.drawLine(
            to(item.centre, 0.9),
            to(item.centre - 0.18, 0),
            paint,
          );
          canvas.drawLine(
            to(item.centre, 0.9),
            to(item.centre + 0.18, 0),
            paint,
          );
          _text(
            canvas,
            item.label,
            to(item.centre, item.top) + const Offset(-14, -16),
            color,
            10,
          );
        case ElevationKind.camera:
          canvas.drawRect(rect, Paint()..color = color);
          canvas.drawLine(
            to(item.centre, item.bottom),
            to(item.centre, 0),
            Paint()
              ..color = color
              ..strokeWidth = 1,
          );
          _text(
            canvas,
            item.label,
            rect.topRight + const Offset(4, -12),
            color,
            10,
          );
        case ElevationKind.prop:
          canvas.drawRect(
            rect,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );
      }
    }
    _text(
      canvas,
      '${e.side.label} · ${e.side.hint}',
      Offset(margin.left, size.height - 22),
      faint,
      11,
    );
  }

  void _text(Canvas canvas, String text, Offset at, Color color, double size) {
    if (text.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 160);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant PlanElevationPainter old) =>
      old.elevation != elevation;
}
