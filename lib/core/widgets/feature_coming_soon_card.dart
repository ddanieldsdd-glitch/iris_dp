import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';

/// Bloque informativo para funcionalidades planificadas pero aún no editables.
class FeatureComingSoonCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String>? plannedFeatures;

  const FeatureComingSoonCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.plannedFeatures,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: palette.textTertiary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title, style: AppTypography.titleMedium(palette)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.surfaceOverlay.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: palette.divider),
                ),
                child: Text(
                  'En desarrollo',
                  style: AppTypography.caption(palette).copyWith(
                    color: palette.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(description, style: AppTypography.bodyMedium(palette)),
          if (plannedFeatures != null && plannedFeatures!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ...plannedFeatures!.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('· ', style: AppTypography.bodyMedium(palette)),
                    Expanded(
                      child: Text(f, style: AppTypography.caption(palette)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
