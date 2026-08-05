import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/templates/user_template_models.dart';
import '../../core/templates/user_template_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_snackbar.dart';
import 'shoot_document_block_types.dart';

/// Editor visual de plantillas de documentos de rodaje.
class ShootTemplateEditorScreen extends ConsumerStatefulWidget {
  final String? templateId;
  final String? initialName;

  const ShootTemplateEditorScreen({
    super.key,
    this.templateId,
    this.initialName,
  });

  @override
  ConsumerState<ShootTemplateEditorScreen> createState() =>
      _ShootTemplateEditorScreenState();
}

class _ShootTemplateEditorScreenState
    extends ConsumerState<ShootTemplateEditorScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<ShootDocumentBlockBlueprint> _blocks = [];
  String _layoutPreset = ShootLayoutPreset.freeform;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.templateId == null) {
      _nameCtrl.text = widget.initialName ?? 'Mi plantilla de rodaje';
      _blocks = defaultShootTemplateBlocks();
      setState(() => _loading = false);
      return;
    }

    final db = ref.read(databaseProvider);
    final template = await UserTemplateService.getTemplate(
      db,
      widget.templateId!,
    );
    if (template != null) {
      final payload = ShootDocumentTemplatePayload.decode(template.payloadJson);
      _nameCtrl.text = template.name;
      _descCtrl.text = template.description ?? '';
      _layoutPreset = payload.layoutPreset;
      _blocks = List.from(payload.blocks);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackBar.showError(context, 'Indica un nombre para la plantilla.');
      return;
    }

    final payload = ShootDocumentTemplatePayload(
      layoutPreset: _layoutPreset,
      blocks: _blocks,
    );

    final db = ref.read(databaseProvider);
    await UserTemplateService.saveShootDocumentTemplateFromPayload(
      db: db,
      name: name,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      payload: payload,
      existingId: widget.templateId,
    );

    if (mounted) {
      AppSnackBar.show(context, 'Plantilla «$name» guardada');
      Navigator.pop(context, true);
    }
  }

  Future<void> _addBlock() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.palette.surfaceElevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in ShootBlockType.all)
              ListTile(
                leading: Icon(_iconFor(t)),
                title: Text(ShootBlockType.label(t)),
                onTap: () => Navigator.pop(ctx, t),
              ),
          ],
        ),
      ),
    );
    if (type == null) return;

    setState(() {
      _blocks.add(
        ShootDocumentBlockBlueprint(
          blockType: type,
          sortOrder: _blocks.length,
          customLabel: type == ShootBlockType.sectionHeader
              ? 'Nueva sección'
              : type == ShootBlockType.sceneHeader
                  ? 'Escena'
                  : null,
          noteBody: type == ShootBlockType.note ? '' : null,
        ),
      );
    });
  }

  Future<void> _editBlock(int index) async {
    final block = _blocks[index];
    final labelCtrl = TextEditingController(text: block.customLabel ?? '');
    final noteCtrl = TextEditingController(text: block.noteBody ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar ${ShootBlockType.label(block.blockType)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (block.blockType == ShootBlockType.sectionHeader ||
                block.blockType == ShootBlockType.sceneHeader)
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(labelText: 'Etiqueta'),
              ),
            if (block.blockType == ShootBlockType.note)
              TextField(
                controller: noteCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Texto de ejemplo'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    setState(() {
      _blocks[index] = ShootDocumentBlockBlueprint(
        blockType: block.blockType,
        sortOrder: block.sortOrder,
        customLabel: labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim(),
        noteBody: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        visibilityJson: block.visibilityJson,
        contentOverridesJson: block.contentOverridesJson,
      );
    });
  }

  IconData _iconFor(String type) => switch (type) {
        ShootBlockType.sectionHeader => Icons.title,
        ShootBlockType.characterList => Icons.people_outline,
        ShootBlockType.sceneHeader => Icons.movie_filter_outlined,
        ShootBlockType.scriptExcerpt => Icons.menu_book_outlined,
        ShootBlockType.shot => Icons.videocam_outlined,
        ShootBlockType.note => Icons.sticky_note_2_outlined,
        ShootBlockType.image => Icons.image_outlined,
        ShootBlockType.pageBreak => Icons.insert_page_break_outlined,
        ShootBlockType.spacer => Icons.height,
        _ => Icons.widgets_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.templateId == null ? 'Nueva plantilla' : 'Editar plantilla',
          style: AppTypography.titleMedium(palette),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Guardar', style: TextStyle(color: palette.accent)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la plantilla',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _layoutPreset,
                  decoration: const InputDecoration(labelText: 'Layout'),
                  items: [
                    ShootLayoutPreset.freeform,
                    ShootLayoutPreset.scriptLeftShotsRight,
                    ShootLayoutPreset.stacked,
                    ShootLayoutPreset.shotsOnly,
                  ]
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(ShootLayoutPreset.label(p)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _layoutPreset = v);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'Arrastra los bloques para definir el orden. Los planos y escenas '
              'se rellenarán con datos del proyecto al usar la plantilla.',
              style: AppTypography.caption(palette),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _blocks.isEmpty
                ? Center(
                    child: Text(
                      'Añade bloques para componer tu documento ideal.',
                      style: AppTypography.bodyMedium(palette),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: _blocks.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _blocks.removeAt(oldIndex);
                        _blocks.insert(newIndex, item);
                        for (var i = 0; i < _blocks.length; i++) {
                          final b = _blocks[i];
                          _blocks[i] = ShootDocumentBlockBlueprint(
                            blockType: b.blockType,
                            sortOrder: i,
                            customLabel: b.customLabel,
                            noteBody: b.noteBody,
                            visibilityJson: b.visibilityJson,
                            contentOverridesJson: b.contentOverridesJson,
                          );
                        }
                      });
                    },
                    itemBuilder: (context, index) {
                      final block = _blocks[index];
                      return ListTile(
                        key: ValueKey('${block.blockType}_$index'),
                        leading: Icon(_iconFor(block.blockType),
                            color: palette.accent),
                        title: Text(ShootBlockType.label(block.blockType)),
                        subtitle: Text(
                          block.customLabel ??
                              block.noteBody ??
                              'Bloque ${index + 1}',
                          style: AppTypography.caption(palette),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.drag_handle, color: palette.textTertiary),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _editBlock(index),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 18, color: palette.error),
                              onPressed: () =>
                                  setState(() => _blocks.removeAt(index)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBlock,
        icon: const Icon(Icons.add),
        label: const Text('Añadir bloque'),
      ),
    );
  }
}

List<ShootDocumentBlockBlueprint> defaultShootTemplateBlocks() => [
      const ShootDocumentBlockBlueprint(
        blockType: ShootBlockType.sectionHeader,
        sortOrder: 0,
        customLabel: 'Plan del día',
      ),
      const ShootDocumentBlockBlueprint(
        blockType: ShootBlockType.sceneHeader,
        sortOrder: 1,
        customLabel: 'Escena',
      ),
      const ShootDocumentBlockBlueprint(
        blockType: ShootBlockType.shot,
        sortOrder: 2,
      ),
    ];
