import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'annotation_document.dart';

/// Render vectorial portable de tinta para documentos PDF.
abstract final class AnnotationPdfRenderer {
  static pw.Widget build(
    AnnotationDocument document, {
    required double width,
    required double height,
  }) {
    return pw.CustomPaint(
      size: PdfPoint(width, height),
      painter: (canvas, size) {
        for (final stroke in document.strokes) {
          _drawStroke(canvas, size, stroke);
        }
        for (final note in document.notes) {
          _drawNote(canvas, size, note);
        }
      },
    );
  }

  static void _drawNote(PdfGraphics canvas, PdfPoint size, AnnotationNote note) {
    final rect = PdfRect(
      note.x * size.x,
      (1 - note.y - note.height) * size.y,
      note.width * size.x,
      note.height * size.y,
    );
    final base = PdfColor.fromInt(note.colorArgb);
    canvas
      ..setFillColor(base)
      ..drawRect(
        rect.left,
        rect.bottom,
        rect.width,
        rect.height,
      )
      ..fillPath();
  }

  static void _drawStroke(
    PdfGraphics canvas,
    PdfPoint size,
    AnnotationStroke stroke,
  ) {
    if (stroke.points.isEmpty) return;
    final alpha = stroke.tool == AnnotationToolType.highlighter ? 0.35 : 1.0;
    final base = PdfColor.fromInt(stroke.colorArgb);
    final color = PdfColor(base.red, base.green, base.blue, alpha);
    canvas
      ..setStrokeColor(color)
      ..setLineCap(PdfLineCap.round)
      ..setLineJoin(PdfLineJoin.round);

    PdfPoint point(AnnotationPoint value) =>
        PdfPoint(value.x * size.x, (1 - value.y) * size.y);

    if (stroke.points.length == 1) {
      final p = point(stroke.points.single);
      final radius = math.max(0.5, stroke.width / 2);
      canvas
        ..setFillColor(color)
        ..drawEllipse(p.x, p.y, radius, radius)
        ..fillPath();
      return;
    }

    if (stroke.tool == AnnotationToolType.arrow) {
      final start = point(stroke.points.first);
      final end = point(stroke.points.last);
      canvas
        ..setLineWidth(math.max(0.75, stroke.width))
        ..drawLine(start.x, start.y, end.x, end.y)
        ..strokePath();
      _drawArrowHead(canvas, start, end, stroke.width);
      return;
    }

    for (var i = 1; i < stroke.points.length; i++) {
      final previous = point(stroke.points[i - 1]);
      final current = point(stroke.points[i]);
      final pressure =
          (stroke.points[i - 1].pressure + stroke.points[i].pressure) / 2;
      canvas
        ..setLineWidth(math.max(0.5, stroke.width * (0.35 + pressure * 0.65)))
        ..drawLine(previous.x, previous.y, current.x, current.y)
        ..strokePath();
    }
  }

  static void _drawArrowHead(
    PdfGraphics canvas,
    PdfPoint start,
    PdfPoint end,
    double strokeWidth,
  ) {
    final angle = math.atan2(end.y - start.y, end.x - start.x);
    final head = math.max(8.0, strokeWidth * 4);
    final left = PdfPoint(
      end.x - head * math.cos(angle - 0.45),
      end.y - head * math.sin(angle - 0.45),
    );
    final right = PdfPoint(
      end.x - head * math.cos(angle + 0.45),
      end.y - head * math.sin(angle + 0.45),
    );
    canvas
      ..moveTo(left.x, left.y)
      ..lineTo(end.x, end.y)
      ..lineTo(right.x, right.y)
      ..strokePath();
  }
}
