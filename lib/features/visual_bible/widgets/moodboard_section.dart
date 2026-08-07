import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/clipboard_image_reader.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../moodboard_association.dart';
import '../moodboard_batch_actions.dart';
import '../moodboard_helpers.dart';
import '../visual_bible_model.dart';
import 'bible_form_widgets.dart';
import 'moodboard_drag.dart';
import 'moodboard_assign_fields.dart';
import 'moodboard_batch_assign_sheet.dart';

class MoodboardSection extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;
  final String? initialFilter;

  const MoodboardSection({
    super.key,
    required this.projectId,
    required this.bibleId,
    this.initialFilter,
  });

  @override
  ConsumerState<MoodboardSection> createState() => _MoodboardSectionState();
}

class _MoodboardSectionState extends ConsumerState<MoodboardSection> {
  static const _unassignedFilter = '__unassigned__';

  String? _activeCategory;
  final _focusNode = FocusNode();
  final Set<int> _selectedIds = {};
  bool _selectionMode = false;

  static const _categories = [
    ('Todas', null),
    ('Técnica de imagen', MoodboardAssociation.technicalFilter),
    ('Luz', MoodboardCategory.lighting),
    ('Color', MoodboardCategory.color),
    ('Encuadre', MoodboardCategory.framing),
    ('Óptica', MoodboardCategory.optics),
    ('Textura', MoodboardCategory.texture),
    ('Localización', MoodboardCategory.location),
    ('Prueba cámara', MoodboardCategory.cameraTest),
    ('Referencia', MoodboardCategory.reference),
    ('Sin clasificar', _unassignedFilter),
  ];

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.initialFilter;
  }

  @override
  void didUpdateWidget(MoodboardSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != oldWidget.initialFilter &&
        widget.initialFilter != null) {
      _activeCategory = widget.initialFilter;
    }
  }

  List<MoodboardImage> _filterImages(List<MoodboardImage> images) {
    return switch (_activeCategory) {
      null => images,
      _unassignedFilter => images.where((i) {
          final model = MoodboardImageModel.fromRow(i);
          return MoodboardAssociation.isUnassigned(
            assignedSections: model.assignedSections,
            linkedLocationBasePlanId: model.linkedLocationBasePlanId,
            linkedLocationName: model.linkedLocationName,
          );
        }).toList(),
      MoodboardAssociation.technicalFilter => images.where((i) {
          final model = MoodboardImageModel.fromRow(i);
          return MoodboardAssociation.visibleInTechnicalLayer(
            category: model.category,
            assignedSections: model.assignedSections,
          );
        }).toList(),
      MoodboardCategory.location => images.where((i) {
          final model = MoodboardImageModel.fromRow(i);
          return MoodboardAssociation.matchesLocationFilter(
            category: model.category,
            assignedSections: model.assignedSections,
            linkedLocationBasePlanId: model.linkedLocationBasePlanId,
            linkedLocationName: model.linkedLocationName,
          );
        }).toList(),
      _ => images.where((i) {
          final model = MoodboardImageModel.fromRow(i);
          return MoodboardAssociation.matchesCategoryFilter(
            filterCategory: _activeCategory!,
            category: model.category,
            assignedSections: model.assignedSections,
          );
        }).toList(),
    };
  }

  bool get _showLocationGroupedView =>
      _activeCategory == MoodboardCategory.location;

  bool get _showGroupedView =>
      _activeCategory != null &&
      _activeCategory != _unassignedFilter &&
      _activeCategory != MoodboardAssociation.technicalFilter &&
      !_showLocationGroupedView;

  Future<void> _createGroup(BuildContext context) async {
    if (_activeCategory == null) return;
    final name = await _promptGroupName(context);
    if (name == null || name.isEmpty) return;
    final db = ref.read(databaseProvider);
    await db.insertMoodboardGroup(
      MoodboardGroupsCompanion.insert(
        projectId: widget.projectId,
        category: _activeCategory!,
        name: name,
      ),
    );
  }

  Future<String?> _promptGroupName(BuildContext context) async {
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

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  void _handleCardTap(MoodboardImageModel image) {
    setState(() {
      _selectionMode = true;
      if (_selectedIds.contains(image.id)) {
        _selectedIds.remove(image.id);
      } else {
        _selectedIds.add(image.id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _handleCardSecondaryTap(
    MoodboardImageModel image,
    Offset globalPosition,
    List<MoodboardImage> allFiltered,
  ) {
    setState(() {
      _selectionMode = true;
      if (!_selectedIds.contains(image.id)) {
        _selectedIds.add(image.id);
      }
    });
    _showSelectionMenu(context, globalPosition, allFiltered);
  }

  List<MoodboardImage> _selectedRows(List<MoodboardImage> filtered) =>
      filtered.where((i) => _selectedIds.contains(i.id)).toList();

  Future<void> _showSelectionMenu(
    BuildContext context,
    Offset position,
    List<MoodboardImage> filtered,
  ) async {
    final selected = _selectedRows(filtered);
    if (selected.isEmpty) return;
    final palette = context.palette;
    final db = ref.read(databaseProvider);

    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: palette.surfaceElevated,
      items: [
        const PopupMenuItem(
          value: 'sections',
          child: Text('Asignar pantallas de la biblia…'),
        ),
        const PopupMenuItem(
          value: 'location',
          child: Text('Asignar localización…'),
        ),
        const PopupMenuItem(
          value: 'group',
          child: Text('Agrupar en sub-grupo…'),
        ),
        if (selected.length == 1)
          const PopupMenuItem(
            value: 'edit',
            child: Text('Editar still…'),
          ),
        if (selected.length == 1)
          const PopupMenuItem(
            value: 'cover',
            child: Text('Usar como portada del proyecto'),
          ),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            'Eliminar (${selected.length})',
            style: TextStyle(color: palette.error),
          ),
        ),
      ],
    );
    if (!context.mounted || action == null) return;

    switch (action) {
      case 'edit':
        if (selected.length == 1) {
          await _editMeta(
            context,
            MoodboardImageModel.fromRow(selected.first),
          );
        }
      case 'sections':
        await MoodboardBatchAssignSheet.showAssignSections(
          context: context,
          db: db,
          images: selected,
        );
      case 'location':
        await MoodboardBatchAssignSheet.showAssignLocation(
          context: context,
          db: db,
          images: selected,
          projectId: widget.projectId,
        );
      case 'group':
        await MoodboardBatchAssignSheet.showAssignGroup(
          context: context,
          db: db,
          projectId: widget.projectId,
          images: selected,
          categoryHint: _activeCategory,
        );
      case 'cover':
        final ok = await MoodboardBatchActions.setProjectCover(
          db: db,
          projectId: widget.projectId,
          sourceImagePath: selected.first.imagePath,
        );
        if (context.mounted) {
          AppSnackBar.show(
            context,
            ok ? 'Portada del proyecto actualizada' : 'No se pudo guardar la portada',
            isError: !ok,
          );
        }
      case 'delete':
        await _deleteBatch(context, selected);
    }
    if (context.mounted) _clearSelection();
  }

  Future<void> _deleteBatch(
    BuildContext context,
    List<MoodboardImage> images,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar ${images.length} imagen(es)'),
        content: const Text('¿Quitar estas imágenes del moodboard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await MoodboardBatchActions.deleteImages(
      db: ref.read(databaseProvider),
      images: images,
    );
  }

  Widget _buildCard(
    MoodboardImageModel image,
    List<MoodboardImage> filtered, {
    VoidCallback? onMoveEarlier,
    VoidCallback? onMoveLater,
  }) {
    return _MoodboardImageCard(
      image: image,
      isSelected: _selectedIds.contains(image.id),
      selectionMode: _selectionMode || _selectedIds.isNotEmpty,
      onTap: () => _handleCardTap(image),
      onSecondaryTap: (pos) => _handleCardSecondaryTap(image, pos, filtered),
      onDelete: () => _delete(context, image),
      onMoveEarlier: onMoveEarlier,
      onMoveLater: onMoveLater,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.keyV, LogicalKeyboardKey.meta):
            const _PasteIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyV, LogicalKeyboardKey.control):
            const _PasteIntent(),
      },
      child: Actions(
        actions: {
          _PasteIntent: CallbackAction<_PasteIntent>(
            onInvoke: (_) {
              _pasteFromClipboard(context);
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final isPaste = event.logicalKey == LogicalKeyboardKey.keyV &&
                (HardwareKeyboard.instance.isMetaPressed ||
                    HardwareKeyboard.instance.isControlPressed);
            if (isPaste) {
              _pasteFromClipboard(context);
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.escape &&
                _selectedIds.isNotEmpty) {
              setState(() {
                _selectedIds.clear();
                _selectionMode = false;
              });
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _focusNode.requestFocus(),
            child: ImageDropZone(
            onImageDropped: (bytes, _) => MoodboardHelpers.addImageFromBytes(
              db: ref.read(databaseProvider),
              projectId: widget.projectId,
              bibleId: widget.bibleId,
              bytes: bytes,
              category: _activeCategory,
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 8,
                    ),
                    children: [
                      ..._categories.map((cat) {
                        final isActive = _activeCategory == cat.$2;
                        return GestureDetector(
                          onTap: () => setState(() => _activeCategory = cat.$2),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? palette.accent
                                  : palette.surfaceOverlay,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              cat.$1,
                              style: AppTypography.label(palette).copyWith(
                                color: isActive
                                    ? Colors.white
                                    : palette.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }),
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectionMode = !_selectionMode;
                          if (!_selectionMode) _selectedIds.clear();
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectionMode
                                ? palette.warning.withValues(alpha: 0.85)
                                : palette.surfaceOverlay,
                            borderRadius: BorderRadius.circular(20),
                            border: _selectionMode
                                ? null
                                : Border.all(color: palette.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_box_outlined,
                                size: 14,
                                color: _selectionMode
                                    ? Colors.white
                                    : palette.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _selectedIds.isEmpty
                                    ? 'Seleccionar'
                                    : '${_selectedIds.length}',
                                style: AppTypography.label(palette).copyWith(
                                  color: _selectionMode
                                      ? Colors.white
                                      : palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<MoodboardImage>>(
                    stream: db.watchMoodboardImages(widget.projectId),
                    builder: (context, snap) {
                      final images = snap.data ?? [];
                      final filtered = _filterImages(images);

                      Widget content;
                      if (filtered.isEmpty) {
                        content = _MoodboardEmptyState(
                          onAddManual: () => _addManual(context),
                          onAddFromScouting: () => _addScouting(context),
                          onSyncScript: () => _syncScript(context),
                          onPaste: () => _pasteFromClipboard(context),
                        );
                      } else if (_showLocationGroupedView) {
                        content = _LocationGroupedMoodboardGrid(
                          db: db,
                          projectId: widget.projectId,
                          images: filtered,
                          cardBuilder: (img) => _buildCard(img, filtered),
                        );
                      } else if (_showGroupedView) {
                        content = _GroupedMoodboardGrid(
                          db: db,
                          projectId: widget.projectId,
                          category: _activeCategory!,
                          images: filtered,
                          onAddGroup: () => _createGroup(context),
                          cardBuilder: (img) => _buildCard(img, filtered),
                        );
                      } else {
                        content = GridView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
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
                              );
                            }
                            final image =
                                MoodboardImageModel.fromRow(filtered[i]);
                            return _buildCard(
                              image,
                              filtered,
                              onMoveEarlier: i > 0
                                  ? () => _swapOrder(filtered, i, i - 1)
                                  : null,
                              onMoveLater: i < filtered.length - 1
                                  ? () => _swapOrder(filtered, i, i + 1)
                                  : null,
                            );
                          },
                        );
                      }

                      return Stack(
                        children: [
                          content,
                          if (_selectedIds.isNotEmpty)
                            Positioned(
                              left: AppSpacing.md,
                              right: AppSpacing.md,
                              bottom: AppSpacing.md,
                              child: _SelectionActionBar(
                                count: _selectedIds.length,
                                onAssignSections: () async {
                                  final selected = _selectedRows(filtered);
                                  await MoodboardBatchAssignSheet
                                      .showAssignSections(
                                    context: context,
                                    db: ref.read(databaseProvider),
                                    images: selected,
                                  );
                                  if (context.mounted) _clearSelection();
                                },
                                onAssignLocation: () async {
                                  final selected = _selectedRows(filtered);
                                  await MoodboardBatchAssignSheet
                                      .showAssignLocation(
                                    context: context,
                                    db: ref.read(databaseProvider),
                                    images: selected,
                                    projectId: widget.projectId,
                                  );
                                  if (context.mounted) _clearSelection();
                                },
                                onAssignGroup: () async {
                                  final selected = _selectedRows(filtered);
                                  await MoodboardBatchAssignSheet
                                      .showAssignGroup(
                                    context: context,
                                    db: ref.read(databaseProvider),
                                    projectId: widget.projectId,
                                    images: selected,
                                    categoryHint: _activeCategory,
                                  );
                                  if (context.mounted) _clearSelection();
                                },
                                onSetCover: _selectedIds.length == 1
                                    ? () async {
                                        final selected =
                                            _selectedRows(filtered);
                                        final ok = await MoodboardBatchActions
                                            .setProjectCover(
                                          db: ref.read(databaseProvider),
                                          projectId: widget.projectId,
                                          sourceImagePath:
                                              selected.first.imagePath,
                                        );
                                        if (context.mounted) {
                                          AppSnackBar.show(
                                            context,
                                            ok
                                                ? 'Portada actualizada'
                                                : 'No se pudo guardar',
                                            isError: !ok,
                                          );
                                          _clearSelection();
                                        }
                                      }
                                    : null,
                                onDelete: () async {
                                  await _deleteBatch(
                                    context,
                                    _selectedRows(filtered),
                                  );
                                  if (context.mounted) _clearSelection();
                                },
                                onCancel: _clearSelection,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard(BuildContext context) async {
    final status = await MoodboardHelpers.addFromClipboard(
      db: ref.read(databaseProvider),
      projectId: widget.projectId,
      bibleId: widget.bibleId,
      category: _activeCategory,
    );
    if (!context.mounted) return;
    final message = switch (status) {
      ClipboardImageReadStatus.success => 'Imagen pegada en el moodboard',
      ClipboardImageReadStatus.downloadFailed =>
        'No se pudo descargar la imagen. En ShotDeck usa clic derecho → Copiar imagen (no la URL).',
      ClipboardImageReadStatus.invalidUrl =>
        'La URL del portapapeles no parece ser una imagen.',
      ClipboardImageReadStatus.noImage =>
        'Copia la imagen en ShotDeck (clic derecho → Copiar imagen) y pulsa ⌘V aquí.',
      ClipboardImageReadStatus.pluginUnavailable =>
        'Reinicia la app (flutter run) para activar el pegado de imágenes.',
    };
    AppSnackBar.show(
      context,
      message,
      isError: status != ClipboardImageReadStatus.success,
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
    final db = ref.read(databaseProvider);
    final sites = await db.watchSitesForProject(widget.projectId).first;
    final sets = await db.watchLocationsForProject(widget.projectId).first;

    var caption = image.caption ?? '';
    var filmRef = image.filmReference ?? '';
    var assignedSections = List<String>.from(image.assignedSections);
    LocationBasePlan? linkedSet;
    if (image.linkedLocationBasePlanId != null) {
      linkedSet = sets
          .where((s) => s.id == image.linkedLocationBasePlanId)
          .firstOrNull;
    }
    linkedSet ??= sets
        .where((s) => s.locationName == image.linkedLocationName)
        .firstOrNull;
    var groupId = image.groupId;

    if (!context.mounted) return;

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
              final derivedCategory =
                  MoodboardAssociation.deriveCategoryFromSections(
                assignedSections,
              );
              final showLocationField =
                  assignedSections.contains(BibleSectionId.location);

              return FutureBuilder<List<MoodboardGroup>>(
                future: derivedCategory == null
                    ? Future.value(<MoodboardGroup>[])
                    : db
                        .watchMoodboardGroups(
                          widget.projectId,
                          category: derivedCategory,
                        )
                        .first,
                builder: (ctx, groupSnap) {
                  final groups = groupSnap.data ?? [];

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Clasificar referencia',
                            style: AppTypography.titleMedium(palette)),
                        const SizedBox(height: AppSpacing.md),
                        MoodboardSectionAssignField(
                          selected: assignedSections,
                          onChanged: (next) => setSt(() {
                            assignedSections = next;
                            if (!next.contains(BibleSectionId.location)) {
                              linkedSet = null;
                            }
                          }),
                        ),
                        if (showLocationField) ...[
                          const SizedBox(height: AppSpacing.lg),
                          MoodboardLocationAssignField(
                            sites: sites,
                            sets: sets,
                            selectedPlanId: linkedSet?.id,
                            onChanged: (plan) =>
                                setSt(() => linkedSet = plan),
                          ),
                        ],
                        if (groups.isNotEmpty && derivedCategory != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          MoodboardGroupAssignField(
                            groups: groups,
                            selectedGroupId: groupId,
                            onChanged: (id) => setSt(() => groupId = id),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
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
                            final category =
                                MoodboardAssociation.deriveCategoryFromSections(
                              assignedSections,
                            );
                            await db.updateMoodboardImage(
                              MoodboardImage(
                                id: image.id,
                                projectId: image.projectId,
                                bibleId: image.bibleId,
                                imagePath: image.imagePath,
                                source: image.source,
                                category: category,
                                caption: caption.trim().isEmpty
                                    ? null
                                    : caption.trim(),
                                filmReference: filmRef.trim().isEmpty
                                    ? null
                                    : filmRef.trim(),
                                linkedSceneId: image.linkedSceneId,
                                linkedLocationName: linkedSet?.locationName,
                                linkedLocationBasePlanId: linkedSet?.id,
                                groupId: groupId,
                                assignedSections: assignedSections.isEmpty
                                    ? null
                                    : jsonEncode(assignedSections),
                                sortOrder: image.sortOrder,
                              ),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Guardar'),
                        ),
                      ],
                    ),
                  );
                },
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
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final void Function(Offset globalPosition)? onSecondaryTap;
  final VoidCallback onDelete;
  final VoidCallback? onMoveEarlier;
  final VoidCallback? onMoveLater;

  const _MoodboardImageCard({
    required this.image,
    this.isSelected = false,
    this.selectionMode = false,
    required this.onTap,
    this.onSecondaryTap,
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
      onTap: onTap,
      onSecondaryTapUp: onSecondaryTap == null
          ? null
          : (details) => onSecondaryTap!(details.globalPosition),
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
          if (isSelected)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.accent, width: 3),
                  color: palette.accent.withValues(alpha: 0.25),
                ),
              ),
            ),
          if (isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
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
                  MoodboardAssignmentBadges(
                    assignedSections: image.assignedSections,
                    linkedLocationName: image.linkedLocationName,
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
                if (!selectionMode && onMoveEarlier != null)
                  _IconBtn(icon: Icons.arrow_back, onTap: onMoveEarlier!),
                if (!selectionMode && onMoveLater != null)
                  _IconBtn(icon: Icons.arrow_forward, onTap: onMoveLater!),
                if (!selectionMode)
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

  const _AddImageCard({required this.onAddManual});

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
  final VoidCallback onAddFromScouting;
  final VoidCallback onSyncScript;
  final VoidCallback onPaste;

  const _MoodboardEmptyState({
    required this.onAddManual,
    required this.onAddFromScouting,
    required this.onSyncScript,
    required this.onPaste,
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
              'Añade imágenes de referencia para construir tu visión.\n'
              'Pega aquí desde ShotDeck → clasifica (pantallas, set) → '
              'aparecerán en cada sección de la biblia.',
              style: AppTypography.bodyMedium(palette),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _AddButton(
                  icon: Icons.content_paste_outlined,
                  label: 'Pegar imagen',
                  color: palette.accent,
                  onTap: onPaste,
                ),
                _AddButton(icon: Icons.upload_outlined, label: 'Añadir imagen', onTap: onAddManual),
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

class _LocationGroupedMoodboardGrid extends StatelessWidget {
  final AppDatabase db;
  final int projectId;
  final List<MoodboardImage> images;
  final Widget Function(MoodboardImageModel) cardBuilder;

  const _LocationGroupedMoodboardGrid({
    required this.db,
    required this.projectId,
    required this.images,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return StreamBuilder<List<LocationSite>>(
      stream: db.watchSitesForProject(projectId),
      builder: (context, siteSnap) {
        final sites = siteSnap.data ?? [];

        return StreamBuilder<List<LocationBasePlan>>(
          stream: db.watchLocationsForProject(projectId),
          builder: (context, setSnap) {
            final sets = setSnap.data ?? [];

            final unassigned = images
                .where((i) =>
                    i.linkedLocationBasePlanId == null &&
                    (i.linkedLocationName == null ||
                        i.linkedLocationName!.isEmpty))
                .toList(growable: false);

            final byPlanId = <int, List<MoodboardImage>>{};
            for (final img in images) {
              final planId = img.linkedLocationBasePlanId;
              if (planId == null) continue;
              byPlanId.putIfAbsent(planId, () => []).add(img);
            }

            final orphanByName = <String, List<MoodboardImage>>{};
            for (final img in images) {
              if (img.linkedLocationBasePlanId != null) continue;
              final name = img.linkedLocationName;
              if (name == null || name.isEmpty) continue;
              orphanByName.putIfAbsent(name, () => []).add(img);
            }

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (unassigned.isNotEmpty) ...[
                  Text(
                    'Sin set asignado',
                    style: AppTypography.label(palette).copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _locationImageGrid(context, unassigned),
                  const SizedBox(height: AppSpacing.lg),
                ],
                for (final site in sites) ...[
                  for (final set
                      in sets.where((s) => s.siteId == site.id)) ...[
                    if (byPlanId.containsKey(set.id)) ...[
                      Text(
                        '${site.name} · ${set.locationName}',
                        style: AppTypography.titleMedium(palette),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _locationImageGrid(context, byPlanId[set.id]!),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ],
                ],
                for (final set in sets.where((s) => s.siteId == null)) ...[
                  if (byPlanId.containsKey(set.id)) ...[
                    Text(
                      set.locationName,
                      style: AppTypography.titleMedium(palette),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _locationImageGrid(context, byPlanId[set.id]!),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ],
                for (final entry in orphanByName.entries) ...[
                  Text(
                    entry.key,
                    style: AppTypography.titleMedium(palette),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _locationImageGrid(context, entry.value),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (unassigned.isEmpty &&
                    byPlanId.isEmpty &&
                    orphanByName.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Clasifica refs con la pantalla Localización y elige un set.',
                      style: AppTypography.bodyMedium(palette).copyWith(
                        color: palette.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _locationImageGrid(BuildContext context, List<MoodboardImage> rows) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.5,
      ),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final image = MoodboardImageModel.fromRow(rows[i]);
        return cardBuilder(image);
      },
    );
  }
}

class _GroupedMoodboardGrid extends StatelessWidget {
  final AppDatabase db;
  final int projectId;
  final String category;
  final List<MoodboardImage> images;
  final VoidCallback onAddGroup;
  final Widget Function(MoodboardImageModel) cardBuilder;

  const _GroupedMoodboardGrid({
    required this.db,
    required this.projectId,
    required this.category,
    required this.images,
    required this.onAddGroup,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return StreamBuilder<List<MoodboardGroup>>(
      stream: db.watchMoodboardGroups(projectId, category: category),
      builder: (context, groupSnap) {
        final groups = groupSnap.data ?? [];
        final ungrouped =
            images.where((i) => i.groupId == null).toList(growable: false);

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onAddGroup,
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('Nuevo grupo'),
              ),
            ),
            if (ungrouped.isNotEmpty) ...[
              Text(
                'Sin grupo',
                style: AppTypography.label(palette).copyWith(
                  color: palette.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _imageGrid(context, ungrouped),
              const SizedBox(height: AppSpacing.lg),
            ],
            for (final group in groups) ...[
              Text(group.name, style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.sm),
              _imageGrid(
                context,
                images.where((i) => i.groupId == group.id).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        );
      },
    );
  }

  Widget _imageGrid(BuildContext context, List<MoodboardImage> rows) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          'Sin imágenes en este grupo.',
          style: AppTypography.caption(context.palette),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.5,
      ),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final image = MoodboardImageModel.fromRow(rows[i]);
        return cardBuilder(image);
      },
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  final int count;
  final VoidCallback onAssignSections;
  final VoidCallback onAssignLocation;
  final VoidCallback onAssignGroup;
  final VoidCallback? onSetCover;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const _SelectionActionBar({
    required this.count,
    required this.onAssignSections,
    required this.onAssignLocation,
    required this.onAssignGroup,
    this.onSetCover,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: palette.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Text(
              '$count seleccionada(s)',
              style: AppTypography.label(palette),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _BarBtn(
                      icon: Icons.view_agenda_outlined,
                      label: 'Pantallas',
                      onTap: onAssignSections,
                    ),
                    _BarBtn(
                      icon: Icons.location_on_outlined,
                      label: 'Localización',
                      onTap: onAssignLocation,
                    ),
                    _BarBtn(
                      icon: Icons.folder_outlined,
                      label: 'Agrupar',
                      onTap: onAssignGroup,
                    ),
                    if (onSetCover != null)
                      _BarBtn(
                        icon: Icons.image_outlined,
                        label: 'Portada',
                        onTap: onSetCover!,
                      ),
                    _BarBtn(
                      icon: Icons.delete_outline,
                      label: 'Eliminar',
                      color: palette.error,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onCancel,
              tooltip: 'Cancelar selección',
            ),
          ],
        ),
      ),
    );
  }
}

class _BarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _BarBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final c = color ?? palette.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: c),
        label: Text(label, style: AppTypography.caption(palette).copyWith(color: c)),
      ),
    );
  }
}

class _PasteIntent extends Intent {
  const _PasteIntent();
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
