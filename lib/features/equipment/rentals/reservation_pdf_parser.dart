import 'pdf_layout_reader.dart';
import 'rental_import_models.dart';

/// Reconstruye una lista de material a partir de las posiciones del texto: la
/// extracción plana mezcla columnas y deja la cantidad en otra línea.
///
/// Todo lo que sigue a «Observaciones» se descarta antes de construir nada:
/// son condiciones legales y una firma con datos personales.
abstract final class ReservationPdfParser {
  static const _rowTolerance = 3.0;

  /// Entre dos filas del mismo bloque hay ~15 pt; entre bloques, más de 18.
  static const _sameBlockGap = 18.0;

  static ParsedReservation parse(List<List<PdfGlyph>> pages) {
    final rawPages = [for (final p in pages) _rows(_dedupe(p))];
    if (rawPages.every((p) => p.isEmpty)) {
      throw const RentalListUnreadable(
        'Este PDF no tiene texto que se pueda leer. Si es un escaneo, pide '
        'la lista en PDF original o en Excel.',
      );
    }
    final footers = _repeatedRows(rawPages);
    final contact = footers.where((t) => t.contains('http')).firstOrNull;
    final kept = <List<_Row>>[];
    var cut = false;
    for (final page in rawPages) {
      if (cut) break;
      final out = <_Row>[];
      for (final r in page) {
        final text = r.text;
        if (RegExp(r'^Observaciones\b', caseSensitive: false).hasMatch(text) ||
            RegExp(
              r'^Condiciones generales',
              caseSensitive: false,
            ).hasMatch(text)) {
          cut = true;
          break;
        }
        if (footers.contains(text) || _pageNumber.hasMatch(text)) continue;
        out.add(r);
      }
      kept.add(out);
    }

    final header = _findTableHeader(kept);
    final metaRows = <_Row>[
      for (final page in kept)
        for (final r in page)
          if (header == null ||
              !identical(r, header.row) && _isBeforeHeader(kept, r, header))
            r,
    ];
    final meta = _Meta.from(metaRows);
    final items = header == null
        ? _parsePlain(kept)
        : _parseTable(kept, header);

    return ParsedReservation(
      number: meta.number,
      externalId: meta.externalId,
      sourceStatus: meta.status,
      documentTitle: meta.title,
      responsible: meta.responsible,
      pickupAt: meta.pickup,
      returnAt: meta.ret,
      suggestedHouse: _guessHouse(contact),
      contact: contact,
      items: items,
      recognizedTable: header != null,
    );
  }

  static final _pageNumber = RegExp(
    r'^P[aá]gina:?\s*\d+\s*/\s*\d+$',
    caseSensitive: false,
  );

  static String? _guessHouse(String? contact) {
    if (contact == null) return null;
    final host = RegExp(r'https?://([^/\s]+)').firstMatch(contact)?.group(1);
    if (host == null) return null;
    if (host.toLowerCase().contains('escac')) return 'ESCAC';
    final parts = host.split('.');
    return parts.length >= 2 ? parts[parts.length - 2].toUpperCase() : null;
  }

  // La negrita simulada dibuja cada letra dos veces, casi en el mismo sitio.
  static List<PdfGlyph> _dedupe(List<PdfGlyph> glyphs) {
    final out = <PdfGlyph>[];
    for (final g in glyphs) {
      final dup = out.any(
        (o) =>
            o.text == g.text &&
            (o.left - g.left).abs() < 1.6 &&
            (o.top - g.top).abs() < _rowTolerance,
      );
      if (!dup) out.add(g);
    }
    return out;
  }

  static List<_Row> _rows(List<PdfGlyph> glyphs) {
    final sorted = [...glyphs]..sort((a, b) => a.top.compareTo(b.top));
    final rows = <_Row>[];
    for (final g in sorted) {
      if (rows.isNotEmpty && (g.top - rows.last.top).abs() <= _rowTolerance) {
        rows.last.glyphs.add(g);
      } else {
        rows.add(_Row(g.top, [g]));
      }
    }
    for (final r in rows) {
      r.glyphs.sort((a, b) => a.left.compareTo(b.left));
    }
    return rows.where((r) => r.text.isNotEmpty).toList();
  }

  /// Las filas que se repiten en más de una página son pie o cabecera.
  static Set<String> _repeatedRows(List<List<_Row>> pages) {
    if (pages.length < 2) return const {};
    final seen = <String, int>{};
    for (final page in pages) {
      for (final t in {for (final r in page) r.text}) {
        seen[t] = (seen[t] ?? 0) + 1;
      }
    }
    return {
      for (final e in seen.entries)
        if (e.value >= 2 && e.key.contains('http')) e.key,
    };
  }

