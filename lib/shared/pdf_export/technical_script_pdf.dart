import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/export_file_saver.dart';
import '../../core/utils/pdf_export_fonts.dart';
import '../rich_text/script_markup.dart';
import '../technical_script_export/technical_script_doc.dart';

/// PDF del guion técnico: hoja blanca apaisada con una tabla por escena,
/// como la del documento de trabajo en Word.
class TechnicalScriptPdfExporter {
  static Future<Uint8List> buildBytes(TechnicalScriptDoc doc) => _build(doc);

  static Future<String?> exportAndSave(
    TechnicalScriptDoc doc, {
    required String fileName,
  }) {
    return ExportFileSaver.saveGenerated(
      dialogTitle: 'Exportar guion técnico',
      fileName: '$fileName.pdf',
      extension: 'pdf',
      build: () => _build(doc),
    );
  }

  static const _ink = PdfColors.black;
  static const _border = pw.BorderSide(color: PdfColors.black, width: 0.7);

  static PdfColor _color(int rgb) => PdfColor.fromInt(0xFF000000 | rgb);

  static Future<Uint8List> _build(TechnicalScriptDoc doc) async {
    final fonts = await PdfExportFonts.load();
    final theme = PdfExportFonts.theme(
      regular: fonts.regular,
      bold: fonts.bold,
    );
    // Las fuentes de la app no traen cursiva: se usa la de serie del PDF.
    final italic = pw.Font.helveticaOblique();
    final boldItalic = pw.Font.helveticaBoldOblique();
    final pdf = pw.Document();

    const base = pw.TextStyle(fontSize: 8.5, color: _ink, lineSpacing: 1.5);

    pw.Widget rich(String text, {required bool centered}) {
      final spans = parseScriptMarkup(text);
      return pw.RichText(
        textAlign: centered ? pw.TextAlign.center : pw.TextAlign.left,
        text: pw.TextSpan(
          style: base,
          children: [
            for (final span in spans)
              pw.TextSpan(
                text: span.text,
                style: pw.TextStyle(
                  font: span.italic
                      ? (span.bold ? boldItalic : italic)
                      : (span.bold ? fonts.bold : null),
                  fontWeight: span.bold ? pw.FontWeight.bold : null,
                  decoration: span.underline
                      ? pw.TextDecoration.underline
                      : null,
                  background: span.marker == null
                      ? null
                      : pw.BoxDecoration(
                          color: _color(
                            kScriptDocMarkerFills[span.marker] ?? 0xFFF176,
                          ),
                        ),
                ),
              ),
          ],
        ),
      );
    }

    pw.Widget cell(pw.Widget child, {required bool centered, PdfColor? fill}) =>
        pw.Container(
          color: fill,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          alignment: centered ? pw.Alignment.center : pw.Alignment.topLeft,
          child: child,
        );

    final widths = <int, pw.TableColumnWidth>{
      for (var i = 0; i < doc.columns.length; i++)
        i: pw.FlexColumnWidth(doc.columns[i].weight),
    };

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            doc.title,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          if (doc.subtitle != null && doc.subtitle!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              doc.subtitle!,
              style: const pw.TextStyle(fontSize: 9, color: _ink),
            ),
          ],
          pw.SizedBox(height: 14),
          for (final section in doc.sections) ...[
            pw.Text(
              section.title,
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Table(
              border: const pw.TableBorder(
                top: _border,
                bottom: _border,
                left: _border,
                right: _border,
                horizontalInside: _border,
                verticalInside: _border,
              ),
              columnWidths: widths,
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
              children: [
                pw.TableRow(
                  repeat: true,
                  decoration: pw.BoxDecoration(
                    color: _color(section.headerFill),
                  ),
                  children: [
                    for (final column in doc.columns)
                      cell(
                        pw.Text(
                          column.label,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: _ink,
                          ),
                        ),
                        centered: true,
                      ),
                  ],
                ),
                for (final row in section.rows)
                  pw.TableRow(
                    children: [
                      for (final column in doc.columns)
                        cell(
                          column.key == 'ref' && row.image != null
                              ? pw.Image(
                                  pw.MemoryImage(row.image!),
                                  fit: pw.BoxFit.contain,
                                  height: 70,
                                )
                              : rich(
                                  row.cells[column.key] ?? '',
                                  centered: column.centered,
                                ),
                          centered: column.centered,
                          fill: row.fillOf(column.key) == null
                              ? null
                              : _color(row.fillOf(column.key)!),
                        ),
                    ],
                  ),
                if (section.rows.isEmpty)
                  pw.TableRow(
                    children: [
                      for (final _ in doc.columns)
                        cell(pw.SizedBox(height: 14), centered: true),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 14),
          ],
        ],
      ),
    );

    return pdf.save();
  }
}
