import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/media_storage.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_card.dart';
import '../camera_plan/camera_plan_editor.dart';
import '../camera_plan/floor_plan_json.dart';
import '../camera_plan/floor_plan_map_tile.dart';
import '../camera_plan/floor_plan_repository.dart';
import '../camera_plan/floor_plan_scope.dart';
import 'location_scan_panel.dart';
import 'location_coming_soon.dart';
import 'location_scene_board.dart';
import 'location_set_gallery.dart';
import '../../core/widgets/app_snackbar.dart';

/// Bloque Base: referencias compartidas de la localización.
class SiteBaseSection extends ConsumerWidget {
  final int projectId;
  final LocationSite site;
  final ProjectColorScheme colors;

  const SiteBaseSection({
    super.key,
    required this.projectId,
    required this.site,
    required this.colors,
  });

  Future<void> _addImage(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;

    final db = ref.read(databaseProvider);
    final existing = await db.watchImagesForSite(site.id).first;
    var sort = existing.length;

    try {
      for (final file in result.files) {
        if (file.path == null) continue;
        final stored = await MediaStorage.copySiteImage(
          projectId: projectId,
          siteId: site.id,
          sourcePath: file.path!,
        );
        await db.insertSiteImage(SiteImagesCompanion.insert(
          siteId: site.id,
          imagePath: stored,
          sortOrder: Value(sort),
        ));
        sort++;
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.show(context, userFriendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Base', style: AppTypography.titleMedium(palette)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Contexto general de «${site.name}»: accesos, vistas panorámicas '
          'y logística compartida por todos los sets.',
          style: AppTypography.caption(palette),
        ),
        if (site.notes != null && site.notes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(site.notes!, style: AppTypography.bodyMedium(palette)),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text('Galería general',
                  style: AppTypography.titleMedium(palette)),
            ),
            TextButton.icon(
              onPressed: () => _addImage(context, ref),
              icon: Icon(Icons.add_photo_alternate_outlined,
                  color: palette.accent, size: 18),
              label: Text('Añadir',
                  style: AppTypography.caption(palette)
                      .copyWith(color: palette.accent)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        StreamBuilder<List<SiteImage>>(
          stream: db.watchImagesForSite(site.id),
          builder: (context, snap) {
            final images = snap.data ?? [];
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (images.isEmpty) {
              return AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Text(
                    'Sin imágenes generales. Añade scouting del acceso o '
                    'referencias de producción.',
                    style: AppTypography.bodyMedium(palette),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.2,
              ),
              itemCount: images.length,
              itemBuilder: (context, i) => _SiteGalleryTile(image: images[i]),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        FloorPlanMapTile(
          scope: FloorPlanScope.site,
          title: site.name,
          subtitle: 'Vista general con todos los sets marcados',
          accentColor: colors.siteColor(site.id),
          hasPlan: FloorPlanRepository(ref.read(databaseProvider)).hasStoredPlan(
            FloorPlanScope.site,
            json: site.floorPlanJson,
          ),
          elementCount: site.floorPlanJson != null &&
                  site.floorPlanJson!.isNotEmpty
              ? FloorPlanJson.decode(site.floorPlanJson).length
              : null,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CameraPlanEditor.site(
                  projectId: projectId,
                  siteId: site.id,
                  siteName: site.name,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        const LocationAdvancedComingSoon(),
      ],
    );
  }
}

class _SiteGalleryTile extends ConsumerWidget {
  final SiteImage image;

  const _SiteGalleryTile({required this.image});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final exists = File(image.imagePath).existsSync();

    return GestureDetector(
      onLongPress: () async {
        final db = ref.read(databaseProvider);
        await db.deleteSiteImage(image.id);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: palette.divider),
          ),
          child: exists
              ? Image.file(File(image.imagePath), fit: BoxFit.cover)
              : ColoredBox(
                  color: palette.surfaceOverlay,
                  child: Icon(Icons.broken_image_outlined,
                      color: palette.textTertiary),
                ),
        ),
      ),
    );
  }
}

/// Sets de rodaje unificados: tarjetas interactivas + distribución de escenas.
class SiteSetsSection extends ConsumerWidget {
  final int projectId;
  final LocationSite site;
  final ProjectColorScheme colors;
  final int? expandedSetId;
  final ValueChanged<int?> onExpandedSetChanged;
  final ValueChanged<LocationBasePlan> onEditSet;
  final ValueChanged<LocationBasePlan> onDeleteSet;
  final VoidCallback onAddSet;

  const SiteSetsSection({
    super.key,
    required this.projectId,
    required this.site,
    required this.colors,
    required this.expandedSetId,
    required this.onExpandedSetChanged,
    required this.onEditSet,
    required this.onDeleteSet,
    required this.onAddSet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Sets de rodaje',
                  style: AppTypography.titleMedium(palette)),
            ),
            TextButton.icon(
              onPressed: onAddSet,
              icon: Icon(Icons.add, color: palette.accent, size: 18),
              label: Text('Nuevo set',
                  style: AppTypography.caption(palette)
                      .copyWith(color: palette.accent)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Cada set agrupa escenas, galería, plano 2D, modelo 3D y luz. '
          'Arrastra escenas entre tarjetas o expande un set para editarlo.',
          style: AppTypography.caption(palette),
        ),
        const SizedBox(height: AppSpacing.md),
        StreamBuilder<List<LocationBasePlan>>(
          stream: db.watchSetsForSite(site.id),
          builder: (context, setsSnap) {
            return StreamBuilder<List<Scene>>(
              stream: db.watchScenesForSite(site.id),
              builder: (context, scenesSnap) {
                final sets = setsSnap.data ?? [];
                final scenes = scenesSnap.data ?? [];
                if (!setsSnap.hasData || !scenesSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (sets.isEmpty) {
                  return AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Sin set base todavía. Recarga la vista o vuelve a abrir '
                      'la localización.',
                      style: AppTypography.bodyMedium(palette),
                    ),
                  );
                }

                final grouped = groupScenesBySet(scenes, sets);
                final unassigned = grouped[null] ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (unassigned.isNotEmpty) ...[
                      UnassignedScenesStrip(
                        scenes: unassigned,
                        sets: sets,
                        colors: colors,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    for (final set in sets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ExpandableSetCard(
                          key: ValueKey('set-${set.id}'),
                          projectId: projectId,
                          set: set,
                          allSets: sets,
                          setScenes: grouped[set.id] ?? [],
                          colors: colors,
                          isExpanded: expandedSetId == set.id,
                          onToggle: () => onExpandedSetChanged(
                            expandedSetId == set.id ? null : set.id,
                          ),
                          onEdit: () => onEditSet(set),
                          onDelete: () => onDeleteSet(set),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class ExpandableSetCard extends ConsumerWidget {
  final int projectId;
  final LocationBasePlan set;
  final List<LocationBasePlan> allSets;
  final List<Scene> setScenes;
  final ProjectColorScheme colors;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ExpandableSetCard({
    super.key,
    required this.projectId,
    required this.set,
    required this.allSets,
    required this.setScenes,
    required this.colors,
    required this.isExpanded,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final accent = colors.setColor(set);

    return StreamBuilder<List<LocationImage>>(
      stream: db.watchImagesForLocation(set.id),
      builder: (context, imgSnap) {
        final imageCount = imgSnap.data?.length ?? 0;
        final sceneCount = setScenes.length;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isExpanded ? accent : palette.divider,
              width: isExpanded ? 2 : 1,
            ),
            boxShadow: isExpanded
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: palette.surfaceElevated,
            borderRadius: BorderRadius.circular(7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: onToggle,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 5,
                              height: 48,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    set.locationName.toUpperCase(),
                                    style: AppTypography.titleMedium(palette),
                                  ),
                                  if (set.description != null &&
                                      set.description!.isNotEmpty)
                                    Text(
                                      set.description!,
                                      style: AppTypography.caption(palette),
                                      maxLines: isExpanded ? null : 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$sceneCount escena(s) · $imageCount imagen(es)',
                                    style: AppTypography.caption(palette),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Editar set',
                              visualDensity: VisualDensity.compact,
                              onPressed: onEdit,
                              icon: Icon(Icons.edit_outlined,
                                  size: 18, color: palette.textSecondary),
                            ),
                            Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: palette.textSecondary,
                            ),
                          ],
                        ),
                        if (!isExpanded) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              _SetAssetChip(
                                icon: Icons.photo_library_outlined,
                                label: 'Galería',
                                onTap: onToggle,
                              ),
                              _SetAssetChip(
                                icon: Icons.grid_on_outlined,
                                label: 'Plano 2D',
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => CameraPlanEditor.set(
                                        projectId: projectId,
                                        setId: set.id,
                                        setName: set.locationName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _SetAssetChip(
                                icon: Icons.view_in_ar_outlined,
                                label: 'Modelo 3D',
                                onTap: onToggle,
                              ),
                              _SetAssetChip(
                                icon: Icons.wb_sunny_outlined,
                                label: 'Luz',
                                onTap: onToggle,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: SetSceneDragPanel(
                    scenes: setScenes,
                    sets: allSets,
                    targetSet: set,
                    colors: colors,
                    compact: !isExpanded,
                  ),
                ),
                if (!isExpanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: onToggle,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        side: BorderSide(color: palette.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      icon: Icon(Icons.open_in_full,
                          size: 18, color: palette.textSecondary),
                      label: Text(
                        'Abrir set completo',
                        style: AppTypography.bodyMedium(palette),
                      ),
                    ),
                  ),
                if (isExpanded) ...[
                  Divider(height: 1, color: palette.divider),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SetReferenceGallerySection(
                          projectId: projectId,
                          locationId: set.id,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        LocationScanPanel(
                          projectId: projectId,
                          set: set,
                          setScenes: setScenes,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FloorPlanMapTile(
                          scope: FloorPlanScope.set,
                          title: set.locationName,
                          subtitle: 'Planta del set para cámaras y focos',
                          accentColor: accent,
                          hasPlan: set.floorPlanJson != null &&
                              set.floorPlanJson!.isNotEmpty,
                          elementCount: set.floorPlanJson != null &&
                                  set.floorPlanJson!.isNotEmpty
                              ? FloorPlanJson.decode(set.floorPlanJson).length
                              : null,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CameraPlanEditor.set(
                                  projectId: projectId,
                                  setId: set.id,
                                  setName: set.locationName,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: onDelete,
                            icon: Icon(Icons.delete_outline,
                                size: 18, color: palette.error),
                            label: Text(
                              'Eliminar set',
                              style: AppTypography.caption(palette)
                                  .copyWith(color: palette.error),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SetAssetChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SetAssetChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ActionChip(
      avatar: Icon(icon, size: 16, color: palette.textSecondary),
      label: Text(label, style: AppTypography.caption(palette)),
      backgroundColor: palette.surface,
      side: BorderSide(color: palette.divider),
      onPressed: onTap,
    );
  }
}
