/// Alcance al guardar un color en la jerarquía maestro → set → escena.
enum ColorEditScope {
  /// Solo esta escena (`scenes.location_color`).
  scene,

  /// Set de rodaje y todas sus escenas vinculadas.
  set,

  /// Toda la localización: recalcula variantes en todos los sets.
  location,
}

extension ColorEditScopeLabel on ColorEditScope {
  String get label => switch (this) {
        ColorEditScope.scene => 'Solo esta escena',
        ColorEditScope.set => 'Todo el set',
        ColorEditScope.location => 'Toda la localización',
      };

  String get shortLabel => switch (this) {
        ColorEditScope.scene => 'Escena',
        ColorEditScope.set => 'Set',
        ColorEditScope.location => 'Localización',
      };

  String hint({int? scenesInSet, int? setsInSite}) => switch (this) {
        ColorEditScope.scene =>
          'Override local: no afecta al set ni a otras escenas.',
        ColorEditScope.set =>
          'Aplica al set y a ${scenesInSet ?? 'sus'} escena(s) vinculada(s).',
        ColorEditScope.location =>
          'Recalcula variantes en ${setsInSite ?? 'todos los'} set(s) de la localización.',
      };
}
