import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/scene_characters.dart';
import '../../core/widgets/app_snackbar.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import '../look_bible/look_bible_model.dart';
import '../pdf_export/shoot_document_pdf.dart';
import '../../core/settings/user_templates_settings_section.dart';
import '../../core/templates/user_template_service.dart';
import 'shoot_document_block_resolver.dart';
import 'shoot_document_block_tile.dart';
import 'shoot_document_block_types.dart';
import 'shoot_document_composer.dart';
import 'shoot_document_on_set_view.dart';

enum _EditorMode { blocks, preview, onSet, settings }

/// Editor flexible de documentos de rodaje.
class ShootDocumentEditorScreen extends ConsumerStatefulWidget {
  final int projectId;
  final int documentId;

  const ShootDocumentEditorScreen({
    super.key,
    required this.projectId,
    required this.documentId,
  });

  @override
  ConsumerState<ShootDocumentEditorScreen> createState() =>
      _ShootDocumentEditorScreenState();
}

class _ShootDocumentEditorScreenState
    extends ConsumerState<ShootDocumentEditorScreen> {
  _EditorMode _mode = _EditorMode.blocks;
  final Map<int, Scene> _scenes = {};
  final Map<int, Shot> _shots = {};

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<ShootDocument?>(
      stream: db.watchShootDocumentsForProject(widget.projectId).map(
            (list) => list.where((d) => d.id == widget.documentId).firstOrNull,
          ),
      builder: (context, docSnap) {
        final doc = docSnap.data;
        if (doc == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Documento')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<List<ShootDocumentBlock>>(
          stream: db.watchBlocksForShootDocument(widget.documentId),
          builder: (context, blockSnap) {
            final blocks = blockSnap.data ?? [];
            return FutureBuilder<void>(
              future: _ensureLookups(db, blocks),
              builder: (context, _) {
                final docVis =
                    decodeDocumentVisibility(doc.defaultVisibilityJson);
                final resolved = blocks
                    .map(
                      (b) => ResolvedShootBlock(
                        block: b,
                        scene: b.sceneId != null ? _scenes[b.sceneId] : null,
                        shot: b.shotId != null ? _shots[b.shotId] : null,
                        visibility: mergeVisibility(docVis, b),
                        overrides: decodeContentOverrides(b.contentOverridesJson),
                      ),
                    )
                    .toList();

                return Scaffold(
                  appBar: AppBar(
                    backgroundColor: palette.surface,
                    title: Text(doc.name, style: AppTypography.titleMedium(palette)),
                    actions: [
                      IconButton(
                        tooltip: 'Guardar como plantilla',
                        icon: Icon(Icons.bookmark_add_outlined, color: palette.accent),
                        onPressed: () async {
                          final name = await promptSaveUserTemplate(
                            context,
                            title: 'Guardar documento como plantilla',
                            initialName: doc.name,
                          );
                          if (name == null) return;
                          await UserTemplateService.saveShootDocumentTemplate(
                            db: db,
                            name: name,
                            documentId: doc.id,
                          );
                          if (context.mounted) {
                            AppSnackBar.show(
                              context,
                              'Plantilla «$name» guardada. Configúrala en Ajustes.',
                            );
                          }
                        },
                      ),
                      GoodNotesPdfActions(
                        projectId: widget.projectId,
                        moduleType: GoodNotesModuleType.shootDocument,
                        filenameBase: doc.name.replaceAll(RegExp(r'[^\w\s-]'), ''),
                        buildPdfBytes: () => ShootDocumentPdfExporter.buildBytes(
                          document: doc,
                          blocks: resolved,
                          projectName: '',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Exportar PDF',
                        icon: Icon(Icons.picture_as_pdf_outlined, color: palette.accent),
                        onPressed: () => _exportPdf(doc, resolved),
                      ),
                      if (!doc.isPrimaryOnSet)
                        IconButton(
                          tooltip: 'Activo hoy',
                          icon: Icon(Icons.star_outline, color: palette.accent),
                          onPressed: () async {
                            await db.setPrimaryShootDocument(
                              widget.projectId,
                              doc.id,
                            );
                          },
                        ),
                    ],
                  ),
                  body: Column(
                    children: [
                      _ModeBar(
                        mode: _mode,
                        palette: palette,
                        onChanged: (m) => setState(() => _mode = m),
                      ),
                      Expanded(
                        child: switch (_mode) {
                          _EditorMode.blocks => _BlocksEditor(
                              blocks: blocks,
                              resolved: resolved,
                              palette: palette,
                              onReorder: (ids) => db.reorderShootDocumentBlocks(
                                widget.documentId,
                                ids,
                              ),
                              onAdd: () => _addBlock(context, db, blocks.length),
                              onEdit: (b) => _editBlock(context, db, b),
                              onDelete: (b) => db.deleteShootDocumentBlock(b.id),
                              onDuplicate: (b) => _duplicateBlock(db, b, blocks.length),
                            ),
                          _EditorMode.preview => ListView(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              children: [
                                for (final r in resolved)
                                  ShootDocumentBlockTile(
                                    resolved: r,
                                    palette: palette,
                                    editing: false,
                                  ),
                              ],
                            ),
                          _EditorMode.onSet => ShootDocumentOnSetView(
                              document: doc,
                              blocks: resolved,
                              palette: palette,
                            ),
                          _EditorMode.settings => _DocSettings(
                              doc: doc,
                              palette: palette,
                              onSave: (updated) => db.updateShootDocument(updated),
                            ),
                        },
                      ),
                    ],
                  ),
                  floatingActionButton: _mode == _EditorMode.blocks
                      ? FloatingActionButton.extended(
                          onPressed: () => _addBlock(context, db, blocks.length),
                          icon: const Icon(Icons.add),
                          label: const Text('Bloque'),
                        )
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _ensureLookups(
    AppDatabase db,
    List<ShootDocumentBlock> blocks,
  ) async {
    for (final b in blocks) {
      if (b.sceneId != null && !_scenes.containsKey(b.sceneId)) {
        final s = await (db.select(db.scenes)
              ..where((sc) => sc.id.equals(b.sceneId!)))
            .getSingleOrNull();
        if (s != null) _scenes[b.sceneId!] = s;
      }
      if (b.shotId != null && !_shots.containsKey(b.shotId)) {
        final sh = await (db.select(db.shots)
              ..where((s) => s.id.equals(b.shotId!)))
            .getSingleOrNull();
        if (sh != null) _shots[b.shotId!] = sh;
      }
    }
  }

  Future<void> _exportPdf(
    ShootDocument doc,
    List<ResolvedShootBlock> resolved,
  ) async {
    final path = await ShootDocumentPdfExporter.exportAndSave(
      document: doc,
      blocks: resolved,
      projectName: doc.name,
    );
    if (!mounted) return;
    if (path != null) {
      AppSnackBar.show(context, 'PDF guardado en $path');
    }
  }

  Future<void> _addBlock(
    BuildContext context,
    AppDatabase db,
    int nextOrder,
  ) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.palette.surfaceElevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in ShootBlockType.all)
              ListTile(
                title: Text(ShootBlockType.label(t)),
                onTap: () => Navigator.pop(ctx, t),
              ),
          ],
        ),
      ),
    );
    if (type == null) return;

    await db.insertShootDocumentBlock(
      ShootDocumentBlocksCompanion.insert(
        documentId: widget.documentId,
        sortOrder: Value(nextOrder),
        blockType: type,
        customLabel: type == ShootBlockType.sectionHeader
            ? const Value('Nueva sección')
            : const Value.absent(),
        noteBody: type == ShootBlockType.note
            ? const Value('')
            : const Value.absent(),
      ),
    );
  }

  Future<void> _editBlock(
    BuildContext context,
    AppDatabase db,
    ShootDocumentBlock block,
  ) async {
    final palette = context.palette;
    final labelCtrl = TextEditingController(text: block.customLabel ?? '');
    final noteCtrl = TextEditingController(text: block.noteBody ?? '');
    final scriptCtrl = TextEditingController(text: block.scriptExcerpt ?? '');
    final durCtrl = TextEditingController(
      text: block.durationSeconds?.toString() ?? '',
    );
    final charsCtrl = TextEditingController(
      text: formatCharactersInput(decodeSceneCharacters(block.charactersJson)),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text('Editar bloque', style: AppTypography.titleLarge(palette)),
        content: SingleChildScrollView(
          child: Column(
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
                  decoration: const InputDecoration(labelText: 'Nota'),
                ),
              if (block.blockType == ShootBlockType.scriptExcerpt)
                TextField(
                  controller: scriptCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Texto de guion'),
                ),
              if (block.blockType == ShootBlockType.shot ||
                  block.blockType == ShootBlockType.characterList) ...[
                TextField(
                  controller: charsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Personajes (coma)',
                  ),
                ),
                TextField(
                  controller: durCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duración (segundos)',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Guardar', style: AppTypography.bodyMedium(palette)
                .copyWith(color: palette.accent)),
          ),
        ],
      ),
    );
    if (saved != true) return;

    await db.updateShootDocumentBlock(
      block.copyWith(
        customLabel: Value(
          labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim(),
        ),
        noteBody: Value(
          noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        ),
        scriptExcerpt: Value(
          scriptCtrl.text.trim().isEmpty ? null : scriptCtrl.text.trim(),
        ),
        charactersJson: Value(
          encodeSceneCharacters(parseCharactersInput(charsCtrl.text)),
        ),
        durationSeconds: Value(int.tryParse(durCtrl.text.trim())),
      ),
    );
  }

  Future<void> _duplicateBlock(
    AppDatabase db,
    ShootDocumentBlock block,
    int nextOrder,
  ) async {
    final companion = ShootDocumentComposer.duplicateBlock(
      block,
      widget.documentId,
      nextOrder,
    );
    await db.insertShootDocumentBlock(companion);
  }
}

