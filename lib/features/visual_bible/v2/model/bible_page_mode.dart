/// Modo de renderizado de una página de Biblia.
enum BiblePageMode {
  /// Layout profesional predefinido (receta Stitch / smart widget).
  recipe,

  /// Grid libre de bloques modulares.
  freeform,
}

extension BiblePageModeJson on BiblePageMode {
  String get wireName => name;

  static BiblePageMode fromWire(String? raw) {
    return switch (raw) {
      'freeform' => BiblePageMode.freeform,
      _ => BiblePageMode.recipe,
    };
  }
}
