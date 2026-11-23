import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../camera_plan_element_model.dart';
import 'arch_recipe.dart';

/// Elegir un lugar tipo (AM.8), por grupos.
Future<RecipeKind?> showRecipePicker(BuildContext context) {
  final palette = context.palette;
  return showDialog<RecipeKind>(
    context: context,
    builder: (ctx) => SimpleDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text('Lugar tipo', style: AppTypography.titleMedium(palette)),
      children: [
        for (final group in RecipeGroup.values) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Text(group.label, style: AppTypography.caption(palette)),
          ),
          for (final k in RecipeKind.values.where((k) => k.group == group))
            SimpleDialogOption(
              key: ValueKey('recipe-pick-${k.name}'),
              onPressed: () => Navigator.pop(ctx, k),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k.label, style: AppTypography.bodyLarge(palette)),
                  Text(
                    k.hint,
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(color: palette.textTertiary),
                  ),
                ],
              ),
            ),
        ],
      ],
    ),
  );
}

/// El panel de una receta de lugar (AM.8): sus medidas y opciones. Al
/// soltar un mando, la receta se rehace (lo tocado a mano se respeta).
class RecipeControls extends StatelessWidget {
  final PlanElement element;
  final VoidCallback onPreview;
  final VoidCallback onUpdate;

  const RecipeControls({
    super.key,
    required this.element,
    required this.onPreview,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final el = element;
    final k = ArchRecipe.kind(el);
    final caption = AppTypography.caption(palette);
    String num(double v, double step) {
      final whole = step >= 1;
      final text = v.toStringAsFixed(whole ? 0 : 2).replaceAll('.', ',');
      return whole && !v.isNaN ? text : '$text m';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(k.hint, style: caption.copyWith(color: palette.textTertiary)),
        const SizedBox(height: AppSpacing.sm),
        for (final knob in ArchRecipe.knobs(k))
          if (knob.isNumber)
            Column(
              key: ValueKey('recipe-${knob.key}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(knob.label, style: caption)),
                    Text(
                      num(ArchRecipe.number(el, knob.key), knob.step),
                      style: caption,
                    ),
                  ],
                ),
                Slider(
                  value: ArchRecipe.number(el, knob.key),
                  min: knob.min,
                  max: knob.max,
                  divisions: ((knob.max - knob.min) / knob.step).round().clamp(
                    1,
                    400,
                  ),
                  onChanged: (v) {
                    ArchRecipe.set(el, knob.key, v);
                    onPreview();
                  },
                  onChangeEnd: (_) => onUpdate(),
                ),
              ],
            )
          else if (knob.isChoice)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(knob.label, style: caption),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final (value, label) in knob.options)
                        ChoiceChip(
                          key: ValueKey('recipe-${knob.key}-$value'),
                          label: Text(label),
                          selected: ArchRecipe.value(el, knob.key) == value,
                          onSelected: (_) {
                            ArchRecipe.set(el, knob.key, value);
                            onUpdate();
                          },
                        ),
                    ],
                  ),
                ],
              ),
            )
          else
            SwitchListTile(
              key: ValueKey('recipe-${knob.key}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(knob.label),
              value: ArchRecipe.value(el, knob.key) as bool,
              onChanged: (v) {
                ArchRecipe.set(el, knob.key, v);
                onUpdate();
              },
            ),
        Text(
          'Las piezas que toques a mano se quedan como las dejes.',
          style: caption.copyWith(color: palette.textTertiary),
        ),
      ],
    );
  }
}
