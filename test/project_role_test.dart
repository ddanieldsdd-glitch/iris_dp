import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/cloud/project_role.dart';
import 'package:iris_dp/core/cloud/user_profile.dart';

void main() {
  test('los papeles coinciden con los de la migración 019', () {
    expect(ProjectRole.values.map((r) => r.code), [
      'dp',
      'director',
      'gaffer',
      'first_ac',
      'camera_assistant',
      'first_ad',
      'viewer',
    ]);
  });

  test('todos editan salvo solo consulta', () {
    for (final r in ProjectRole.values) {
      expect(r.canEdit, r != ProjectRole.viewer, reason: r.code);
    }
  });

  test('fromCode y etiquetas', () {
    expect(ProjectRole.fromCode('first_ac'), ProjectRole.firstAc);
    expect(ProjectRole.fromCode('nada'), isNull);
    expect(ProjectRole.fromCode(null), isNull);
    expect(ProjectRole.shortLabel(null), 'propietario');
    expect(ProjectRole.shortLabel('gaffer'), 'gaffer');
    expect(ProjectRole.shortLabel('first_ac'), '1.º ayudante de cámara');
    expect(ProjectRole.shortLabel('director'), 'dirección');
    expect(ProjectRole.shortLabel('otro'), 'otro');
    expect(roleLabel('first_ad'), '1.º ayudante de dirección');
    expect(roleLabel('owner'), 'DP');
    expect(roleLabel('viewer'), 'Solo consulta');
    expect(roleLabel(null), 'Sin rol');
  });
}
