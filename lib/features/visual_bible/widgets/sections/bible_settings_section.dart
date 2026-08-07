import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../master_config/master_config_section.dart';

/// Configuración de la biblia: Master Config (Stitch) + plantillas.
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

    return MasterConfigSection(
      bibleId: bibleId,
      projectId: projectId,
    );
  }
}
