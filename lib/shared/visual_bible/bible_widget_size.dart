/// Tamaño semántico de un widget de la biblia (ancho en grid, no píxeles fijos).
enum BibleWidgetSize {
  /// Pequeño — peso 4/12. Métrica suelta, texto corto, carrusel compacto.
  small,

  /// Mediano — peso 6/12. Vista de trabajo.
  medium,

  /// Grande — peso 12/12. Hero, mosaico, tabla completa.
  large;

  /// Peso en unidades de grid de 12 columnas.
  int get gridWeight => switch (this) {
        BibleWidgetSize.small => 4,
        BibleWidgetSize.medium => 6,
        BibleWidgetSize.large => 12,
      };

  /// Alias para export v2 (`colSpan`).
  int get colSpan => gridWeight;

  String get storageKey => switch (this) {
        BibleWidgetSize.small => 'S',
        BibleWidgetSize.medium => 'M',
        BibleWidgetSize.large => 'L',
      };

  String get label => storageKey;

  static BibleWidgetSize fromStorage(String? value) {
    return switch (value?.toUpperCase()) {
      'S' || 'SMALL' => BibleWidgetSize.small,
      'M' || 'MEDIUM' => BibleWidgetSize.medium,
      'L' || 'LARGE' => BibleWidgetSize.large,
      _ => BibleWidgetSize.large,
    };
  }
}
