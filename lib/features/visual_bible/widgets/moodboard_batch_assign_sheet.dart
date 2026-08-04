import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../moodboard_batch_actions.dart';
import 'moodboard_assign_fields.dart';

/// Bottom sheets para asignación en lote de refs del moodboard.
abstract final class MoodboardBatchAssignSheet {
  static Future<void> showAssignSections({
    required BuildContext context,
    required AppDatabase db,
    required List<MoodboardImage> images,
  }) async {
    var assignedSections = <String>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surfaceElevated,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.paddingOf(ctx).bottom + AppSpacing.lg,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSt) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Asignar pantallas (${images.length})',
                      style: AppTypography.titleMedium(context.palette),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MoodboardSectionAssignField(
                      selected: assignedSections,
                      onChanged: (next) =>
                          setSt(() => assignedSections = next),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: assignedSections.isEmpty
                          ? null
                          : () async {
                              await MoodboardBatchActions.assignSections(
                                db: db,
                                images: images,
                                sections: assignedSections,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      child: const Text('Aplicar a selección'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  static Future<void> showAssignLocation({
    required BuildContext context,
    required AppDatabase db,
    required List<MoodboardImage> images,
    required int projectId,
  }) async {
    final sites = await db.watchSitesForProject(projectId).first;
    final sets = await db.watchLocationsForProject(projectId).first;
    if (!context.mounted) return;

    LocationBasePlan? linkedSet;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surfaceElevated,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.paddingOf(ctx).bottom + AppSpacing.lg,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSt) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Asignar localización (${images.length})',
                      style: AppTypography.titleMedium(context.palette),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    MoodboardLocationAssignField(
                      sites: sites,
                      sets: sets,
                      selectedPlanId: linkedSet?.id,
                      onChanged: (plan) => setSt(() => linkedSet = plan),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: () async {
                        await MoodboardBatchActions.assignLocation(
                          db: db,
                          images: images,
                          set: linkedSet,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Aplicar a selección'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  static Future<void> showAssignGroup({
    required BuildContext context,
    required AppDatabase db,
    required int projectId,
    required List<MoodboardImage> images,
    required String? categoryHint,
  }) async {
    final category = MoodboardBatchActions.resolveGroupCategory(
      images: images,
      activeCategoryFilter: categoryHint,
    );
    if (category == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Asigna primero una pantalla técnica (Luz, Color, etc.) '
              'o filtra por categoría.',
            ),
          ),
        );
      }
      return;
    }

    final groups =
        await db.watchMoodboardGroups(projectId, category: category).first;
    if (!context.mounted) return;

    int? selectedGroupId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surfaceElevated,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.paddingOf(ctx).bottom + AppSpacing.lg,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSt) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Agrupar (${images.length})',
                      style: AppTypography.titleMedium(context.palette),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (groups.isNotEmpty)
                      MoodboardGroupAssignField(
                        groups: groups,
                        selectedGroupId: selectedGroupId,
                        onChanged: (id) => setSt(() => selectedGroupId = id),
                      )
                    else
                      Text(
                        'No hay sub-grupos en esta categoría.',
                        style: AppTypography.caption(context.palette),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final name = await _promptGroupName(ctx);
                        if (name == null || name.isEmpty) return;
                        await MoodboardBatchActions.createGroupAndAssign(
                          db: db,
                          projectId: projectId,
                          category: category,
                          name: name,
                          images: images,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Crear grupo y agrupar'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: selectedGroupId == null
                          ? null
                          : () async {
                              await MoodboardBatchActions.assignGroup(
                                db: db,
                                images: images,
                                groupId: selectedGroupId,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      child: const Text('Aplicar a selección'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  static Future<String?> _promptGroupName(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo grupo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre del grupo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}
