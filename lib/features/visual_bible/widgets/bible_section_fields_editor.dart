import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_section_ids.dart';
import '../../../shared/visual_bible/bible_stitch_module_registry.dart';
import '../../../shared/visual_bible/bible_subsection_kind_catalog.dart';
import '../bible_section_fields.dart';

/// Editor de sub-apartados: añadir, quitar, cambiar tipo y reordenar.
class BibleSectionFieldsEditor extends ConsumerStatefulWidget {
  final int bibleId;
  final BibleSectionDefinition definition;
  final bool embedded;

  const BibleSectionFieldsEditor({
    super.key,
    required this.bibleId,
    required this.definition,
    this.embedded = false,
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
        builder: (ctx, scrollController) =>
            BibleSectionFieldsEditor(bibleId: bibleId, definition: definition),
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
    _reloadFields();
  }

  void _reloadFields() {
    _fields = BibleSectionFieldsConfig.parse(
      widget.definition.contentJson,
      widget.definition.id,
    );
  }

  @override
  void didUpdateWidget(BibleSectionFieldsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition.id != widget.definition.id ||
        oldWidget.definition.contentJson != widget.definition.contentJson) {
      setState(_reloadFields);
    }
  }

  Future<void> _save() async {
    await ref
        .read(databaseProvider)
        .saveBibleSectionFields(widget.bibleId, widget.definition.id, _fields);
    if (mounted && !widget.embedded) Navigator.pop(context);
  }

  Future<void> _saveEmbedded() async {
    await ref
        .read(databaseProvider)
        .saveBibleSectionFields(widget.bibleId, widget.definition.id, _fields);
  }

  Future<void> _renameField(int index) async {
    final field = _fields[index];
    final controller = TextEditingController(text: field.label);
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar sub-apartado'),
        content: TextField(controller: controller, autofocus: true),
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
    if (widget.embedded) unawaited(_saveEmbedded());
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
    if (widget.embedded) unawaited(_saveEmbedded());
  }

