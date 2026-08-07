import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../bible_structure_editor.dart';

/// Configuración de la biblia: estructura, plantillas y sub-apartados.
class BibleSettingsSection extends StatelessWidget {
  final int bibleId;
  final int projectId;

  const BibleSettingsSection({
    super.key,
    required this.bibleId,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (bibleId <= 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'La biblia se está inicializando. Vuelve a abrir esta sección en un momento.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(palette),
          ),
        ),
      );
    }

    return BibleStructureEditor(
      bibleId: bibleId,
      projectId: projectId,
    );
  }
}
