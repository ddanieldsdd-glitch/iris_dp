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
        for (final stamp in document.stamps) {
          _drawStamp(canvas, size, stamp);
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
    // La goma de pintura no tiene equivalente vectorial.
    if (stroke.tool == AnnotationToolType.eraseArea) return;
    final toolAlpha = switch (stroke.tool) {
      AnnotationToolType.highlighter => 0.35,
      AnnotationToolType.marker => 0.6,
      AnnotationToolType.wash => 0.32,
      AnnotationToolType.airbrush => 0.18,
      AnnotationToolType.pencil => 0.75,
      AnnotationToolType.charcoal => 0.5,
      _ => 1.0,
    };
    final alpha = toolAlpha * stroke.opacity.clamp(0.0, 1.0);
    final base = PdfColor.fromInt(stroke.colorArgb);
    final color = PdfColor(base.red, base.green, base.blue, alpha);
    final widthFactor = switch (stroke.tool) {
      AnnotationToolType.marker => 1.6,
      AnnotationToolType.charcoal => 1.8,
      AnnotationToolType.wash => 2.4,
      AnnotationToolType.airbrush => 3.0,
      AnnotationToolType.pencil => 0.55,
      _ => 1.0,
    };
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

    if (stroke.tool == AnnotationToolType.fill ||
        stroke.tool == AnnotationToolType.hatch ||
        stroke.closed) {
      final first = point(stroke.points.first);
      canvas.moveTo(first.x, first.y);
      for (final value in stroke.points.skip(1)) {
        final p = point(value);
        canvas.lineTo(p.x, p.y);
      }
      canvas.closePath();
      if (stroke.tool == AnnotationToolType.fill ||
          stroke.tool == AnnotationToolType.hatch) {
        // La trama se aproxima con un relleno suave.
        canvas
          ..setFillColor(
            stroke.tool == AnnotationToolType.hatch
                ? PdfColor(base.red, base.green, base.blue, alpha * 0.35)
                : color,
          )
          ..fillPath();
      } else {
        canvas
          ..setLineWidth(math.max(0.5, stroke.width * widthFactor))
          ..strokePath();
      }
      return;
    }

    if (stroke.tool == AnnotationToolType.arrow ||
        stroke.tool == AnnotationToolType.line) {
      final start = point(stroke.points.first);
      final end = point(stroke.points.last);
      canvas
        ..setLineWidth(math.max(0.75, stroke.width))
        ..drawLine(start.x, start.y, end.x, end.y)
        ..strokePath();
      if (stroke.tool == AnnotationToolType.arrow) {
        _drawArrowHead(canvas, start, end, stroke.width);
      }
      return;
    }

    for (var i = 1; i < stroke.points.length; i++) {
      final previous = point(stroke.points[i - 1]);
      final current = point(stroke.points[i]);
      final pressure =
          (stroke.points[i - 1].pressure + stroke.points[i].pressure) / 2;
      canvas
        ..setLineWidth(
          math.max(0.5, stroke.width * widthFactor * (0.35 + pressure * 0.65)),
        )
        ..drawLine(previous.x, previous.y, current.x, current.y)
        ..strokePath();
    }
  }

  /// Sello simplificado: disco con una marca hacia donde mira.
  static void _drawStamp(
    PdfGraphics canvas,
    PdfPoint size,
    AnnotationStamp stamp,
  ) {
    final color = PdfColor.fromInt(stamp.colorArgb);
    final r = stamp.size * math.min(size.x, size.y) / 2;
    final cx = stamp.x * size.x;
    final cy = (1 - stamp.y) * size.y;
    if (stamp.kind == AnnotationStampKind.text) return;
    canvas
      ..setStrokeColor(color)
      ..setLineWidth(math.max(0.6, r * 0.08))
      ..drawEllipse(cx, cy, r * 0.45, r * 0.45)
      ..strokePath()
      // En PDF el eje Y va hacia arriba: se invierte el giro.
      ..drawLine(
        cx,
        cy,
        cx + math.cos(stamp.rotation) * r * 1.2,
        cy - math.sin(stamp.rotation) * r * 1.2,
      )
      ..strokePath();
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
