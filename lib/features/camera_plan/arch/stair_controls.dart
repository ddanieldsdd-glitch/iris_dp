import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../camera_plan_element_model.dart';
import 'arch_material.dart';
import 'arch_material_picker.dart';
import 'arch_stair.dart';

/// El panel de una escalera o una rampa (AM.6): forma, medidas, hacia
/// dónde gira, cuántos peldaños salen y su material.
class StairControls extends StatelessWidget {
  final PlanElement element;
  final VoidCallback onPreview;
  final VoidCallback onUpdate;

  const StairControls({
    super.key,
    required this.element,
    required this.onPreview,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final el = element;
    final shape = ArchStair.shape(el);
    String m(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} m';
    String cm(double v) =>
        '${(v * 100).toStringAsFixed(1).replaceAll('.', ',').replaceAll(',0', '')} cm';

    Widget slider(
      String label,
      String text,
      double value, {
      required double min,
      required double max,
      required ValueChanged<double> onChanged,
      Key? key,
    }) => Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.caption(palette))),
            Text(text, style: AppTypography.caption(palette)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) {
            onChanged(v);
            onPreview();
          },
          onChangeEnd: (_) => onUpdate(),
        ),
      ],
    );

    double snap(double v, [double step = 0.05]) => (v / step).round() * step;
    final warning = ArchStair.warning(el);
    final turns = shape == StairShape.l ||
        shape == StairShape.u ||
        shape == StairShape.spiral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Forma', style: AppTypography.caption(palette)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final s in StairShape.values)
              ChoiceChip(
                key: ValueKey('stair-shape-${s.name}'),
                label: Text(s.label),
                selected: shape == s,
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  el.props[ArchStair.shapeKey] = s.name;
                  // Una rampa con la altura de un piso no se sube: se
                  // deja al 8 %.
                  if (s == StairShape.ramp && ArchStair.slopePct(el) > 12) {
                    el.props[ArchStair.riseKey] =
                        snap(ArchStair.runM(el) * 0.08, 0.01);
                  }
                  onUpdate();
                },
              ),
          ],
        ),
        if (turns) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 6,
            children: [
              for (final (left, label) in const [
                (true, 'Gira a la izquierda'),
                (false, 'Gira a la derecha'),
              ])
                ChoiceChip(
                  key: ValueKey('stair-turn-${left ? 'left' : 'right'}'),
                  label: Text(label),
                  selected: ArchStair.turnsLeft(el) == left,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    el.props[ArchStair.turnKey] = left ? 'left' : 'right';
                    onUpdate();
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        slider(
          'Ancho de paso',
          m(ArchStair.widthM(el)),
          ArchStair.widthM(el),
          min: 0.6,
          max: 4,
          onChanged: (v) => el.props[ArchStair.widthKey] = snap(v),
        ),
        slider(
          shape == StairShape.ramp ? 'Altura que sube' : 'Altura que salva',
          m(ArchStair.riseM(el)),
          ArchStair.riseM(el),
          min: 0.05,
          max: 8,
          onChanged: (v) => el.props[ArchStair.riseKey] = snap(v, 0.01),
        ),
        slider(
          switch (shape) {
            StairShape.spiral => 'Radio',
            StairShape.l || StairShape.u => 'Largo del primer tramo',
            _ => 'Largo',
          },
          m(ArchStair.runM(el)),
          ArchStair.runM(el),
          min: shape == StairShape.spiral ? 0.6 : 0.3,
          max: shape == StairShape.spiral ? 3 : 30,
          onChanged: (v) => el.props[ArchStair.runKey] = snap(v),
        ),
        if (shape == StairShape.spiral)
          slider(
            'Lo que gira',
            '${ArchStair.sweepDeg(el).round()}°',
            ArchStair.sweepDeg(el),
            min: 90,
            max: 720,
            onChanged: (v) => el.props[ArchStair.sweepKey] = snap(v, 15),
          ),
        Text(
          shape == StairShape.ramp
              ? 'Pendiente del ${ArchStair.slopePct(el).toStringAsFixed(1).replaceAll('.', ',')} %.'
              : '${ArchStair.risers(el)} peldaños: contrahuella de '
                    '${cm(ArchStair.riserM(el))} y huella de '
                    '${cm(ArchStair.treadM(el))}.',
          key: const ValueKey('stair-summary'),
          style: AppTypography.caption(palette),
        ),
        if (warning != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              warning,
              key: const ValueKey('stair-warning'),
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.warning),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        ArchMaterialField(
          label: 'Material',
          value: ArchStair.material(el),
          onChanged: (mat) {
            el.props[ArchMaterials.key] = mat.id;
            onUpdate();
          },
        ),
      ],
    );
  }
}
