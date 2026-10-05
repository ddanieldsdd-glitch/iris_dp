import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/database/app_database.dart';
import 'light/ambient.dart';
import 'plan_equipment.dart';

/// Ambiente del esquema de luz: día o noche, sol, cielo y rebote de
/// paredes.
class PlanAmbientSheet extends StatefulWidget {
  final PlanAmbient initial;
  final ValueChanged<PlanAmbient> onChanged;

  const PlanAmbientSheet({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<PlanAmbientSheet> createState() => _PlanAmbientSheetState();
}

class _PlanAmbientSheetState extends State<PlanAmbientSheet> {
  late PlanAmbient _ambient = widget.initial;

  void _set(PlanAmbient next) {
    setState(() => _ambient = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final a = _ambient;
    Widget toggle(String label, bool value, ValueChanged<bool> onChanged) =>
        Row(
          children: [
            Expanded(
              child: Text(label, style: AppTypography.bodyMedium(palette)),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ambiente', style: AppTypography.titleMedium(palette)),
            Text(
              'La luz que no ponemos nosotros. Se guarda con el esquema de '
              'luz.',
              style: AppTypography.caption(palette),
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.wb_sunny_outlined, size: 18),
                  label: Text('Día'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.nightlight_outlined, size: 18),
                  label: Text('Noche'),
                ),
              ],
              selected: {a.day},
              onSelectionChanged: (v) => _set(a.copyWith(day: v.first)),
            ),
            const SizedBox(height: AppSpacing.md),
            if (a.day) ...[
              Text('Tiempo', style: AppTypography.caption(palette)),
              SegmentedButton<SkyCondition>(
                showSelectedIcon: false,
                segments: [
                  for (final c in SkyCondition.values)
                    ButtonSegment(value: c, label: Text(c.label)),
                ],
                selected: {a.condition},
                onSelectionChanged: (v) => _set(a.copyWith(condition: v.first)),
              ),
              toggle(
                a.condition == SkyCondition.overcast
                    ? 'Sol directo (nublado: no hay)'
                    : 'Sol directo',
                a.sunOn && a.condition != SkyCondition.overcast,
                (v) => _set(a.copyWith(sunOn: v)),
              ),
              if (a.hasSun) ...[
                Text(
                  'De dónde viene: ${a.sunAzimuth.round()}° '
                  '(0° arriba del plano, 90° derecha)',
                  style: AppTypography.caption(palette),
                ),
                Slider(
                  value: a.sunAzimuth,
                  min: 0,
                  max: 359,
                  onChanged: (v) =>
                      _set(a.copyWith(sunAzimuth: v.roundToDouble())),
                ),
                Text(
                  'Altura: ${a.sunElevation.round()}° · sombra de una pared '
                  'de 2,5 m: ${a.shadowLength(2.5).toStringAsFixed(1)} m',
                  style: AppTypography.caption(palette),
                ),
                Slider(
                  value: a.sunElevation,
                  min: 5,
                  max: 85,
                  onChanged: (v) =>
                      _set(a.copyWith(sunElevation: v.roundToDouble())),
                ),
              ],
            ],
            toggle(
              a.day ? 'Luz del cielo' : 'Luz de luna',
              a.skyOn,
              (v) => _set(a.copyWith(skyOn: v)),
            ),
            toggle(
              'Las paredes devuelven luz a la sala',
              a.wallBounce,
              (v) => _set(a.copyWith(wallBounce: v)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Buscador de luces del catálogo de Equipo.
class PlanLightCatalogDialog extends StatefulWidget {
  final List<Light> lights;

  const PlanLightCatalogDialog({super.key, required this.lights});

  @override
  State<PlanLightCatalogDialog> createState() => _PlanLightCatalogDialogState();
}

class _PlanLightCatalogDialogState extends State<PlanLightCatalogDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final q = _query.trim().toLowerCase();
    final matches = widget.lights
        .where(
          (l) => q.isEmpty || '${l.brand} ${l.model}'.toLowerCase().contains(q),
        )
        .toList();
    return AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(
        'Catálogo de luces',
        style: AppTypography.titleMedium(palette),
      ),
      content: SizedBox(
        width: 420,
        height: 460,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar por marca o modelo',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (context, i) {
                  final light = matches[i];
                  return ListTile(
                    dense: true,
                    title: Text('${light.brand} ${light.model}'),
                    subtitle: Text(
                      [
                        '${light.powerW} W',
                        if (light.beamAngleDeg != null)
                          '${light.beamAngleDeg!.round()}°',
                        '${light.colorTempMin}–${light.colorTempMax} K',
                        light.photometryLux != null
                            ? 'fotometría del fabricante'
                            : 'luz estimada',
                      ].join(' · '),
                    ),
                    onTap: () => Navigator.pop(context, light),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

/// Cámara y lente del proyecto para una cámara de la planta.
class PlanProjectCameraPicker extends StatelessWidget {
  final ProjectGear gear;
  final int? cameraId;
  final int? lensId;
  final ValueChanged<Camera> onCamera;
  final ValueChanged<Lense> onLens;

  const PlanProjectCameraPicker({
    super.key,
    required this.gear,
    required this.cameraId,
    required this.lensId,
    required this.onCamera,
    required this.onLens,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (gear.cameras.isEmpty && gear.lenses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(
          'Añade la cámara y las lentes del proyecto en Equipo para '
          'elegirlas aquí.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textTertiary),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Equipo del proyecto', style: AppTypography.label(palette)),
        const SizedBox(height: AppSpacing.sm),
        if (gear.cameras.isNotEmpty) ...[
          Text('Cámara', style: AppTypography.caption(palette)),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: gear.cameras.any((c) => c.id == cameraId)
                ? cameraId
                : null,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Elegir cámara',
            ),
            items: [
              for (final c in gear.cameras)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(
                    '${c.brand} ${c.model}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) {
              if (id != null) {
                onCamera(gear.cameras.firstWhere((c) => c.id == id));
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (gear.lenses.isNotEmpty) ...[
          Text('Lente', style: AppTypography.caption(palette)),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: gear.lenses.any((l) => l.id == lensId)
                ? lensId
                : null,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Elegir lente',
            ),
            items: [
              for (final l in gear.lenses)
                DropdownMenuItem(
                  value: l.id,
                  child: Text(
                    PlanEquipment.lensLabel(l),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) {
              if (id != null) {
                onLens(gear.lenses.firstWhere((l) => l.id == id));
              }
            },
          ),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
