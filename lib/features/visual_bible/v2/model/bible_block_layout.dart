import 'bible_json_parse.dart';

/// Layout de un bloque en grid Smart (12 columnas) o Freeform.
class BibleBlockLayout {
  static const int gridColumns = 12;

  /// Columna inicial 0..11 (smart).
  final int col;

  /// Fila lógica (smart).
  final int row;

  /// Span horizontal 1..12.
  final int colSpan;

  /// Span vertical en unidades de fila.
  final int rowSpan;

  /// `smart` | `freeform`
  final String mode;

  /// Posición libre (fracción 0..1 del canvas) si freeform.
  final double? x;
  final double? y;
  final double? width;
  final double? height;

  const BibleBlockLayout({
    this.col = 0,
    this.row = 0,
    this.colSpan = 12,
    this.rowSpan = 2,
    this.mode = 'smart',
    this.x,
    this.y,
    this.width,
    this.height,
  });

  Map<String, dynamic> toJson() => {
    'col': col,
    'row': row,
    'colSpan': colSpan,
    'rowSpan': rowSpan,
    'mode': mode,
    if (x != null) 'x': x,
    if (y != null) 'y': y,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
  };

  factory BibleBlockLayout.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BibleBlockLayout();
    return BibleBlockLayout(
      col: bibleJsonIntOr(json['col'], 0),
      row: bibleJsonIntOr(json['row'], 0),
      colSpan: bibleJsonIntOr(json['colSpan'], 12),
      rowSpan: bibleJsonIntOr(json['rowSpan'], 2),
      mode: json['mode']?.toString() ?? 'smart',
      x: bibleJsonDouble(json['x']),
      y: bibleJsonDouble(json['y']),
      width: bibleJsonDouble(json['width']),
      height: bibleJsonDouble(json['height']),
    );
  }

  BibleBlockLayout copyWith({
    int? col,
    int? row,
    int? colSpan,
    int? rowSpan,
    String? mode,
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return BibleBlockLayout(
      col: col ?? this.col,
      row: row ?? this.row,
      colSpan: colSpan ?? this.colSpan,
      rowSpan: rowSpan ?? this.rowSpan,
      mode: mode ?? this.mode,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}
