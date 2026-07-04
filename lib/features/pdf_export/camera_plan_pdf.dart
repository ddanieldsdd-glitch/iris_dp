import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/database/app_database.dart';
import '../camera_plan/camera_plan_constants.dart';
import '../camera_plan/camera_plan_element_model.dart';
import '../camera_plan/camera_plan_grouping.dart';

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

        blocks.add(
          pw.Text(
            'Plano ${shot.number}',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        );

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
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
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