  Future<void> _addRegistryModule() async {
    final missing = BibleStitchModuleRegistry.missingModules(
      widget.definition.id,
      _fields,
    );
    if (missing.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todos los módulos Stitch ya están en la lista')),
        );
      }
      return;
    }
    final picked = await showModalBottomSheet<StitchModule>(
      context: context,
      backgroundColor: context.palette.surfaceElevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Añadir módulo Stitch',
                style: AppTypography.titleMedium(context.palette),
              ),
            ),
            for (final module in missing)
              ListTile(
                leading: Icon(_iconForType(module.type)),
                title: Text(module.label),
                subtitle: Text(module.key),
                onTap: () => Navigator.pop(ctx, module),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _fields.add(picked.toField()));
    if (widget.embedded) unawaited(_saveEmbedded());
  }

  void _addField() {
    final key = BibleSectionFieldsConfig.newFieldKey();
    setState(() {
      _fields.add(
        BibleSectionField(key: key, label: 'Nuevo apartado', maxLines: 4),
      );
    });
    if (widget.embedded) unawaited(_saveEmbedded());
  }

  Future<void> _applyStylePack() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar módulos Stitch'),
        content: const Text(
          '¿Restaurar los módulos estándar de esta pantalla? '
          'Se conservan tus textos e imágenes guardados en valores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

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
                  'Densidad visual (opcional)',
                  style: AppTypography.titleMedium(palette),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.movie_filter_outlined),
                title: const Text('Cinematic'),
                subtitle: const Text('Layout Stitch completo'),
                onTap: () => Navigator.pop(ctx, 'cinematic'),
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Technical'),
                subtitle: const Text('Layout Stitch completo'),
                onTap: () => Navigator.pop(ctx, 'technical'),
              ),
              ListTile(
                leading: const Icon(Icons.crop_square_outlined),
                title: const Text('Minimalist'),
                subtitle: const Text('Layout Stitch completo'),
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
        sectionId: widget.definition.id,
      );
    });
    if (widget.embedded) unawaited(_saveEmbedded());
  }

  void _removeField(int index) {
    setState(() => _fields.removeAt(index));
    if (widget.embedded) unawaited(_saveEmbedded());
  }

  IconData _iconForType(BibleSectionFieldType type) => switch (type) {
    BibleSectionFieldType.text => Icons.notes_outlined,
    BibleSectionFieldType.narrative => Icons.auto_stories_outlined,
    BibleSectionFieldType.references => Icons.collections_outlined,
    BibleSectionFieldType.image => Icons.image_outlined,
    BibleSectionFieldType.blocks => Icons.view_agenda_outlined,
  };

  Widget _contentFamilyChip(
    AppPalette palette,
    BibleWidgetContentFamily family,
  ) {
    final isCinematic = family == BibleWidgetContentFamily.cinematic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isCinematic
            ? palette.accent.withValues(alpha: 0.12)
            : palette.surfaceOverlay.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCinematic
              ? palette.accent.withValues(alpha: 0.35)
              : palette.border,
        ),
      ),
      child: Text(
        family.label,
        style: AppTypography.mono(palette).copyWith(
          fontSize: 9,
          letterSpacing: 0.4,
          color: isCinematic ? palette.accent : palette.textSecondary,
        ),
      ),
    );
  }

  String _fieldSubtitle(
    BibleSectionField field,
    bool hasRenderer,
    AppPalette palette,
  ) {
    final module = BibleStitchModuleRegistry.module(
      widget.definition.id,
      field.key,
    );
    final kindLabel = module?.catalogKind.label ??
        BibleSubsectionKindCatalog.fromFieldType(field.type).label;
    final typeLabel = BibleSectionFieldsConfig.labelForType(field.type);
  final rendererNote = hasRenderer
        ? typeLabel
        : '$typeLabel · sin renderer Stitch';
    if (widget.definition.id == BibleSectionId.lighting && module != null) {
      return '$kindLabel · $rendererNote';
    }
    return rendererNote;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.surfaceElevated,
      child: Padding(
      padding: EdgeInsets.all(widget.embedded ? AppSpacing.md : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded) ...[
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
          ],
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _fields.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _fields.removeAt(oldIndex);
                  _fields.insert(newIndex, item);
                });
                if (widget.embedded) unawaited(_saveEmbedded());
              },
              itemBuilder: (context, index) {
                final field = _fields[index];
                final module = BibleStitchModuleRegistry.module(
                  widget.definition.id,
                  field.key,
                );
                final registryLabel = module?.label;
                final hasRenderer = BibleStitchModuleRegistry.hasRenderer(
                  widget.definition.id,
                  field.key,
                );
                final showFamilyChip =
                    widget.definition.id == BibleSectionId.lighting &&
                        module != null;
                return Material(
                  key: ValueKey(field.key),
                  color: palette.surfaceElevated,
                  child: ListTile(
                  leading: Icon(
                    module?.catalogKind.icon ?? _iconForType(field.type),
                  ),
                  title: Text(registryLabel ?? field.label),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showFamilyChip) ...[
                        const SizedBox(height: 4),
                        _contentFamilyChip(palette, module!.contentFamily),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        _fieldSubtitle(field, hasRenderer, palette),
                        style: AppTypography.caption(palette).copyWith(
                          color: hasRenderer ? null : palette.warning,
                        ),
                      ),
                    ],
                  ),
                  trailing: SizedBox(
                    width: 144,
                    child: Row(
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
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: palette.error,
                        ),
                        tooltip: 'Eliminar',
                        onPressed: () => _removeField(index),
                      ),
                    ],
                  ),
                  ),
                ),
                );
              },
            ),
          ),
          OutlinedButton.icon(
            onPressed: _applyStylePack,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Restaurar módulos Stitch'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _addRegistryModule,
            icon: const Icon(Icons.view_module_outlined),
            label: const Text('Añadir módulo Stitch'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _addField,
            icon: const Icon(Icons.add),
            label: const Text('Añadir campo personalizado'),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (widget.embedded)
            Text(
              'Los cambios se aplican al instante en la pantalla.',
              style: AppTypography.caption(palette).copyWith(
                color: palette.textTertiary,
              ),
            )
          else
            FilledButton(
              onPressed: _save,
              child: const Text('Guardar sub-apartados'),
            ),
        ],
      ),
    ),
    );
  }
}
