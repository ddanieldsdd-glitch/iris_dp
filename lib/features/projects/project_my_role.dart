import '../../core/database/app_database.dart';

/// Tu papel en un proyecto, que ordena la pantalla de proyectos en páginas
/// (LZ.2). Todas las páginas tienen las mismas funciones: el papel solo
/// sirve para encontrar los proyectos.
///
/// Los códigos son los de `project_members.role` (019), para que un
/// proyecto al que te invitaron caiga solo en su página.
enum MyProjectRole {
  dp('dp', 'Dirección de fotografía', 'Foto'),
  gaffer('gaffer', 'Gaffer', 'Gaffer'),
  firstAc('first_ac', '1.º ayudante de cámara', '1.º AC');

  const MyProjectRole(this.code, this.label, this.tab);

  final String code;
  final String label;

  /// Lo que pone la pestaña: corto, para que quepan en el iPhone.
  final String tab;

  /// El papel guardado; sin papel, dirección de fotografía.
  static MyProjectRole of(String? code) => fromCode(code) ?? dp;

  static MyProjectRole? fromCode(String? code) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    return null;
  }

  static MyProjectRole ofProject(Project p) => of(p.myRole);

  /// Los proyectos de esta página.
  List<Project> filter(Iterable<Project> projects) => [
    for (final p in projects)
      if (ofProject(p) == this) p,
  ];
}
