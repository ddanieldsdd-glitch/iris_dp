import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_editor.dart';
import 'floor_plan_repository.dart';

enum CameraPlanStatus { empty, inheritable, hasPlan }

/// Celda compacta de estado de planta (guion técnico y listados).
class CameraPlanStatusCell extends ConsumerWidget {
  final Shot shot;
  final int sceneNumber;
  final Scene? scene;

  const CameraPlanStatusCell({
    super.key,
    required this.shot,
    required this.sceneNumber,
    this.scene,
  });

  String get _label => 'Esc $sceneNumber · Plano ${shot.number}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final palette = context.palette;

    return StreamBuilder<List<CameraPlanElement>>(
      stream: db.watchCameraPlanElementsForShot(shot.id),
      builder: (context, planSnap) {
        final elementCount = planSnap.data?.length ?? 0;
        final hasPlan = elementCount > 0;

        if (hasPlan) {
          return _buildCell(
            context: context,
            palette: palette,
            icon: Icons.check_circle_outline,
            iconColor: palette.accent,
            borderColor: palette.accent,
            background: palette.accent.withValues(alpha: 0.12),
            caption: '$elementCount elem.',
          );
        }

        if (scene == null) {
          return _buildCell(
            context: context,
            palette: palette,
            icon: Icons.grid_on_outlined,
            iconColor: palette.textTertiary,
            borderColor: palette.divider,
            background: palette.surfaceOverlay.withValues(alpha: 0.4),
            caption: 'Vacío',
          );
        }

        return FutureBuilder<String?>(
          future: FloorPlanRepository(db).resolveTemplateJsonForScene(scene!),
          builder: (context, templateSnap) {
            final inheritable = templateSnap.data != null;
            return _buildCell(
              context: context,
              palette: palette,
              icon: inheritable
                  ? Icons.layers_outlined
                  : Icons.grid_on_outlined,
              iconColor: inheritable ? palette.highlightYellow : palette.textTertiary,
              borderColor:
                  inheritable ? palette.highlightYellow : palette.divider,
              background: inheritable
                  ? palette.highlightYellow.withValues(alpha: 0.12)
                  : palette.surfaceOverlay.withValues(alpha: 0.4),
              caption: inheritable ? 'Heredar' : 'Vacío',
            );
          },
        );
      },
    );
  }

  Widget _buildCell({
    required BuildContext context,
    required AppPalette palette,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required Color background,
    required String caption,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CameraPlanEditor.shot(
              projectId: shot.projectId,
              shotId: shot.id,
              shotLabel: _label,
            ),
          ),
        );
      },
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 2),
            Text(
              caption,
              style: AppTypography.caption(palette).copyWith(color: iconColor),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
