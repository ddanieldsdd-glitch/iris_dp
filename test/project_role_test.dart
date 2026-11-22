import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/cloud/project_role.dart';
import 'package:iris_dp/core/cloud/user_profile.dart';

void main() {
  test('los papeles coinciden con los de la última migración (022)', () {
    final sql = File(
      'supabase/migrations/022_light_crew_roles.sql',
    ).readAsStringSync();
    final check = RegExp(
      r'project_members_role_check CHECK \(role IN \(([^)]*)\)',
    ).firstMatch(sql)!;
    final codes = RegExp(
      r"'([a-z_]+)'",
    ).allMatches(check.group(1)!).map((m) => m.group(1)).toSet();
    expect(ProjectRole.values.map((r) => r.code).toSet(), codes);
  });

  test('editan todos salvo solo consulta y los eléctricos', () {
    const readOnly = {
      ProjectRole.viewer,
      ProjectRole.bestBoy,
      ProjectRole.electrician,
    };
    for (final r in ProjectRole.values) {
      expect(r.canEdit, !readOnly.contains(r), reason: r.code);
    }
    // Lo mismo que hace cumplir la nube (iris_role_can_edit, 022).
    final sql = File(
      'supabase/migrations/022_light_crew_roles.sql',
    ).readAsStringSync();
    expect(sql, contains("NOT IN ('viewer', 'best_boy', 'electrician')"));
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
