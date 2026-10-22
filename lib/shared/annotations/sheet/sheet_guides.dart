import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Marco de encuadre dentro de la viñeta (no se exporta).
enum SheetFrame {
  none('Sin marco', null),
  flat('1.85', 1.85),
  scope('2.39', 2.39),
  academy('4:3', 4 / 3),
  vertical('9:16', 9 / 16),
  square('1:1', 1);

  const SheetFrame(this.label, this.ratio);

  final String label;
  final double? ratio;
}

/// Guía de perspectiva de uno o dos puntos de fuga, en coordenadas 0–1 del
/// folio (un punto puede quedar fuera, como en un dibujo de verdad).
class PerspectiveGuide {
  /// 0 = apagada, 1 o 2 puntos de fuga.
  final int points;
  final Offset vp1;
  final Offset vp2;

  const PerspectiveGuide({
    this.points = 0,
    this.vp1 = const Offset(0.5, 0.42),
    this.vp2 = const Offset(0.92, 0.42),
  });

  bool get enabled => points > 0;

  PerspectiveGuide copyWith({int? points, Offset? vp1, Offset? vp2}) =>
      PerspectiveGuide(
        points: points ?? this.points,
        vp1: vp1 ?? this.vp1,
        vp2: vp2 ?? this.vp2,
      );

  List<Offset> vanishingPoints(Size size) => [
    Offset(vp1.dx * size.width, vp1.dy * size.height),
    if (points == 2) Offset(vp2.dx * size.width, vp2.dy * size.height),
  ];

  /// Imán: si la recta va casi hacia un punto de fuga, en vertical o (con un
  /// punto) en horizontal, se ajusta a esa dirección. Si no, `null`.
  Offset? snap(Offset start, Offset end, Size size) {
    if (!enabled) return null;
    final drawn = end - start;
    final length = drawn.distance;
    if (length < 4) return null;
    final directions = <Offset>[
      const Offset(0, 1),
      if (points == 1) const Offset(1, 0),
      for (final vp in vanishingPoints(size))
        if ((vp - start).distance > 1) (vp - start) / (vp - start).distance,
    ];
    Offset? best;
    var bestAngle = 0.21; // ~12°
    for (final dir in directions) {
      final cos = (drawn.dx * dir.dx + drawn.dy * dir.dy) / length;
      final angle = math.acos(cos.abs().clamp(0.0, 1.0));
      if (angle < bestAngle) {
        bestAngle = angle;
        best = dir * (cos.sign * length * cos.abs());
      }
    }
    return best == null ? null : start + best;
  }
}

/// Dibuja el marco de encuadre (oscurece lo que queda fuera) y la zona
/// segura.
class FrameGuidePainter extends CustomPainter {
  final SheetFrame frame;
  final bool safeArea;

  const FrameGuidePainter({required this.frame, required this.safeArea});

  /// Rectángulo del encuadre dentro del folio.
  static Rect frameRect(Size size, double? ratio) {
    final full = Offset.zero & size;
    if (ratio == null) return full;
    final sheetRatio = size.width / size.height;
    if (ratio > sheetRatio) {
      final h = size.width / ratio;
      return Rect.fromLTWH(0, (size.height - h) / 2, size.width, h);
    }
    final w = size.height * ratio;
    return Rect.fromLTWH((size.width - w) / 2, 0, w, size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final inner = frameRect(size, frame.ratio);
    if (frame.ratio != null) {
      final outside = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(inner);
      canvas.drawPath(outside, Paint()..color = const Color(0x55000000));
      canvas.drawRect(
        inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xCC2997FF)
          ..strokeWidth = 1.2,
      );
    }
    if (safeArea) {
      final dash = Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x882997FF)
        ..strokeWidth = 1;
      canvas.drawRect(inner.deflate(inner.shortestSide * 0.05), dash);
      canvas.drawRect(inner.deflate(inner.shortestSide * 0.1), dash);
    }
  }

  @override
  bool shouldRepaint(covariant FrameGuidePainter old) =>
      old.frame != frame || old.safeArea != safeArea;
}

/// Rejilla de perspectiva: horizonte y rayos desde cada punto de fuga.
class PerspectivePainter extends CustomPainter {
  final PerspectiveGuide guide;

  const PerspectivePainter(this.guide);

  @override
  void paint(Canvas canvas, Size size) {
    if (!guide.enabled) return;
    final vps = guide.vanishingPoints(size);
    final ray = Paint()
      ..color = const Color(0x332997FF)
      ..strokeWidth = 1;
    final horizon = Paint()
      ..color = const Color(0x992997FF)
      ..strokeWidth = 1.4;
    final reach = size.longestSide * 3;
    for (final vp in vps) {
      for (var i = 0; i < 36; i++) {
        final a = i / 36 * 2 * math.pi;
        canvas.drawLine(vp, vp + Offset(math.cos(a), math.sin(a)) * reach, ray);
      }
    }
    if (vps.length == 2) {
      final dir = vps[1] - vps[0];
      final unit = dir.distance == 0 ? const Offset(1, 0) : dir / dir.distance;
      canvas.drawLine(vps[0] - unit * reach, vps[0] + unit * reach, horizon);
    } else {
      canvas.drawLine(
        Offset(0, vps[0].dy),
        Offset(size.width, vps[0].dy),
        horizon,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PerspectivePainter old) =>
      old.guide.points != guide.points ||
      old.guide.vp1 != guide.vp1 ||
      old.guide.vp2 != guide.vp2;
}

/// Asa para arrastrar un punto de fuga.
class VanishingPointHandle extends StatelessWidget {
  final Offset position;
  final Size sheet;
  final ValueChanged<Offset> onMoved;
  final String tooltip;

  const VanishingPointHandle({
    super.key,
    required this.position,
    required this.sheet,
    required this.onMoved,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    const r = 14.0;
    final px = Offset(
      (position.dx * sheet.width).clamp(r, sheet.width - r),
      (position.dy * sheet.height).clamp(r, sheet.height - r),
    );
    return Positioned(
      left: px.dx - r,
      top: px.dy - r,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => onMoved(
            Offset(
              (position.dx + d.delta.dx / sheet.width).clamp(-1.0, 2.0),
              (position.dy + d.delta.dy / sheet.height).clamp(0.0, 1.0),
            ),
          ),
          child: Container(
            width: r * 2,
            height: r * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x552997FF),
              border: Border.all(color: const Color(0xFF2997FF), width: 2),
            ),
            child: const Icon(Icons.adjust, size: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
