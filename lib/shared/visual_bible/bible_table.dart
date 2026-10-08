import 'dart:convert';

/// Valor de un punto «Tabla»: columnas con nombre y filas de texto.
class BibleTableValue {
  final List<String> columns;
  final List<List<String>> rows;

  const BibleTableValue({this.columns = const [], this.rows = const []});

  factory BibleTableValue.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const BibleTableValue();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final columns = [
          if (decoded['columns'] is List)
            for (final c in decoded['columns'] as List) c.toString(),
        ];
        final rows = [
          if (decoded['rows'] is List)
            for (final r in decoded['rows'] as List)
              if (r is List)
                // Cada fila tiene exactamente una celda por columna.
                [
                  for (var i = 0; i < columns.length; i++)
                    i < r.length ? r[i].toString() : '',
                ],
        ];
        return BibleTableValue(columns: columns, rows: rows);
      }
    } catch (_) {}
    return const BibleTableValue();
  }

  static String initial(List<String> columns) =>
      BibleTableValue(columns: columns).encode();

  String encode() => jsonEncode({'columns': columns, 'rows': rows});

  /// Filas con algo escrito.
  List<List<String>> get filledRows => [
    for (final row in rows)
      if (row.any((cell) => cell.trim().isNotEmpty)) row,
  ];

  bool get isEmpty => filledRows.isEmpty;

  BibleTableValue withCell(int row, int column, String text) => BibleTableValue(
    columns: columns,
    rows: [
      for (var r = 0; r < rows.length; r++)
        [
          for (var c = 0; c < columns.length; c++)
            r == row && c == column ? text : rows[r][c],
        ],
    ],
  );

  BibleTableValue withColumnName(int column, String name) => BibleTableValue(
    columns: [
      for (var c = 0; c < columns.length; c++) c == column ? name : columns[c],
    ],
    rows: rows,
  );

  BibleTableValue addRow() => BibleTableValue(
    columns: columns,
    rows: [...rows, List.filled(columns.length, '')],
  );

  BibleTableValue removeRow(int row) => BibleTableValue(
    columns: columns,
    rows: [
      for (var r = 0; r < rows.length; r++)
        if (r != row) rows[r],
    ],
  );

  BibleTableValue addColumn(String name) => BibleTableValue(
    columns: [...columns, name],
    rows: [
      for (final row in rows) [...row, ''],
    ],
  );

  BibleTableValue removeColumn(int column) => BibleTableValue(
    columns: [
      for (var c = 0; c < columns.length; c++)
        if (c != column) columns[c],
    ],
    rows: [
      for (final row in rows)
        [
          for (var c = 0; c < row.length; c++)
            if (c != column) row[c],
        ],
    ],
  );
}

/// Un medidor: un dato con su valor y, si es un número dentro de una
/// escala, dónde cae en ella.
class BibleMeter {
  final String label;

  /// El valor tal como se escribe: «5600 K», «8:1», «1/4».
  final String value;
  final String note;
  final double? min;
  final double? max;

  const BibleMeter({
    this.label = '',
    this.value = '',
    this.note = '',
    this.min,
    this.max,
  });

  bool get isEmpty => label.trim().isEmpty && value.trim().isEmpty;

  /// Primer número del valor: «5600 K» → 5600; «1/4» → 0,25; «8:1» → 8.
  double? get number {
    final fraction = RegExp(r'(\d+(?:[.,]\d+)?)\s*/\s*(\d+(?:[.,]\d+)?)')
        .firstMatch(value);
    if (fraction != null) {
      final a = double.tryParse(fraction.group(1)!.replaceAll(',', '.'));
      final b = double.tryParse(fraction.group(2)!.replaceAll(',', '.'));
      if (a != null && b != null && b != 0) return a / b;
    }
    final match = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(value);
    if (match == null) return null;
    return double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }

  /// Posición en la escala, de 0 a 1. Nula si no hay escala o número.
  double? get fraction {
    final n = number;
    if (n == null || min == null || max == null || max! <= min!) return null;
    return ((n - min!) / (max! - min!)).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    if (note.isNotEmpty) 'note': note,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
  };

  BibleMeter copyWith({
    String? label,
    String? value,
    String? note,
  }) => BibleMeter(
    label: label ?? this.label,
    value: value ?? this.value,
    note: note ?? this.note,
    min: min,
    max: max,
  );

  static List<BibleMeter> listFrom(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return [
          for (final e in decoded)
            if (e is Map)
              BibleMeter(
                label: e['label']?.toString() ?? '',
                value: e['value']?.toString() ?? '',
                note: e['note']?.toString() ?? '',
                min: (e['min'] as num?)?.toDouble(),
                max: (e['max'] as num?)?.toDouble(),
              ),
        ];
      }
    } catch (_) {}
    return [];
  }

  static String? encode(List<BibleMeter> meters) =>
      meters.isEmpty ? null : jsonEncode([for (final m in meters) m.toJson()]);
}
