/// Nivel de exportación de un plano (referencia Artemis). Todos salen en PDF.
enum StoryboardExportStyle {
  /// La imagen sola, sin metadatos ni superposiciones.
  clean,

  /// Líneas de encuadre y abanico de focal y ángulo de visión.
  basic,

  /// Barra de cámara y óptica, paleta y franja de proyecto, escena y notas.
  detail,

  /// Página entera: lo de DETAIL más guion técnico, planta y sol.
  shotPlan,
}

extension StoryboardExportStyleX on StoryboardExportStyle {
  String get title => switch (this) {
    StoryboardExportStyle.clean => 'CLEAN',
    StoryboardExportStyle.basic => 'BASIC',
    StoryboardExportStyle.detail => 'DETAIL',
    StoryboardExportStyle.shotPlan => 'SHOT PLAN',
  };

  String get description => switch (this) {
    StoryboardExportStyle.clean =>
      'La imagen sola, sin metadatos ni superposiciones.',
    StoryboardExportStyle.basic =>
      'Líneas de encuadre e indicador de focal y ángulo de visión.',
    StoryboardExportStyle.detail =>
      'Cámara y óptica, paleta, escena, notas y localización.',
    StoryboardExportStyle.shotPlan =>
      'Página entera con guion técnico, planta de luz y cámara y sol.',
  };

  /// Sufijo Artemis en el nombre de archivo.
  String get artemisFileSuffix => switch (this) {
    StoryboardExportStyle.clean => 'RAW',
    StoryboardExportStyle.basic => 'S1',
    StoryboardExportStyle.detail => 'S2',
    StoryboardExportStyle.shotPlan => 'S3',
  };
}
