import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../shared/equipment/recording_catalog.dart';

/// Plan de grabación y volcado con datos publicados por el fabricante.
///
/// Solo aparece para las cámaras que tienen medios y formatos en
/// `assets/catalog/recording.json`.
class RecordingPlanCard extends StatefulWidget {
  /// Nombre visible de cada cámara por su `externalId`.
  final Map<String, String> cameraNames;

  const RecordingPlanCard({super.key, required this.cameraNames});

  @override
  State<RecordingPlanCard> createState() => _RecordingPlanCardState();
}

class _RecordingPlanCardState extends State<RecordingPlanCard> {
  List<CameraRecording> _catalog = const [];
  CameraRecording? _camera;
  RecordingFormat? _format;
  RecordingMedium? _medium;
  double _minutesPerDay = 60;
  int _days = 1;
  double _destinationMbPerSec = 400;
  int _copies = 2;
  bool _verify = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final catalog = parseRecordingCatalog(
        await rootBundle.loadString('assets/catalog/recording.json'),
      );
      if (!mounted || catalog.isEmpty) return;
      setState(() {
        _catalog = catalog;
        _selectCamera(catalog.first);
      });
    } catch (_) {
      // Sin datos de grabación: la tarjeta no se muestra.
    }
  }

  void _selectCamera(CameraRecording camera) {
    _camera = camera;
    _selectFormat(camera.formats.last);
  }

  void _selectFormat(RecordingFormat format) {
    _format = format;
    final options = _camera!.mediaFor(format);
    _medium = options.contains(_medium)
        ? _medium
        : (options.isEmpty ? null : options.first);
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final format = _format;
    if (camera == null || format == null) return const SizedBox.shrink();
    final palette = context.palette;
    final medium = _medium;
    final media = camera.mediaFor(format);
    final plan = medium == null
        ? null
        : RecordingPlan.compute(
            format: format,
            medium: medium,
            minutesPerDay: _minutesPerDay,
            days: _days,
            destinationMbPerSec: _destinationMbPerSec,
            copies: _copies,
            verify: _verify,
          );

    Widget number(
      String label,
      String value,
      ValueChanged<double> onChanged, {
      String? suffix,
    }) => SizedBox(
      width: 170,
      child: TextFormField(
        initialValue: value,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, suffixText: suffix),
        onChanged: (v) {
          final parsed = double.tryParse(v.replaceAll(',', '.'));
          if (parsed != null && parsed >= 0) setState(() => onChanged(parsed));
        },
      ),
    );

    Widget result(String label, String value) => SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTypography.label(palette)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.mono(palette).copyWith(fontSize: 18),
          ),
        ],
      ),
    );

    String hours(double h) {
      final total = (h * 60).round();
      return '${total ~/ 60} h ${(total % 60).toString().padLeft(2, '0')} min';
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan de grabación y volcado',
            style: AppTypography.titleMedium(palette),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tiempos por cargador publicados por el fabricante, a '
            '${camera.fps.toStringAsFixed(0)} fps. Disponible para las '
            'cámaras con sus medios y formatos en el catálogo.',
            style: AppTypography.caption(palette),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<CameraRecording>(
                  value: camera,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Cámara'),
                  items: [
                    for (final c in _catalog)
                      DropdownMenuItem(
                        value: c,
                        child: Text(
                          widget.cameraNames[c.cameraId] ?? c.cameraId,
                        ),
                      ),
                  ],
                  onChanged: (c) {
                    if (c != null) setState(() => _selectCamera(c));
                  },
                ),
              ),
              SizedBox(
                width: 340,
                child: DropdownButtonFormField<RecordingFormat>(
                  value: format,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Formato y códec',
                  ),
                  items: [
                    for (final f in camera.formats)
                      DropdownMenuItem(value: f, child: Text(f.label)),
                  ],
                  onChanged: (f) {
                    if (f != null) setState(() => _selectFormat(f));
                  },
                ),
              ),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<RecordingMedium>(
                  value: medium,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Medio'),
                  items: [
                    for (final m in media)
                      DropdownMenuItem(value: m, child: Text(m.name)),
                  ],
                  onChanged: (m) => setState(() => _medium = m),
                ),
              ),
            ],
          ),
          if (media.length < camera.media.length)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Este formato no se puede grabar en: '
                '${camera.media.where((m) => !media.contains(m)).map((m) => m.name).join(', ')}.',
                style: AppTypography.caption(palette),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              number(
                'Minutos grabados por jornada',
                _minutesPerDay.toStringAsFixed(0),
                (v) => _minutesPerDay = v,
                suffix: 'min',
              ),
              number(
                'Jornadas',
                '$_days',
                (v) => _days = v.round().clamp(1, 999),
              ),
              number(
                'Escritura del disco destino',
                _destinationMbPerSec.toStringAsFixed(0),
                (v) => _destinationMbPerSec = v,
                suffix: 'MB/s',
              ),
              number(
                'Copias de seguridad',
                '$_copies',
                (v) => _copies = v.round().clamp(1, 9),
              ),
              FilterChip(
                label: const Text('Verificar con checksum'),
                selected: _verify,
                onSelected: (v) => setState(() => _verify = v),
              ),
            ],
          ),
          if (plan != null) ...[
            const Divider(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.lg,
              children: [
                result(
                  'Minutos por cargador',
                  plan.minutesPerMag == null
                      ? '—'
                      : '${plan.minutesPerMag} min',
                ),
                result(
                  'Cargadores por jornada',
                  plan.magsPerDay == null ? '—' : '${plan.magsPerDay}',
                ),
                result(
                  'Tasa de datos',
                  '${format.rateMbPerSec.toStringAsFixed(0)} MB/s',
                ),
                result(
                  'Volumen por jornada',
                  '${plan.gbPerDay.toStringAsFixed(0)} GB',
                ),
                result(
                  'Volumen del rodaje',
                  '${plan.totalTb.toStringAsFixed(2)} TB',
                ),
                result('Volcado por jornada', hours(plan.offloadHoursPerDay)),
                result(
                  'Almacenamiento a prever',
                  '${plan.storageTb.toStringAsFixed(2)} TB',
                ),
              ],
            ),
            if (medium != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                [
                  if (medium.adapter != null) 'Adaptador: ${medium.adapter}',
                  if (medium.dock != null) 'Volcado: ${medium.dock}',
                  if (medium.sourceLabel != null)
                    'Fuente: ${medium.sourceLabel} (${medium.status.label})',
                  'La tasa de datos es aproximada; los minutos por cargador '
                      'son los del fabricante.',
                ].join('\n'),
                style: AppTypography.caption(palette),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
