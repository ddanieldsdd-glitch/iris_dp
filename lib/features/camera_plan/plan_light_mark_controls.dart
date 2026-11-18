import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_element_model.dart';
import 'light_beam.dart';
import 'plan_marks.dart';

/// Cómo está un foco en una de sus posiciones (PL.3): encendido,
/// intensidad y temperatura desde esa marca. Lo que no se toca sigue como
/// en la anterior.
class PlanLightMarkControls extends StatelessWidget {
  final PlanElement element;

  /// La marca de `pathPoints` (la posición [index] + 2).
  final int index;
  final VoidCallback onUpdate;

  const PlanLightMarkControls({
    super.key,
    required this.element,
    required this.index,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final here = LightBeam.of(PlanMarks.atPosition(element, index + 1));
    if (here == null) return const SizedBox.shrink();
    final changes = PlanMarks.lightChangeLabels(element, index);
    void set(String key, Object? value) {
      PlanMarks.setLightAt(element, index, key, value);
      onUpdate();
    }

    final caption = AppTypography.caption(palette).copyWith(fontSize: 10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(
            'En la posición ${index + 2}',
            style: AppTypography.label(palette),
          ),
        ),
        Text(
          changes.isEmpty
              ? 'Igual que en la posición ${index + 1}.'
              : 'Al llegar: ${changes.join(', ')}.',
          style: caption.copyWith(
            color: changes.isEmpty ? palette.textTertiary : palette.accent,
          ),
        ),
        SwitchListTile(
          key: const ValueKey('light-mark-on'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Encendido'),
          value: !here.off,
          onChanged: (on) => set(LightBeam.offKey, !on),
        ),
        if (!here.off) ...[
          Text('Intensidad ${here.intensity.round()} %', style: caption),
          Slider(
            key: const ValueKey('light-mark-intensity'),
            value: here.intensity.clamp(0, 100).toDouble(),
            max: 100,
            divisions: 20,
            label: '${here.intensity.round()} %',
            onChanged: (v) => set(LightBeam.intensityKey, v.roundToDouble()),
          ),
          if (here.rgb == null) ...[
            Text('Temperatura ${here.cct.round()} K', style: caption),
            Slider(
              key: const ValueKey('light-mark-cct'),
              value: here.cct.clamp(1800, 12000).toDouble(),
              min: 1800,
              max: 12000,
              divisions: 102,
              label: '${here.cct.round()} K',
              onChanged: (v) => set(LightBeam.cctKey, (v / 100).round() * 100),
            ),
          ],
        ],
        if (PlanMarks.lightChangeAt(element, index).isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                for (final key in PlanMarks.lightValueKeys) {
                  PlanMarks.setLightAt(element, index, key, null);
                }
                onUpdate();
              },
              child: Text(
                'Como en la posición ${index + 1}',
                style: caption.copyWith(color: palette.textSecondary),
              ),
            ),
          ),
      ],
    );
  }
}