  static _Header? _findTableHeader(List<List<_Row>> pages) {
    for (final page in pages) {
      for (final r in page) {
        final name = _labelLeft(r, 'nombre');
        final qty = _labelLeft(r, 'cantidad');
        if (name != null && qty != null) {
          return _Header(
            row: r,
            nameLeft: name,
            descriptionLeft: _labelLeft(r, 'descripci'),
            lotLeft: _labelLeft(r, 'lote'),
            quantityLeft: qty,
            checkLeft: _labelLeft(r, 'check'),
          );
        }
      }
    }
    return null;
  }

  static double? _labelLeft(_Row row, String label) {
    final letters = row.glyphs;
    final text = letters.map((g) => g.text.toLowerCase()).join();
    final at = text.indexOf(label);
    if (at < 0) return null;
    // Con trozos de más de una letra, hay que buscar qué trozo la contiene.
    var position = 0;
    for (final g in letters) {
      if (position + g.text.length > at) return g.left;
      position += g.text.length;
    }
    return null;
  }

  static bool _isBeforeHeader(List<List<_Row>> pages, _Row r, _Header h) {
    for (final page in pages) {
      for (final x in page) {
        if (identical(x, h.row)) return false;
        if (identical(x, r)) return true;
      }
    }
    return false;
  }

  /// El inicio real de la columna Descripción: su título va centrado, así
  /// que se toma de dónde empieza el texto en las filas.
  static double _descriptionStart(List<_Row> rows, _Header h) {
    final limit = h.lotLeft ?? h.quantityLeft;
    final counts = <int, int>{};
    for (final r in rows) {
      final segments = r.segments(gap: 8);
      for (final s in segments) {
        final x = s.first.left;
        if (x > h.nameLeft + 60 && x < limit - 30) {
          counts[x.round()] = (counts[x.round()] ?? 0) + 1;
        }
      }
    }
    if (counts.isEmpty) return h.descriptionLeft ?? limit;
    final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    // Columna: el x más a la izquierda con casi tantas filas como el mejor.
    final near = counts.entries
        .where((e) => e.value >= best.value * 0.5)
        .map((e) => e.key)
        .reduce((a, b) => a < b ? a : b);
    return near - 1.5;
  }

  static List<ParsedRentalItem> _parseTable(List<List<_Row>> pages, _Header h) {
    final body = <_Row>[];
    final pageStart = <_Row>{};
    var past = false;
    for (final page in pages) {
      var first = true;
      for (final r in page) {
        if (identical(r, h.row)) {
          past = true;
          first = true;
          continue;
        }
        if (!past) continue;
        if (first) pageStart.add(r);
        first = false;
        body.add(r);
      }
    }
    final descriptionStart = _descriptionStart(body, h);
    final descriptionEnd = h.lotLeft ?? h.quantityLeft - 4;

    final items = <ParsedRentalItem>[];
    String? section;
    _Block? block;
    _Row? previous;

    void flush() {
      if (block != null) items.add(block!.build(section));
      block = null;
    }

    for (final r in body) {
      final text = r.text;
      final prev = previous;
      final gap = prev == null || pageStart.contains(r)
          ? double.infinity
          : r.top - prev.top;
      previous = r;
      if (RegExp(r'^Subtotal\b', caseSensitive: false).hasMatch(text)) {
        flush();
        continue;
      }
      final name = r.textIn(0, descriptionStart);
      final description = r.textIn(descriptionStart, descriptionEnd);
      final quantity = _parseQuantity(
        r.textIn(descriptionEnd, h.checkLeft ?? double.infinity),
      );
      final full =
          r.rightIn(descriptionStart, descriptionEnd) > descriptionEnd - 28;

      if (quantity != null && name.isNotEmpty) {
        flush();
        block = _Block(name, quantity);
        if (description.isNotEmpty) block!.addDescription(description, full);
        continue;
      }
      if (name.isEmpty) {
        if (description.isNotEmpty) block?.addDescription(description, full);
        continue;
      }
      // Sin cantidad y con nombre: sigue el nombre, o sección, o nota.
      if (gap <= _sameBlockGap && block != null && !block!.isNote) {
        block!.nameParts.add(name);
        if (description.isNotEmpty) block!.addDescription(description, full);
        continue;
      }
      if (description.isEmpty && _isAllCaps(name)) {
        flush();
        section = name;
        continue;
      }
      if (block != null && pageStart.contains(r)) {
        // Fila partida entre dos páginas.
        block!.nameParts.add(name);
        if (description.isNotEmpty) block!.addDescription(description, full);
        continue;
      }
      flush();
      items.add(
        ParsedRentalItem(
          kind: 'note',
          section: section,
          name: name,
          rawText: name,
        ),
      );
    }
    flush();
    return items;
  }

