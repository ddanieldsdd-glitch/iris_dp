import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/database/app_database.dart';
import '../../core/utils/export_file_saver.dart';
import '../../core/utils/pdf_export_fonts.dart';

/// Genera y guarda un PDF del guion técnico de un proyecto.
class TechnicalScriptPdfExporter {
  static Future<Uint8List> buildBytes({
    required Project project,
    required List<Scene> scenes,
    required Map<int, List<Shot>> shotsByScene,
  }) =>
      _buildPdf(project, scenes, shotsByScene);

  static Future<String?> exportAndSave({
    required Project project,
    required List<Scene> scenes,
    required Map<int, List<Shot>> shotsByScene,
  }) async {
    final defaultName =
        '${project.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim()}_guion_tecnico';
    return ExportFileSaver.saveGenerated(
      dialogTitle: 'Exportar guion técnico',
      fileName: defaultName.isEmpty ? 'guion_tecnico.pdf' : '$defaultName.pdf',
      extension: 'pdf',
      build: () => _buildPdf(project, scenes, shotsByScene),
    );
  }

  static Future<Uint8List> _buildPdf(
    Project project,
    List<Scene> scenes,
    Map<int, List<Shot>> shotsByScene,
  ) async {
    final fonts = await PdfExportFonts.load();
    final pdfTheme = PdfExportFonts.theme(
      regular: fonts.regular,
      bold: fonts.bold,
    );
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        theme: pdfTheme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            project.name,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (project.director != null) ...[
            pw.SizedBox(height: 4),
            pw.Text('Director: ${project.director}',
                style: const pw.TextStyle(fontSize: 10)),
          ],
          pw.SizedBox(height: 16),
          ...scenes.expand((scene) {
            final shots = shotsByScene[scene.id] ?? [];
            return [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey400),
                  ),
                ),
                child: pw.Text(
                  '${scene.number}. ${scene.name}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (shots.isEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 12, top: 4, bottom: 8),
                  child: pw.Text(
                    'Sin planos',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                )
              else
                ...shots.map(
                  (shot) => pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 12, top: 4, bottom: 4),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(
                          width: 28,
                          child: pw.Text(
                            '${shot.number}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (shot.framing?.isNotEmpty == true)
                                pw.Text(
                                  shot.framing!,
                                  style: const pw.TextStyle(fontSize: 9),
                                ),
                              if (shot.lens?.isNotEmpty == true)
                                pw.Text(
                                  shot.lens!,
                                  style: const pw.TextStyle(fontSize: 8),
                                ),
                              if (shot.action?.isNotEmpty == true)
                                pw.Text(
                                  shot.action!,
                                  style: const pw.TextStyle(fontSize: 8),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              pw.SizedBox(height: 8),
            ];
          }),
        ],
      ),
    );

    return doc.save();
  }
}