class _ModeBar extends StatelessWidget {
  final _EditorMode mode;
  final AppPalette palette;
  final ValueChanged<_EditorMode> onChanged;

  const _ModeBar({
    required this.mode,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: SegmentedButton<_EditorMode>(
          segments: const [
            ButtonSegment(value: _EditorMode.blocks, label: Text('Bloques')),
            ButtonSegment(value: _EditorMode.preview, label: Text('Vista previa')),
            ButtonSegment(value: _EditorMode.onSet, label: Text('Modo set')),
            ButtonSegment(value: _EditorMode.settings, label: Text('Ajustes')),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ),
    );
  }
}

class _BlocksEditor extends StatelessWidget {
  final List<ShootDocumentBlock> blocks;
  final List<ResolvedShootBlock> resolved;
  final AppPalette palette;
  final Future<void> Function(List<int> ids) onReorder;
  final VoidCallback onAdd;
  final void Function(ShootDocumentBlock) onEdit;
  final void Function(ShootDocumentBlock) onDelete;
  final void Function(ShootDocumentBlock) onDuplicate;

  const _BlocksEditor({
    required this.blocks,
    required this.resolved,
    required this.palette,
    required this.onReorder,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return Center(
        child: Text(
          'Añade bloques con el botón +',
          style: AppTypography.bodyMedium(palette),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: blocks.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        final ids = blocks.map((b) => b.id).toList();
        final id = ids.removeAt(oldIndex);
        ids.insert(newIndex, id);
        onReorder(ids);
      },
      itemBuilder: (context, index) {
        final block = blocks[index];
        final r = resolved[index];
        return ShootDocumentBlockTile(
          key: ValueKey(block.id),
          resolved: r,
          palette: palette,
          onEdit: () => onEdit(block),
          onDelete: () => onDelete(block),
          onDuplicate: () => onDuplicate(block),
        );
      },
    );
  }
}

class _DocSettings extends StatefulWidget {
  final ShootDocument doc;
  final AppPalette palette;
  final Future<bool> Function(ShootDocument) onSave;

