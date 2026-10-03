import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Panel de un punto de la biblia: cristal oscuro con rótulo técnico.
///
/// Es la base visual compartida por todas las secciones, tengan o no
/// boceto propio.
class BiblePointPanel extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const BiblePointPanel({
    super.key,
    required this.label,
    required this.child,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  static const double radius = 12;

  static BoxDecoration decoration(AppPalette palette) => BoxDecoration(
        color: palette.surfaceElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.borderBright),
      );

  static TextStyle labelStyle(AppPalette palette) =>
      AppTypography.mono(palette).copyWith(
        fontSize: 11,
        height: 16 / 11,
        letterSpacing: 0.66,
        color: palette.textSecondary,
      );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: decoration(palette),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: palette.accent),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: labelStyle(palette),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
