import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../moodboard_annotation_store.dart';

/// Pinta trazos normalizados (0–1) sobre el frame.
class MoodboardAnnotationPainter extends CustomPainter {
  final List<MoodboardStroke> strokes;

  MoodboardAnnotationPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (s.label == 'ARROW' && s.points.length >= 2) {
        final a = Offset(
          s.points.first.dx * size.width,
          s.points.first.dy * size.height,
        );
        final b = Offset(
          s.points.last.dx * size.width,
          s.points.last.dy * size.height,
        );
        paint.strokeWidth = s.width;
        canvas.drawLine(a, b, paint);
        final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
        const head = 12.0;
        final p1 = Offset(
          b.dx - head * math.cos(angle - 0.4),
          b.dy - head * math.sin(angle - 0.4),
        );
        final p2 = Offset(
          b.dx - head * math.cos(angle + 0.4),
          b.dy - head * math.sin(angle + 0.4),
        );
        final path = Path()
          ..moveTo(b.dx, b.dy)
          ..lineTo(p1.dx, p1.dy)
          ..moveTo(b.dx, b.dy)
          ..lineTo(p2.dx, p2.dy);
        canvas.drawPath(path, paint);
        continue;
      }

      if (s.label != null && s.label != 'ARROW' && s.points.length == 1) {
        final o = Offset(
          s.points.first.dx * size.width,
          s.points.first.dy * size.height,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: s.label,
            style: TextStyle(
              color: s.color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, o);
        continue;
      }

      if (s.points.length < 2) continue;
      final path = Path()
        ..moveTo(
          s.points.first.dx * size.width,
          s.points.first.dy * size.height,
        );
      for (var i = 1; i < s.points.length; i++) {
        path.lineTo(
          s.points[i].dx * size.width,
          s.points[i].dy * size.height,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MoodboardAnnotationPainter oldDelegate) =>
      !identical(oldDelegate.strokes, strokes);
}
