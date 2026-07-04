/// Normaliza y prepara el texto del guion para lectura en pantalla.
class ScriptTextFormatter {
  ScriptTextFormatter._();

  static String forDisplay(String raw) {
    var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Separar sluglines pegadas en PDF (EXT. LUGAR - NOCHE texto...)
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\n.])((?:INT\.?\/EXT\.?|EXT\.?\/INT\.?|INT\.?|EXT\.?|INTERIOR|EXTERIOR)\.?\s+[^\n]{4,80}?\s*[-–—,]\s*(?:DÍA|DIA|DAY|NOCHE|NIGHT|AMANECER|ATARDECER|CONTINUO))',
        caseSensitive: false,
      ),
      (m) => '\n${m.group(1)!.trim()}',
    );

    // Colapsar espacios horizontales excesivos pero conservar saltos de línea
    text = text.split('\n').map((line) => line.trimRight()).join('\n');

    // Máximo 2 líneas en blanco seguidas
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  static final sluglinePattern = RegExp(
    r'^(INT\.?\/EXT\.?|EXT\.?\/INT\.?|INT\.?|EXT\.?|I\/E\.?|INTERIOR\/EXTERIOR|INTERIOR|EXTERIOR)\s+.+$',
    caseSensitive: false,
  );

  static bool isSlugline(String line) {
    final t = line.trim();
    if (t.isEmpty) return false;
    return sluglinePattern.hasMatch(t);
  }
}
