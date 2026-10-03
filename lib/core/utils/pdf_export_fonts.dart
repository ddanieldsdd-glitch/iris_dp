import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fuentes de los PDFs exportados (bundled, sin red).
///
/// Inter es la tipografía de la app. El archivo embebido cubre el alfabeto
/// latino; Noto Sans queda de respaldo para los glifos que le falten.
abstract final class PdfExportFonts {
  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.Font? _fallbackRegular;
  static pw.Font? _fallbackBold;

  static Future<({pw.Font regular, pw.Font bold})> load() async {
    if (_regular != null && _bold != null) {
      return (regular: _regular!, bold: _bold!);
    }
    _regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
    );
    _bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    _fallbackRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    _fallbackBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    return (regular: _regular!, bold: _bold!);
  }

  /// Tema con Inter y Noto Sans de respaldo. Llamar tras [load].
  static pw.ThemeData theme({required pw.Font regular, required pw.Font bold}) =>
      pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: [
          if (_fallbackRegular != null) _fallbackRegular!,
          if (_fallbackBold != null) _fallbackBold!,
        ],
      );

  /// Sustituye glifos que Helvetica/pdf por defecto no dibuja bien.
  static String asciiFallback(String text) => text
      .replaceAll('→', '->')
      .replaceAll('—', '-')
      .replaceAll('–', '-');
}
