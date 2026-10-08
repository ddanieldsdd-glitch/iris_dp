import 'dart:convert';

/// Valor de un punto «Texto con datos»: un desarrollo y, debajo, pares de
/// dato y valor. Lee también el formato de «Datos técnicos» (solo filas).
class BibleTextSpecsValue {
  final String text;
  final List<(String, String)> rows;

  const BibleTextSpecsValue({this.text = '', this.rows = const []});

  static List<(String, String)> _rows(Object? raw) => [
    if (raw is List)
      for (final e in raw)
        if (e is Map)
          (e['label']?.toString() ?? '', e['value']?.toString() ?? ''),
  ];

  factory BibleTextSpecsValue.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const BibleTextSpecsValue();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return BibleTextSpecsValue(rows: _rows(decoded));
      if (decoded is Map) {
        return BibleTextSpecsValue(
          text: decoded['text']?.toString() ?? '',
          rows: _rows(decoded['rows']),
        );
      }
    } catch (_) {}
    return BibleTextSpecsValue(text: raw);
  }

  /// Filas con valor escrito: las que salen en el PDF.
  List<(String, String)> get filledRows => [
    for (final row in rows)
      if (row.$2.trim().isNotEmpty) row,
  ];

  bool get isEmpty => text.trim().isEmpty && filledRows.isEmpty;

  String encode() => jsonEncode({
    'text': text,
    'rows': [
      for (final (label, value) in rows) {'label': label, 'value': value},
    ],
  });

  BibleTextSpecsValue copyWith({String? text, List<(String, String)>? rows}) =>
      BibleTextSpecsValue(text: text ?? this.text, rows: rows ?? this.rows);
}
