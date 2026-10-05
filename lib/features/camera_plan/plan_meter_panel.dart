import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_element_model.dart';
import 'light/exposure.dart';
import 'light/meter.dart';

/// Lo que lee el fotómetro en un punto: diafragma, lux, lo que sobra o
/// falta, clave y relleno, y lo que aporta cada fuente.
class PlanMeterPanel extends StatelessWidget {
  final MeterReading reading;
  final ExposureSettings exposure;

  const PlanMeterPanel({
    super.key,
    required this.reading,
    required this.exposure,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final r = reading;
    final caption = AppTypography.caption(palette);
    final dim = caption.copyWith(color: palette.textTertiary, fontSize: 10);

    Widget row(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyMedium(
              palette,
            ).copyWith(color: color ?? palette.textPrimary),
          ),
        ],
      ),
    );

    String side(MeterSide s) => s.lux < 0.5
        ? '—'
        : '${formatStop(exposure.stopFor(s.lux))} · ${formatLux(s.lux)}';

    final over = r.stopsOverTarget;
    final verdict = r.lux < 0.5
        ? 'No llega luz'
        : over.abs() < 0.17
        ? 'En su punto para ${formatStop(r.targetStop)}'
        : over > 0
        ? 'Sobran ${formatStopDifference(over).substring(1)} stops '
              'para ${formatStop(r.targetStop)}'
        : 'Faltan ${formatStopDifference(over).substring(1)} stops '
              'para ${formatStop(r.targetStop)}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surfaceOverlay,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatStop(r.stop),
                style: AppTypography.titleLarge(palette),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(formatLux(r.lux), style: caption),
                ),
              ),
              if (r.estimated)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: palette.warning.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'estimado',
                    style: caption.copyWith(
                      color: palette.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            verdict,
            style: caption.copyWith(
              color: r.lux < 0.5 || over.abs() >= 0.17
                  ? palette.warning
                  : palette.success,
            ),
          ),
          Text(
            [
              'ISO ${exposure.iso.round()}',
              '${exposure.shutterDeg.round()}°',
              '${exposure.fps.round()} fps',
              if (exposure.ndStops > 0)
                'ND ${exposure.ndStops.toStringAsFixed(1)}',
              if (r.cct != null) '${(r.cct! / 50).round() * 50} K',
            ].join(' · '),
            style: dim,
          ),
          if (r.lux >= 0.5) ...[
            const Divider(height: AppSpacing.lg),
            if (r.hasCamera) ...[
              row(
                'Clave (${r.keyIsLeft ? 'izquierda' : 'derecha'} de cámara)',
                side(r.key),
              ),
              row('Relleno', side(r.fill)),
              row('Contra', side(r.back)),
              row(
                'Contraste',
                r.fill.lux < 0.5
                    ? r.ratioLabel
                    : '${r.ratioLabel} · '
                          '${formatStopDifference(r.contrastStops).substring(1)}'
                          ' stops',
                color: palette.accent,
              ),
            ] else
              Text(
                'Pon una cámara en la planta para separar clave, relleno y '
                'contra.',
                style: dim,
              ),
            const Divider(height: AppSpacing.lg),
            Text('Qué aporta cada fuente', style: caption),
            const SizedBox(height: 2),
            for (final part in r.parts.take(8))
              row(
                part.light.label,
                '${formatStop(exposure.stopFor(part.lux))} · '
                '${formatLux(part.lux)}',
              ),
            if (r.parts.length > 8)
              Text('y ${r.parts.length - 8} más', style: dim),
          ],
        ],
      ),
    );
  }
}

/// Ajustes de exposición de una cámara de la planta: con ellos se lee la
/// luz en diafragmas.
class PlanCameraExposureControls extends StatefulWidget {
  final PlanElement camera;

  /// Lo que se usa si la cámara no dice otra cosa (los datos del plano).
  final ExposureSettings fallback;
  final double fallbackStop;
  final VoidCallback onUpdate;

  const PlanCameraExposureControls({
    super.key,
    required this.camera,
    required this.fallback,
    required this.fallbackStop,
    required this.onUpdate,
  });

  @override
  State<PlanCameraExposureControls> createState() =>
      _PlanCameraExposureControlsState();
}

class _PlanCameraExposureControlsState
    extends State<PlanCameraExposureControls> {
  final _controllers = <String, TextEditingController>{};

  static const _fields = [
    (CameraExposure.isoKey, 'ISO', ''),
    (CameraExposure.shutterKey, 'Obturación', '°'),
    (CameraExposure.fpsKey, 'Fotogramas', 'fps'),
    (CameraExposure.ndKey, 'ND', 'stops'),
    (CameraExposure.stopKey, 'Diafragma de trabajo', 'T'),
  ];

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PlanCameraExposureControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera != widget.camera) _sync();
  }

  void _sync() {
    for (final (key, _, _) in _fields) {
      final v = (widget.camera.props[key] as num?)?.toDouble();
      (_controllers[key] ??= TextEditingController()).text = v == null
          ? ''
          : v == v.roundToDouble()
          ? v.toStringAsFixed(0)
          : v.toString();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _hint(String key) {
    final f = widget.fallback;
    final v = switch (key) {
      CameraExposure.isoKey => f.iso,
      CameraExposure.shutterKey => f.shutterDeg,
      CameraExposure.fpsKey => f.fps,
      CameraExposure.ndKey => f.ndStops,
      _ => widget.fallbackStop,
    };
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  }

  void _commit(String key, String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    final previous = widget.camera.props[key];
    if (value == null ||
        value < 0 ||
        (value == 0 && key != CameraExposure.ndKey)) {
      widget.camera.props.remove(key);
    } else {
      widget.camera.props[key] = value;
    }
    if (previous != widget.camera.props[key]) widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Exposición', style: AppTypography.label(palette)),
        Text(
          'Con estos ajustes se lee la luz de la planta en diafragmas.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textTertiary, fontSize: 10),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final (key, label, suffix) in _fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: AppTypography.caption(palette)),
                ),
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _controllers[key],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.end,
                    style: AppTypography.bodyMedium(palette),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _hint(key),
                      suffixText: suffix.isEmpty ? null : suffix,
                    ),
                    onSubmitted: (v) => _commit(key, v),
                    onTapOutside: (_) => _commit(key, _controllers[key]!.text),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
