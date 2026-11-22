/// Qué hace una persona en un proyecto compartido (`project_members.role`,
/// migraciones 019 y 022). Todos editan todo salvo [viewer] y los
/// eléctricos ([bestBoy] y [electrician], LZ.3), que solo consultan: en la
/// nube lo hace cumplir `iris_role_can_edit` (022).
enum ProjectRole {
  dp('dp', 'Dirección de fotografía'),
  director('director', 'Dirección'),
  gaffer('gaffer', 'Gaffer'),
  firstAc('first_ac', '1.º ayudante de cámara'),
  cameraAssistant('camera_assistant', 'Auxiliar de cámara'),
  firstAd('first_ad', '1.º ayudante de dirección'),
  bestBoy('best_boy', 'Best boy (solo consulta)'),
  electrician('electrician', 'Eléctrico (solo consulta)'),
  viewer('viewer', 'Solo consulta');

  const ProjectRole(this.code, this.label);

  /// Como se guarda en la nube.
  final String code;
  final String label;

  bool get canEdit => this != viewer && !isLightCrew;

  /// Eléctricos: entran a la vista de consulta de luz (LZ.3).
  bool get isLightCrew => this == bestBoy || this == electrician;

  static ProjectRole? fromCode(String? code) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    return null;
  }

  /// Cómo se dice en los avisos: en minúscula y, sin papel, «propietario»
  /// (lo que no es de un invitado es de esta cuenta).
  static String shortLabel(String? code) {
    if (code == null) return 'propietario';
    final role = fromCode(code);
    if (role == null) return code;
    return switch (role) {
      gaffer => 'gaffer',
      bestBoy => 'best boy',
      electrician => 'eléctrico',
      _ => role.label[0].toLowerCase() + role.label.substring(1),
    };
  }
}