  static List<ParsedRentalItem> _parsePlain(List<List<_Row>> pages) {
    final out = <ParsedRentalItem>[];
    for (final page in pages) {
      for (final r in page) {
        final line = _QuantityLine.parse(r.text);
        out.add(
          ParsedRentalItem(
            name: line.name,
            quantity: line.quantity,
            quantityCertain: false,
            rawText: r.text,
          ),
        );
      }
    }
    return out;
  }

  static double? _parseQuantity(String text) {
    final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*$').firstMatch(text.trim());
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }

  static bool _isAllCaps(String text) {
    final letters = text.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
    return letters.isNotEmpty && letters == letters.toUpperCase();
  }
}

class _Row {
  final double top;
  final List<PdfGlyph> glyphs;

  _Row(this.top, this.glyphs);

  static String _join(Iterable<PdfGlyph> glyphs) {
    final b = StringBuffer();
    PdfGlyph? prev;
    for (final g in glyphs) {
      if (prev != null && g.left - prev.right > 2.5) {
        final last = b.toString();
        if (!last.endsWith(' ') && g.text.trim().isNotEmpty) b.write(' ');
      }
      b.write(g.text);
      prev = g;
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String get text => _join(glyphs);

  String textIn(double from, double to) => _join(
    glyphs.where((g) {
      final center = (g.left + g.right) / 2;
      return center >= from && center < to;
    }),
  );

  double rightIn(double from, double to) {
    var right = from;
    for (final g in glyphs) {
      final center = (g.left + g.right) / 2;
      if (center >= from && center < to && g.right > right) right = g.right;
    }
    return right;
  }

  List<List<PdfGlyph>> segments({required double gap}) {
    final out = <List<PdfGlyph>>[];
    for (final g in glyphs) {
      if (g.text.trim().isEmpty) continue;
      if (out.isEmpty || g.left - out.last.last.right > gap) {
        out.add([g]);
      } else {
        out.last.add(g);
      }
    }
    return out;
  }
}

class _Header {
  final _Row row;
  final double nameLeft;
  final double? descriptionLeft;
  final double? lotLeft;
  final double quantityLeft;
  final double? checkLeft;

  _Header({
    required this.row,
    required this.nameLeft,
    required this.descriptionLeft,
    required this.lotLeft,
    required this.quantityLeft,
    required this.checkLeft,
  });
}

class _Meta {
  String? number, externalId, status, title, responsible, pickup, ret;

  _Meta.from(List<_Row> rows) {
    for (var i = 0; i < rows.length; i++) {
      final t = rows[i].text;
      number ??= _first(r'RESERVA:\s*(\S+)', t);
      externalId ??= _first(r'\bID:\s*([\d.]+)', t);
      status ??= _first(r'Estado:\s*(\S+)', t);
      responsible ??= _first(r'^Responsable:?\s+(.+)$', t);
      pickup ??= _date(_first(r'Recogida:?\s*([\d/\-]+\s+[\d:]+)', t));
      ret ??= _date(_first(r'Devoluci[oó]n:?\s*([\d/\-]+\s+[\d:]+)', t));
      if (title == null && t.contains('RESERVA') && i + 1 < rows.length) {
        title = rows[i + 1].text;
      }
    }
  }

  static String? _first(String pattern, String text) =>
      RegExp(pattern, caseSensitive: false).firstMatch(text)?.group(1)?.trim();

  static String? _date(String? raw) {
    if (raw == null) return null;
    final m = RegExp(
      r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})\s+(\d{1,2}):(\d{2})',
    ).firstMatch(raw);
    if (m == null) return null;
    String two(int i) => m.group(i)!.padLeft(2, '0');
    return '${m.group(3)}-${two(2)}-${two(1)}T${two(4)}:${two(5)}';
  }
}

class _Block {
  final List<String> nameParts;
  final double? quantity;
  final List<String> description = [];

  /// Índices de las líneas que llegan al borde de la columna: la siguiente
  /// puede ser su continuación.
  final Set<int> fullLines = {};

  void addDescription(String line, bool full) {
    if (full) fullLines.add(description.length);
    description.add(line);
  }

  _Block(String name, this.quantity) : nameParts = [name];

