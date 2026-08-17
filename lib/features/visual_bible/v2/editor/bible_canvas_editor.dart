import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../bible_paste_helpers.dart';
import '../../bible_block_catalog.dart';
import '../commands/bible_document_history.dart';
import '../commands/bible_editor_commands.dart';
import '../model/bible_block.dart';
import '../model/bible_block_layout.dart';
import '../model/bible_document.dart';
import '../model/bible_page.dart';
import '../theme/bible_theme.dart';
import '../widgets/bible_block_compositor.dart';
import 'bible_block_inspector.dart';

/// Editor canvas v2: Pages | Canvas | Inspector.
class BibleCanvasEditor extends StatefulWidget {
  final BibleDocument document;
  final ValueChanged<BibleDocument> onDocumentChanged;
  final BibleDocumentHistory history;
  final bool previewMode;
  final VoidCallback? onTogglePreview;
  final String? initialPageId;
  final int? projectId;
  final int? bibleId;
  final VoidCallback? onBrowseTemplates;

  const BibleCanvasEditor({
    super.key,
    required this.document,
    required this.onDocumentChanged,
    required this.history,
    this.previewMode = false,
    this.onTogglePreview,
    this.initialPageId,
    this.projectId,
    this.bibleId,
    this.onBrowseTemplates,
  });

  @override
  State<BibleCanvasEditor> createState() => _BibleCanvasEditorState();
}

class _BibleCanvasEditorState extends State<BibleCanvasEditor> {
  late String? _pageId;
  String? _selectedBlockId;
  bool _designMode = true;

  @override
  void initState() {
    super.initState();
    _pageId =
        widget.initialPageId ??
        widget.document.navigation['lastPageId']?.toString() ??
        (widget.document.pages.isNotEmpty
            ? widget.document.pages.first.id
            : null);
  }

  BiblePage? get _page =>
      _pageId == null ? null : widget.document.pageById(_pageId!);

  BibleTheme get _theme => widget.document.resolvedTheme;

  void _apply(BibleEditorCommand cmd) {
    final next = widget.history.execute(cmd);
    widget.onDocumentChanged(next);
    setState(() {});
  }

  void _undo() {
    final next = widget.history.undo();
    if (next != null) widget.onDocumentChanged(next);
  }

  void _redo() {
    final next = widget.history.redo();
    if (next != null) widget.onDocumentChanged(next);
  }

  void _addPage() {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final page = BiblePage(
      id: 'page_$stamp',
      groupId: 'main',
      label: 'Página ${widget.document.pages.length + 1}',
      sortOrder: widget.document.pages.length,
      blocks: const [],
    );
    _apply(AddPageCommand(page));
    setState(() => _pageId = page.id);
  }

  void _duplicatePage() {
    final page = _page;
    if (page == null) return;
    final cmd = DuplicatePageCommand.create(
      doc: widget.document,
      sourcePageId: page.id,
      newPageId: 'page_${DateTime.now().millisecondsSinceEpoch}',
    );
    _apply(cmd);
    setState(() => _pageId = cmd.duplicate.id);
  }

  void _deletePage() {
    final page = _page;
    if (page == null || widget.document.pages.length <= 1) return;
    final idx = widget.document.pages.indexWhere((p) => p.id == page.id);
    _apply(DeletePageCommand(removed: page, index: idx));
    final remaining = widget.history.current.pages;
    setState(() {
      _pageId = remaining.isNotEmpty ? remaining.first.id : null;
      _selectedBlockId = null;
    });
  }

  Future<void> _renamePage() async {
    final page = _page;
    if (page == null) return;
    final ctrl = TextEditingController(text: page.label);
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar página'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (label == null || label.isEmpty || label == page.label) return;
    _apply(RenamePageCommand(pageId: page.id, fromLabel: page.label, toLabel: label));
  }

  void _movePage(int delta) {
    final page = _page;
    if (page == null) return;
    final pages = List<BiblePage>.from(widget.document.pages);
    final idx = pages.indexWhere((p) => p.id == page.id);
    final newIdx = idx + delta;
    if (idx < 0 || newIdx < 0 || newIdx >= pages.length) return;
    final item = pages.removeAt(idx);
    pages.insert(newIdx, item);
    _apply(ReorderPagesCommand(fromOrder: widget.document.pages, toOrder: pages));
  }

  void _changeTheme(String themeId) {
    _apply(UpdateThemeCommand(
      fromThemeId: widget.document.themeId,
      toThemeId: themeId,
    ));
  }

