import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'light/ambient.dart';
import 'light/light_scene.dart';
import 'arch/arch_material.dart';
import 'arch/arch_material_picker.dart';

/// Propiedades de un recinto cerrado: si tiene techo, a qué altura y de
/// qué es el suelo.
class PlanRoomPanel extends StatelessWidget {
  final SceneRoom room;
  final double metersPerUnit;

  /// Punto del recinto con el que se guardan sus ajustes.
  final Offset anchor;
  final ValueChanged<RoomSetting> onChanged;
  final VoidCallback onClose;

  const PlanRoomPanel({
    super.key,
    required this.room,
    required this.metersPerUnit,
    required this.anchor,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final areaM2 = room.room.area * metersPerUnit * metersPerUnit;

    void save({bool? roofed, double? ceilingM, String? floor}) => onChanged(
      RoomSetting(
        x: anchor.dx,
        y: anchor.dy,
        openSky: !(roofed ?? room.roofed),
        ceilingM: ceilingM ?? room.ceilingM,
        floor: floor ?? room.floor.id,
      ),
    );

    return Material(
      color: palette.surface,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recinto',
                  style: AppTypography.titleMedium(palette),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClose,
              ),
            ],
          ),
          Text(
            '${areaM2.toStringAsFixed(1)} m² cerrados por paredes',
            style: AppTypography.caption(palette),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tiene techo',
                  style: AppTypography.bodyMedium(palette),
                ),
              ),
              Switch(
                value: room.roofed,
                onChanged: (v) => save(roofed: v),
              ),
            ],
          ),
          Text(
            room.roofed
                ? 'El sol y el cielo solo entran por puertas y ventanas.'
                : 'A cielo abierto, como un patio: le da el sol y el cielo.',
            style: AppTypography.caption(
              palette,
            ).copyWith(color: palette.textTertiary),
          ),
          if (room.roofed) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Altura del techo',
                    style: AppTypography.caption(palette),
                  ),
                ),
                Text(
                  '${room.ceilingM.toStringAsFixed(1)} m',
                  style: AppTypography.caption(palette),
                ),
              ],
            ),
            Slider(
              value: room.ceilingM.clamp(2.0, 12.0),
              min: 2,
              max: 12,
              divisions: 100,
              onChanged: (v) => save(ceilingM: (v * 10).round() / 10),
            ),
            // La biblioteca de materiales (AM.1).
            ArchMaterialField(
              label: 'Suelo · devuelve el '
                  '${(room.floor.reflectance * 100).round()} %',
              value: ArchMaterials.floorOf(room.floor.id),
              onChanged: (m) => save(
                floor: ArchMaterials.storedId(m, ArchMaterials.floorLegacy),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'La mancha de sol que cae en el suelo devuelve luz a la sala '
              'según el material.',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
