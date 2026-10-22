import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_editor.dart';
import 'floor_plan_repository.dart';
import 'plan_guide.dart';

enum CameraPlanStatus { empty, inheritable, hasPlan }

/// Abre la planta de un plano. Si le falta la localización o el set, abre
/// antes el plano maestro con la guía localización › sets › planos.
Future<void> openShotPlan(
  BuildContext context,
  AppDatabase db,
  Shot shot, {
  required String label,
}) async {
  final navigator = Navigator.of(context);
  var state = await PlanEntryState.resolve(db, shot);
  if (!context.mounted) return;
  if (state.need == PlanEntryNeed.none) {
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => CameraPlanEditor.shot(
          projectId: shot.projectId,
          shotId: shot.id,
          shotLabel: label,
        ),
      ),
    );
    return;
  }
  if (state.site == null) {
    final scene = state.scene;
    if (scene == null) return;
    final site = await pickSiteForScene(context, db, scene);
    if (site == null) return;
    state = await PlanEntryState.resolve(db, shot);
  }
  final site = state.site;
  if (site == null) return;
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => CameraPlanEditor.site(
        projectId: shot.projectId,
        siteId: site.id,
        siteName: site.name,
        guide: PlanGuide(
          sceneId: shot.sceneId,
          shotId: shot.id,
          shotLabel: label,
          startStep: state.startStep,
        ),
      ),
    ),
  );
}

/// Celda compacta de estado de planta (guion técnico y listados).
class CameraPlanStatusCell extends ConsumerWidget {
  final Shot shot;
  final String sceneNumber;
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

        return FutureBuilder<(PlanEntryState, String?)>(
          future: _entryAndTemplate(db),
          builder: (context, snap) {
            final missing = snap.data?.$1.missingLabel;
            if (missing != null) {
              return _buildCell(
                context: context,
                palette: palette,
                icon: Icons.route_outlined,
                iconColor: palette.textSecondary,
                borderColor: palette.divider,
                background: palette.surfaceOverlay.withValues(alpha: 0.4),
                caption: missing,
              );
            }
            final inheritable = snap.data?.$2 != null;
            return _buildCell(
              context: context,
              palette: palette,
              icon: inheritable
                  ? Icons.layers_outlined
                  : Icons.grid_on_outlined,
              iconColor: inheritable
                  ? palette.highlightYellow
                  : palette.textTertiary,
              borderColor: inheritable
                  ? palette.highlightYellow
                  : palette.divider,
              background: inheritable
                  ? palette.highlightYellow.withValues(alpha: 0.12)
                  : palette.surfaceOverlay.withValues(alpha: 0.4),
              caption: inheritable ? 'Base' : 'Vacío',
            );
          },
        );
      },
    );
  }

  Future<(PlanEntryState, String?)> _entryAndTemplate(AppDatabase db) async =>
      (
        await PlanEntryState.resolve(db, shot),
        await FloorPlanRepository(db).resolveTemplateJsonForScene(scene!),
      );

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
      onTap: () => openShotPlan(
        context,
        ProviderScope.containerOf(context).read(databaseProvider),
        shot,
        label: _label,
      ),
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
