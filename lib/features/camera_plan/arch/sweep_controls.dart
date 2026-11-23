import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../camera_plan_element_model.dart';
import 'arch_material.dart';
import 'arch_material_picker.dart';
import 'arch_sweep.dart';

/// El panel de un barrido (AM.5): qué perfil, sus medidas, cada cuánto
/// se repite lo que se repite, la curva y el material.
class SweepControls extends StatelessWidget {
  final PlanElement element;
  final double metersPerUnit;
  final VoidCallback onPreview;
  final VoidCallback onUpdate;

  const SweepControls({
    super.key,
    required this.element,
    required this.metersPerUnit,
    required this.onPreview,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final el = element;
    final kind = ArchSweep.kind(el);
    final knobs = ArchSweep.knobs(kind);
    String m(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} m';
    double snap(double v, [double step = 0.05]) => (v / step).round() * step;

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

    final (hMin, hMax, hLabel) = switch (kind) {
      SweepKind.railing => (0.6, 1.5, 'Alto'),
      SweepKind.kerb => (0.05, 0.4, 'Alto'),
      SweepKind.skirting => (0.04, 0.3, 'Alto'),
      SweepKind.cornice => (0.06, 0.6, 'Alto'),
      SweepKind.catenary => (4.0, 7.0, 'Altura del hilo'),
      SweepKind.deck => (0.4, 1.6, 'Alto del pretil'),
      SweepKind.hull => (2.0, 4.0, 'Alto del casco'),
      SweepKind.columns => (1.0, 12.0, 'Alto'),
      SweepKind.seats => (0.6, 1.4, 'Alto del respaldo'),
      _ => (0.02, 10.0, 'Alto'),
    };
    final (wMin, wMax) = switch (kind) {
      SweepKind.deck => (2.0, 30.0),
      SweepKind.hull => (2.0, 4.0),
      SweepKind.columns => (0.1, 2.0),
      SweepKind.cornice => (0.05, 1.0),
      SweepKind.seats => (0.3, 0.8),
      _ => (0.02, 10.0),
    };
    final (zMin, zMax, zLabel) = switch (kind) {
      SweepKind.cornice => (1.0, 12.0, 'Desde'),
      SweepKind.deck => (0.5, 60.0, 'Altura del tablero'),
      SweepKind.hull => (0.0, 2.0, 'Altura del piso'),
      _ => (0.0, 20.0, 'Desde'),
    };
    final curveM = ArchSweep.curve(el) * metersPerUnit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Perfil', style: AppTypography.caption(palette)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final k in SweepKind.values)
              ChoiceChip(
                key: ValueKey('sweep-kind-${k.name}'),
                label: Text(k.label),
                selected: kind == k,
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  ArchSweep.setKind(el, k);
                  onUpdate();
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (knobs.height)
          slider(
            hLabel,
            m(ArchSweep.heightM(el)),
            ArchSweep.heightM(el),
            min: hMin,
            max: hMax,
            key: const ValueKey('sweep-height'),
            onChanged: (v) => el.props[ArchSweep.heightKey] = snap(v, 0.01),
          ),
        if (knobs.width)
          slider(
            'Ancho',
            m(ArchSweep.widthM(el)),
            ArchSweep.widthM(el),
            min: wMin,
            max: wMax,
            onChanged: (v) => el.props[ArchSweep.widthKey] = snap(v, 0.01),
          ),
        if (knobs.base)
          slider(
            zLabel,
            m(ArchSweep.baseM(el)),
            ArchSweep.baseM(el),
            min: zMin,
            max: zMax,
            onChanged: (v) => el.props[ArchSweep.baseKey] = snap(v),
          ),
        if (knobs.every)
          slider(
            'Cada cuánto',
            m(ArchSweep.everyM(el)),
            ArchSweep.everyM(el),
            min: kind == SweepKind.catenary || kind == SweepKind.deck
                ? 5
                : 0.3,
            max: kind == SweepKind.catenary || kind == SweepKind.deck
                ? 80
                : 6,
            key: const ValueKey('sweep-every'),
            onChanged: (v) => el.props[ArchSweep.everyKey] = snap(v),
          ),
        if (ArchSweep.points(el).length == 2)
          slider(
            'Curva',
            m(curveM),
            curveM,
            min: -10,
            max: 10,
            key: const ValueKey('sweep-curve'),
            onChanged: (v) {
              final c = snap(v, 0.1);
              if (c.abs() < 0.05) {
                el.props.remove(ArchSweep.curveKey);
              } else {
                el.props[ArchSweep.curveKey] = c / metersPerUnit;
              }
            },
          ),
        Text(
          ArchSweep.summary(el, metersPerUnit),
          key: const ValueKey('sweep-summary'),
          style: AppTypography.caption(palette),
        ),
        const SizedBox(height: AppSpacing.sm),
        ArchMaterialField(
          label: 'Material',
          value: ArchSweep.mainMaterial(el),
          onChanged: (mat) {
            el.props[ArchMaterials.key] = mat.id;
            onUpdate();
          },
        ),
      ],
    );
  }
}
