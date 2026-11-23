import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../camera_plan_element_model.dart';
import '../plan_opening.dart';
import '../plan_segment.dart';
import 'arch_material_picker.dart';
import 'wall_faces.dart';

/// Forma de la pared por arriba (AM.4).
enum WallProfile {
  flat('Recta'),
  slope('Inclinada'),
  gable('Hastial');

  const WallProfile(this.label);
  final String label;

  static WallProfile of(PlanElement el) => PlanSegment.peakM(el) != null
      ? gable
      : PlanSegment.heightEndM(el) != null
      ? slope
      : flat;
}

/// El perfil de la pared y el material de su otra cara (AM.4).
class WallProfileControls extends StatelessWidget {
  final PlanElement element;
  final VoidCallback onPreview;
  final VoidCallback onUpdate;

  const WallProfileControls({
    super.key,
    required this.element,
    required this.onPreview,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final el = element;
    final profile = WallProfile.of(el);
    final base = PlanSegment.heightM(el) ?? PlanSegment.defaultProfileM;

    void setProfile(WallProfile p) {
      el.props
        ..remove(PlanSegment.heightEndKey)
        ..remove(PlanSegment.peakKey)
        ..remove(PlanSegment.peakAtKey);
      switch (p) {
        case WallProfile.flat:
          break;
        case WallProfile.slope:
          el.props[PlanSegment.heightKey] = base;
          el.props[PlanSegment.heightEndKey] = base + 1;
        case WallProfile.gable:
          el.props[PlanSegment.heightKey] = base;
          el.props[PlanSegment.peakKey] = base + 1.5;
      }
      onUpdate();
    }

    Widget slider(
      String label,
      double value, {
      required double min,
      required double max,
      required ValueChanged<double> onChanged,
      String? text,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.caption(palette))),
            Text(
              text ?? '${value.toStringAsFixed(2)} m',
              style: AppTypography.caption(palette),
            ),
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

    final back = WallFaces.back(el);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Por arriba', style: AppTypography.caption(palette)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final p in WallProfile.values)
              ChoiceChip(
                key: ValueKey('wall-profile-${p.name}'),
                label: Text(p.label),
                selected: profile == p,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setProfile(p),
              ),
          ],
        ),
        if (profile == WallProfile.slope)
          slider(
            'Alto al final',
            PlanSegment.heightEndM(el)!,
            min: 0.5,
            max: 30,
            onChanged: (v) =>
                el.props[PlanSegment.heightEndKey] = (v * 20).round() / 20,
          ),
        if (profile == WallProfile.gable) ...[
          slider(
            'Alto del pico',
            PlanSegment.peakM(el)!,
            min: 0.5,
            max: 30,
            onChanged: (v) =>
                el.props[PlanSegment.peakKey] = (v * 20).round() / 20,
          ),
          slider(
            'Dónde está el pico',
            PlanSegment.peakAt(el),
            min: 0.05,
            max: 0.95,
            text: PlanSegment.peakAt(el) == 0.5
                ? 'en medio'
                : '${(PlanSegment.peakAt(el) * 100).round()} %',
            onChanged: (v) =>
                el.props[PlanSegment.peakAtKey] = (v * 20).round() / 20,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        ArchMaterialField(
          label: 'Material del otro lado',
          value: back ?? WallFaces.front(el),
          onChanged: (m) {
            el.props[WallFaces.backKey] = m.id;
            onUpdate();
          },
        ),
        if (back != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('wall-face-same'),
              onPressed: () {
                el.props.remove(WallFaces.backKey);
                onUpdate();
              },
              child: const Text('El mismo en las dos caras'),
            ),
          ),
      ],
    );
  }
}

/// El remate de una puerta, una ventana o un hueco: recto o en arco.
class OpeningArchChips extends StatelessWidget {
  final PlanElement element;
  final VoidCallback onUpdate;

  const OpeningArchChips({
    super.key,
    required this.element,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final current = PlanOpening.arch(element);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Remate', style: AppTypography.caption(palette)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          children: [
            for (final a in const [
              null,
              PlanOpening.archRound,
              PlanOpening.archSegmental,
            ])
              ChoiceChip(
                key: ValueKey('opening-arch-${a ?? 'flat'}'),
                label: Text(PlanOpening.archLabel(a)),
                selected: current == a,
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  if (a == null) {
                    element.props.remove(PlanOpening.archKey);
                  } else {
                    element.props[PlanOpening.archKey] = a;
                  }
                  onUpdate();
                },
              ),
          ],
        ),
      ],
    );
  }
}
