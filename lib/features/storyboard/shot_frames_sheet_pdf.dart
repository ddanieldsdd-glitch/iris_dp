import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/pdf_export_fonts.dart';
import 'shot_export_layout.dart';
import 'shot_sheet_data.dart';

/// Un encuadre ya cargado, con su rótulo («Antes del movimiento»).
class ShotSheetFrame {
  final Uint8List bytes;
  final String label;

  const ShotSheetFrame({required this.bytes, required this.label});
}

/// Hoja de un plano con sus imágenes: los encuadres en orden y del mismo
/// tamaño (en un movimiento, el de antes y el de después; en una secuencia,
/// sus partes) y, debajo y más pequeños, los refuerzos.
abstract final class ShotFramesSheetPdf {
  static const _page = PdfPageFormat(842, 595);
  static const _margin = 28.0;
  static const _gap = 18.0;
  static const _accent = PdfColor.fromInt(0xFFF5A300);
  static const _ink = PdfColor.fromInt(0xFF1A1A1A);
  static const _muted = PdfColor.fromInt(0xFF6B6B6B);

  static Future<Uint8List> buildBytes({
    required ShotSheetData data,
    required ShotLayoutKind kind,
    required List<ShotSheetFrame> frames,
    required List<Uint8List> support,
  }) async {
    final fonts = await PdfExportFonts.load();
    final theme = PdfExportFonts.theme(
      regular: fonts.regular,
      bold: fonts.bold,
    );
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        theme: theme,
        pageFormat: _page,
        margin: const pw.EdgeInsets.all(_margin),
        build: (_) => _body(data, kind, frames, support),
      ),
    );
    return doc.save();
  }

  /// Proporción ancho / alto de una imagen; 16:9 si no se sabe.
  static double _aspect(Uint8List bytes) {
    try {
      final image = pw.MemoryImage(bytes);
      final w = image.width;
      final h = image.height;
      if (w != null && h != null && w > 0 && h > 0) return w / h;
    } catch (_) {}
    return 16 / 9;
  }

  static pw.Widget _body(
    ShotSheetData data,
    ShotLayoutKind kind,
    List<ShotSheetFrame> frames,
    List<Uint8List> support,
  ) {
    final width = _page.width - 2 * _margin;
    final text = [
      if (data.action != null) ('Acción', data.action!),
      if (data.notes != null) ('Notas', data.notes!),
    ];
    // Alto para los encuadres: lo que dejan la cabecera, los refuerzos y el
    // texto de abajo.
    final supportHeight = support.isEmpty ? 0.0 : 96.0;
    final textHeight = text.isEmpty ? 0.0 : 64.0;
    final framesHeight =
        _page.height -
        2 * _margin -
        58 -
        (supportHeight == 0 ? 0 : supportHeight + 30) -
        textHeight;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _header(data),
        pw.SizedBox(height: 14),
        pw.SizedBox(
          height: framesHeight,
          child: frames.isEmpty
              ? pw.Center(
                  child: pw.Text(
                    'Plano ${data.shotNumber} sin encuadres elegidos',
                    style: const pw.TextStyle(color: _muted, fontSize: 12),
                  ),
                )
              : _frames(kind, frames, width, framesHeight),
        ),
        if (support.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text(
            'REFUERZO',
            style: pw.TextStyle(
              fontSize: 7.5,
              letterSpacing: 1.2,
              color: _muted,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.SizedBox(
            height: supportHeight,
            child: pw.Row(
              children: [
                for (final bytes in support.take(8)) ...[
                  pw.Container(
                    width: supportHeight * _aspect(bytes).clamp(0.5, 2.4),
                    height: supportHeight,
                    child: pw.Image(
                      pw.MemoryImage(bytes),
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
        if (text.isNotEmpty) ...[
          pw.Spacer(),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final (title, body) in text)
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 16),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          title.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            letterSpacing: 1.2,
                            color: _muted,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          body,
                          maxLines: 3,
                          style: const pw.TextStyle(fontSize: 9, color: _ink),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  static pw.Widget _header(ShotSheetData data) {
    final meta = [
      data.framing,
      data.lens,
      data.angle,
      data.movement,
    ].whereType<String>().join(' · ');
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: _accent,
          child: pw.Text(
            '${data.sceneNumber}·${data.shotNumber}',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${data.projectName.toUpperCase()}  ·  ESCENA '
                '${data.sceneNumber}  ·  PLANO ${data.shotNumber}',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                data.sceneSlug,
                maxLines: 1,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
        if (meta.isNotEmpty)
          pw.ConstrainedBox(
            constraints: const pw.BoxConstraints(maxWidth: 330),
            child: pw.Text(
              meta,
              maxLines: 2,
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 9, color: _ink),
            ),
          ),
      ],
    );
  }

  /// Los encuadres, todos del mismo tamaño: en una fila si caben; si son
  /// muchos, en dos.
  static pw.Widget _frames(
    ShotLayoutKind kind,
    List<ShotSheetFrame> frames,
    double width,
    double height,
  ) {
    final n = frames.length;
    final rows = n <= 3 ? 1 : 2;
    final perRow = (n / rows).ceil();
    // Una proporción común (la del primero) para que midan lo mismo.
    final aspect = _aspect(frames.first.bytes).clamp(0.6, 2.6);
    const labelHeight = 16.0;
    final cellHeight = (height - (rows - 1) * _gap) / rows - labelHeight;
    var w = (width - (perRow - 1) * _gap) / perRow;
    var h = w / aspect;
    if (h > cellHeight) {
      h = cellHeight;
      w = h * aspect;
    }
    final arrows = kind != ShotLayoutKind.single;

    pw.Widget cell(int i) {
      final frame = frames[i];
      return pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            height: labelHeight,
            child: frame.label.isEmpty
                ? null
                : pw.Text(
                    '${i + 1}.  ${frame.label}',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
          ),
          pw.Container(
            width: w,
            height: h,
            color: PdfColors.grey200,
            child: pw.Image(pw.MemoryImage(frame.bytes), fit: pw.BoxFit.cover),
          ),
        ],
      );
    }

    pw.Widget arrow() => pw.SizedBox(
      width: _gap,
      height: h,
      child: pw.Center(
        child: pw.Text(
          arrows ? '›' : '',
          style: pw.TextStyle(
            fontSize: 18,
            color: _accent,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );

    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) pw.SizedBox(height: _gap),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              for (
                var i = r * perRow;
                i < math.min(n, (r + 1) * perRow);
                i++
              ) ...[if (i > r * perRow) arrow(), cell(i)],
            ],
          ),
        ],
      ],
    );
  }
}
