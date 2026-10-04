import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_element_model.dart';
import 'light/exposure.dart';
import 'light/modifiers.dart';
import 'light/photometry.dart';
import 'light/plan_light.dart';

/// Controles fotométricos de una luz: potencia, dato medido, difusión, red
/// y gelatina, con la lectura de lo que da a tres distancias.
class PlanLightControls extends StatefulWidget {
  final PlanElement element;
  final ExposureSettings exposure;

  /// Guarda el cambio.
  final VoidCallback onUpdate;

  const PlanLightControls({
    super.key,
    required this.element,
    required this.onUpdate,
    this.exposure = const ExposureSettings(),
  });

  @override
  State<PlanLightControls> createState() => _PlanLightControlsState();
}

class _PlanLightControlsState extends State<PlanLightControls> {
  late final _watts = TextEditingController();
  late final _lux = TextEditingController();
  late final _meters = TextEditingController();

  PlanElement get _el => widget.element;

  @override
  void initState() {
    super.initState();
    _syncFields();
  }

  @override
  void didUpdateWidget(PlanLightControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.element != widget.element) _syncFields();
  }

  void _syncFields() {
    String text(String key) {
      final v = (_el.props[key] as num?)?.toDouble();
      if (v == null) return '';
      return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
    }

    _watts.text = text(PlanLight.wattsKey);
    _lux.text = text(PlanLight.measuredLuxKey);
    _meters.text = text(PlanLight.measuredMetersKey);
  }

  @override
  void dispose() {
    _watts.dispose();
    _lux.dispose();
    _meters.dispose();
    super.dispose();
  }

  void _setNumber(String key, String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) {
      _el.props.remove(key);
    } else {
      _el.props[key] = value;
    }
    setState(() {});
    widget.onUpdate();
  }

  /// Modificador elegido de un tipo; solo cabe uno por tipo.
  LightModifier? _current(ModifierKind kind, List<LightModifier> all) {
    for (final m in all) {
      if (m.kind == kind) return m;
    }
    return null;
  }

  void _setModifier(ModifierKind kind, String? id) {
    final ids = [
      for (final m in PlanLight.of(_el)?.modifiers ?? const <LightModifier>[])
        if (m.kind != kind) m.id,
      ?id,
    ];
    if (ids.isEmpty) {
      _el.props.remove(PlanLight.modifiersKey);
    } else {
      _el.props[PlanLight.modifiersKey] = ids;
    }
    setState(() {});
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final light = PlanLight.of(_el);
    if (light == null) return const SizedBox.shrink();
    final defaults = PlanLight.defaultsFor(_el.lightType);

    Widget number(
      TextEditingController controller,
      String key,
      String hint, {
      String? suffix,
    }) => TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: AppTypography.bodyMedium(palette),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        suffixText: suffix,
      ),
      onSubmitted: (v) => _setNumber(key, v),
      onTapOutside: (_) => _setNumber(key, controller.text),
    );

    Widget picker(String label, ModifierKind kind) {
      final current = _current(kind, light.modifiers);
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.caption(palette)),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: current?.id,
              decoration: const InputDecoration(isDense: true),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Ninguna'),
                ),
                for (final m in LightModifier.ofKind(kind))
                  DropdownMenuItem<String?>(
                    value: m.id,
                    child: Text(
                      '${m.name} · −${formatStopDifference(m.stopsLost).substring(1)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) => _setModifier(kind, id),
            ),
            if (current?.reference != null)
              Text(
                current!.reference!,
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.textTertiary, fontSize: 10),
              ),
          ],
        ),
      );
    }

    final lost = light.stopsLost;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Potencia', style: AppTypography.caption(palette)),
        number(
          _watts,
          PlanLight.wattsKey,
          '${defaults.watts.round()} (típica)',
          suffix: 'W · ${light.tech.label}',
        ),
        picker('Difusión', ModifierKind.diffusion),
        picker('Red', ModifierKind.scrim),
        picker('Gelatina', ModifierKind.correction),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Dato medido o del fabricante',
          style: AppTypography.caption(palette),
        ),
        Row(
          children: [
            Expanded(
              child: number(
                _lux,
                PlanLight.measuredLuxKey,
                'lux',
                suffix: 'lx',
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('a'),
            ),
            Expanded(
              child: number(
                _meters,
                PlanLight.measuredMetersKey,
                'metros',
                suffix: 'm',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: palette.surfaceOverlay,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lo que da en el eje',
                      style: AppTypography.caption(palette),
                    ),
                  ),
                  _StatusTag(status: light.source.status),
                ],
              ),
              const SizedBox(height: 4),
              for (final meters in const [2.0, 4.0, 8.0])
                Text(
                  'a ${meters.round()} m: '
                  '${formatLux(light.source.illuminance(meters))} · '
                  '${formatStop(widget.exposure.stopFor(light.source.illuminance(meters)))}',
                  style: AppTypography.bodyMedium(palette),
                ),
              const SizedBox(height: 4),
              Text(
                [
                  'ISO ${widget.exposure.iso.round()}',
                  '${widget.exposure.shutterDeg.round()}°',
                  '${widget.exposure.fps.round()} fps',
                  if (lost > 0.15)
                    '−${formatStopDifference(lost).substring(1)} por '
                        'regulación y filtros',
                ].join(' · '),
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.textTertiary, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _StatusTag extends StatelessWidget {
  final PhotometryStatus status;

  const _StatusTag({required this.status});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = status == PhotometryStatus.estimated
        ? palette.warning
        : palette.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: AppTypography.caption(
          palette,
        ).copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
