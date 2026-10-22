import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../camera_plan_element_model.dart';
import 'plan_rig.dart';

/// Propiedades de una estructura: truss (perfil, tamaño, altura y largo),
/// motor o ground support (carga de trabajo) y pilar (forma, grosor y
/// altura).
class RigControls extends StatelessWidget {
  final PlanElement element;
  final double metersPerUnit;

  /// Repinta sin guardar (mientras se arrastra un control).
  final VoidCallback onPreview;

  /// Guarda el cambio.
  final VoidCallback onUpdate;

  const RigControls({
    super.key,
    required this.element,
    required this.metersPerUnit,
    required this.onPreview,
    required this.onUpdate,
  });

  static bool appliesTo(PlanElement el) => switch (RigTypeCodec.of(el)) {
    RigType.truss ||
    RigType.motor ||
    RigType.groundSupport ||
    RigType.pillar => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final el = element;

    Widget slider(
      String label,
      String value, {
      required double current,
      required double min,
      required double max,
      required double step,
      required ValueChanged<double> onChanged,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.caption(palette))),
            Text(value, style: AppTypography.caption(palette)),
          ],
        ),
        Slider(
          value: current.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) {
            onChanged((v / step).round() * step);
            onPreview();
          },
          onChangeEnd: (_) => onUpdate(),
        ),
      ],
    );

    Widget segmented<T>(
      T value,
      List<(T, String)> options,
      ValueChanged<T> on,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SegmentedButton<T>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          for (final (v, label) in options)
            ButtonSegment(value: v, label: Text(label)),
        ],
        selected: {value},
        onSelectionChanged: (v) {
          on(v.first);
          onUpdate();
        },
      ),
    );

    Widget note(String text) => Text(
      text,
      style: AppTypography.caption(
        palette,
      ).copyWith(color: palette.textTertiary),
    );

    String m(double v) => '${v.toStringAsFixed(2)} m';

    switch (RigTypeCodec.of(el)) {
      case RigType.truss:
        final lengthM = PlanTruss.length(el) * metersPerUnit;
        final pieces = PlanTruss.pieces(el, metersPerUnit);
        final profile = PlanTruss.profile(el);
        final size = PlanTruss.sizeCm(el);
        final weight = PlanTruss.kgPerMeter(profile, size) * lengthM;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            segmented<TrussProfile>(profile, const [
              (TrussProfile.square, 'Cuadrado'),
              (TrussProfile.triangle, 'Triangular'),
              (TrussProfile.ladder, 'Escalera'),
            ], (p) => el.props[PlanTruss.profileKey] = p.name),
            segmented<int>(size, const [
              (30, '30'),
              (40, '40'),
              (52, '52'),
            ], (s) => el.props[PlanTruss.sizeKey] = s),
            slider(
              'Cuerda inferior',
              m(PlanTruss.lowM(el)),
              current: PlanTruss.lowM(el),
              min: 1,
              max: 20,
              step: 0.05,
              onChanged: (v) => el.props[PlanTruss.lowKey] = v,
            ),
            slider(
              'Largo',
              m(lengthM),
              current: lengthM,
              min: 0.5,
              max: 40,
              step: 0.5,
              onChanged: (v) => PlanTruss.setLengthM(el, v, metersPerUnit),
            ),
            Text(
              'Tramos: ${pieces.pieces.map(_short).join(' + ')}'
              '${pieces.rest > 0 ? ' · faltan ${m(pieces.rest)}' : ''}',
              style: AppTypography.bodyMedium(palette),
            ),
            note(
              'Unos ${weight.round()} kg de truss. Suelta una luz cerca y '
              'se cuelga de él; sus motores y torres lo siguen al moverlo.',
            ),
          ],
        );
      case RigType.motor || RigType.groundSupport:
        final motor = RigTypeCodec.of(el) == RigType.motor;
        final wll = PlanRigPoint.wllKg(el);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            segmented<bool>(
              motor,
              const [(true, 'Motor'), (false, 'Ground support')],
              (v) {
                el.label = (v ? RigType.motor : RigType.groundSupport).dbValue;
                el.props.remove(PlanRigPoint.wllKey);
              },
            ),
            if (motor)
              segmented<double>(
                const [250.0, 500.0, 1000.0, 2000.0].contains(wll) ? wll : 500,
                const [
                  (250.0, '250 kg'),
                  (500.0, '500 kg'),
                  (1000.0, '1 t'),
                  (2000.0, '2 t'),
                ],
                (v) => el.props[PlanRigPoint.wllKey] = v,
              )
            else
              slider(
                'Carga de la torre',
                '${wll.round()} kg',
                current: wll,
                min: 100,
                max: 2000,
                step: 50,
                onChanged: (v) => el.props[PlanRigPoint.wllKey] = v,
              ),
            note(
              el.props[PlanRigPoint.trussKey] == null
                  ? 'No sujeta ningún truss.'
                  : 'Sujeta su truss a '
                        '${m((el.props[PlanRigPoint.alongKey] as num?)?.toDouble() ?? 0)} '
                        'de su inicio.',
            ),
          ],
        );
      case RigType.pillar:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            segmented<bool>(
              PlanPillar.isRound(el),
              const [(true, 'Redondo'), (false, 'Cuadrado')],
              (v) => el.props[PlanPillar.shapeKey] = v
                  ? PlanPillar.round
                  : PlanPillar.square,
            ),
            slider(
              PlanPillar.isRound(el) ? 'Diámetro' : 'Lado',
              '${(PlanPillar.sizeM(el) * 100).round()} cm',
              current: PlanPillar.sizeM(el),
              min: 0.05,
              max: 2,
              step: 0.01,
              onChanged: (v) => el.props[PlanPillar.sizeKey] = v,
            ),
            slider(
              'Altura',
              m(PlanPillar.heightM(el)),
              current: PlanPillar.heightM(el),
              min: 0.5,
              max: 20,
              step: 0.05,
              onChanged: (v) => el.props[PlanPillar.heightKey] = v,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  static String _short(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
