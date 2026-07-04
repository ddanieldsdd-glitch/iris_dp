import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../moodboard_helpers.dart';
import '../visual_bible_model.dart';
import 'bible_form_widgets.dart';

class MoodboardSection extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;

  const MoodboardSection({
    super.key,
    required this.projectId,
    required this.bibleId,
  });

  @override
  ConsumerState<MoodboardSection> createState() => _MoodboardSectionState();
}

class _MoodboardSectionState extends ConsumerState<MoodboardSection> {
  String? _activeCategory;

  static const _categories = [
    ('Todas', null),
    ('Luz', MoodboardCategory.lighting),
    ('Color', MoodboardCategory.color),
    ('Encuadre', MoodboardCategory.framing),
    ('Textura', MoodboardCategory.texture),
    ('Localización', MoodboardCategory.location),
    ('Personaje', MoodboardCategory.character),
    ('Referencia', MoodboardCategory.reference),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 8,
            ),
            children: _categories.map((cat) {
              final isActive = _activeCategory == cat.$2;
              return GestureDetector(
                onTap: () => setState(() => _activeCategory = cat.$2),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? palette.accent : palette.surfaceOverlay,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    cat.$1,
                    style: AppTypography.label(palette).copyWith(
                      color: isActive ? Colors.white : palette.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<MoodboardImage>>(
            stream: db.watchMoodboardImages(widget.projectId),
            builder: (context, snap) {
              final images = snap.data ?? [];
              final filtered = _activeCategory == null
                  ? images
                  : images.where((i) => i.category == _activeCategory).toList();

              if (filtered.isEmpty) {
                return _MoodboardEmptyState(
                  onAddManual: () => _addManual(context),
                  onGenerateAI: () => _generateAI(context),
                  onAddFromScouting: () => _addScouting(context),
                  onSyncScript: () => _syncScript(context),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.5,
                ),
                itemCount: filtered.length + 1,
                itemBuilder: (context, i) {
                  if (i == filtered.length) {
                    return _AddImageCard(
                      onAddManual: () => _addManual(context),
                      onGenerateAI: () => _generateAI(context),
                    );
                  }
                  final image = MoodboardImageModel.fromRow(filtered[i]);
                  return _MoodboardImageCard(
                    image: image,
                    onEdit: () => _editMeta(context, image),
                    onDelete: () => _delete(context, image),
                    onMoveEarlier: i > 0
                        ? () => _swapOrder(filtered, i, i - 1)
                        : null,
                    onMoveLater: i < filtered.length - 1
                        ? () => _swapOrder(filtered, i, i + 1)
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _addManual(BuildContext context) async {
    final db = ref.read(databaseProvider);
    await MoodboardHelpers.addManualImages(
      db: db,
      projectId: widget.projectId,
      bibleId: widget.bibleId,
      category: _activeCategory,
    );
  }

  Future<void> _generateAI(BuildContext context) async {
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      'Generación con IA disponible en Fase 2. Añade imágenes manualmente por ahora.',
    );
  }

  Future<void> _syncScript(BuildContext context) async {
    final db = ref.read(databaseProvider);
    final count = await MoodboardHelpers.syncScriptReferences(
      db: db,
      projectId: widget.projectId,
      bibleId: widget.bibleId,
    );
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      count > 0
          ? '$count referencias del guion añadidas al moodboard'
          : 'No hay referencias nuevas en el guion técnico',
    );
  }

  Future<void> _addScouting(BuildContext context) async {
    final db = ref.read(databaseProvider);
    final candidates = await MoodboardHelpers.listScoutingCandidates(
      db,
      widget.projectId,
    );
    if (!context.mounted) return;
    if (candidates.isEmpty) {
      AppSnackBar.show(context, 'No hay fotos de scouting en localizaciones.');
      return;
    }

    final selected = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final selectedIdx = <int>{};
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Fotos del scouting',
                      style: AppTypography.titleMedium(context.palette),
                    ),
                  ),
                  SizedBox(
                    height: 320,
                    child: ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (_, i) {
                        final c = candidates[i];
                        final checked = selectedIdx.contains(i);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (v) {
                            setSt(() {
                              if (v == true) {
                                selectedIdx.add(i);
                              } else {
                                selectedIdx.remove(i);
                              }
                            });
                          },
                          title: Text(c.label, style: AppTypography.bodyMedium(context.palette)),
                          secondary: Image.file(
                            File(c.path),
                            width: 56,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: FilledButton(
                      onPressed: selectedIdx.isEmpty
                          ? null
                          : () => Navigator.pop(ctx, selectedIdx),
                      child: const Text('Añadir seleccionadas'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected == null || selected.isEmpty) return;
    final paths = selected.map((i) => candidates[i].path).toList();
    final count = await MoodboardHelpers.importScoutingImages(
      db: db,
      projectId: widget.projectId,
      bibleId: widget.bibleId,
      imagePaths: paths,
    );
    if (!context.mounted) return;
    AppSnackBar.show(context, '$count foto(s) añadidas al moodboard');
  }

  Future<void> _editMeta(BuildContext context, MoodboardImageModel image) async {
    final palette = context.palette;
    var category = image.category;
    var caption = image.caption ?? '';
    var filmRef = image.filmReference ?? '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surfaceElevated,
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
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Editar imagen', style: AppTypography.titleMedium(palette)),
                  const SizedBox(height: AppSpacing.md),
                  BibleDropdown(
                    label: 'Categoría',
                    options: MoodboardCategory.all.map(MoodboardCategory.label).toList(),
                    value: category != null ? MoodboardCategory.label(category!) : null,
                    onChanged: (v) {
                      setSt(() {
                        final idx = MoodboardCategory.all.indexWhere(
                          (k) => MoodboardCategory.label(k) == v,
                        );
                        category = idx >= 0 ? MoodboardCategory.all[idx] : null;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BibleTextField(
                    label: 'Pie de foto',
                    hint: 'Descripción breve',
                    initialValue: caption,
                    onChanged: (v) => caption = v,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BibleTextField(
                    label: 'Referencia cinematográfica',
                    hint: 'Blade Runner 2049 (Deakins, 2017)',
                    initialValue: filmRef,
                    onChanged: (v) => filmRef = v,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () async {
                      final db = ref.read(databaseProvider);
                      await db.updateMoodboardImage(
                        MoodboardImage(
                          id: image.id,
                          projectId: image.projectId,
                          bibleId: image.bibleId,
                          imagePath: image.imagePath,
                          source: image.source,
                          category: category,
                          caption: caption.trim().isEmpty ? null : caption.trim(),
                          filmReference:
                              filmRef.trim().isEmpty ? null : filmRef.trim(),
                          linkedSceneId: image.linkedSceneId,
                          linkedLocationName: image.linkedLocationName,
                          sortOrder: image.sortOrder,
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, MoodboardImageModel image) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar imagen'),
        content: const Text('¿Quitar esta imagen del moodboard?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(databaseProvider).deleteMoodboardImage(image.id);
  }

  Future<void> _swapOrder(List<MoodboardImage> list, int a, int b) async {
    final db = ref.read(databaseProvider);
    final orderA = list[a].sortOrder;
    final orderB = list[b].sortOrder;
    await db.updateMoodboardImage(list[a].copyWith(sortOrder: orderB));
    await db.updateMoodboardImage(list[b].copyWith(sortOrder: orderA));
  }
}

class _MoodboardImageCard extends StatelessWidget {
  final MoodboardImageModel image;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveEarlier;
  final VoidCallback? onMoveLater;

  const _MoodboardImageCard({
    required this.image,
    required this.onEdit,
    required this.onDelete,
    this.onMoveEarlier,
    this.onMoveLater,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final badge = MoodboardSource.badge(image.source);
    Color badgeColor = palette.accent;
    if (image.source == MoodboardSource.scouting) badgeColor = palette.success;
    if (image.source == MoodboardSource.unrealRender) badgeColor = palette.warning;

    return GestureDetector(
      onLongPress: onEdit,
      onTap: onEdit,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(image.imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: palette.surfaceElevated,
                child: Icon(Icons.broken_image_outlined, color: palette.textTertiary),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (image.caption != null)
                    Text(
                      image.caption!,
                      style: AppTypography.caption(palette).copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (image.filmReference != null)
                    Text(
                      image.filmReference!,
                      style: AppTypography.caption(palette).copyWith(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          if (badge.isNotEmpty)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: AppTypography.caption(palette).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onMoveEarlier != null)
                  _IconBtn(icon: Icons.arrow_back, onTap: onMoveEarlier!),
                if (onMoveLater != null)
                  _IconBtn(icon: Icons.arrow_forward, onTap: onMoveLater!),
                _IconBtn(icon: Icons.close, onTap: onDelete),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.only(left: 2),
        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }
}

class _AddImageCard extends StatelessWidget {
  final VoidCallback onAddManual;
  final VoidCallback onGenerateAI;

  const _AddImageCard({required this.onAddManual, required this.onGenerateAI});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surfaceOverlay,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onAddManual,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate_outlined, color: palette.accent),
              const SizedBox(height: 4),
              Text('Añadir', style: AppTypography.label(palette)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodboardEmptyState extends StatelessWidget {
  final VoidCallback onAddManual;
  final VoidCallback onGenerateAI;
  final VoidCallback onAddFromScouting;
  final VoidCallback onSyncScript;

  const _MoodboardEmptyState({
    required this.onAddManual,
    required this.onGenerateAI,
    required this.onAddFromScouting,
    required this.onSyncScript,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, color: palette.textTertiary, size: 64),
            const SizedBox(height: 24),
            Text('Moodboard vacío', style: AppTypography.titleLarge(palette)),
            const SizedBox(height: 8),
            Text(
              'Añade imágenes de referencia para construir tu visión.',
              style: AppTypography.bodyMedium(palette),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _AddButton(icon: Icons.upload_outlined, label: 'Añadir imagen', onTap: onAddManual),
                _AddButton(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Generar con IA',
                  color: palette.accent,
                  onTap: onGenerateAI,
                ),
                _AddButton(
                  icon: Icons.location_on_outlined,
                  label: 'Del scouting',
                  color: palette.success,
                  onTap: onAddFromScouting,
                ),
                _AddButton(
                  icon: Icons.movie_outlined,
                  label: 'Del guion técnico',
                  color: palette.textSecondary,
                  onTap: onSyncScript,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AddButton({
    required this.icon,
    required this.label,
    this.color = const Color(0x99EBEBF5),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(label, style: AppTypography.bodyMedium(context.palette).copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
