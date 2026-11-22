import 'package:flutter/material.dart';
import 'project_form_sheet.dart';
import 'project_my_role.dart';

class CreateProjectSheet extends StatelessWidget {
  /// Tu papel en el proyecto: el de la página desde la que se crea.
  final MyProjectRole? initialRole;

  const CreateProjectSheet({super.key, this.initialRole});

  @override
  Widget build(BuildContext context) {
    return ProjectFormSheet(initialRole: initialRole);
  }
}
