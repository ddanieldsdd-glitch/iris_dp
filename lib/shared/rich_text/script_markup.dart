/// Formato de texto del guion técnico: negrita, cursiva, subrayado y
/// marcador de color, guardados en el propio texto con marcas ligeras.
///
/// - `**negrita**`
/// - `*cursiva*`
/// - `__subrayado__`
/// - `==marcado==` (amarillo) o `==g:marcado==` con otro color
///
/// Una marca sin su pareja se deja como texto normal. Código puro.
library;

/// Colores del marcador: letra de la marca → nombre.
const kScriptMarkerColors = {
  'y': 'Amarillo',
  'g': 'Verde',
  'p': 'Rosa',
  'b': 'Azul',
};

enum ScriptMark { bold, italic, underline, marker }

/// Trozo de texto con su formato.
class ScriptSpan {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;

  /// Letra del color del marcador, o nulo si no va marcado.
  final String? marker;

  /// Es una marca (`**`, `==g:`…), no contenido: se oculta al leer y se
  /// atenúa al escribir.
  final bool isMarkup;

  const ScriptSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.marker,
    this.isMarkup = false,
  });

  bool get isPlain => !bold && !italic && !underline && marker == null;

  @override
  String toString() =>
      'ScriptSpan("$text"${bold ? ' b' : ''}${italic ? ' i' : ''}'
      '${underline ? ' u' : ''}${marker != null ? ' m:$marker' : ''}'
      '${isMarkup ? ' markup' : ''})';
}

class _Style {
  final bool bold;
  final bool italic;
  final bool underline;
  final String? marker;

  const _Style({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.marker,
  });
}

// El orden importa: `**` antes que `*`.
final _pattern = RegExp(
  r'\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|==(?:([ygpb]):)?(.+?)==',
  dotAll: true,
);

/// Trocea [text] según sus marcas. Con [keepMarkup] las marcas salen como
/// trozos propios (para pintarlas atenuadas mientras se escribe); sin él,
/// solo el contenido.
List<ScriptSpan> parseScriptMarkup(String text, {bool keepMarkup = false}) {
  final out = <ScriptSpan>[];

  void emit(String value, _Style style, {bool markup = false}) {
    if (value.isEmpty) return;
    if (markup && !keepMarkup) return;
    out.add(
      ScriptSpan(
        value,
        bold: style.bold,
        italic: style.italic,
        underline: style.underline,
        marker: style.marker,
        isMarkup: markup,
      ),
    );
  }

  void walk(String value, _Style style) {
    var index = 0;
    for (final match in _pattern.allMatches(value)) {
      emit(value.substring(index, match.start), style);
      final String open;
      final String close;
      final String inner;
      final _Style next;
      if (match.group(1) != null) {
        open = close = '**';
        inner = match.group(1)!;
        next = _Style(
          bold: true,
          italic: style.italic,
          underline: style.underline,
          marker: style.marker,
        );
      } else if (match.group(2) != null) {
        open = close = '__';
        inner = match.group(2)!;
        next = _Style(
          bold: style.bold,
          italic: style.italic,
          underline: true,
          marker: style.marker,
        );
      } else if (match.group(3) != null) {
        open = close = '*';
        inner = match.group(3)!;
        next = _Style(
          bold: style.bold,
          italic: true,
          underline: style.underline,
          marker: style.marker,
        );
      } else {
        final color = match.group(4);
        open = color == null ? '==' : '==$color:';
        close = '==';
        inner = match.group(5)!;
        next = _Style(
          bold: style.bold,
          italic: style.italic,
          underline: style.underline,
          marker: color ?? 'y',
        );
      }
      emit(open, next, markup: true);
      walk(inner, next);
      emit(close, next, markup: true);
      index = match.end;
    }
    emit(value.substring(index), style);
  }

  walk(text, const _Style());
  return out;
}

