import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../shared/visual_bible/bible_section_ids.dart';
import '../moodboard_helpers.dart';
import '../moodboard_reference_meta.dart';
import '../services/bible_section_references_service.dart';
import '../visual_bible_model.dart';
import 'bible_navigation_scope.dart';

/// Gestor unificado de referencias de imagen por sección (añadir, reordenar, hero, eliminar).
class BibleSectionReferencesManager extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final bool compact;
  final String? title;

  const BibleSectionReferencesManager({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    this.compact = false,
    this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final label = title ?? 'Referencias · ${BibleSectionId.label(sectionId)}';

    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImagesForSection(projectId, sectionId),
      builder: (context, snap) {
        final images = BibleSectionReferencesService.sorted(snap.data ?? []);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) ...[
              Row(
                children: [
                  Icon(Icons.collections_outlined, color: palette.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label, style: AppTypography.titleMedium(palette)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (images.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Aún no hay referencias en esta pantalla. Añade stills '
                  'orientativas que ilustren la intención del texto.',
                  style: AppTypography.caption(palette).copyWith(
                    color: palette.textTertiary,
                    height: 1.4,
                  ),
                ),
              ),
            if (compact)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: images.length,
                onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) newIndex--;
                  await BibleSectionReferencesService.reorder(
                    db,
                    images,
                    oldIndex,
                    newIndex,
                  );
                },
                itemBuilder: (context, index) {
                  final image = images[index];
                  return _CompactRefTile(
                    key: ValueKey(image.id),
                    image: image,
                    isHero: image.sortOrder <= 0,
                    onHero: () => BibleSectionReferencesService.setHero(db, image),
                    onRemove: () => _confirmRemove(context, ref, image),
                  );
                },
              )
            else
              LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth >= 700 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: images.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.95,
                    ),
                    itemBuilder: (context, i) {
                      final image = images[i];
                      return _FullRefCard(
                        image: image,
                        palette: palette,
                        isHero: image.sortOrder <= 0,
                        onHero: () => BibleSectionReferencesService.setHero(db, image),
                        onRemove: () => _confirmRemove(context, ref, image),
                        onMoveEarlier: i > 0
                            ? () => BibleSectionReferencesService.reorder(
                                  db,
                                  images,
                                  i,
                                  i - 1,
                                )
                            : null,
                        onMoveLater: i < images.length - 1
                            ? () => BibleSectionReferencesService.reorder(
                                  db,
                                  images,
                                  i,
                                  i + 2,
                                )
                            : null,
                      );
                    },
                  );
                },
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addImages(ref),
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: Text(compact ? 'Añadir' : 'Añadir referencia'),
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => BibleNavigationScope.openMoodboardForSection(
                      context,
                      sectionId,
                    ),
                    child: Text('Moodboard', style: TextStyle(color: palette.accent)),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _addImages(WidgetRef ref) async {
    await MoodboardHelpers.addManualImages(
      db: ref.read(databaseProvider),
      projectId: projectId,
      bibleId: bibleId,
      assignedSections: [sectionId],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    MoodboardImage image,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar referencia'),
        content: const Text(
          '¿Quitar esta imagen de esta pantalla? '
          'Permanece en el moodboard si está asignada a otras secciones.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await BibleSectionReferencesService.removeFromSection(
      ref.read(databaseProvider),
      image,
      sectionId,
    );
    if (context.mounted) {
      AppSnackBar.show(context, 'Referencia quitada de la pantalla');
    }
  }
}

class _CompactRefTile extends ConsumerWidget {
  final MoodboardImage image;
  final bool isHero;
  final VoidCallback onHero;
  final VoidCallback onRemove;

  const _CompactRefTile({
    super.key,
    required this.image,
    required this.isHero,
    required this.onHero,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final model = MoodboardImageModel.fromRow(image);
    final file = File(model.imagePath);
    return Material(
      color: palette.surfaceOverlay,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 44,
            height: 44,
            child: file.existsSync()
                ? Image.file(file, fit: BoxFit.cover)
                : ColoredBox(color: palette.border),
          ),
        ),
        title: Text(
          model.caption ?? model.filmReference ?? 'Referencia',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyMedium(palette).copyWith(fontSize: 13),
        ),
        subtitle: isHero
            ? Text(
                'Hero',
                style: AppTypography.caption(palette).copyWith(color: palette.accent),
              )
            : null,
        trailing: SizedBox(
          width: 96,
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Marcar como hero',
              icon: Icon(
                isHero ? Icons.star : Icons.star_border,
                size: 18,
                color: isHero ? palette.warning : palette.textSecondary,
              ),
              onPressed: onHero,
            ),
            IconButton(
              tooltip: 'Quitar',
              icon: Icon(Icons.close, size: 18, color: palette.textSecondary),
              onPressed: onRemove,
            ),
            const Icon(Icons.drag_handle, size: 18),
          ],
        ),
        ),
      ),
    );
  }
}

class _FullRefCard extends ConsumerStatefulWidget {
  final MoodboardImage image;
  final AppPalette palette;
  final bool isHero;
  final VoidCallback onHero;
  final VoidCallback onRemove;
  final VoidCallback? onMoveEarlier;
  final VoidCallback? onMoveLater;

  const _FullRefCard({
    required this.image,
    required this.palette,
    required this.isHero,
    required this.onHero,
    required this.onRemove,
    this.onMoveEarlier,
    this.onMoveLater,
  });

  @override
  ConsumerState<_FullRefCard> createState() => _FullRefCardState();
}

class _FullRefCardState extends ConsumerState<_FullRefCard> {
  MoodboardReferenceMeta? _meta;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final meta = await MoodboardReferenceMetaStore.load(widget.image.id);
    if (mounted) setState(() => _meta = meta);
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final model = MoodboardImageModel.fromRow(widget.image);
    final file = File(model.imagePath);
    final title = _meta?.title?.trim().isNotEmpty == true
        ? _meta!.title!
        : (model.caption ?? model.filmReference ?? 'Referencia orientativa');

    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isHero
              ? palette.warning.withValues(alpha: 0.5)
              : palette.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (file.existsSync())
                  Image.file(file, fit: BoxFit.cover)
                else
                  ColoredBox(color: palette.surfaceOverlay),
                if (widget.isHero)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: palette.warning.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'HERO',
                        style: AppTypography.mono(palette).copyWith(
                          fontSize: 9,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          widget.isHero ? Icons.star : Icons.star_border,
                          color: widget.isHero ? palette.warning : Colors.white70,
                        ),
                        onPressed: widget.onHero,
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: widget.onRemove,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium(palette).copyWith(fontSize: 14),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      if (widget.onMoveEarlier != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_back, size: 18),
                          tooltip: 'Prioridad ↑',
                          onPressed: widget.onMoveEarlier,
                        ),
                      if (widget.onMoveLater != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          tooltip: 'Prioridad ↓',
                          onPressed: widget.onMoveLater,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
