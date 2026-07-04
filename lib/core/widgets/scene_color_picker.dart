import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/scene_color.dart';

/// Selector compacto de color representativo de escena.
class SceneColorPicker extends StatelessWidget {
  final String? selectedHex;
  final ValueChanged<String> onChanged;
  final AppPalette palette;
  final String? hint;

  const SceneColorPicker({
    super.key,
    required this.selectedHex,
    required this.onChanged,
    required this.palette,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final selected = sceneColorForPicker(selectedHex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color de escena', style: AppTypography.label(palette)),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint!, style: AppTypography.caption(palette)),
        ] else ...[
          const SizedBox(height: 4),
          Text(
            'Neutro por defecto. Más adelante podrá heredarse de la localización.',
            style: AppTypography.caption(palette),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _ColorSwatch(
              hex: kSceneColorNeutral,
              selected: selected == kSceneColorNeutral,
              onTap: () => onChanged(kSceneColorNeutral),
            ),
            for (final hex in kSceneColorPalette)
              _ColorSwatch(
                hex: hex,
                selected: hex == selected,
                onTap: () => onChanged(hex),
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(hex)!;
    final isNeutral = hex == kSceneColorNeutral;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Colors.white
                  : (isNeutral ? color.withValues(alpha: 0.4) : Colors.transparent),
              width: isNeutral ? 1.5 : 2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.55),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  size: 14,
                  color: isNeutral ? Colors.white70 : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}
