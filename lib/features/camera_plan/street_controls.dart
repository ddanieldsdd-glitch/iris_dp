import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_element_model.dart';
import 'light/street_lamp.dart';
import 'plan_segment.dart';
import 'plan_street.dart';

/// Panel de una calle (CA.6): plantillas, perfil en metros y farolas.
class StreetControls extends StatelessWidget {
  final PlanElement element;
  final double metersPerUnit;
  final VoidCallback onPreview;
  final VoidCallback onUpdate;

  /// Añade piezas nuevas a la planta (farolas, paredes de fachada).
  final ValueChanged<List<PlanElement>>? onAddElements;

  const StreetControls({
    super.key,
    required this.element,
    required this.metersPerUnit,
    required this.onPreview,
    required this.onUpdate,
    this.onAddElements,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final el = element;
    final p = StreetProfile.of(el);
    String m(double v) => '${v.toStringAsFixed(v < 1 ? 2 : 1)} m';
    final caption = AppTypography.caption(palette);
    final hint = caption.copyWith(color: palette.textTertiary);

    Widget slider(
      String label,
      String value,
      double current,
      double min,
      double max,
      String key, {
      double step = 0.1,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: caption)),
            Text(value, style: caption),
          ],
        ),
        Slider(
          value: current.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) {
            el.props[key] = (v / step).round() * step;
            onPreview();
          },
          onChangeEnd: (_) => onUpdate(),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Plantilla', style: caption),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final (name, preset) in kStreetPresets)
              ActionChip(
                label: Text(name),
                onPressed: () {
                  preset.writeTo(el);
                  onUpdate();
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Ancho total ${m(p.widthM)}'
          '${p.singleLevel ? ' · plataforma única' : ''}.',
          style: hint,
        ),
        slider('Calzada', m(p.roadM), p.roadM, 2, 30, StreetProfile.roadKey),
        slider(
          'Acera izquierda',
          m(p.walkLeftM),
          p.walkLeftM,
          0,
          10,
          StreetProfile.walkLeftKey,
        ),
        slider(
          'Acera derecha',
          m(p.walkRightM),
          p.walkRightM,
          0,
          10,
          StreetProfile.walkRightKey,
        ),
        slider(
          'Bordillo',
          p.singleLevel ? 'sin bordillo' : '${(p.kerbM * 100).round()} cm',
          p.kerbM,
          0,
          0.3,
          StreetProfile.kerbKey,
          step: 0.01,
        ),
        slider(
          'Fachada izquierda',
          p.facadeLeftM <= 0 ? 'sin fachada' : m(p.facadeLeftM),
          p.facadeLeftM,
          0,
          40,
          StreetProfile.facadeLeftKey,
          step: 0.5,
        ),
        slider(
          'Fachada derecha',
          p.facadeRightM <= 0 ? 'sin fachada' : m(p.facadeRightM),
          p.facadeRightM,
          0,
          40,
          StreetProfile.facadeRightKey,
          step: 0.5,
        ),
        Text(
          'La izquierda es la de quien va del inicio al final de la calle. '
          'Planta baja de unos 4 m; cada piso, unos 3 m.',
          style: hint,
        ),
        const Divider(),
        Text('Farolas', style: caption),
        SegmentedButton<String>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: 'both', label: Text('A los dos lados')),
            ButtonSegment(value: 'left', label: Text('Izq.')),
            ButtonSegment(value: 'right', label: Text('Der.')),
          ],
          selected: {p.lampSide == 'none' ? 'both' : p.lampSide},
          onSelectionChanged: (v) {
            el.props[StreetProfile.lampSideKey] = v.first;
            onUpdate();
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<String>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(
              value: StreetLamp.styleArm,
              label: Text('De brazo en fachada'),
            ),
            ButtonSegment(
              value: StreetLamp.stylePole,
              label: Text('De báculo'),
            ),
          ],
          selected: {p.lampStyle},
          onSelectionChanged: (v) {
            el.props[StreetProfile.lampStyleKey] = v.first;
            onUpdate();
          },
        ),
        slider(
          'Cada',
          m(p.lampEveryM),
          p.lampEveryM,
          5,
          50,
          StreetProfile.lampEveryKey,
          step: 0.5,
        ),
        slider(
          'Altura',
          m(p.lampHeightM),
          p.lampHeightM,
          2.5,
          10,
          StreetProfile.lampHeightKey,
          step: 0.1,
        ),
        slider(
          'Temperatura',
          '${p.lampKelvin.round()} K',
          p.lampKelvin,
          1800,
          6500,
          StreetProfile.lampKelvinKey,
          step: 100,
        ),
        if (onAddElements != null) ...[
          const SizedBox(height: AppSpacing.xs),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.light_outlined, size: 16),
            label: const Text('Poner farolas'),
            onPressed: p.lampSide == 'none'
                ? null
                : () => onAddElements!(p.lamps(el, metersPerUnit)),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            icon: const Icon(Icons.call_split, size: 16),
            label: const Text('Separar fachadas en paredes'),
            onPressed: p.facadeLeftM <= 0 && p.facadeRightM <= 0
                ? null
                : () {
                    final walls = facadeWalls(el, metersPerUnit);
                    el.props
                      ..[StreetProfile.facadeLeftKey] = 0.0
                      ..[StreetProfile.facadeRightKey] = 0.0;
                    onAddElements!(walls);
                    onUpdate();
                  },
          ),
          Text(
            'Cada farola queda suelta para moverla o cambiarle la luz. Las '
            'paredes separadas aceptan puertas y ventanas como cualquier otra.',
            style: hint,
          ),
        ],
      ],
    );
  }

  /// Las fachadas como paredes normales, con su alto y su grosor.
  static List<PlanElement> facadeWalls(PlanElement street, double mpu) => [
    for (final f in StreetProfile.of(street).facades(street, mpu))
      for (var i = 1; i < f.line.length; i++)
        PlanSegment.create(start: f.line[i - 1], end: f.line[i])
          ..props[PlanSegment.heightKey] = f.heightM
          ..props[PlanSegment.thicknessKey] = StreetProfile.facadeThicknessM,
  ];
}
