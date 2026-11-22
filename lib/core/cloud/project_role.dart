/// Qué hace una persona en un proyecto compartido (`project_members.role`,
/// migración 019). Todos editan todo salvo [viewer]: los permisos finos
/// llegarán si las pruebas con equipo los piden.
enum ProjectRole {
  dp('dp', 'Dirección de fotografía'),
  director('director', 'Dirección'),
  gaffer('gaffer', 'Gaffer'),
  firstAc('first_ac', '1.º ayudante de cámara'),
  cameraAssistant('camera_assistant', 'Auxiliar de cámara'),
  firstAd('first_ad', '1.º ayudante de dirección'),
  viewer('viewer', 'Solo consulta');

  const ProjectRole(this.code, this.label);

  /// Como se guarda en la nube.
  final String code;
  final String label;

  bool get canEdit => this != viewer;

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
      _ => role.label[0].toLowerCase() + role.label.substring(1),
    };
  }
}
