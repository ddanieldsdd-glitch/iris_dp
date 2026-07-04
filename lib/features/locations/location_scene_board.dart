import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../core/utils/scene_format.dart';
import '../camera_plan/camera_plan_scene_badge.dart';
import '../../core/widgets/app_snackbar.dart';

Map<int?, List<Scene>> groupScenesBySet(
  List<Scene> scenes,
  List<LocationBasePlan> sets,
) {
  final setIds = {for (final s in sets) s.id: s};
  final grouped = <int?, List<Scene>>{
    for (final set in sets) set.id: <Scene>[],
    null: <Scene>[],
  };

  for (final scene in scenes) {
    final setId = scene.locationId;
    if (setId != null && setIds.containsKey(setId)) {
      grouped[setId]!.add(scene);
    } else {
      grouped[null]!.add(scene);
    }
  }
  return grouped;
}

Future<void> moveSceneToSetWithFeedback(
  BuildContext context,
  WidgetRef ref,
  Scene scene,
  LocationBasePlan targetSet,
) async {
  if (scene.locationId == targetSet.id) return;
  final db = ref.read(databaseProvider);
  await db.moveSceneToSet(scene: scene, targetSet: targetSet);
  if (!context.mounted) return;
  AppSnackBar.show(context, 'Escena ${scene.number} → ${targetSet.locationName}', duration: const Duration(seconds: 2));
}

/// Panel de escenas arrastrables hacia un set.
class SetSceneDragPanel extends ConsumerWidget {
  final List<Scene> scenes;
  final List<LocationBasePlan> sets;
  final LocationBasePlan targetSet;
  final ProjectColorScheme colors;
  final bool compact;

  const SetSceneDragPanel({
    super.key,
    required this.scenes,
    required this.sets,
    required this.targetSet,
    required this.colors,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    final panel = Container(
      constraints: BoxConstraints(minHeight: compact ? 56 : 80),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.divider),
      ),
      child: scenes.isEmpty
          ? Center(
              child: Text(
                compact
                    ? 'Arrastra escenas aquí'
                    : 'Suelta escenas aquí o arrástralas desde otro set',
                style: AppTypography.caption(palette),
                textAlign: TextAlign.center,
              ),
            )
          : compact
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < scenes.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.xs),
                        SizedBox(
                          width: 200,
                          child: DraggableSceneChip(
                            scene: scenes[i],
                            sets: sets,
                            colors: colors,
                            currentSetId: targetSet.id,
                            onMove: (s, t) =>
                                moveSceneToSetWithFeedback(context, ref, s, t),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final scene in scenes)
                      SizedBox(
                        width: 220,
                        child: DraggableSceneChip(
                          scene: scene,
                          sets: sets,
                          colors: colors,
                          currentSetId: targetSet.id,
                          onMove: (s, t) =>
                              moveSceneToSetWithFeedback(context, ref, s, t),
                        ),
                      ),
                  ],
                ),
    );

    return DragTarget<Scene>(
      onWillAcceptWithDetails: (d) => d.data.locationId != targetSet.id,
      onAcceptWithDetails: (d) =>
          moveSceneToSetWithFeedback(context, ref, d.data, targetSet),
      builder: (context, candidate, rejected) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: candidate.isNotEmpty
                ? Border.all(color: palette.accent, width: 2)
                : null,
          ),
          child: panel,
        );
      },
    );
  }
}

/// Escenas sin set asignado dentro de la localización.
class UnassignedScenesStrip extends ConsumerWidget {
  final List<Scene> scenes;
  final List<LocationBasePlan> sets;
  final ProjectColorScheme colors;

  const UnassignedScenesStrip({
    super.key,
    required this.scenes,
    required this.sets,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    if (scenes.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 18, color: palette.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Sin asignar',
                  style: AppTypography.label(palette),
                ),
              ),
              Text('${scenes.length}', style: AppTypography.mono(palette)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < scenes.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: 200,
                    child: DraggableSceneChip(
                      scene: scenes[i],
                      sets: sets,
                      colors: colors,
                      onMove: (s, t) =>
                          moveSceneToSetWithFeedback(context, ref, s, t),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de escena arrastrable entre sets.
class DraggableSceneChip extends StatelessWidget {
  final Scene scene;
  final List<LocationBasePlan> sets;
  final ProjectColorScheme colors;
  final int? currentSetId;
  final void Function(Scene scene, LocationBasePlan targetSet) onMove;

  const DraggableSceneChip({
    super.key,
    required this.scene,
    required this.sets,
    required this.colors,
    required this.onMove,
    this.currentSetId,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sceneColor = colors.sceneColor(scene);
    final label = formatSceneMetaLine(
      intExt: scene.intExt,
      dayNight: scene.dayNight,
      location: locationFromCanonical(scene.locationCanonical),
    );

    final chip = Material(
      color: sceneColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: sets.length > 1
            ? () => _showMoveMenu(context, scene, sets, colors, currentSetId, onMove)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.drag_indicator,
                  size: 16, color: palette.textTertiary),
              const SizedBox(width: 4),
              SceneNumberBadge(
                sceneNumber: scene.number,
                color: sceneColor,
                size: 22,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.caption(palette),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Draggable<Scene>(
      data: scene,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Opacity(opacity: 0.92, child: chip),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: chip,
    );
  }

  static void _showMoveMenu(
    BuildContext context,
    Scene scene,
    List<LocationBasePlan> sets,
    ProjectColorScheme colors,
    int? currentSetId,
    void Function(Scene, LocationBasePlan) onMove,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.surfaceElevated,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Mover escena ${scene.number} a…',
                style: AppTypography.titleMedium(context.palette),
              ),
            ),
            for (final set in sets)
              if (set.id != currentSetId)
                ListTile(
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors.setColor(set),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(set.locationName),
                  onTap: () {
                    Navigator.pop(context);
                    onMove(scene, set);
                  },
                ),
          ],
        ),
      ),
    );
  }
}
