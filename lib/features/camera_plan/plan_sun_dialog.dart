import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'light/sun_position.dart';

/// El sol elegido: para la planta y con su norte.
class SunPick {
  final double azimuth;
  final double elevation;
  final double northDeg;

  const SunPick(this.azimuth, this.elevation, this.northDeg);
}

/// Saca el sol de un lugar, un día y una hora, y lo orienta en la planta.
class PlanSunDialog extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final double northDeg;
  final String? place;

  /// Para las pruebas: el «ahora» del diálogo.
  final DateTime? now;

  const PlanSunDialog({
    super.key,
    this.latitude,
    this.longitude,
    this.northDeg = 0,
    this.place,
    this.now,
  });

  @override
  State<PlanSunDialog> createState() => _PlanSunDialogState();
}

class _PlanSunDialogState extends State<PlanSunDialog> {
  late DateTime _when = widget.now ?? DateTime.now();
  late int _offset = _when.timeZoneOffset.inMinutes;
  late double _north = widget.northDeg;
  late final _lat = TextEditingController(
    text: widget.latitude?.toStringAsFixed(4) ?? '',
  );
  late final _lon = TextEditingController(
    text: widget.longitude?.toStringAsFixed(4) ?? '',
  );

  @override
  void dispose() {
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  double? _number(TextEditingController c, double limit) {
    final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
    return v == null || v.abs() > limit ? null : v;
  }

  String _clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(
      () => _when = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _when.hour,
        _when.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (picked == null) return;
    setState(
      () => _when = DateTime(
        _when.year,
        _when.month,
        _when.day,
        picked.hour,
        picked.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lat = _number(_lat, 90), lon = _number(_lon, 180);
    SunPosition? sun;
    ({int rise, int set})? day;
    if (lat != null && lon != null) {
      final utc = DateTime.utc(
        _when.year,
        _when.month,
        _when.day,
        _when.hour,
        _when.minute,
      ).subtract(Duration(minutes: _offset));
      sun = SunPosition.at(utc, lat, lon);
      day = SunPosition.dayOf(_when, lat, lon, utcOffsetMinutes: _offset);
    }
    final hours = _offset / 60;
    final zone =
        'UTC${hours >= 0 ? '+' : ''}${hours == hours.roundToDouble() ? hours.round() : hours}';
    final found = sun;

    return AlertDialog(
      title: const Text('Sol real'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.place != null)
            Text(widget.place!, style: AppTypography.caption(palette)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('sun-lat'),
                  controller: _lat,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Latitud'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  key: const ValueKey('sun-lon'),
                  controller: _lon,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Longitud'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton(
                onPressed: _pickDate,
                child: Text(
                  '${_when.day.toString().padLeft(2, '0')}/'
                  '${_when.month.toString().padLeft(2, '0')}/${_when.year}',
                ),
              ),
              TextButton(
                onPressed: _pickTime,
                child: Text(_clock(_when.hour * 60 + _when.minute)),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Zona horaria del lugar: $zone',
                  style: AppTypography.caption(palette),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                tooltip: 'Media hora menos',
                onPressed: () => setState(() => _offset -= 30),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                tooltip: 'Media hora más',
                onPressed: () => setState(() => _offset += 30),
              ),
            ],
          ),
          Text(
            'El norte de la planta: ${_north.round()}° '
            '(0° arriba, 90° derecha)',
            style: AppTypography.caption(palette),
          ),
          Slider(
            value: _north,
            min: 0,
            max: 359,
            onChanged: (v) => setState(() => _north = v.roundToDouble()),
          ),
          if (found == null)
            Text(
              'Escribe la latitud y la longitud del lugar.',
              style: AppTypography.bodyMedium(palette),
            )
          else ...[
            Text(
              found.up
                  ? 'Sol al ${found.compass}, ${found.azimuth.round()}°, '
                        'a ${found.elevation.round()}° de altura'
                  : 'A esa hora el sol está bajo el horizonte',
              key: const ValueKey('sun-result'),
              style: AppTypography.bodyMedium(palette),
            ),
            if (day != null)
              Text(
                'Sale a las ${_clock(day.rise)} y se pone a las '
                '${_clock(day.set)}',
                style: AppTypography.caption(palette),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('sun-apply'),
          onPressed: found == null || !found.up
              ? null
              : () => Navigator.pop(
                  context,
                  SunPick(found.planAzimuth(_north), found.elevation, _north),
                ),
          child: const Text('Poner este sol'),
        ),
      ],
    );
  }
}
