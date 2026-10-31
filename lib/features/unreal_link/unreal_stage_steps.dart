import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import 'unreal_library.dart';
import 'unreal_library_screen.dart';
import 'unreal_link.dart';
import 'unreal_link_button.dart';
import 'unreal_render_view.dart';
import 'unreal_stage_launcher.dart';

/// Cómo va un paso de IRIS Stage.
enum StageStepState { done, ready, waiting }

/// Un paso de la guía: qué se hace, si está hecho y qué botón lo hace.
class StageStep {
  final String title;
  final String hint;
  final StageStepState state;
  final String? action;
  final VoidCallback? onAction;

  const StageStep({
    required this.title,
    required this.hint,
    required this.state,
    this.action,
    this.onAction,
  });
}

/// Los seis pasos de IRIS Stage (F6.20 C1–C4), con su estado sacado de lo
/// que hay: proyecto de Unreal, conexión, escena enviada y biblioteca.
List<StageStep> stageSteps({
  required int? projectId,
  required bool onPc,
  required String? savedProject,
  required bool connected,
  required String? worldPath,
  required int libraryCount,
  VoidCallback? onOpenUnreal,
  VoidCallback? onConnect,
  VoidCallback? onLibrary,
  VoidCallback? onRender,
}) {
  StageStepState after(bool ok, bool previous) => ok
      ? StageStepState.done
      : previous
      ? StageStepState.ready
      : StageStepState.waiting;
  final prepared = savedProject != null || connected;
  final sent = connected && worldPath != null;
  return [
    StageStep(
      title: 'Preparar Unreal',
      hint: onPc
          ? 'IRIS crea (o usa) el proyecto de Unreal de este proyecto y le '
                'instala IRIS Stage Link.'
          : 'Se hace en el PC con Unreal: «Abrir en Unreal» en IRIS para '
                'Windows.',
      state: prepared ? StageStepState.done : StageStepState.ready,
      action: onPc ? 'Abrir en Unreal' : null,
      onAction: onPc ? onOpenUnreal : null,
    ),
    StageStep(
      title: 'Conectar',
      hint: onPc
          ? '«Abrir en Unreal» conecta solo al abrirse el editor.'
          : 'Escribe la dirección del PC (la que da «Abrir en Unreal» allí).',
      state: after(connected, prepared),
      action: connected ? null : (onPc ? 'Abrir en Unreal' : 'Conectar…'),
      onAction: connected ? null : (onPc ? onOpenUnreal : onConnect),
    ),
    StageStep(
      title: 'Mandar la planta',
      hint: sent
          ? 'En Unreal: $worldPath. Lo que cambias en la planta se ve allí al '
                'momento, y al revés.'
          : 'Abre una planta de cámara y luz con el 3D: sus luces, cámaras, '
                'sol y escaneos pasan a Unreal.',
      state: after(sent, connected),
    ),
    StageStep(
      title: 'Escaneos y assets',
      hint: libraryCount == 0
          ? 'Busca en Fab o en el proyecto de Unreal y pon assets en la '
                'planta; los escaneos se importan en el 3D.'
          : '$libraryCount assets en la biblioteca. Ponlos en la planta desde '
                'la biblioteca o desde la ficha de cada elemento.',
      state: libraryCount > 0 ? StageStepState.done : after(false, connected),
      action: 'Biblioteca',
      onAction: onLibrary,
    ),
    StageStep(
      title: 'Render RTX',
      hint: 'La imagen de Unreal (Lumen, trazado de rayos, DLSS) dentro de '
          'IRIS, por la cámara que elijas.',
      state: connected ? StageStepState.ready : StageStepState.waiting,
      action: connected ? 'Ver Render RTX' : null,
      onAction: connected ? onRender : null,
    ),
    StageStep(
      title: 'Capturas al storyboard',
      hint: 'Desde la planta de un plano, con el 3D abierto: «Capturar» guarda '
          'una foto en alta de Unreal como referencia del plano.',
      state: sent ? StageStepState.ready : StageStepState.waiting,
    ),
  ];
}

/// La guía en pantalla: los seis pasos con su estado y su botón.
class UnrealStageSteps extends StatelessWidget {
  final int? projectId;
  final String projectName;
  final UnrealLink link;
  final UnrealStageLauncher launcher;
  final UnrealLibrary library;

  UnrealStageSteps({
    super.key,
    required this.projectId,
    required this.projectName,
    UnrealLink? link,
    UnrealStageLauncher? launcher,
    UnrealLibrary? library,
  }) : link = link ?? UnrealLink.instance,
       launcher = launcher ?? UnrealStageLauncher.instance,
       library = library ?? UnrealLibrary.instance;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListenableBuilder(
      listenable: Listenable.merge([link, launcher, library]),
      builder: (context, _) {
        final steps = stageSteps(
          projectId: projectId,
          onPc: UnrealStageLauncher.supported,
          savedProject: UnrealStageLauncher.savedProject(projectId),
          connected: link.isOn,
          worldPath: link.worldPath,
          libraryCount: library.entries.length,
          onOpenUnreal: launcher.busy
              ? null
              : () => launcher.open(
                  projectId: projectId,
                  projectName: projectName,
                ),
          onConnect: () => showUnrealLinkDialog(context, link),
          onLibrary: () =>
              UnrealLibraryScreen.open(context, projectId: projectId),
          onRender: () => UnrealRenderScreen.open(context, cameras: const []),
        );
        final done = steps.where((s) => s.state == StageStepState.done).length;
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'IRIS Stage en seis pasos · $done de ${steps.length}',
                style: AppTypography.titleMedium(palette),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final (i, step) in steps.indexed)
                _StepRow(number: i + 1, step: step),
            ],
          ),
        );
      },
    );
  }
}

class _StepRow extends StatelessWidget {
  final int number;
  final StageStep step;

  const _StepRow({required this.number, required this.step});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = switch (step.state) {
      StageStepState.done => palette.success,
      StageStepState.ready => palette.accent,
      StageStepState.waiting => palette.textTertiary,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: color.withValues(alpha: 0.18),
            child: step.state == StageStepState.done
                ? Icon(Icons.check, size: 16, color: color)
                : Text(
                    '$number',
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(color: color),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: AppTypography.bodyMedium(palette).copyWith(
                    color: step.state == StageStepState.waiting
                        ? palette.textTertiary
                        : palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(step.hint, style: AppTypography.caption(palette)),
              ],
            ),
          ),
          if (step.action != null && step.onAction != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: TextButton(
                onPressed: step.onAction,
                child: Text(step.action!),
              ),
            ),
        ],
      ),
    );
  }
}
