import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../bible_section_fields.dart';

/// Editor de sub-apartados: añadir, quitar, cambiar tipo y reordenar.
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

  Future<void> _changeType(int index) async {
    final field = _fields[index];
    final picked = await showModalBottomSheet<BibleSectionFieldType>(
      context: context,
      backgroundColor: context.palette.surfaceElevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Tipo de sub-apartado',
                style: AppTypography.titleMedium(context.palette),
              ),
            ),
            for (final type in BibleSectionFieldType.values)
              ListTile(
                leading: Icon(_iconForType(type)),
                title: Text(BibleSectionFieldsConfig.labelForType(type)),
                selected: field.type == type,
                onTap: () => Navigator.pop(ctx, type),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _fields[index] = field.copyWith(type: picked);
    });
  }

  void _addField() {
    final key = BibleSectionFieldsConfig.newFieldKey();
    setState(() {
      _fields.add(
        BibleSectionField(
          key: key,
          label: 'Nuevo apartado',
          maxLines: 4,
        ),
      );
    });
  }

  Future<void> _applyStylePack() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.palette.surfaceElevated,
      builder: (ctx) {
        final palette = context.palette;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Plantilla de sub-apartados',
                  style: AppTypography.titleMedium(palette),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.movie_filter_outlined),
                title: const Text('Cinematic'),
                subtitle: const Text('Narrativa + atmósfera + refs moodboard'),
                onTap: () => Navigator.pop(ctx, 'cinematic'),
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Technical'),
                subtitle: const Text('Specs + notas de rodaje + refs'),
                onTap: () => Navigator.pop(ctx, 'technical'),
              ),
              ListTile(
                leading: const Icon(Icons.crop_square_outlined),
                title: const Text('Minimalist'),
                subtitle: const Text('Intención + notas + imagen'),
                onTap: () => Navigator.pop(ctx, 'minimalist'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _fields = BibleSectionFieldsConfig.packForStyle(
        picked,
        sectionLabel: widget.definition.label,
      );
    });
  }

  void _removeField(int index) {
    setState(() => _fields.removeAt(index));
  }

  IconData _iconForType(BibleSectionFieldType type) => switch (type) {
        BibleSectionFieldType.text => Icons.notes_outlined,
        BibleSectionFieldType.narrative => Icons.auto_stories_outlined,
        BibleSectionFieldType.references => Icons.collections_outlined,
        BibleSectionFieldType.image => Icons.image_outlined,
        BibleSectionFieldType.blocks => Icons.view_agenda_outlined,
      };

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
            'Añade campos de texto, imágenes o referencias moodboard en cualquier '
            'orden. Por ejemplo, convierte «Referencias cinematográficas» en '
            'imágenes.',
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
                  leading: Icon(_iconForType(field.type)),
                  title: Text(field.label),
                  subtitle: Text(
                    BibleSectionFieldsConfig.labelForType(field.type),
                    style: AppTypography.caption(palette),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.category_outlined, size: 18),
                        tooltip: 'Cambiar tipo',
                        onPressed: () => _changeType(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Renombrar',
                        onPressed: () => _renameField(index),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: palette.error),
                        tooltip: 'Eliminar',
                        onPressed: () => _removeField(index),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          OutlinedButton.icon(
            onPressed: _applyStylePack,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Aplicar plantilla estándar'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _addField,
            icon: const Icon(Icons.add),
            label: const Text('Añadir sub-apartado'),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _save,
            child: const Text('Guardar sub-apartados'),
          ),
        ],
      ),
    );
  }
}
