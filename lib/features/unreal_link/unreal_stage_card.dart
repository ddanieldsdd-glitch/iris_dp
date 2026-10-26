import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import 'unreal_link_button.dart';
import 'unreal_stage_launcher.dart';

/// «Unreal en vivo»: el botón «Abrir en Unreal» con su progreso. En el PC
/// lo hace todo (crear, preparar, abrir y conectar); en el Mac y el iPad
/// conecta con el PC.
class UnrealStageCard extends StatelessWidget {
  final int? projectId;
  final String projectName;
  final UnrealStageLauncher launcher;

  UnrealStageCard({
    super.key,
    required this.projectId,
    required this.projectName,
    UnrealStageLauncher? launcher,
  }) : launcher = launcher ?? UnrealStageLauncher.instance;

  Future<void> _useOwnProject() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Elige el proyecto de Unreal (.uproject)',
      type: FileType.custom,
      allowedExtensions: const ['uproject'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    await launcher.open(
      projectId: projectId,
      projectName: projectName,
      uproject: path,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final link = launcher.link;
    return ListenableBuilder(
      listenable: Listenable.merge([launcher, link]),
      builder: (context, _) {
        final busy = launcher.busy;
        final saved = UnrealStageLauncher.savedProject(projectId);
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.view_in_ar_outlined,
                    color: link.isOn ? palette.success : palette.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Unreal en vivo',
                      style: AppTypography.titleMedium(palette),
                    ),
                  ),
                  if (link.isOn)
                    Text(
                      'Conectado',
                      style: AppTypography.label(
                        palette,
                      ).copyWith(color: palette.success),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                UnrealStageLauncher.supported
                    ? 'Un botón: IRIS crea el proyecto de Unreal de este '
                          'proyecto (si no lo tiene), lo prepara, abre Unreal '
                          'y se conecta. Después, en la planta de cámara y '
                          'luz con el 3D abierto, todo se ve y se mueve en '
                          'Unreal al momento.'
                    : 'Unreal se abre desde IRIS en el PC. Desde aquí te '
                          'conectas a él por la red.',
                style: AppTypography.bodyMedium(
                  palette,
                ).copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              if (UnrealStageLauncher.supported)
                FilledButton.icon(
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.rocket_launch_outlined),
                  label: Text(
                    link.isOn ? 'Volver a abrir en Unreal' : 'Abrir en Unreal',
                  ),
                  onPressed: busy
                      ? null
                      : () => launcher.open(
                          projectId: projectId,
                          projectName: projectName,
                        ),
                )
              else
                FilledButton.icon(
                  icon: const Icon(Icons.cast_connected_outlined),
                  label: Text(
                    link.isOn ? 'Conectado con el PC' : 'Conectar con el PC…',
                  ),
                  onPressed: () => showUnrealLinkDialog(context, link),
                ),
              if (launcher.message != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    launcher.message!,
                    style: AppTypography.bodyMedium(palette).copyWith(
                      color: launcher.phase == UnrealLaunchPhase.done
                          ? palette.success
                          : palette.textSecondary,
                    ),
                  ),
                ),
              if (launcher.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    launcher.error!,
                    style: AppTypography.bodyMedium(
                      palette,
                    ).copyWith(color: palette.error),
                  ),
                ),
              if (launcher.report case final report?
                  when report.lines.any((l) => l.changed || l.warning))
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final l in report.lines)
                        if (l.changed || l.warning)
                          Text(
                            '${l.warning ? '⚠' : '✓'} ${l.text}',
                            style: AppTypography.caption(palette).copyWith(
                              color: l.warning
                                  ? palette.warning
                                  : palette.textTertiary,
                            ),
                          ),
                    ],
                  ),
                ),
              if (UnrealStageLauncher.supported) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  saved == null
                      ? 'Proyecto de Unreal: se creará en Documentos\\Unreal '
                            'Projects.'
                      : 'Proyecto de Unreal: $saved',
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.textTertiary),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: busy ? null : _useOwnProject,
                    child: const Text('Usar otro proyecto de Unreal…'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
