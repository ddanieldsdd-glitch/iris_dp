import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_element_model.dart';
import 'light_beam.dart';

/// El color de un aparato RGB: apagado, la luz es blanca y manda la
/// temperatura; encendido, la planta se pinta con este color.
class PlanLightColorControl extends StatelessWidget {
  final PlanElement element;
  final VoidCallback onPreview;
  final VoidCallback onUpdate;

  const PlanLightColorControl({
    super.key,
    required this.element,
    required this.onPreview,
    required this.onUpdate,
  });

  static const presets = <(String, int)>[
    ('Rojo', 0xFF1E1E),
    ('Ámbar', 0xFF9A00),
    ('Verde', 0x00E05A),
    ('Cian', 0x00D8FF),
    ('Azul', 0x1E3CFF),
    ('Violeta', 0x8A2BFF),
    ('Magenta', 0xFF1EB4),
  ];

  void _set(int? rgb, {bool preview = false}) {
    if (rgb == null) {
      element.props.remove(LightBeam.rgbKey);
    } else {
      element.props[LightBeam.rgbKey] = rgb;
    }
    preview ? onPreview() : onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = AppTypography.caption(palette);
    final rgb = LightBeam.of(element)?.rgb;
    final hsv = rgb == null ? null : HSVColor.fromColor(Color(0xFF000000 | rgb));

    int compose(double hue, double saturation) =>
        HSVColor.fromAHSV(1, hue, saturation, 1).toColor().toARGB32() &
        0xFFFFFF;

    Widget slider(
      String name,
      String value,
      double current,
      double min,
      double max,
      int Function(double) toRgb,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(name, style: label)),
            Text(value, style: label),
          ],
        ),
        Slider(
          value: current.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) => _set(toRgb(v), preview: true),
          onChangeEnd: (_) => onUpdate(),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Color RGB', style: label)),
            Switch(
              value: rgb != null,
              onChanged: (on) => _set(on ? presets.first.$2 : null),
            ),
          ],
        ),
        if (hsv != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (name, value) in presets)
                Tooltip(
                  message: name,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _set(value),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF000000 | value),
                        border: Border.all(
                          color: value == rgb
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          slider(
            'Tono',
            '${hsv.hue.round()}°',
            hsv.hue,
            0,
            359,
            (v) => compose(v, hsv.saturation),
          ),
          // Sin bajar de aquí: a saturación cero se perdería el tono.
          slider(
            'Saturación',
            '${(hsv.saturation * 100).round()} %',
            hsv.saturation,
            0.05,
            1,
            (v) => compose(hsv.hue, v),
          ),
        ],
      ],
    );
  }
}
