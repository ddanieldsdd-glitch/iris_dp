import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/color_edit_scope.dart';
import '../utils/scene_color.dart';
import 'scene_color_picker.dart';

/// Selector de color con alcance (escena / set / localización) y vista previa.
class SceneColorEditor extends StatelessWidget {
  final AppPalette palette;
  final Color effectiveColor;
  final String selectedHex;
  final ColorEditScope scope;
  final ValueChanged<String> onColorChanged;
  final ValueChanged<ColorEditScope> onScopeChanged;
  final int? scenesInSet;
  final int? setsInSite;
  final bool showScopeSelector;

  const SceneColorEditor({
    super.key,
    required this.palette,
    required this.effectiveColor,
    required this.selectedHex,
    required this.scope,
    required this.onColorChanged,
    required this.onScopeChanged,
    this.scenesInSet,
    this.setsInSite,
    this.showScopeSelector = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: effectiveColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: effectiveColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Color actual', style: AppTypography.label(palette)),
                  Text(
                    hexFromColor(effectiveColor),
                    style: AppTypography.caption(palette),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showScopeSelector) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Aplicar cambio a', style: AppTypography.label(palette)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ColorEditScope>(
            segments: ColorEditScope.values
                .map(
                  (s) => ButtonSegment(
                    value: s,
                    label: Text(s.shortLabel),
                  ),
                )
                .toList(),
            selected: {scope},
            onSelectionChanged: (selected) =>
                onScopeChanged(selected.first),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            scope.hint(
              scenesInSet: scenesInSet,
              setsInSite: setsInSite,
            ),
            style: AppTypography.caption(palette),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SceneColorPicker(
          palette: palette,
          selectedHex: selectedHex,
          onChanged: onColorChanged,
          hint: scope == ColorEditScope.location
              ? 'Color base de la localización (los sets usarán variantes).'
              : scope == ColorEditScope.set
                  ? 'Color del set (misma tonalidad, puede diferir en brillo).'
                  : 'Color exclusivo de esta escena.',
        ),
      ],
    );
  }
}
