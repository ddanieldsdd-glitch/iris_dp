import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Onboarding unificado: plantilla profesional (recomendado) / desde cero / explorar.
class BibleCreationOnboarding extends StatelessWidget {
  final VoidCallback onUseTemplate;
  final VoidCallback onStartFromScratch;
  final VoidCallback onExploreTemplates;
  final String? title;
  final String? subtitle;

  const BibleCreationOnboarding({
    super.key,
    required this.onUseTemplate,
    required this.onStartFromScratch,
    required this.onExploreTemplates,
    this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final cardWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - ((columns - 1) * AppSpacing.md)) /
                  columns;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? 'Crea tu Biblia',
                    style: AppTypography.titleLarge(palette).copyWith(
                      fontSize: 32,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle ??
                        '¿Cómo quieres empezar? Empieza con un diseño profesional '
                        'y personalízalo, o construye desde cero si lo prefieres.',
                    style: AppTypography.bodyLarge(palette).copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _OptionCard(
                          icon: Icons.dashboard_customize_outlined,
                          title: 'Plantilla profesional',
                          description:
                              'Empieza con una estructura diseñada y '
                              'personalízala a tu proyecto.',
                          actionLabel: 'Ver plantillas',
                          primary: true,
                          onPressed: onUseTemplate,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _OptionCard(
                          icon: Icons.add_box_outlined,
                          title: 'Desde cero',
                          description:
                              'Crea cada pantalla y bloque manualmente.',
                          actionLabel: 'Crear vacía',
                          onPressed: onStartFromScratch,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _OptionCard(
                          icon: Icons.auto_awesome_mosaic_outlined,
                          title: 'Explorar primero',
                          description:
                              'Ver todas las plantillas y decidir más adelante.',
                          actionLabel: 'Explorar',
                          onPressed: onExploreTemplates,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final bool primary;
  final VoidCallback onPressed;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      constraints: const BoxConstraints(minHeight: 245),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primary
              ? palette.accent.withValues(alpha: 0.7)
              : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primary ? palette.accent : palette.textSecondary),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTypography.titleMedium(palette)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: AppTypography.bodyMedium(palette).copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (primary)
            FilledButton(onPressed: onPressed, child: Text(actionLabel))
          else
            OutlinedButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
