import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/settings/settings_center_screen.dart';
import '../../core/theme/app_colors.dart';
import 'app_settings_sections.dart';

export 'app_settings_sections.dart' show SettingsSectionIds;

/// Abre el centro de ajustes. Desde un proyecto, con [projectId], permite
/// cambiar ajustes solo para él.
Future<void> openSettingsCenter(
  BuildContext context, {
  int? projectId,
  String? sectionId,
}) async {
  String? projectName;
  if (projectId != null) {
    final db = ProviderScope.containerOf(context).read(databaseProvider);
    projectName = (await db.getProject(projectId))?.name;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => SettingsCenterScreen(
        sections: appSettingsSections(),
        initialSectionId: sectionId,
        projectId: projectId,
        projectName: projectName,
      ),
    ),
  );
}

/// Abre solo la sección de una pantalla, en un panel a la derecha.
Future<void> openScreenSettings(
  BuildContext context, {
  required String sectionId,
  int? projectId,
}) {
  final spec = appSettingsSections().firstWhere((s) => s.id == sectionId);
  return showScreenSettingsPanel(
    context,
    spec: spec,
    projectId: projectId,
    onOpenAll: () {
      Navigator.of(context).pop();
      openSettingsCenter(context, projectId: projectId, sectionId: sectionId);
    },
  );
}

/// Engranaje de la barra de una pantalla.
class ScreenSettingsButton extends StatelessWidget {
  final String sectionId;
  final int? projectId;

  const ScreenSettingsButton({
    super.key,
    required this.sectionId,
    this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ajustes de esta pantalla',
      icon: Icon(Icons.settings_outlined, color: context.palette.textSecondary),
      onPressed: () => openScreenSettings(
        context,
        sectionId: sectionId,
        projectId: projectId,
      ),
    );
  }
}