/// El texto sin marcas, para donde no hay formato (storyboard, planta…).
String scriptMarkupToPlain(String? text) {
  if (text == null || text.isEmpty) return text ?? '';
  return parseScriptMarkup(text).map((s) => s.text).join();
}

/// Posición en el texto con marcas que corresponde a la posición [plain]
/// del texto visible (para poner el cursor donde se hizo clic).
int scriptRawOffsetForPlain(String text, int plain) {
  var seen = 0;
  var raw = 0;
  for (final span in parseScriptMarkup(text, keepMarkup: true)) {
    if (!span.isMarkup) {
      if (plain <= seen + span.text.length) return raw + (plain - seen);
      seen += span.text.length;
    }
    raw += span.text.length;
  }
  return text.length;
}

String _open(ScriptMark mark, String? color) => switch (mark) {
  ScriptMark.bold => '**',
  ScriptMark.italic => '*',
  ScriptMark.underline => '__',
  ScriptMark.marker => color == null || color == 'y' ? '==' : '==$color:',
};

String _close(ScriptMark mark) => switch (mark) {
  ScriptMark.bold => '**',
  ScriptMark.italic => '*',
  ScriptMark.underline => '__',
  ScriptMark.marker => '==',
};

/// Resultado de aplicar un formato: el texto y la selección que queda.
typedef ScriptMarkupEdit = ({String text, int start, int end});

/// Pone o quita [mark] en la selección [start]–[end] de [text]. Si la
/// selección ya lo lleva justo alrededor (dentro o fuera de ella), lo quita.
/// Para el marcador, [color] nulo lo quita siempre.
ScriptMarkupEdit toggleScriptMarkup(
  String text,
  int start,
  int end,
  ScriptMark mark, {
  String? color,
}) {
  if (start > end) {
    final swap = start;
    start = end;
    end = swap;
  }
  start = start.clamp(0, text.length);
  end = end.clamp(0, text.length);
  if (start == end) return (text: text, start: start, end: end);

  final close = _close(mark);
  final opens = mark == ScriptMark.marker
      ? ['==', for (final c in kScriptMarkerColors.keys) '==$c:']
      : [_open(mark, null)];
  // Las más largas primero: `==g:` antes que `==`.
  opens.sort((a, b) => b.length.compareTo(a.length));

  final selected = text.substring(start, end);

  // Marcas justo fuera de la selección.
  for (final open in opens) {
    if (start >= open.length &&
        text.substring(start - open.length, start) == open &&
        text.startsWith(close, end)) {
      final without =
          text.substring(0, start - open.length) +
          selected +
          text.substring(end + close.length);
      final newStart = start - open.length;
      if (mark == ScriptMark.marker &&
          color != null &&
          _open(mark, color) != open) {
        return toggleScriptMarkup(
          without,
          newStart,
          newStart + selected.length,
          mark,
          color: color,
        );
      }
      return (text: without, start: newStart, end: newStart + selected.length);
    }
  }

  // Marcas dentro de la selección.
  for (final open in opens) {
    if (selected.length >= open.length + close.length &&
        selected.startsWith(open) &&
        selected.endsWith(close)) {
      final inner = selected.substring(
        open.length,
        selected.length - close.length,
      );
      final without = text.substring(0, start) + inner + text.substring(end);
      if (mark == ScriptMark.marker &&
          color != null &&
          _open(mark, color) != open) {
        return toggleScriptMarkup(
          without,
          start,
          start + inner.length,
          mark,
          color: color,
        );
      }
      return (text: without, start: start, end: start + inner.length);
    }
  }

  if (mark == ScriptMark.marker && color == null) {
    return (text: text, start: start, end: end);
  }

  final open = _open(mark, color);
  final wrapped =
      text.substring(0, start) + open + selected + close + text.substring(end);
  return (
    text: wrapped,
    start: start + open.length,
    end: start + open.length + selected.length,
  );
}
