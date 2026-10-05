import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/database/app_database.dart';
import 'camera_plan_element_model.dart';
import 'light/ambient.dart';
import '../equipment/lens_set_utils.dart';
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
  final PlanElement camera;
  final ValueChanged<Camera> onCamera;
  final ValueChanged<Lense> onLens;

  /// Cambia la focal dentro de un zoom.
  final ValueChanged<double> onFocal;

  /// Abre «Cámaras y lentes del proyecto».
  final VoidCallback? onManage;

  const PlanProjectCameraPicker({
    super.key,
    required this.gear,
    required this.camera,
    required this.onCamera,
    required this.onLens,
    required this.onFocal,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cameraId = camera.externalMapping.catalogCameraId;
    final lensId = camera.externalMapping.catalogLensId;
    final manage = onManage == null
        ? const SizedBox.shrink()
        : Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Cámaras y lentes del proyecto…'),
            ),
          );
    if (gear.cameras.isEmpty && gear.lenses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Elige las cámaras y los juegos de lentes que van al rodaje '
              'para tenerlos aquí.',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary),
            ),
            manage,
          ],
        ),
      );
    }
    Lense? selected;
    for (final l in gear.lenses) {
      if (l.id == lensId) selected = l;
    }
    final sets = LensSetUtils.groupBySet(gear.lenses);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Equipo del proyecto', style: AppTypography.label(palette)),
        const SizedBox(height: AppSpacing.sm),
        if (gear.cameras.isNotEmpty) ...[
          Text('Cuerpo', style: AppTypography.caption(palette)),
          DropdownButtonFormField<int>(
            key: ValueKey('body_${cameraId}_${gear.cameras.length}'),
            isExpanded: true,
            initialValue: gear.cameras.any((c) => c.id == cameraId)
                ? cameraId
                : null,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Elegir cámara',
            ),
            items: [
              for (final (i, c) in gear.cameras.indexed)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(
                    '${ProjectGear.letterAt(i)} · ${c.brand} ${c.model}',
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
        // Las lentes del proyecto, por juegos y de la más angular a la más
        // tele: se toca una y el cono cambia.
        for (final lenses in sets.values) ...[
          Text(
            '${lenses.first.brand} ${LensSetUtils.setName(lenses.first)}',
            style: AppTypography.caption(palette),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final lens in lenses)
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  label: Text(
                    LensSetUtils.focalLabel(lens).replaceAll(' mm', ''),
                    style: const TextStyle(fontSize: 12),
                  ),
                  tooltip:
                      '${LensSetUtils.focalLabel(lens)} · '
                      'T${lens.minTStop.toStringAsFixed(1)}',
                  selected: lens.id == lensId,
                  onSelected: (_) => onLens(lens),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (selected != null &&
            selected.focalLength <= 0 &&
            selected.focalMin != null &&
            selected.focalMax != null &&
            selected.focalMax! > selected.focalMin!) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Focal del zoom',
                  style: AppTypography.caption(palette),
                ),
              ),
              Text(camera.lens ?? '', style: AppTypography.caption(palette)),
            ],
          ),
          Slider(
            value: (PlanEquipment.focalOf(camera) ?? selected.focalMin!).clamp(
              selected.focalMin!,
              selected.focalMax!,
            ),
            min: selected.focalMin!,
            max: selected.focalMax!,
            onChanged: onFocal,
          ),
        ],
        manage,
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
