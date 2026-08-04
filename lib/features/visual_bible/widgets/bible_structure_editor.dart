import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart' hide BibleSectionGroup;
import '../../../core/database/app_database.dart' as app_db show BibleSectionGroup;
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import 'bible_navigation_scope.dart';
import 'bible_section_fields_editor.dart';

/// Editor de estructura: renombrar, reordenar y configurar sub-apartados.
class BibleStructureEditor extends ConsumerStatefulWidget {
  final int bibleId;

  const BibleStructureEditor({super.key, required this.bibleId});

  @override
  ConsumerState<BibleStructureEditor> createState() =>
      _BibleStructureEditorState();
}

class _BibleStructureEditorState extends ConsumerState<BibleStructureEditor> {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<app_db.BibleSectionGroup>>(
      stream: db.watchBibleSectionGroups(widget.bibleId),
      builder: (context, groupSnap) {
        final groups = groupSnap.data ?? [];
        return StreamBuilder<List<BibleSectionDefinition>>(
          stream: db.watchBibleSectionDefinitions(widget.bibleId),
          builder: (context, defSnap) {
            final defs = defSnap.data ?? [];
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Estructura de la biblia',
                      style: AppTypography.titleMedium(palette),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Renombra secciones, reordénalas y edita los sub-apartados '
                      'internos de cada pantalla.',
                      style: AppTypography.caption(palette),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final group in groups) ...[
                            _GroupHeader(
                              label: group.label,
                              onRename: () => _renameGroup(context, group),
                            ),
                            _ReorderableSectionList(
                              defs: defs
                                  .where(
                                    (d) =>
                                        d.groupId == group.id && !d.isHidden,
                                  )
                                  .toList(),
                              onReorder: (ordered) => db
                                  .reorderBibleSectionsInGroup(
                                widget.bibleId,
                                group.id,
                                ordered.map((d) => d.id).toList(),
                              ),
                              onRename: (def) => _renameSection(context, def),
                              onEditFields: (def) =>
                                  BibleSectionFieldsEditor.show(
                                context,
                                bibleId: widget.bibleId,
                                definition: def,
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.add, size: 20),
                              title: const Text('Añadir sección personalizada'),
                              onTap: () => _addCustomSection(context, group.id),
                            ),
                            const Divider(height: 24),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _renameGroup(
    BuildContext context,
    app_db.BibleSectionGroup group,
  ) async {
    final label = await _promptLabel(context, 'Renombrar grupo', group.label);
    if (label == null || label.isEmpty) return;
    final db = ref.read(databaseProvider);
    await db.upsertBibleSectionGroup(group.copyWith(label: label));
  }

  Future<void> _renameSection(
    BuildContext context,
    BibleSectionDefinition def,
  ) async {
    final label = await _promptLabel(context, 'Renombrar sección', def.label);
    if (label == null || label.isEmpty) return;
    final db = ref.read(databaseProvider);
    await db.upsertBibleSectionDefinition(def.copyWith(label: label));
  }

  Future<void> _addCustomSection(BuildContext context, String groupId) async {
    final label = await _promptLabel(context, 'Nueva sección', '');
    if (label == null || label.isEmpty) return;
    final db = ref.read(databaseProvider);
    await db.insertCustomBibleSection(
      bibleId: widget.bibleId,
      groupId: groupId,
      label: label,
    );
    if (context.mounted) {
      AppSnackBar.show(context, 'Sección «$label» creada');
    }
  }

  Future<String?> _promptLabel(
    BuildContext context,
    String title,
    String initial,
  ) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _ReorderableSectionList extends StatefulWidget {
  final List<BibleSectionDefinition> defs;
  final Future<void> Function(List<BibleSectionDefinition> ordered) onReorder;
  final void Function(BibleSectionDefinition def) onRename;
  final void Function(BibleSectionDefinition def) onEditFields;

  const _ReorderableSectionList({
    required this.defs,
    required this.onReorder,
    required this.onRename,
    required this.onEditFields,
  });

  @override
  State<_ReorderableSectionList> createState() =>
      _ReorderableSectionListState();
}

class _ReorderableSectionListState extends State<_ReorderableSectionList> {
  late List<BibleSectionDefinition> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.defs);
  }

  @override
  void didUpdateWidget(_ReorderableSectionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.defs.length != oldWidget.defs.length ||
        widget.defs.map((d) => d.id).join() !=
            oldWidget.defs.map((d) => d.id).join()) {
      _items = List.from(widget.defs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      onReorder: (oldIndex, newIndex) async {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _items.removeAt(oldIndex);
          _items.insert(newIndex, item);
        });
        await widget.onReorder(_items);
      },
      itemBuilder: (context, index) {
        final def = _items[index];
        return ListTile(
          key: ValueKey(def.id),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.drag_handle, size: 18),
              const SizedBox(width: 4),
              Icon(bibleIconFromKey(def.iconKey), size: 20),
            ],
          ),
          title: Text(def.label),
          subtitle: def.isBuiltIn
              ? null
              : Text(
                  'Personalizada',
                  style: AppTypography.caption(palette),
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.view_list_outlined, size: 18),
                tooltip: 'Sub-apartados',
                onPressed: () => widget.onEditFields(def),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => widget.onRename(def),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final VoidCallback onRename;

  const _GroupHeader({required this.label, required this.onRename});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: AppTypography.caption(palette).copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: onRename,
            tooltip: 'Renombrar grupo',
          ),
        ],
      ),
    );
  }
}
