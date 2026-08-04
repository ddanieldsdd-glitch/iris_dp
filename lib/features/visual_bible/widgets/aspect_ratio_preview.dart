import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';

/// Preview proporcional del aspect ratio.
class AspectRatioPreview extends StatelessWidget {
  final String? aspectRatio;
  final String? label;

  const AspectRatioPreview({
    super.key,
    required this.aspectRatio,
    this.label,
  });

  (double, double)? _parseRatio() {
    if (aspectRatio == null) return null;
    final parts = aspectRatio!.split(':');
    if (parts.length != 2) return null;
    final w = double.tryParse(parts[0]);
    final h = double.tryParse(parts[1]);
    if (w == null || h == null || h == 0) return null;
    return (w, h);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final parsed = _parseRatio();
    if (parsed == null) return const SizedBox.shrink();

    const maxW = 280.0;
    final (w, h) = parsed;
    final frameW = w >= h ? maxW : maxW * (w / h);
    final frameH = w >= h ? maxW * (h / w) : maxW;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: frameW,
            height: frameH,
            decoration: BoxDecoration(
              color: palette.background,
              border: Border.all(color: palette.accent, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                aspectRatio!,
                style: AppTypography.label(palette).copyWith(
                  color: palette.textTertiary,
                ),
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              label!,
              textAlign: TextAlign.center,
              style: AppTypography.caption(palette).copyWith(
                color: palette.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