  const _DocSettings({
    required this.doc,
    required this.palette,
    required this.onSave,
  });

  @override
  State<_DocSettings> createState() => _DocSettingsState();
}

class _DocSettingsState extends State<_DocSettings> {
  late ShootBlockVisibility _vis;
  late TextEditingController _dateCtrl;
  late String _layout;

  @override
  void initState() {
    super.initState();
    _vis = decodeDocumentVisibility(widget.doc.defaultVisibilityJson);
    _dateCtrl = TextEditingController(text: widget.doc.shootDate ?? '');
    _layout = widget.doc.layoutPreset;
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Visibilidad global', style: AppTypography.titleMedium(widget.palette)),
        SwitchListTile(
          title: const Text('Referencias visuales'),
          value: _vis.showThumbnail,
          onChanged: (v) => setState(() => _vis = _vis.copyWith(showThumbnail: v)),
        ),
        SwitchListTile(
          title: const Text('Personajes'),
          value: _vis.showCharacters,
          onChanged: (v) => setState(() => _vis = _vis.copyWith(showCharacters: v)),
        ),
        SwitchListTile(
          title: const Text('Duración'),
          value: _vis.showDuration,
          onChanged: (v) => setState(() => _vis = _vis.copyWith(showDuration: v)),
        ),
        SwitchListTile(
          title: const Text('Datos de cámara'),
          value: _vis.showCamera,
          onChanged: (v) => setState(() => _vis = _vis.copyWith(showCamera: v)),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _dateCtrl,
          decoration: const InputDecoration(
            labelText: 'Fecha de jornada (opcional)',
            hintText: '2026-08-04',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          value: _layout,
          decoration: const InputDecoration(labelText: 'Layout de vista'),
          items: [
            for (final p in [
              ShootLayoutPreset.freeform,
              ShootLayoutPreset.scriptLeftShotsRight,
              ShootLayoutPreset.stacked,
              ShootLayoutPreset.shotsOnly,
            ])
              DropdownMenuItem(
                value: p,
                child: Text(ShootLayoutPreset.label(p)),
              ),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _layout = v);
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: () async {
            await widget.onSave(
              widget.doc.copyWith(
                defaultVisibilityJson: Value(encodeDocumentVisibility(_vis)),
                shootDate: Value(
                  _dateCtrl.text.trim().isEmpty ? null : _dateCtrl.text.trim(),
                ),
                layoutPreset: _layout,
                updatedAt: DateTime.now(),
              ),
            );
            if (mounted) {
              AppSnackBar.show(context, 'Ajustes guardados');
            }
          },
          child: const Text('Guardar ajustes'),
        ),
      ],
    );
  }
}
