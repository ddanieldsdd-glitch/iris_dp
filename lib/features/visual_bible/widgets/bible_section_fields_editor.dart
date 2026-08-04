import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../bible_section_fields.dart';

/// Editor de sub-apartados (nombre y orden) de una sección.
class BibleSectionFieldsEditor extends ConsumerStatefulWidget {
  final int bibleId;
  final BibleSectionDefinition definition;

  const BibleSectionFieldsEditor({
    super.key,
    required this.bibleId,
    required this.definition,
  });

  static Future<void> show(
    BuildContext context, {
    required int bibleId,
    required BibleSectionDefinition definition,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surfaceElevated,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => BibleSectionFieldsEditor(
          bibleId: bibleId,
          definition: definition,
        ),
      ),
    );
  }

  @override
  ConsumerState<BibleSectionFieldsEditor> createState() =>
      _BibleSectionFieldsEditorState();
}

class _BibleSectionFieldsEditorState
    extends ConsumerState<BibleSectionFieldsEditor> {
  late List<BibleSectionField> _fields;

  @override
  void initState() {
    super.initState();
    _fields = BibleSectionFieldsConfig.parse(
      widget.definition.contentJson,
      widget.definition.id,
    );
  }

  Future<void> _save() async {
    await ref.read(databaseProvider).saveBibleSectionFields(
          widget.bibleId,
          widget.definition.id,
          _fields,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _renameField(int index) async {
    final field = _fields[index];
    final controller = TextEditingController(text: field.label);
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar sub-apartado'),
        content: TextField(
          controller: controller,
          autofocus: true,
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
    if (label == null || label.isEmpty) return;
    setState(() {
      _fields[index] = field.copyWith(label: label);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sub-apartados · ${widget.definition.label}',
            style: AppTypography.titleMedium(palette),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Arrastra para reordenar. Los tipos especiales (referencias, bloques) '
            'mantienen su comportamiento.',
            style: AppTypography.caption(palette),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _fields.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _fields.removeAt(oldIndex);
                  _fields.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final field = _fields[index];
                return ListTile(
                  key: ValueKey(field.key),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(field.label),
                  subtitle: Text(
                    switch (field.type) {
                      BibleSectionFieldType.narrative => 'Intención narrativa',
                      BibleSectionFieldType.references => 'Referencias moodboard',
                      BibleSectionFieldType.blocks => 'Bloques dinámicos',
                      BibleSectionFieldType.text => 'Campo de texto',
                    },
                    style: AppTypography.caption(palette),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _renameField(index),
                  ),
                );
              },
            ),
          ),
          FilledButton(
            onPressed: _save,
            child: const Text('Guardar sub-apartados'),
          ),
        ],
      ),
    );
  }
}
