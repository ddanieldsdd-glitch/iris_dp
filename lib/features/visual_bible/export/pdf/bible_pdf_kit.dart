import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../shared/visual_bible/bible_section_fields.dart';

/// Tokens visuales del PDF de la biblia. Claro e imprimible.
abstract final class BiblePdfTokens {
  static const ink = PdfColor.fromInt(0xFF111113);
  static const secondary = PdfColor.fromInt(0xFF4A4F59);
  static const tertiary = PdfColor.fromInt(0xFF8A919E);
  static const rule = PdfColor.fromInt(0xFFE3E5EA);
  static const panel = PdfColor.fromInt(0xFFF5F6F8);
  static const accent = PdfColor.fromInt(0xFF0A84FF);

  static const double pageMargin = 40;
  static const double gap = 14;
  static const double radius = 6;
}

/// Componentes del PDF de la biblia: uno por tipo de punto.
///
/// Es el equivalente en PDF de `BiblePointPanel` y `BibleGenericPointView`.
class BiblePdfKit {
  final pw.Font regular;
  final pw.Font bold;

  const BiblePdfKit({required this.regular, required this.bold});

  pw.TextStyle get body => pw.TextStyle(
        font: regular,
        fontSize: 11,
        lineSpacing: 4,
        color: BiblePdfTokens.ink,
      );

  pw.Widget sectionHeader(String title) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(height: 3, width: 32, color: BiblePdfTokens.accent),
          pw.SizedBox(height: 8),
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              font: bold,
              fontSize: 11,
              letterSpacing: 3,
              color: BiblePdfTokens.tertiary,
            ),
          ),
        ],
      );

  pw.Widget label(String text) => pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
          font: bold,
          fontSize: 8,
          letterSpacing: 1,
          color: BiblePdfTokens.tertiary,
        ),
      );

  pw.Widget chip(String label, String value) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: BiblePdfTokens.panel,
          borderRadius: pw.BorderRadius.circular(BiblePdfTokens.radius),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                font: regular,
                fontSize: 7,
                color: BiblePdfTokens.tertiary,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: bold,
                fontSize: 11,
                color: BiblePdfTokens.ink,
              ),
            ),
          ],
        ),
      );

  /// Punto de texto: rótulo y párrafo.
  pw.Widget textPoint(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            this.label(label),
            pw.SizedBox(height: 4),
            pw.Text(value, style: body),
          ],
        ),
      );

  /// Punto de lista: rótulo y viñetas.
  pw.Widget listPoint(String label, List<String> items) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            this.label(label),
            pw.SizedBox(height: 4),
            for (final item in items)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 3,
                      height: 3,
                      margin: const pw.EdgeInsets.only(top: 5, right: 7),
                      decoration: const pw.BoxDecoration(
                        color: BiblePdfTokens.accent,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.Expanded(child: pw.Text(item, style: body)),
                  ],
                ),
              ),
          ],
        ),
      );

  /// Punto de datos técnicos: rótulo y tabla etiqueta/valor.
  pw.Widget specsPoint(String label, List<(String, String)> rows) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            this.label(label),
            pw.SizedBox(height: 4),
            for (final (name, value) in rows)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(
                      color: BiblePdfTokens.rule,
                      width: 0.5,
                    ),
                  ),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        name.toUpperCase(),
                        style: pw.TextStyle(
                          font: regular,
                          fontSize: 8,
                          letterSpacing: 0.6,
                          color: BiblePdfTokens.secondary,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        value,
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 10,
                          color: BiblePdfTokens.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  /// Fila de imágenes adjuntas a un punto.
  pw.Widget imageRow(List<pw.MemoryImage> images) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: BiblePdfTokens.gap),
        child: pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final image in images)
              pw.ClipRRect(
                horizontalRadius: BiblePdfTokens.radius,
                verticalRadius: BiblePdfTokens.radius,
                child: pw.Image(image, height: 110, fit: pw.BoxFit.cover),
              ),
          ],
        ),
      );

  /// Pinta un punto según su tipo. `null` si no tiene contenido.
  pw.Widget? point(BibleSectionField field, String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    switch (field.type) {
      case BibleSectionFieldType.list:
        final items = BibleSectionPointValue.decodeList(raw)
            .where((e) => e.trim().isNotEmpty)
            .toList();
        return items.isEmpty ? null : listPoint(field.label, items);
      case BibleSectionFieldType.specs:
        final rows = BibleSectionPointValue.decodeSpecs(raw)
            .where((r) => r.$1.trim().isNotEmpty || r.$2.trim().isNotEmpty)
            .toList();
        return rows.isEmpty ? null : specsPoint(field.label, rows);
      default:
        return textPoint(field.label, raw.trim());
    }
  }
}
