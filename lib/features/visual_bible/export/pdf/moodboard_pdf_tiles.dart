import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/pdf_export_fonts.dart';

/// Maquetación compartida de stills moodboard en PDF (clásico + compositor).
abstract final class MoodboardPdfTiles {
  static const PdfColor neutralBackground = PdfColor.fromInt(0xFFF2F2F7);
  static const PdfColor detailColor = PdfColor.fromInt(0xFF636366);
  static const PdfColor accentBar = PdfColor.fromInt(0xFF0A84FF);

  /// Encabezado de faceta (MOODBOARD · LUZ) con barra azul como otras secciones.
  static pw.Widget facetSectionHeader({
    required String facetLabel,
    required pw.Font bold,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 4),
        pw.Container(height: 3, width: 32, color: accentBar),
        pw.SizedBox(height: 8),
        pw.Text(
          'MOODBOARD · ${PdfExportFonts.asciiFallback(facetLabel).toUpperCase()}',
          style: pw.TextStyle(
            font: bold,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  /// Layout plano con reflow entre páginas (mismo mecanismo que wrap por faceta).
  static pw.Widget flatGrid({
    required List<pw.Widget> tiles,
    double spacing = 6,
    double runSpacing = 6,
  }) =>
      pw.Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: tiles,
      );

  static List<pw.Widget> captionWidgets({
    required String? caption,
    required List<String> details,
    pw.Font? font,
    double fontSize = 7,
    int detailLimit = 2,
    double? maxWidth,
  }) {
    final widgets = <pw.Widget>[];
    if (caption != null && caption.trim().isNotEmpty) {
      widgets.add(pw.SizedBox(height: 3));
      widgets.add(
        _boundedText(
          maxWidth: maxWidth,
          child: pw.Text(
            PdfExportFonts.asciiFallback(caption.trim()),
            style: pw.TextStyle(font: font, fontSize: fontSize),
            maxLines: 2,
          ),
        ),
      );
    }
    for (final line in details.take(detailLimit)) {
      widgets.add(pw.SizedBox(height: 2));
      widgets.add(
        _boundedText(
          maxWidth: maxWidth,
          child: pw.Text(
            PdfExportFonts.asciiFallback(line),
            style: pw.TextStyle(
              font: font,
              fontSize: fontSize - 0.5,
              color: detailColor,
            ),
            maxLines: 2,
          ),
        ),
      );
    }
    return widgets;
  }

  static pw.Widget tileColumn({
    required pw.ImageProvider image,
    pw.Font? font,
    String? caption,
    List<String> details = const [],
    double? tileWidth = 175,
    double imageHeight = 120,
    double fontSize = 7,
    int detailLimit = 2,
  }) {
    final column = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          height: imageHeight,
          color: neutralBackground,
          alignment: pw.Alignment.center,
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
        ...captionWidgets(
          caption: caption,
          details: details,
          font: font,
          fontSize: fontSize,
          detailLimit: detailLimit,
          maxWidth: tileWidth,
        ),
      ],
    );
    if (tileWidth == null) return column;
    return pw.Container(width: tileWidth, child: column);
  }

  static pw.Widget wrap({
    required List<pw.Widget> tiles,
    double spacing = 6,
  }) =>
      pw.Wrap(spacing: spacing, runSpacing: spacing, children: tiles);

  static pw.Widget _boundedText({
    required pw.Widget child,
    double? maxWidth,
  }) {
    if (maxWidth == null) return child;
    return pw.SizedBox(width: maxWidth, child: child);
  }
}