  bool get isNote => false;

  ParsedRentalItem build(String? section) {
    final name = nameParts
        .join(' ')
        // «V-» + «LOCK»: la columna partió la palabra por el guion.
        .replaceAllMapped(RegExp(r'(\S)- (\S)'), (m) => '${m[1]}-${m[2]}');
    return ParsedRentalItem(
      section: section,
      name: name,
      quantity: quantity,
      quantityCertain: quantity != null,
      rawText: [name, ...description].join('\n'),
      children: _DescriptionParser.parse(description, fullLines, section),
    );
  }
}

class _QuantityLine {
  final String name;
  final double? quantity;
  final bool marked;

  const _QuantityLine(this.name, this.quantity, this.marked);

  // «1x Foo», «1 x Foo», «1X Foo», pero no «4x4 Foo».
  static final _leading = RegExp(
    r'^[-•]?\s*(\d+)\s*[xX]\s*(?=[\p{L}(])(.+)$',
    unicode: true,
  );
  static final _xFirst = RegExp(r'^[-•]?\s*[xX]\s*(\d+)\s+(.+)$');
  static final _trailing = RegExp(r'^[-•]?\s*(.+?)\s*\([xX]\s*(\d+)\)\s*$');

  static _QuantityLine parse(String line) {
    final t = line.trim();
    if (_leading.firstMatch(t) case final m?) {
      return _QuantityLine(m.group(2)!.trim(), double.parse(m.group(1)!), true);
    }
    if (_xFirst.firstMatch(t) case final m?) {
      return _QuantityLine(m.group(2)!.trim(), double.parse(m.group(1)!), true);
    }
    if (_trailing.firstMatch(t) case final m?) {
      return _QuantityLine(m.group(1)!.trim(), double.parse(m.group(2)!), true);
    }
    return _QuantityLine(t.replaceFirst(RegExp(r'^[-•]\s*'), ''), null, false);
  }
}

abstract final class _DescriptionParser {
  static final _serial = RegExp(
    r'[\[(]?\bn[º°o]\.?\s*(?:de\s+)?(?:serie\s*)?([A-Za-z0-9][A-Za-z0-9.\-]{3,})[\])]?',
    caseSensitive: false,
  );
  static final _missing = RegExp(
    r'\(?LES FALTA:\s*([^)]*)\)?',
    caseSensitive: false,
  );

  static bool _isLabel(String line) =>
      line.endsWith(':') ||
      RegExp(r'^Maleta\b', caseSensitive: false).hasMatch(line);

  static bool _isSeparator(String line) => RegExp(r'^-{3,}$').hasMatch(line);

  static List<ParsedRentalItem> parse(
    List<String> lines,
    Set<int> fullLines,
    String? section,
  ) {
    final content = [
      for (final l in lines)
        if (!_isSeparator(l) && !_isLabel(l)) l,
    ];
    final marked = content.where((l) => _QuantityLine.parse(l).marked).length;
    // Si casi todas llevan cantidad, una línea sin ella continúa la anterior.
    final continues = content.isNotEmpty && marked * 2 >= content.length;

    final merged = <({String text, String? group})>[];
    String? group;
    for (final (index, line) in lines.indexed) {
      if (_isSeparator(line)) {
        group = null;
        continue;
      }
      if (_isLabel(line)) {
        group = line.replaceFirst(RegExp(r':\s*$'), '').trim();
        continue;
      }
      final continuation =
          !_QuantityLine.parse(line).marked &&
          (continues || fullLines.contains(index - 1));
      if (continuation && merged.isNotEmpty) {
        final last = merged.removeLast();
        merged.add((text: '${last.text} $line', group: last.group));
        continue;
      }
      merged.add((text: line, group: group));
    }

    return [for (final m in merged) _item(m.text, m.group, section)];
  }

  static ParsedRentalItem _item(String text, String? group, String? section) {
    final line = _QuantityLine.parse(text);
    var name = line.name;
    String? note;
    if (_missing.firstMatch(name) case final m?) {
      note = 'Falta: ${m.group(1)!.trim()}';
      name = name.replaceRange(m.start, m.end, '').trim();
    }
    String? serial;
    if (_serial.firstMatch(name) case final m?) {
      serial = m.group(1);
      name = name.replaceRange(m.start, m.end, '').trim();
    }
    name = name
        .replaceAll(RegExp(r'\(\s*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return ParsedRentalItem(
      section: section,
      groupLabel: group,
      name: name,
      quantity: line.quantity,
      serial: serial,
      note: note,
      rawText: text,
    );
  }
}
