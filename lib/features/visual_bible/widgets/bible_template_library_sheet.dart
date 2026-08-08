import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class BibleTemplateChoice {
  final String id;
  final String name;
  final String description;
  final String category;
  final int? screenCount;

  const BibleTemplateChoice({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.screenCount,
  });
}

class BibleTemplateLibrarySheet extends StatelessWidget {
  final List<BibleTemplateChoice> templates;
  final bool examplesMode;
  final Future<void> Function(BibleTemplateChoice template) onUse;

  const BibleTemplateLibrarySheet({
    super.key,
    required this.templates,
    required this.examplesMode,
    required this.onUse,
  });

  static Future<String?> show(
    BuildContext context, {
    required List<BibleTemplateChoice> templates,
    required bool examplesMode,
    required Future<void> Function(BibleTemplateChoice template) onUse,
  }) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surface,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.9,
      child: BibleTemplateLibrarySheet(
        templates: templates,
        examplesMode: examplesMode,
        onUse: onUse,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final categories = templates.map((t) => t.category).toSet().toList();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        examplesMode ? 'Explorar ejemplos' : 'Plantillas',
                        style: AppTypography.titleLarge(palette),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        examplesMode
                            ? 'Descubre estructuras con contenido de ejemplo.'
                            : 'Elige un punto de partida. Podrás personalizarlo después.',
                        style: AppTypography.bodyMedium(
                          palette,
                        ).copyWith(color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final category in categories) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: AppSpacing.sm,
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: AppTypography.mono(palette).copyWith(
                        color: palette.textSecondary,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  for (final template in templates.where(
                    (t) => t.category == category,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _TemplateCard(
                        template: template,
                        actionLabel: examplesMode
                            ? 'Usar ejemplo'
                            : 'Usar plantilla',
                        onUse: () async {
                          await onUse(template);
                          if (context.mounted) {
                            Navigator.pop(context, template.id);
                          }
                        },
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final BibleTemplateChoice template;
  final String actionLabel;
  final Future<void> Function() onUse;

  const _TemplateCard({
    required this.template,
    required this.actionLabel,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 80,
            decoration: BoxDecoration(
              color: palette.surfaceOverlay,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_stories_outlined, color: palette.accent),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.name, style: AppTypography.titleMedium(palette)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  template.description,
                  style: AppTypography.bodyMedium(
                    palette,
                  ).copyWith(color: palette.textSecondary),
                ),
                if (template.screenCount != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${template.screenCount} pantallas',
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(color: palette.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          FilledButton.tonal(onPressed: onUse, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
