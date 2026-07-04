import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_constants.dart';
import 'light_symbols.dart';

/// Celda del grid de luces — alineada con AppCard / paleta de la app.
class LightGridTile extends StatelessWidget {
  final LightType type;
  final VoidCallback onTap;

  const LightGridTile({
    super.key,
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.surfaceElevated,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.divider),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LightSymbolPreview(type: type, size: 36),
              const SizedBox(height: 4),
              Text(
                type.label,
                style: AppTypography.caption(palette).copyWith(fontSize: 9),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
