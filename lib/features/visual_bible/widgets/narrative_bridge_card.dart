import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import 'bible_form_widgets.dart';

/// Tarjeta transversal: ¿por qué esta decisión técnica sirve a la narrativa?
class NarrativeBridgeCard extends StatelessWidget {
  final String hint;
  final String? value;
  final ValueChanged<String> onChanged;
  final String title;
  final String? subtitle;

  const NarrativeBridgeCard({
    super.key,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.title = 'Intención narrativa',
    this.subtitle = '¿Qué pretendemos contar con esta decisión técnica?',
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
              Icon(Icons.auto_stories_outlined, color: palette.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.titleMedium(palette),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppTypography.caption(palette).copyWith(
                color: palette.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          BibleTextField(
            label: '',
            hint: hint,
            maxLines: 3,
            initialValue: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
