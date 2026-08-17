import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fuentes con soporte Unicode para PDFs exportados (bundled, sin red).
abstract final class PdfExportFonts {
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<({pw.Font regular, pw.Font bold})> load() async {
    if (_regular != null && _bold != null) {
      return (regular: _regular!, bold: _bold!);
    }
    _regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    _bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    return (regular: _regular!, bold: _bold!);
  }

  static pw.ThemeData theme({required pw.Font regular, required pw.Font bold}) =>
      pw.ThemeData.withFont(base: regular, bold: bold);

  /// Sustituye glifos que Helvetica/pdf por defecto no dibuja bien.
  static String asciiFallback(String text) => text
      .replaceAll('→', '->')
      .replaceAll('—', '-')
      .replaceAll('–', '-');
}
