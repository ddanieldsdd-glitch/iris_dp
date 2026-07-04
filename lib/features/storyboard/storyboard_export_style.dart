/// Estilo de exportación de fotogramas (referencia Artemis).
enum StoryboardExportStyle {
  /// Imagen sin metadatos ni overlays (RAW).
  clean,

  /// Badge de focal y FOV en esquina inferior derecha (S1).
  basic,

  /// PDF con cabecera técnica, paleta de color y notas (S2).
  detail,

  /// PDF completo con localización, sol y planta cenital (S3).
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
          'Imagen sin metadatos ni overlays.',
        StoryboardExportStyle.basic =>
          'Indicador de focal y ángulo de visión (estilo Artemis).',
        StoryboardExportStyle.detail =>
          'PDF con cámara, paleta de color, FOV y notas.',
        StoryboardExportStyle.shotPlan =>
          'PDF completo con localización, sol y planta cenital.',
      };

  /// PNG (RAW/S1) vs PDF (S2/S3).
  bool get singleShotUsesPdf =>
      this == StoryboardExportStyle.detail ||
      this == StoryboardExportStyle.shotPlan;

  String get fileExtension => singleShotUsesPdf ? 'pdf' : 'png';

  /// Sufijo Artemis en el nombre de archivo.
  String get artemisFileSuffix => switch (this) {
        StoryboardExportStyle.clean => 'RAW',
        StoryboardExportStyle.basic => 'S1',
        StoryboardExportStyle.detail => 'S2',
        StoryboardExportStyle.shotPlan => 'S3',
      };
}
