import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import 'floor_plan_scope.dart';

/// Tarjeta unificada para plano maestro, plano de set o planta de plano.
class FloorPlanMapTile extends StatelessWidget {
  final FloorPlanScope scope;
  final String title;
  final String? subtitle;
  final Color accentColor;
  final bool hasPlan;
  final int? elementCount;
  final VoidCallback onTap;

  const FloorPlanMapTile({
    super.key,
    required this.scope,
    required this.title,
    required this.accentColor,
    required this.hasPlan,
    required this.onTap,
    this.subtitle,
    this.elementCount,
  });

  IconData get _icon => switch (scope) {
        FloorPlanScope.site => Icons.map_outlined,
        FloorPlanScope.set => Icons.layers_outlined,
        FloorPlanScope.shot => Icons.grid_on_outlined,
      };

  String get _levelLabel => scope.title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: hasPlan
                    ? accentColor.withValues(alpha: 0.18)
                    : palette.surfaceOverlay.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasPlan ? accentColor : palette.divider,
                ),
              ),
              child: Icon(
                _icon,
                color: hasPlan ? accentColor : palette.textTertiary,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _levelLabel,
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(title, style: AppTypography.titleMedium(palette)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppTypography.bodyMedium(palette)),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    hasPlan
                        ? elementCount != null
                            ? '$elementCount elemento${elementCount == 1 ? '' : 's'}'
                            : 'Plano creado'
                        : 'Sin plano — pulsa para crear',
                    style: AppTypography.caption(palette).copyWith(
                      color: hasPlan ? palette.accent : palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: palette.textTertiary),
          ],
        ),
      ),
    );
  }
}
