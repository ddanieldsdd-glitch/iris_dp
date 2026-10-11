import 'dart:typed_data';

/// Guion técnico listo para exportar: lo mismo que se ve en la hoja, sin
/// depender de la pantalla. El PDF y el Word pintan este modelo.
class TechnicalScriptDoc {
  final String title;

  /// Línea bajo el título (dirección, jornada…).
  final String? subtitle;
  final List<ScriptDocColumn> columns;
  final List<ScriptDocSection> sections;

  const TechnicalScriptDoc({
    required this.title,
    required this.columns,
    required this.sections,
    this.subtitle,
  });
}

class ScriptDocColumn {
  final String key;
  final String label;

  /// Ancho relativo, con las proporciones del Word de referencia.
  final double weight;
  final bool centered;

  const ScriptDocColumn(
    this.key,
    this.label,
    this.weight, {
    this.centered = false,
  });
}

/// Columnas del guion técnico, en su orden. Las opcionales se filtran con
/// [scriptDocColumns].
const kScriptDocColumns = [
  ScriptDocColumn('esc', 'ESC', 705, centered: true),
  ScriptDocColumn('plano', 'PLANO', 1080, centered: true),
  ScriptDocColumn('encuadre', 'Encuadre', 1350, centered: true),
  ScriptDocColumn('lens', 'LENTE/ANG/MOV', 1665, centered: true),
  ScriptDocColumn('f', 'F', 750, centered: true),
  ScriptDocColumn('pers', 'PERS.', 1200),
  ScriptDocColumn('dur', 'DUR.', 700, centered: true),
  ScriptDocColumn('action', 'ACCIÓN', 3570),
  ScriptDocColumn('ref', 'REFERENCIA', 2625, centered: true),
  ScriptDocColumn('planta', 'PLANTA', 2100, centered: true),
  ScriptDocColumn('notes', 'APUNTES', 2190),
];

List<ScriptDocColumn> scriptDocColumns({required Set<String> hidden}) => [
  for (final c in kScriptDocColumns)
    if (!hidden.contains(c.key)) c,
];

/// Una escena: su título y su tabla.
class ScriptDocSection {
  final String title;

  /// Color de la fila de títulos (0xRRGGBB), el de la escena aclarado.
  final int headerFill;
  final List<ScriptDocRow> rows;

  const ScriptDocSection({
    required this.title,
    required this.headerFill,
    required this.rows,
  });
}

class ScriptDocRow {
  /// Texto de cada celda por clave de columna, con las marcas de formato.
  final Map<String, String> cells;

  /// Color de la fila entera (0xRRGGBB), si lo tiene.
  final int? fill;

  /// Color propio de algunas celdas (0xRRGGBB), por clave de columna.
  final Map<String, int> cellFills;

  /// Imágenes de la celda de referencia (una por encuadre), ya en un
  /// formato que PDF y Word admiten (PNG o JPEG).
  final List<Uint8List> images;

  /// Imágenes de la celda de planta: la planta dibujada y sus bocetos.
  final List<Uint8List> planImages;

  const ScriptDocRow({
    required this.cells,
    this.fill,
    this.cellFills = const {},
    this.images = const [],
    this.planImages = const [],
  });

  /// Imágenes de una columna de imágenes; nulo si la columna es de texto.
  List<Uint8List>? imagesOf(String column) => switch (column) {
    'ref' => images,
    'planta' => planImages,
    _ => null,
  };

  /// La primera imagen, si hay alguna.
  Uint8List? get image => images.isEmpty ? null : images.first;

  int? fillOf(String column) => cellFills[column] ?? fill;
}

/// Fondo de cada color de marcador (0xRRGGBB).
const kScriptDocMarkerFills = {
  'y': 0xFFF176,
  'g': 0xA5D6A7,
  'p': 0xF48FB1,
  'b': 0x90CAF9,
};
