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
    final family = await PdfExportFonts.loadFamily(doc.fontFamily);
    if (!doc.hasIndex) return _compose(doc, family);
    // Primera pasada para saber en qué página cae cada escena; la segunda
    // ya pone esas páginas en el índice (que ocupa lo mismo en las dos).
    final pages = <int, int>{};
    await _compose(doc, family, record: pages);
    return _compose(doc, family, pages: pages);
  }

  /// Página en la que empieza cada escena (por su posición) en el PDF; el
  /// Word la usa como valor inicial de su índice.
  static Future<Map<int, int>> scenePages(TechnicalScriptDoc doc) async {
    final pages = <int, int>{};
    if (!doc.hasIndex) return pages;
    final family = await PdfExportFonts.loadFamily(doc.fontFamily);
    await _compose(doc, family, record: pages);
    return pages;
  }

  /// Nombre del destino de la sección [i], para los enlaces del índice.
  static String _anchor(int i) => 'esc_$i';

  static Future<Uint8List> _compose(
    TechnicalScriptDoc doc,
    PdfFontFamily family, {
    Map<int, int>? record,
    Map<int, int> pages = const {},
  }) async {
    final theme = PdfExportFonts.familyTheme(family);
    final pdf = pw.Document();

    final bodySize = doc.fontSize ?? 8.5;
    final base = pw.TextStyle(
      fontSize: bodySize,
      color: _ink,
      lineSpacing: 1.5,
    );
    final paper = doc.paper == ScriptDocPaper.letter
        ? PdfPageFormat.letter
        : PdfPageFormat.a4;

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
                  font: family.of(bold: span.bold, italic: span.italic),
                  fontWeight: span.bold ? pw.FontWeight.bold : null,
                  fontStyle: span.italic ? pw.FontStyle.italic : null,
                  color: span.textColor == null
                      ? null
                      : _color(kScriptTextColorRgb[span.textColor]!),
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

    // Índice: una línea por escena, con puntos hasta su página; cada línea
    // lleva a su escena.
    pw.Widget indexLine(int i) {
      final style = pw.TextStyle(
        fontSize: 9.5,
        fontWeight: pw.FontWeight.bold,
        color: _ink,
      );
      final page = pages[i];
      return pw.Link(
        destination: _anchor(i),
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(doc.sections[i].indexText, style: style),
              pw.Expanded(
                child: pw.Container(
                  height: 1,
                  margin: const pw.EdgeInsets.only(left: 2, right: 2, bottom: 2.5),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                        color: _ink,
                        width: 0.8,
                        style: pw.BorderStyle.dotted,
                      ),
                    ),
                  ),
                ),
              ),
              pw.SizedBox(
                width: 22,
                child: pw.Text(
                  page == null ? '000' : '$page',
                  textAlign: pw.TextAlign.right,
                  style: style,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Encabezado de escena: destino de su línea del índice y marcador del
    // lector; en la primera pasada apunta en qué página cae.
    pw.Widget heading(int i) {
      final section = doc.sections[i];
      final text = pw.Text(
        section.title,
        style: pw.TextStyle(
          fontSize: 10.5,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      );
      // El Builder se vuelve a montar si la escena salta de página: en la
      // pasada que mide no se crean marcadores, que saldrían repetidos.
      if (record != null) {
        return pw.Builder(
          builder: (context) {
            record[i] = context.pageNumber;
            return text;
          },
        );
      }
      if (!doc.hasIndex) return text;
      return pw.Outline(
        name: _anchor(i),
        title: section.indexText,
        child: text,
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
        pageFormat: doc.landscape ? paper.landscape : paper.portrait,
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
          if (doc.hasIndex) ...[
            pw.Text(
              'ÍNDICE',
              style: const pw.TextStyle(fontSize: 18, color: _ink),
            ),
            pw.SizedBox(height: 6),
            for (var i = 0; i < doc.sections.length; i++) indexLine(i),
            pw.NewPage(),
          ],
          for (final (i, section) in doc.sections.indexed) ...[
            heading(i),
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
                            fontSize: bodySize - 0.5,
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
                          (row.imagesOf(column.key) ?? const []).isNotEmpty
                              ? pw.Column(
                                  mainAxisSize: pw.MainAxisSize.min,
                                  children: [
                                    for (final (i, image)
                                        in row
                                            .imagesOf(column.key)!
                                            .indexed) ...[
                                      if (i > 0) pw.SizedBox(height: 3),
                                      pw.Image(
                                        pw.MemoryImage(image),
                                        fit: pw.BoxFit.contain,
                                        height: 70,
                                      ),
                                    ],
                                  ],
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
