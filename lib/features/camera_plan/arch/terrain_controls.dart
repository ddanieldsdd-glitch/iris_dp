import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../camera_plan_element_model.dart';
import 'arch_material.dart';
import 'arch_material_picker.dart';
import 'arch_terrain.dart';

/// El panel de un terreno (AM.7): el pincel (subir, bajar, alisar,
/// aplanar o pintar un material), el material de fondo y el agua.
///
/// Con el pincel puesto, arrastrar sobre el terreno lo trabaja; al cerrar
/// el panel se quita, para que arrastrar vuelva a mover.
class TerrainControls extends StatefulWidget {
  final PlanElement element;
  final double metersPerUnit;
  final VoidCallback onPreview;
  final VoidCallback onUpdate;

  const TerrainControls({
    super.key,
    required this.element,
    required this.metersPerUnit,
    required this.onPreview,
    required this.onUpdate,
  });

  @override
  State<TerrainControls> createState() => _TerrainControlsState();
}

class _TerrainControlsState extends State<TerrainControls> {
  /// El último pincel, para volver a él al encenderlo.
  TerrainBrush _last = const TerrainBrush();

  @override
  void dispose() {
    ArchTerrain.brush.value = null;
    super.dispose();
  }

  void _set(TerrainBrush? b) {
    if (b != null) _last = b;
    ArchTerrain.brush.value = b;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final el = widget.element;
    String m(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} m';
    final caption = AppTypography.caption(palette);

    Widget slider(
      String label,
      String text,
      double value, {
      required double min,
      required double max,
      required ValueChanged<double> onChanged,
      VoidCallback? onEnd,
      Key? key,
    }) => Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: caption)),
            Text(text, style: caption),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
          onChangeEnd: (_) => onEnd?.call(),
        ),
      ],
    );

    return ValueListenableBuilder<TerrainBrush?>(
      valueListenable: ArchTerrain.brush,
      builder: (context, brush, _) {
        final on = brush != null;
        final b = brush ?? _last;
        final (lo, hi) = ArchTerrain.range(el);
        final water = ArchTerrain.water(el);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: const ValueKey('terrain-brush'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Pincel'),
              subtitle: Text(
                on
                    ? 'Arrastra sobre el terreno para trabajarlo.'
                    : 'Arrastrar mueve el terreno.',
                style: caption,
              ),
              value: on,
              onChanged: (v) => _set(v ? _last : null),
            ),
            if (on) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final mode in TerrainBrushMode.values)
                    ChoiceChip(
                      key: ValueKey('terrain-mode-${mode.name}'),
                      label: Text(mode.label),
                      selected: b.mode == mode,
                      onSelected: (_) => _set(b.copyWith(mode: mode)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              slider(
                'Radio',
                m(b.radiusM),
                b.radiusM,
                min: 0.5,
                max: 20,
                onChanged: (v) =>
                    _set(b.copyWith(radiusM: (v * 4).round() / 4)),
                key: const ValueKey('terrain-radius'),
              ),
              if (b.mode != TerrainBrushMode.paint)
                slider(
                  b.mode == TerrainBrushMode.raise ||
                          b.mode == TerrainBrushMode.lower
                      ? 'Cuánto por pasada'
                      : 'Fuerza',
                  m(b.strengthM),
                  b.strengthM,
                  min: 0.05,
                  max: 3,
                  onChanged: (v) =>
                      _set(b.copyWith(strengthM: (v * 20).round() / 20)),
                  key: const ValueKey('terrain-strength'),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in ArchTerrain.paintable)
                      if (ArchMaterials.byId(id) case final mat?)
                        ChoiceChip(
                          key: ValueKey('terrain-paint-$id'),
                          label: Text(mat.name),
                          selected: b.materialId == id,
                          onSelected: (_) => _set(b.copyWith(materialId: id)),
                        ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
            ArchMaterialField(
              label: 'Material de fondo',
              value:
                  ArchMaterials.byId(ArchTerrain.baseMaterial(el)) ??
                  ArchMaterials.byId(ArchTerrain.defaultMat)!,
              onChanged: (mat) {
                ArchTerrain.setBaseMaterial(el, mat.id);
                widget.onUpdate();
                setState(() {});
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              key: const ValueKey('terrain-water'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Agua'),
              subtitle: Text(
                'Mar, orilla o lago hasta una cota.',
                style: caption,
              ),
              value: water != null,
              onChanged: (v) {
                ArchTerrain.setWater(el, v ? (lo + hi) / 2 : null);
                widget.onUpdate();
                setState(() {});
              },
            ),
            if (water != null)
              slider(
                'Cota del agua',
                m(water),
                water,
                min: lo - 1,
                max: hi + 1,
                onChanged: (v) {
                  ArchTerrain.setWater(el, (v * 20).round() / 20);
                  widget.onPreview();
                  setState(() {});
                },
                onEnd: widget.onUpdate,
                key: const ValueKey('terrain-water-level'),
              ),
            Text(
              ArchTerrain.summary(el),
              key: const ValueKey('terrain-summary'),
              style: caption,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('terrain-flat'),
                onPressed: () {
                  ArchTerrain.setHeights(el, [
                    for (final _ in ArchTerrain.heights(el)) 0.0,
                  ]);
                  widget.onUpdate();
                  setState(() {});
                },
                child: const Text('Dejarlo llano'),
              ),
            ),
          ],
        );
      },
    );
  }
}
