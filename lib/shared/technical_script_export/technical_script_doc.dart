import 'dart:typed_data';

/// Tamaño de papel del documento.
enum ScriptDocPaper {
  a4('A4'),
  letter('Carta');

  final String label;
  const ScriptDocPaper(this.label);

  static ScriptDocPaper? parse(Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}

/// Guion técnico listo para exportar: lo mismo que se ve en la hoja, sin
/// depender de la pantalla. El PDF y el Word pintan este modelo.
class TechnicalScriptDoc {
  final String title;

  /// Línea bajo el título (dirección, jornada…).
  final String? subtitle;
  final List<ScriptDocColumn> columns;
  final List<ScriptDocSection> sections;

  /// Tipografía de la hoja ('Inter', 'Noto Sans', 'Tinos'): el documento
  /// sale con la misma que se ve en pantalla.
  final String fontFamily;

  /// Índice de escenas al principio, con su página y enlace a cada una.
  final bool includeIndex;

  final ScriptDocPaper paper;
  final bool landscape;

  /// Cuerpo del texto de la tabla, en puntos. Nulo: el de cada formato
  /// (8,5 en el PDF, 9 en el Word).
  final double? fontSize;

  const TechnicalScriptDoc({
    required this.title,
    required this.columns,
    required this.sections,
    this.subtitle,
    this.fontFamily = 'Inter',
    this.includeIndex = true,
    this.paper = ScriptDocPaper.a4,
    this.landscape = true,
    this.fontSize,
  });

  TechnicalScriptDoc copyWith({
    bool? includeIndex,
    String? fontFamily,
    ScriptDocPaper? paper,
    bool? landscape,
    double? fontSize,
  }) => TechnicalScriptDoc(
    title: title,
    subtitle: subtitle,
    columns: columns,
    sections: sections,
    fontFamily: fontFamily ?? this.fontFamily,
    includeIndex: includeIndex ?? this.includeIndex,
    paper: paper ?? this.paper,
    landscape: landscape ?? this.landscape,
    fontSize: fontSize ?? this.fontSize,
  );

  /// Hay índice que poner.
  bool get hasIndex => includeIndex && sections.isNotEmpty;
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
  ScriptDocColumn('story', 'STORYBOARD', 2625, centered: true),
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

  /// Línea del índice: «ESCENA 4. INT/EXT CORTIJO NOCHE (1-2)». Sin ella
  /// se usa el título.
  final String? indexLabel;

  /// Color de la fila de títulos (0xRRGGBB), el de la escena aclarado.
  final int headerFill;
  final List<ScriptDocRow> rows;

  const ScriptDocSection({
    required this.title,
    required this.headerFill,
    required this.rows,
    this.indexLabel,
  });

  String get indexText => indexLabel ?? title;
}

/// Línea del índice de una escena, como la de la planta de cámara:
/// «ESCENA 4. INT/EXT CORTIJO NOCHE (1-2)». [shots] son los números de los
/// planos de ese tramo; sin ellos no lleva paréntesis.
String scriptIndexLabel({
  required String sceneLabel,
  required String intExt,
  required String location,
  required String dayNight,
  List<String> shots = const [],
}) {
  final meta = [
    intExt.trim(),
    location.trim(),
    dayNight.trim(),
  ].where((s) => s.isNotEmpty).join(' ');
  final planes = shots.isEmpty ? '' : ' (${shots.join('-')})';
  return 'ESCENA $sceneLabel. $meta$planes'.toUpperCase();
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

  /// Imagen de la celda de storyboard.
  final List<Uint8List> storyboardImages;

  const ScriptDocRow({
    required this.cells,
    this.fill,
    this.cellFills = const {},
    this.images = const [],
    this.planImages = const [],
    this.storyboardImages = const [],
  });

  /// Imágenes de una columna de imágenes; nulo si la columna es de texto.
  List<Uint8List>? imagesOf(String column) => switch (column) {
    'ref' => images,
    'planta' => planImages,
    'story' => storyboardImages,
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
