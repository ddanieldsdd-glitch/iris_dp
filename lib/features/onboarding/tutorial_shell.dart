import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';

/// Paso informativo del tutorial (contenido fijo).
class TutorialInfoStep {
  final String title;
  final IconData icon;
  final List<String> paragraphs;
  final List<String>? bullets;

  const TutorialInfoStep({
    required this.title,
    required this.icon,
    required this.paragraphs,
    this.bullets,
  });
}

/// Shell común: barra de progreso + navegación atrás/siguiente.
class TutorialShell extends StatelessWidget {
  final int stepIndex;
  final int totalSteps;
  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final String nextLabel;
  final bool nextEnabled;

  const TutorialShell({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    required this.title,
    required this.body,
    this.onBack,
    required this.onNext,
    this.nextLabel = 'Siguiente',
    this.nextEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final progress = (stepIndex + 1) / totalSteps;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Tutorial · Paso ${stepIndex + 1} de $totalSteps',
                        style: AppTypography.caption(palette).copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        title,
                        style: AppTypography.caption(palette).copyWith(
                          color: palette.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: palette.border,
                      color: palette.accent,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: body,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  if (onBack != null)
                    TextButton(
                      onPressed: onBack,
                      child: const Text('Atrás'),
                    )
                  else
                    const SizedBox(width: 8),
                  const Spacer(),
                  AppButton(
                    label: nextLabel,
                    icon: Icons.arrow_forward,
                    onTap: nextEnabled ? onNext : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla de paso informativo reutilizable.
class TutorialInfoPage extends StatelessWidget {
  final TutorialInfoStep step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final String nextLabel;

  const TutorialInfoPage({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    this.onBack,
    required this.onNext,
    this.nextLabel = 'Siguiente',
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TutorialShell(
      stepIndex: stepIndex,
      totalSteps: totalSteps,
      title: step.title,
      onBack: onBack,
      onNext: onNext,
      nextLabel: nextLabel,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(step.icon, size: 56, color: palette.accent),
          const SizedBox(height: AppSpacing.lg),
          Text(step.title, style: AppTypography.titleLarge(palette)),
          const SizedBox(height: AppSpacing.md),
          for (final p in step.paragraphs) ...[
            Text(
              p,
              style: AppTypography.bodyMedium(palette).copyWith(
                color: palette.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (step.bullets != null) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final b in step.bullets!)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 18, color: palette.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        b,
                        style: AppTypography.bodyMedium(palette),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Pasos informativos del tutorial (los pasos de nube/cuenta/mac tienen pantallas propias).
List<TutorialInfoStep> buildTutorialInfoSteps({required bool cloudMode}) {
  return [
    const TutorialInfoStep(
      title: 'Bienvenido a IRIS DP',
      icon: Icons.movie_filter_outlined,
      paragraphs: [
        'IRIS DP es tu espacio de preproducción: guion, biblia de fotografía, '
        'moodboard, localizaciones y planos.',
        'Este asistente te guía en pocos pasos. Tardarás unos 2 minutos.',
      ],
      bullets: [
        'Conectamos tu nube (ya hecho si ves el paso verde)',
        'Creas tu cuenta o inicias sesión',
        'Eliges carpetas en tu Mac',
        'Sincronizas con iPad u otros ordenadores',
      ],
    ),
    const TutorialInfoStep(
      title: 'Carpetas en tu Mac',
      icon: Icons.folder_outlined,
      paragraphs: [
        'IRIS DP guarda una copia local para trabajar offline. '
        'En el siguiente paso elegirás dos carpetas:',
      ],
      bullets: [
        'Datos técnicos: base de datos y catálogos de la app',
        'Documentos: imágenes, guiones, moodboard, exports',
        'Puedes cambiarlas después en Ajustes',
      ],
    ),
    if (cloudMode)
      const TutorialInfoStep(
        title: 'Mantener todos los dispositivos al día',
        icon: Icons.devices_outlined,
        paragraphs: [
          'Tus proyectos viven en Supabase. Cuando actualices IRIS DP en '
          'este Mac, en otro Mac o en el iPad:',
        ],
        bullets: [
          'Instala la nueva versión (.dmg, .exe o App Store)',
          'Abre la app e inicia sesión con el MISMO email',
          'Pulsa el icono de nube — la app sincroniza sola tras actualizar',
          'No hace falta volver a migrar ni reconfigurar carpetas en el mismo dispositivo',
        ],
      ),
    const TutorialInfoStep(
      title: '¡Listo para trabajar!',
      icon: Icons.rocket_launch_outlined,
      paragraphs: [
        'Al entrar verás tus proyectos. Un tour rápido te mostrará '
        'dónde crear proyectos y sincronizar.',
      ],
      bullets: [
        '«Nuevo proyecto» para empezar una producción',
        'Biblia de Fotografía → Dirección para definir el look',
        'Icono de nube para sync manual cuando quieras',
      ],
    ),
  ];
}
