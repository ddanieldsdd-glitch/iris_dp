import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_status_cell.dart';
import 'plan_data.dart';
import 'plan_thumbnail.dart';
import 'plan_view_picker.dart';

/// La planta de un plano en pequeño, con su sección. Tocarla abre la planta;
/// el recuadro de la esquina elige qué sección lo representa. Necesita un
/// [PlanDataScope] por encima.
class ShotPlanPreview extends ConsumerWidget {
  final Shot shot;
  final String label;

  const ShotPlanPreview({super.key, required this.shot, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final data = PlanDataScope.of(context);
    final own = [...data.lightOfShot(shot), ...data.ownOfShot(shot)];
    final base = data.baseOfShot(shot);
    final drawings = data.drawingsOfShot(shot);
    final hasPlan = own.isNotEmpty || base.isNotEmpty || drawings.isNotEmpty;
    final (:focus, :crop) = data.framingOf(shot);

    void open() =>
        openShotPlan(context, ref.read(databaseProvider), shot, label: label);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: palette.surfaceOverlay,
            child: InkWell(
              onTap: open,
              child: hasPlan
                  ? PlanThumbnail(
                      elements: own,
                      inherited: base,
                      drawings: drawings,
                      focus: focus,
                      crop: crop,
                      emptyIcon: Icons.videocam_outlined,
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.grid_on_outlined,
                            size: 22,
                            color: palette.textTertiary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sin planta',
                            style: AppTypography.caption(palette),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          if (hasPlan)
            Positioned(
              right: 4,
              bottom: 4,
              child: IconButton.filledTonal(
                tooltip: crop == null
                    ? 'Elegir la sección de la planta'
                    : 'Cambiar la sección de la planta',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                icon: Icon(
                  Icons.crop_free,
                  color: crop == null ? null : palette.accent,
                ),
                onPressed: () =>
                    showPlanViewPicker(context, data: data, shot: shot),
              ),
            ),
        ],
      ),
    );
  }
}