  void _addBlock(BibleBlockKind kind) {
    final page = _page;
    if (page == null) return;
    final id = 'block_${DateTime.now().millisecondsSinceEpoch}_${kind.name}';
    final maxRow = page.blocks.isEmpty
        ? 0
        : page.blocks.map((b) => b.layout.row).reduce((a, b) => a > b ? a : b) +
              2;
    final block = BibleBlock(
      id: id,
      type: kind,
      layout: BibleBlockLayout(row: maxRow, colSpan: 12, rowSpan: 2),
      content: _defaultContent(kind),
    );
    _apply(AddBlockCommand(pageId: page.id, block: block));
    setState(() => _selectedBlockId = id);
  }

  Map<String, dynamic> _defaultContent(BibleBlockKind kind) => switch (kind) {
    BibleBlockKind.narrative => {'text': '', 'label': 'Intención'},
    BibleBlockKind.chipSelect => {
      'chips': ['TENSIÓN', 'CLAUSTROFOBIA'],
      'selected': <String>[],
    },
    BibleBlockKind.colorPalette => {
      'colors': [
        {'hex': '#1E1E1E', 'name': 'DEEP SHADOW'},
        {'hex': '#2997FF', 'name': 'ACCENT'},
      ],
    },
    BibleBlockKind.telemetry => {
      'metrics': [
        {'label': 'Kelvin', 'value': '3200K'},
        {'label': 'Ratio', 'value': '4:1'},
      ],
    },
    BibleBlockKind.equipmentList => {
      'items': ['ARRI SkyPanel S60-C'],
    },
    BibleBlockKind.specsTable => {
      'columns': ['label', 'value'],
      'rows': [
        {'label': 'Camera', 'value': ''},
        {'label': 'ISO', 'value': ''},
      ],
    },
    BibleBlockKind.workflowPipeline => {
      'steps': List<String>.from(kBibleWorkflowDefaultSteps),
    },
    BibleBlockKind.lightingDiagram => {
      'label': 'Setup',
      'nodes': <Map<String, dynamic>>[],
    },
    BibleBlockKind.moodboardRefs => {'images': <Map<String, dynamic>>[]},
    BibleBlockKind.heroImage => {'label': 'Imagen'},
    _ => {'label': kind.label, 'text': ''},
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final meta =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (meta && event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (shift) {
        _redo();
      } else {
        _undo();
      }
      return KeyEventResult.handled;
    }
    if (meta &&
        event.logicalKey == LogicalKeyboardKey.keyV &&
        _selectedBlockId != null) {
      final page = _page;
      final block = page?.blocks
          .where((b) => b.id == _selectedBlockId)
          .firstOrNull;
      if (block != null &&
          (block.type == BibleBlockKind.heroImage ||
              block.type == BibleBlockKind.moodboardRefs)) {
        unawaited(_pasteIntoImageBlock(block));
        return KeyEventResult.handled;
      }
    }
    if (meta && event.logicalKey == LogicalKeyboardKey.keyD) {
      final page = _page;
      final id = _selectedBlockId;
      if (page != null && id != null) {
        final original = page.blocks.where((b) => b.id == id).firstOrNull;
        if (original != null) {
          _apply(
            DuplicateBlockCommand.create(
              pageId: page.id,
              original: original,
              newId: 'block_${DateTime.now().millisecondsSinceEpoch}',
            ),
          );
        }
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      final page = _page;
      final id = _selectedBlockId;
      if (page != null && id != null && _designMode && !widget.previewMode) {
        final idx = page.blocks.indexWhere((b) => b.id == id);
        if (idx >= 0) {
          _apply(
            DeleteBlockCommand(
              pageId: page.id,
              removed: page.blocks[idx],
              index: idx,
            ),
          );
          setState(() => _selectedBlockId = null);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _pasteIntoImageBlock(BibleBlock block) async {
    final page = _page;
    if (page == null || widget.projectId == null) return;
    await BiblePasteHelpers.pasteFromClipboard(
      onPayload: (payload) async {
        final stored = await BiblePasteHelpers.savePayloadToProject(
          projectId: widget.projectId!,
          subfolder: 'visual_bible/bible_images',
          payload: payload,
          prefix: 'img',
        );
        if (stored == null) return;
        final from = block.content;
        if (block.type == BibleBlockKind.moodboardRefs) {
          final images = List<Map<String, dynamic>>.from(
            (block.content['images'] as List? ?? const []).whereType<Map>().map(
              (e) => Map<String, dynamic>.from(e),
            ),
          );
          images.add({'path': stored});
          _apply(
            UpdateBlockContentCommand(
              pageId: page.id,
              blockId: block.id,
              from: from,
              to: {...block.content, 'images': images},
            ),
          );
          return;
        }
        final to = {
          ...block.content,
          'image': {'path': stored, 'source': 'local'},
        };
        _apply(UpdateBlockContentCommand(
          pageId: page.id,
          blockId: block.id,
          from: from,
          to: to,
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final page = _page;
    final editing = _designMode && !widget.previewMode;

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        children: [
          _Toolbar(
            canUndo: widget.history.canUndo,
            canRedo: widget.history.canRedo,
            designMode: _designMode,
            previewMode: widget.previewMode,
            themeId: widget.document.themeId,
            onThemeChanged: _changeTheme,
            onUndo: _undo,
            onRedo: _redo,
            onToggleDesign: () => setState(() => _designMode = !_designMode),
            onTogglePreview: widget.onTogglePreview,
            onAdd: editing ? () => _showAddSheet(context) : null,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!widget.previewMode)
                  SizedBox(
                    width: 200,
                    child: _PagesRail(
                      document: widget.document,
                      selectedPageId: _pageId,
                      onSelect: (id) => setState(() {
                        _pageId = id;
                        _selectedBlockId = null;
                      }),
                      onAddPage: _addPage,
                      onDuplicatePage: _duplicatePage,
                      onDeletePage: _deletePage,
                      onRenamePage: _renamePage,
                      onMovePageUp: () => _movePage(-1),
                      onMovePageDown: () => _movePage(1),
                    ),
                  ),
                Expanded(
                  child: ColoredBox(
                    color:
                        _parseHex(_theme.colors.background) ??
                        palette.background,
                    child: page == null
                        ? Center(
                            child: Text(
                              'Sin páginas',
                              style: AppTypography.bodyMedium(palette),
                            ),
                          )
                        : page.blocks.isEmpty && editing
                        ? _EmptyPage(
                            onAdd: () => _showAddSheet(context),
                            onBrowseTemplates: widget.onBrowseTemplates,
                          )
                        : SingleChildScrollView(
                            padding: EdgeInsets.all(_theme.spacing.l),
                            child: BibleBlockCompositor(
                              blocks: page.blocks,
                              theme: _theme,
                              projectId: widget.projectId ?? widget.document.projectId,
                              editing: editing,
                              selectedBlockId: _selectedBlockId,
                              onSelect: (id) =>
                                  setState(() => _selectedBlockId = id),
                              onBlockChanged: (b) {
                                final from = page.blocks.firstWhere(
                                  (x) => x.id == b.id,
                                );
                                _apply(
                                  UpdateBlockContentCommand(
                                    pageId: page.id,
                                    blockId: b.id,
                                    from: from.content,
                                    to: b.content,
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ),
                if (editing && !widget.previewMode)
                  SizedBox(
                    width: 280,
                    child: BibleBlockInspector(
                      page: page,
                      selectedBlockId: _selectedBlockId,
                      theme: _theme,
                      projectId: widget.projectId ?? widget.document.projectId,
                      onBlockChanged: (b) {
                        if (page == null) return;
                        final from = page.blocks.firstWhere(
                          (x) => x.id == b.id,
                        );
                        if (from.content.toString() != b.content.toString()) {
                          _apply(
                            UpdateBlockContentCommand(
                              pageId: page.id,
                              blockId: b.id,
                              from: from.content,
                              to: b.content,
                            ),
                          );
                        }
                        if (from.style != b.style) {
                          _apply(
                            UpdateBlockStyleCommand(
                              pageId: page.id,
                              blockId: b.id,
                              from: from.style,
                              to: b.style,
                            ),
                          );
                        }
                        if (from.layout != b.layout) {
                          _apply(
                            MoveBlockCommand(
                              pageId: page.id,
                              blockId: b.id,
                              from: from.layout,
                              to: b.layout,
                            ),
                          );
                        }
                        if (from.type != b.type) {
                          _apply(
                            ChangeBlockTypeCommand(
                              pageId: page.id,
                              blockId: b.id,
                              from: from.type,
                              to: b.type,
                            ),
                          );
                        }
                      },
                      onDelete: () {
                        if (page == null || _selectedBlockId == null) return;
                        final idx = page.blocks.indexWhere(
                          (b) => b.id == _selectedBlockId,
                        );
                        if (idx < 0) return;
                        _apply(
                          DeleteBlockCommand(
                            pageId: page.id,
                            removed: page.blocks[idx],
                            index: idx,
                          ),
                        );
                        setState(() => _selectedBlockId = null);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Añadir widget')),
              for (final kind in BibleBlockCatalog.pickerKinds)
                ListTile(
                  leading: Icon(kind.icon),
                  title: Text(kind.label),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addBlock(kind);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

Color? _parseHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

class _Toolbar extends StatelessWidget {
  final bool canUndo;
  final bool canRedo;
  final bool designMode;
  final bool previewMode;
  final String themeId;
  final ValueChanged<String> onThemeChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onToggleDesign;
  final VoidCallback? onTogglePreview;
  final VoidCallback? onAdd;

  const _Toolbar({
    required this.canUndo,
    required this.canRedo,
    required this.designMode,
    required this.previewMode,
    required this.themeId,
    required this.onThemeChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onToggleDesign,
    this.onTogglePreview,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Deshacer',
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Rehacer',
            onPressed: canRedo ? onRedo : null,
            icon: const Icon(Icons.redo),
          ),
          const VerticalDivider(width: 16),
          if (onAdd != null)
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir widget'),
            ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: themeId,
            items: const [
              DropdownMenuItem(value: BibleThemeIds.cinematic, child: Text('Cinematic')),
              DropdownMenuItem(value: BibleThemeIds.technical, child: Text('Technical')),
              DropdownMenuItem(value: BibleThemeIds.minimalist, child: Text('Minimalist')),
              DropdownMenuItem(value: BibleThemeIds.custom, child: Text('Custom')),
            ],
            onChanged: (v) {
              if (v != null) onThemeChanged(v);
            },
          ),
          const Spacer(),
          FilterChip(
            label: Text(designMode ? 'Editar diseño' : 'Lectura'),
            selected: designMode,
            onSelected: (_) => onToggleDesign(),
          ),
          const SizedBox(width: 8),
          if (onTogglePreview != null)
            OutlinedButton(
              onPressed: onTogglePreview,
              child: Text(previewMode ? 'Salir preview' : 'Preview'),
            ),
        ],
      ),
    );
  }
}

class _PagesRail extends StatelessWidget {
  final BibleDocument document;
  final String? selectedPageId;
  final ValueChanged<String> onSelect;
  final VoidCallback onAddPage;
  final VoidCallback onDuplicatePage;
  final VoidCallback onDeletePage;
  final VoidCallback onRenamePage;
  final VoidCallback onMovePageUp;
  final VoidCallback onMovePageDown;

  const _PagesRail({
    required this.document,
    required this.selectedPageId,
    required this.onSelect,
    required this.onAddPage,
    required this.onDuplicatePage,
    required this.onDeletePage,
    required this.onRenamePage,
    required this.onMovePageUp,
    required this.onMovePageDown,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pages = document.pages.where((p) => !p.isHidden).toList();
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(right: BorderSide(color: palette.border)),
      ),
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Text('PAGES', style: AppTypography.label(palette))),
                IconButton(
                  tooltip: 'Nueva página',
                  onPressed: onAddPage,
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
          ),
          for (final page in pages)
            ListTile(
              dense: true,
              selected: page.id == selectedPageId,
              title: Text(page.label, style: AppTypography.bodyMedium(palette)),
              subtitle: Text('${page.blocks.length} widgets'),
              onTap: () => onSelect(page.id),
              trailing: page.id == selectedPageId
                  ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (v) {
                        switch (v) {
                          case 'rename':
                            onRenamePage();
                          case 'dup':
                            onDuplicatePage();
                          case 'up':
                            onMovePageUp();
                          case 'down':
                            onMovePageDown();
                          case 'del':
                            onDeletePage();
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                        const PopupMenuItem(value: 'dup', child: Text('Duplicar')),
                        const PopupMenuItem(value: 'up', child: Text('Subir')),
                        const PopupMenuItem(value: 'down', child: Text('Bajar')),
                        const PopupMenuItem(value: 'del', child: Text('Eliminar')),
                      ],
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

class _EmptyPage extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback? onBrowseTemplates;

  const _EmptyPage({required this.onAdd, this.onBrowseTemplates});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Página vacía',
            style: AppTypography.titleMedium(palette),
          ),
          const SizedBox(height: 8),
          Text(
            'Añade widgets o usa un layout preset.',
            style: AppTypography.bodyMedium(palette),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Añadir widget'),
          ),
          if (onBrowseTemplates != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onBrowseTemplates,
              child: const Text('Usar plantilla de página'),
            ),
          ],
        ],
      ),
    );
  }
}
