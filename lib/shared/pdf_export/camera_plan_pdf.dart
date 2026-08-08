import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/database/app_database.dart';
import '../../shared/annotations/annotation_document.dart';
import '../../shared/annotations/annotation_pdf_renderer.dart';
import '../../features/camera_plan/camera_plan_constants.dart';
import '../../features/camera_plan/camera_plan_element_model.dart';
import '../../features/camera_plan/camera_plan_grouping.dart';

/// Representación cenital vectorial de una planta de cámara.
///
/// Usa el mismo espacio lógico 1600 × 1200 del editor. De esta forma la capa
/// normalizada de [AnnotationDocument] queda alineada con los elementos de DB.
abstract final class CameraPlanPdfDiagram {
  static const double documentWidth = 1600;
  static const double documentHeight = 1200;
  static const double width = 480;
  static const double height = 360;

  static pw.Widget build({
    required List<PlanElement> elements,
    required AnnotationDocument annotations,
  }) {
    return pw.Container(
      width: width,
      height: height,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.7),
      ),
      child: pw.Stack(
        children: [
          pw.CustomPaint(
            size: const PdfPoint(width, height),
            painter: (canvas, size) => _paintPlan(canvas, size, elements),
          ),
          ...elements.map(_buildLabel),
          AnnotationPdfRenderer.build(
            annotations,
            width: width,
            height: height,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLabel(PlanElement element) {
    final x = element.position.dx / documentWidth * width;
    final y = element.position.dy / documentHeight * height;
    return pw.Positioned(
      left: (x - 38).clamp(0, width - 76),
      top: (y + 8).clamp(0, height - 18),
      child: pw.SizedBox(
        width: 76,
        child: pw.Text(
          element.displayLabel,
          textAlign: pw.TextAlign.center,
          maxLines: 1,
          style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey800),
        ),
      ),
    );
  }

  static void _paintPlan(
    PdfGraphics canvas,
    PdfPoint size,
    List<PlanElement> elements,
  ) {
    double x(double value) => value / documentWidth * size.x;
    double y(double value) => (1 - value / documentHeight) * size.y;

    canvas
      ..setStrokeColor(PdfColors.grey200)
      ..setLineWidth(0.35);
    for (var gridX = 0.0; gridX <= documentWidth; gridX += 100) {
      canvas
        ..drawLine(x(gridX), 0, x(gridX), size.y)
        ..strokePath();
    }
    for (var gridY = 0.0; gridY <= documentHeight; gridY += 100) {
      canvas
        ..drawLine(0, y(gridY), size.x, y(gridY))
        ..strokePath();
    }

    for (final camera in elements.where(
      (element) => element.type == ElementType.camera,
    )) {
      final points = [camera.position, ...camera.pathPoints];
      if (points.length < 2) continue;
      final color = _cameraColor(camera.cameraLetter);
      canvas
        ..setStrokeColor(color)
        ..setLineWidth(1.4)
        ..setLineCap(PdfLineCap.round);
      for (var index = 1; index < points.length; index++) {
        final from = points[index - 1];
        final to = points[index];
        _drawDashedLine(canvas, x(from.dx), y(from.dy), x(to.dx), y(to.dy));
      }
    }

    for (final element in elements) {
      final centerX = x(element.position.dx);
      final centerY = y(element.position.dy);
      final rotation = -element.rotation * math.pi / 180;
      switch (element.type) {
        case ElementType.camera:
          _drawCamera(
            canvas,
            centerX,
            centerY,
            rotation,
            _cameraColor(element.cameraLetter),
          );
        case ElementType.actor:
          _drawActor(
            canvas,
            centerX,
            centerY,
            PdfColor.fromInt(element.actorColor.toARGB32()),
          );
        case ElementType.light:
          _drawLight(canvas, centerX, centerY, rotation);
        case ElementType.prop:
          _drawProp(canvas, centerX, centerY, rotation);
        case ElementType.wall:
          _drawWall(canvas, centerX, centerY, rotation);
      }
    }
  }

  static PdfColor _cameraColor(String letter) =>
      PdfColor.fromInt(cameraColorForLetter(letter).toARGB32());

  static void _drawDashedLine(
    PdfGraphics canvas,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final distance = math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
    if (distance == 0) return;
    const dash = 5.0;
    const gap = 3.0;
    for (var cursor = 0.0; cursor < distance; cursor += dash + gap) {
      final end = math.min(cursor + dash, distance);
      canvas
        ..drawLine(
          x1 + (x2 - x1) * cursor / distance,
          y1 + (y2 - y1) * cursor / distance,
          x1 + (x2 - x1) * end / distance,
          y1 + (y2 - y1) * end / distance,
        )
        ..strokePath();
    }
  }

  static PdfPoint _rotated(
    double centerX,
    double centerY,
    double localX,
    double localY,
    double angle,
  ) => PdfPoint(
    centerX + localX * math.cos(angle) - localY * math.sin(angle),
    centerY + localX * math.sin(angle) + localY * math.cos(angle),
  );

  static void _drawCamera(
    PdfGraphics canvas,
    double x,
    double y,
    double rotation,
    PdfColor color,
  ) {
    final tip = _rotated(x, y, 0, 10, rotation);
    final left = _rotated(x, y, -7, -7, rotation);
    final right = _rotated(x, y, 7, -7, rotation);
    canvas
      ..setFillColor(color)
      ..setStrokeColor(color)
      ..moveTo(tip.x, tip.y)
      ..lineTo(left.x, left.y)
      ..lineTo(right.x, right.y)
      ..closePath()
      ..fillPath()
      ..setLineWidth(1)
      ..drawEllipse(x, y, 12, 12)
      ..strokePath();
  }

  static void _drawActor(
    PdfGraphics canvas,
    double x,
    double y,
    PdfColor color,
  ) {
    canvas
      ..setFillColor(color)
      ..setStrokeColor(PdfColors.grey800)
      ..setLineWidth(0.8)
      ..drawEllipse(x, y, 9, 9)
      ..fillAndStrokePath();
  }

  static void _drawLight(
    PdfGraphics canvas,
    double x,
    double y,
    double rotation,
  ) {
    canvas
      ..setStrokeColor(PdfColors.orange700)
      ..setFillColor(PdfColors.orange100)
      ..setLineWidth(1)
      ..drawEllipse(x, y, 8, 8)
      ..fillAndStrokePath();
    for (var index = 0; index < 8; index++) {
      final angle = rotation + index * math.pi / 4;
      canvas
        ..drawLine(
          x + math.cos(angle) * 10,
          y + math.sin(angle) * 10,
          x + math.cos(angle) * 15,
          y + math.sin(angle) * 15,
        )
        ..strokePath();
    }
  }

  static void _drawProp(
    PdfGraphics canvas,
    double x,
    double y,
    double rotation,
  ) {
    final corners = [
      _rotated(x, y, -10, -7, rotation),
      _rotated(x, y, 10, -7, rotation),
      _rotated(x, y, 10, 7, rotation),
      _rotated(x, y, -10, 7, rotation),
    ];
    canvas
      ..setStrokeColor(PdfColors.blueGrey700)
      ..setLineWidth(1)
      ..moveTo(corners.first.x, corners.first.y);
    for (final corner in corners.skip(1)) {
      canvas.lineTo(corner.x, corner.y);
    }
    canvas
      ..closePath()
      ..strokePath();
  }

  static void _drawWall(
    PdfGraphics canvas,
    double x,
    double y,
    double rotation,
  ) {
    final from = _rotated(x, y, -16, 0, rotation);
    final to = _rotated(x, y, 16, 0, rotation);
    canvas
      ..setStrokeColor(PdfColors.grey900)
      ..setLineWidth(2.5)
      ..drawLine(from.x, from.y, to.x, to.y)
      ..strokePath();
  }
}

/// PDF resumen de blocking / planta de cámara por escena y plano.
class CameraPlanPdfExporter {
  CameraPlanPdfExporter._();

  static Future<List<int>> buildBytes({
    required Project project,
    required List<Scene> scenes,
    required AppDatabase db,
  }) async {
    final doc = pw.Document();
    final ordered = scenesInScriptOrder(scenes);
    final blocks = <pw.Widget>[
      pw.Text(
        project.name,
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.Text(
        'Plantas de cámara — blocking cenital',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 16),
    ];

    for (final scene in ordered) {
      blocks.add(
        pw.Text(
          'Esc ${scene.number} · ${scene.locationCanonical}',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      );
      blocks.add(pw.SizedBox(height: 6));

      final shots = await db.getShotsForScene(scene.id);
      shots.sort((a, b) => a.number.compareTo(b.number));

      if (shots.isEmpty) {
        blocks.add(pw.Text('Sin planos.'));
        blocks.add(pw.SizedBox(height: 12));
        continue;
      }

      for (final shot in shots) {
        final rows = await db.getCameraPlanElementsForShot(shot.id);
        final elements = <PlanElement>[];
        for (final row in rows) {
          final paths = await db.getPathPointsForElement(row.id);
          elements.add(PlanElement.fromDb(row, pathRows: paths));
        }
        final annotationRow = await db.getProjectAnnotationDocument(
          projectId: project.id,
          targetType: 'camera_plan_shot',
          targetId: shot.id.toString(),
        );
        final annotations = AnnotationDocument.decode(
          annotationRow?.documentJson,
        );

        blocks.add(
          pw.Text(
            'Plano ${shot.number}',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        );

        blocks.add(pw.SizedBox(height: 4));
        blocks.add(
          CameraPlanPdfDiagram.build(
            elements: elements,
            annotations: annotations,
          ),
        );
        blocks.add(pw.SizedBox(height: 6));

        if (elements.isEmpty) {
          blocks.add(pw.Text('  Sin elementos en planta.'));
        } else {
          blocks.add(
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              headers: const ['Tipo', 'Etiqueta', 'X', 'Y', 'Notas'],
              data: elements.map((el) {
                final notes = switch (el.type) {
                  ElementType.camera =>
                    '${el.lens ?? ''} · ${el.stabilization ?? ''} · ${el.pathPoints.length} pts trayectoria',
                  ElementType.light =>
                    '${el.lightType?.label ?? ''}${el.lukaCompatible ? ' · LUKA' : ''}',
                  _ => '',
                };
                return [
                  el.type.name,
                  el.displayLabel,
                  el.position.dx.toStringAsFixed(0),
                  el.position.dy.toStringAsFixed(0),
                  notes,
                ];
              }).toList(),
            ),
          );
        }
        blocks.add(pw.SizedBox(height: 8));
      }
      blocks.add(pw.SizedBox(height: 12));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => blocks,
      ),
    );

    return doc.save();
  }
}
