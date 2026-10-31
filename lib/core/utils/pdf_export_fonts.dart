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

  static final _families = <String, PdfFontFamily>{};

  /// Archivo base de cada tipografía de la hoja del guion técnico.
  static const _familyFiles = {
    'Inter': 'Inter',
    'Noto Sans': 'NotoSans',
    'Tinos': 'Tinos',
  };

  /// Las cuatro variantes de una tipografía de la hoja (Inter si no se
  /// conoce), para que el PDF salga con la misma letra que la pantalla,
  /// también en cursiva.
  static Future<PdfFontFamily> loadFamily(String family) async {
    await load();
    final file = _familyFiles[family] ?? 'Inter';
    final cached = _families[file];
    if (cached != null) return cached;
    Future<pw.Font> font(String variant) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$file-$variant.ttf'));
    return _families[file] = PdfFontFamily(
      regular: await font('Regular'),
      bold: await font('Bold'),
      italic: await font('Italic'),
      boldItalic: await font('BoldItalic'),
    );
  }

  /// Tema con Inter y Noto Sans de respaldo. Llamar tras [load].
  static pw.ThemeData theme({
    required pw.Font regular,
    required pw.Font bold,
    pw.Font? italic,
    pw.Font? boldItalic,
  }) => pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        italic: italic,
        boldItalic: boldItalic,
        fontFallback: [
          if (_fallbackRegular != null) _fallbackRegular!,
          if (_fallbackBold != null) _fallbackBold!,
        ],
      );

  /// Tema con las cuatro variantes de [family].
  static pw.ThemeData familyTheme(PdfFontFamily family) => theme(
    regular: family.regular,
    bold: family.bold,
    italic: family.italic,
    boldItalic: family.boldItalic,
  );

  /// Sustituye glifos que Helvetica/pdf por defecto no dibuja bien.
  static String asciiFallback(String text) => text
      .replaceAll('→', '->')
      .replaceAll('—', '-')
      .replaceAll('–', '-');
}

/// Una tipografía con sus cuatro variantes.
class PdfFontFamily {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font italic;
  final pw.Font boldItalic;

  const PdfFontFamily({
    required this.regular,
    required this.bold,
    required this.italic,
    required this.boldItalic,
  });

  pw.Font of({bool bold = false, bool italic = false}) => italic
      ? (bold ? boldItalic : this.italic)
      : (bold ? this.bold : regular);
}
