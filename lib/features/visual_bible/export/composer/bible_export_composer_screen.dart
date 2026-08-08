import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../shared/annotations/annotation_canvas.dart';
import '../../../../shared/annotations/annotation_document.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../../bible_block_catalog.dart';
import '../../v2/model/bible_block.dart';
import '../../v2/model/bible_block_layout.dart';
import '../../v2/theme/bible_theme.dart';
import '../../v2/model/bible_document.dart';
import '../../v2/widgets/bible_block_compositor.dart';
import '../builder/bible_export_composition_builder.dart';
import '../commands/bible_export_composition_history.dart';
import '../model/bible_export_composition.dart';
import '../store/bible_export_composition_store.dart';

typedef BibleExportRenderRequest =
    Future<void> Function(BibleExportComposition composition);

typedef BibleExportBundleLoader = Future<BibleExportSourceBundle> Function();
typedef BibleExportDocumentLoader = Future<BibleDocument?> Function();

/// Editor visual no destructivo previo al renderer PDF.
class BibleExportComposerScreen extends StatefulWidget {
  final BibleExportComposition initialComposition;
  final BibleExportCompositionStore store;
  final AppDatabase database;
  final BibleExportRenderRequest? onRequestPdf;
  final BibleExportBundleLoader? loadExportBundle;
  final BibleExportDocumentLoader? loadSourceDocument;

  const BibleExportComposerScreen({
    super.key,
    required this.initialComposition,
    required this.store,
    required this.database,
    this.onRequestPdf,
    this.loadExportBundle,
    this.loadSourceDocument,
  });

  @override
  State<BibleExportComposerScreen> createState() =>
      _BibleExportComposerScreenState();
}

class _BibleExportComposerScreenState extends State<BibleExportComposerScreen> {
  late BibleExportCompositionHistory _history;
  late BibleExportComposition _composition;
  final _annotationControllers = <String, AnnotationCanvasController>{};
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _loadedAnnotations = <String>{};
  Future<void> _annotationSaveChain = Future.value();
  String? _selectedPageId;
  String? _selectedBlockId;
  bool _annotating = false;
  bool _saving = false;
  bool _dirty = false;
  AnnotationToolType _tool = AnnotationToolType.pen;
  Color _annotationColor = const Color(0xFF2997FF);
  double _annotationWidth = 4;

  BibleExportPage? get _page =>
      _selectedPageId == null ? null : _composition.pageById(_selectedPageId!);

  AnnotationCanvasController? get _annotationController =>
      _selectedPageId == null ? null : _annotationControllers[_selectedPageId!];

  @override
  void initState() {
    super.initState();
    _composition = widget.initialComposition;
    _history = BibleExportCompositionHistory(_composition);
    if (_composition.pages.isNotEmpty) {
      _selectedPageId = _composition.pages.first.id;
      unawaited(_ensureAnnotations(_composition.pages.first));
    }
  }

  @override
  void dispose() {
    for (final controller in _annotationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  AnnotationCanvasController _controllerFor(String pageId) {
    return _annotationControllers.putIfAbsent(pageId, () {
      final controller = AnnotationCanvasController();
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      return controller;
    });
  }

  Future<void> _ensureAnnotations(BibleExportPage page) async {
    final controller = _controllerFor(page.id);
    if (_loadedAnnotations.contains(page.id)) return;
    final row = await widget.database.getProjectAnnotationDocument(
      projectId: _composition.projectId,
      targetType: kBibleExportAnnotationTargetType,
      targetId: page.annotationTargetId,
    );
    if (!mounted) return;
    controller.replaceDocument(AnnotationDocument.decode(row?.documentJson));
    _loadedAnnotations.add(page.id);
    setState(() {});
  }

  void _selectPage(BibleExportPage page) {
    setState(() {
      _selectedPageId = page.id;
      _selectedBlockId = null;
    });
    unawaited(_ensureAnnotations(page));
  }

  void _execute(BibleExportCompositionMutation mutation) {
    setState(() {
      _composition = _history.execute(mutation);
      _dirty = true;
    });
  }

  void _undo() {
    final annotations = _annotationController;
    if (_annotating && annotations?.canUndo == true) {
      annotations!.undo();
      return;
    }
    final previous = _history.undo();
    if (previous != null) {
      setState(() {
        _composition = previous;
        _dirty = true;
      });
    }
  }

  void _redo() {
    final annotations = _annotationController;
    if (_annotating && annotations?.canRedo == true) {
      annotations!.redo();
      return;
    }
    final next = _history.redo();
    if (next != null) {
      setState(() {
        _composition = next;
        _dirty = true;
      });
    }
  }

  Future<void> _saveDraft() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.store.save(_composition, label: 'Montaje');
      if (!mounted) return;
      setState(() {
        _composition = saved;
        _dirty = false;
      });
      AppSnackBar.show(context, 'Borrador guardado');
    } catch (error) {
      if (mounted) AppSnackBar.showError(context, 'No se pudo guardar: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _persistAnnotations(BibleExportPage page, AnnotationDocument document) {
    if (!_loadedAnnotations.contains(page.id)) return;
    _annotationSaveChain = _annotationSaveChain
        .then(
          (_) => widget.database.saveProjectAnnotationDocument(
            projectId: _composition.projectId,
            targetType: kBibleExportAnnotationTargetType,
            targetId: page.annotationTargetId,
            documentJson: document.encode(),
            documentSchemaVersion: document.schemaVersion,
          ),
        )
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('No se pudo guardar la anotación de exportación: $error');
        });
  }

  BibleTheme _themeForPage(BibleExportPage page) {
    final sectionId = page.source?.sectionId ??
        page.metadata['sectionId']?.toString();
    if (sectionId == null) return BibleThemePresets.cinematic;
    return switch (sectionId) {
      BibleSectionId.camera ||
      BibleSectionId.optics ||
      BibleSectionId.exposure => BibleThemePresets.technical,
      BibleSectionId.format || BibleSectionId.texture => BibleThemePresets.minimalist,
      _ => BibleThemePresets.cinematic,
    };
  }

  void _addCatalogBlock(BibleBlockKind kind) {
    final page = _page;
    if (page == null) return;
    final id = const Uuid().v4();
    final block = BibleBlock(
      id: '${kind.name}_$id',
      type: kind,
      layout: BibleBlockLayout(row: page.blocks.length, colSpan: kind == BibleBlockKind.heroImage ? 12 : 6),
      content: switch (kind) {
        BibleBlockKind.narrative => const {
            'label': 'Intención narrativa',
            'hint': 'Ej.: tono orientativo para esta pantalla…',
            'text': '',
          },
        BibleBlockKind.moodboardRefs => const {'title': 'Referencias'},
        BibleBlockKind.colorPalette => const {'title': 'Paleta dominante'},
        BibleBlockKind.heroImage => const {'title': 'Referencia hero'},
        _ => {'label': kind.label, 'text': ''},
      },
    );
    _execute(
      (composition) => replaceBibleExportPage(
        composition,
        page.copyWith(blocks: [...page.blocks, block]),
      ),
    );
    setState(() => _selectedBlockId = block.id);
  }

  void _addBlankPage() {
    final id = const Uuid().v4();
    final page = BibleExportPage(
      id: '${_composition.id}__blank_$id',
      label: 'Folio blanco ${_composition.pages.length + 1}',
      type: BibleExportPageType.blank,
      format: _page?.format ?? BibleExportPageFormat.a4Portrait,
    );
    _execute((composition) => appendBibleExportPage(composition, page));
    _selectPage(page);
  }

  void _addText() {
    final page = _page;
    if (page == null) return;
    final id = const Uuid().v4();
    final block = BibleBlock(
      id: 'text_$id',
      type: BibleBlockKind.text,
      layout: BibleBlockLayout(row: page.blocks.length),
      content: const {'label': 'Texto', 'text': 'Escribe aquí…'},
    );
    _execute(
      (composition) => replaceBibleExportPage(
        composition,
        page.copyWith(blocks: [...page.blocks, block]),
      ),
    );
    setState(() => _selectedBlockId = block.id);
  }

  Future<void> _addPostIt() async {
    final page = _page;
    if (page == null) return;
    final text = await _askText('Nuevo post-it', 'Nota…');
    if (text == null || text.trim().isEmpty || !mounted) return;
    await _ensureAnnotations(page);
    _annotationControllers[page.id]?.addNote(
      AnnotationNote(
        id: const Uuid().v4(),
        text: text.trim(),
        x: 0.1,
        y: 0.1,
        width: 0.28,
        height: 0.16,
        colorArgb: 0xFFFFE082,
      ),
    );
    final controller = _annotationControllers[page.id];
    if (controller != null) _persistAnnotations(page, controller.document);
    setState(() => _annotating = true);
  }

  Future<String?> _askText(String title, String hint) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _updateBlock(BibleBlock block) {
    final page = _page;
    if (page == null) return;
    _execute(
      (composition) => replaceBibleExportPage(
        composition,
        page.copyWith(
          blocks: [
            for (final current in page.blocks)
              if (current.id == block.id) block else current,
          ],
        ),
      ),
    );
  }

  void _deleteSelectedBlock() {
    final page = _page;
    final blockId = _selectedBlockId;
    if (page == null || blockId == null) return;
    _execute(
      (composition) => replaceBibleExportPage(
        composition,
        page.copyWith(
          blocks: page.blocks.where((block) => block.id != blockId).toList(),
        ),
      ),
    );
    setState(() => _selectedBlockId = null);
  }

  void _toggleFormat() {
    final page = _page;
    if (page == null) return;
    final format = page.format == BibleExportPageFormat.a4Portrait
        ? BibleExportPageFormat.a4Landscape
        : BibleExportPageFormat.a4Portrait;
    _execute(
      (composition) =>
          replaceBibleExportPage(composition, page.copyWith(format: format)),
    );
  }

  void _restorePage() async {
    final page = _page;
    if (page == null || page.source == null) return;

    final loadBundle = widget.loadExportBundle;
    final loadDoc = widget.loadSourceDocument;
    if (loadBundle != null) {
      try {
        final bundle = await loadBundle();
        final sourceDocument = loadDoc != null ? await loadDoc() : null;
        final restored = BibleExportCompositionBuilder().restorePage(
          composition: _composition,
          pageId: page.id,
          bundle: bundle,
          sourceDocument: sourceDocument,
        );
        _execute((_) => restored);
        setState(() => _selectedBlockId = null);
        if (mounted) {
          AppSnackBar.show(context, 'Página restaurada desde la Biblia');
        }
        return;
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(context, 'No se pudo restaurar: $e');
        }
      }
    }

    final sourceBlocks = page.metadata['sourceBlocks'];
    if (sourceBlocks is! List) return;
    final blocks = sourceBlocks
        .whereType<Map>()
        .map((value) => BibleBlock.fromJson(Map<String, dynamic>.from(value)))
        .toList();
    _execute(
      (composition) =>
          replaceBibleExportPage(composition, page.copyWith(blocks: blocks)),
    );
    setState(() => _selectedBlockId = null);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final compact = MediaQuery.sizeOf(context).width < 1100;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !_dirty) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Borrador sin guardar'),
            content: const Text('¿Salir y descartar los últimos cambios?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Seguir editando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salir'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: palette.background,
        appBar: _buildAppBar(compact: compact),
        endDrawer: compact
            ? Drawer(width: 300, child: SafeArea(child: _buildInspector()))
            : null,
        body: Row(
          children: [
            SizedBox(width: compact ? 176 : 224, child: _buildPageRail()),
            VerticalDivider(width: 1, color: palette.border),
            Expanded(child: _buildWorkspace()),
            if (!compact) ...[
              VerticalDivider(width: 1, color: palette.border),
              SizedBox(width: 248, child: _buildInspector()),
            ],
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({required bool compact}) {
    final annotation = _annotationController;
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_composition.config.name),
          Text(
            _dirty
                ? 'Cambios sin guardar'
                : 'Borrador · revisión ${_composition.revision}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Deshacer',
          onPressed:
              (_annotating ? annotation?.canUndo == true : _history.canUndo)
              ? _undo
              : null,
          icon: const Icon(Icons.undo),
        ),
        IconButton(
          tooltip: 'Rehacer',
          onPressed:
              (_annotating ? annotation?.canRedo == true : _history.canRedo)
              ? _redo
              : null,
          icon: const Icon(Icons.redo),
        ),
        const SizedBox(width: AppSpacing.sm),
        if (compact)
          IconButton(
            tooltip: 'Guardar borrador',
            onPressed: _saving ? null : _saveDraft,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          )
        else
          OutlinedButton.icon(
            onPressed: _saving ? null : _saveDraft,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Guardar borrador'),
          ),
        if (widget.onRequestPdf != null) ...[
          const SizedBox(width: AppSpacing.sm),
          if (compact)
            IconButton.filled(
              tooltip: 'Generar PDF',
              onPressed: () => widget.onRequestPdf!(_composition),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            )
          else
            FilledButton.icon(
              onPressed: () => widget.onRequestPdf!(_composition),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Generar PDF'),
            ),
        ],
        if (compact)
          IconButton(
            tooltip: 'Inspector',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.tune),
          ),
        const SizedBox(width: AppSpacing.md),
      ],
    );
  }

  Widget _buildPageRail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Expanded(child: Text('PÁGINAS')),
              IconButton(
                tooltip: 'Añadir folio blanco',
                onPressed: _addBlankPage,
                icon: const Icon(Icons.note_add_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            itemCount: _composition.pages.length,
            onReorderItem: (oldIndex, newIndex) => _execute(
              (composition) =>
                  reorderBibleExportPages(composition, oldIndex, newIndex),
            ),
            itemBuilder: (context, index) {
              final page = _composition.pages[index];
              final selected = page.id == _selectedPageId;
              return Card(
                key: ValueKey(page.id),
                color: selected ? context.palette.accentMuted : null,
                child: ListTile(
                  selected: selected,
                  onTap: () => _selectPage(page),
                  leading: SizedBox(
                    width: 38,
                    child: AspectRatio(
                      aspectRatio:
                          page.format == BibleExportPageFormat.a4Portrait
                          ? 1 / 1.4142
                          : 1.4142,
                      child: const ColoredBox(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    page.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${index + 1} · ${page.formatLabel}'),
                  trailing: const Icon(Icons.drag_indicator),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWorkspace() {
    final page = _page;
    if (page == null) {
      return const Center(child: Text('Añade una página para comenzar'));
    }
    final controller = _controllerFor(page.id);
    final ratio = page.format == BibleExportPageFormat.a4Portrait
        ? 1 / 1.4142
        : 1.4142;
    return Column(
      children: [
        _buildCanvasToolbar(page),
        Expanded(
          child: ColoredBox(
            color: const Color(0xFF3A3A3C),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: AspectRatio(
                  aspectRatio: ratio,
                  child: Material(
                    elevation: 12,
                    color: Colors.white,
                    child: AnnotationCanvas(
                      controller: controller,
                      enabled: _annotating && _tool != AnnotationToolType.select,
                      tool: _tool,
                      color: _annotationColor,
                      width: _annotationWidth,
                      acceptTouch: false,
                      acceptMouse: true,
                      interactiveNotes: _annotating,
                      onChanged: (document) =>
                          _persistAnnotations(page, document),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          page.margins.left,
                          page.margins.top,
                          page.margins.right,
                          page.margins.bottom,
                        ),
                        child: SingleChildScrollView(
                          child: BibleBlockCompositor(
                            blocks: page.blocks,
                            theme: _themeForPage(page),
                            projectId: _composition.projectId,
                            editing: !_annotating,
                            selectedBlockId: _selectedBlockId,
                            onSelect: (id) =>
                                setState(() => _selectedBlockId = id),
                            onBlockChanged: _updateBlock,
                            freeformAspectRatio: ratio,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCanvasToolbar(BibleExportPage page) {
    return Material(
      color: context.palette.surface,
      child: SizedBox(
        height: 52,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.touch_app_outlined),
                  label: Text('Editar'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.draw_outlined),
                  label: Text('Anotar'),
                ),
              ],
              selected: {_annotating},
              onSelectionChanged: (value) =>
                  setState(() => _annotating = value.first),
            ),
            if (_annotating) ...[
              const SizedBox(width: AppSpacing.md),
              DropdownButton<AnnotationToolType>(
                value: _tool,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: AnnotationToolType.pen,
                    child: Text('Lápiz'),
                  ),
                  DropdownMenuItem(
                    value: AnnotationToolType.highlighter,
                    child: Text('Marcador'),
                  ),
                  DropdownMenuItem(
                    value: AnnotationToolType.arrow,
                    child: Text('Flecha'),
                  ),
                  DropdownMenuItem(
                    value: AnnotationToolType.eraser,
                    child: Text('Goma'),
                  ),
                  DropdownMenuItem(
                    value: AnnotationToolType.select,
                    child: Text('Seleccionar'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _tool = value);
                },
              ),
              IconButton(
                tooltip: 'Cambiar color',
                onPressed: () => setState(() {
                  _annotationColor = _annotationColor == const Color(0xFF2997FF)
                      ? const Color(0xFFFF453A)
                      : const Color(0xFF2997FF);
                }),
                icon: Icon(Icons.circle, color: _annotationColor),
              ),
              SizedBox(
                width: 90,
                child: Slider(
                  value: _annotationWidth,
                  min: 2,
                  max: 16,
                  onChanged: (value) =>
                      setState(() => _annotationWidth = value),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInspector() {
    final page = _page;
    final selectedBlock = page?.blocks
        .where((block) => block.id == _selectedBlockId)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('AÑADIR'),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: _addBlankPage,
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Folio blanco'),
          ),
          OutlinedButton.icon(
            onPressed: page == null ? null : _addText,
            icon: const Icon(Icons.text_fields),
            label: const Text('Texto'),
          ),
          OutlinedButton.icon(
            onPressed: page == null ? null : _addPostIt,
            icon: const Icon(Icons.sticky_note_2_outlined),
            label: const Text('Post-it'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'BLOQUES STITCH',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final kind in [
                BibleBlockKind.narrative,
                BibleBlockKind.moodboardRefs,
                BibleBlockKind.heroImage,
                BibleBlockKind.colorPalette,
                BibleBlockKind.telemetry,
                BibleBlockKind.dynamicBlocks,
              ])
                ActionChip(
                  avatar: Icon(kind.icon, size: 16),
                  label: Text(kind.label, style: const TextStyle(fontSize: 11)),
                  onPressed: page == null ? null : () => _addCatalogBlock(kind),
                ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          const Text('PÁGINA'),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(page?.label ?? 'Sin página'),
            subtitle: Text(page?.formatLabel ?? ''),
          ),
          OutlinedButton.icon(
            onPressed: page == null ? null : _toggleFormat,
            icon: const Icon(Icons.screen_rotation_alt_outlined),
            label: const Text('Cambiar orientación'),
          ),
          OutlinedButton.icon(
            onPressed:
                page?.source != null || page?.metadata['sourceBlocks'] is List
                ? _restorePage
                : null,
            icon: const Icon(Icons.restore_page_outlined),
            label: const Text('Restaurar desde Biblia'),
          ),
          if (_selectedBlockId != null) ...[
            const Divider(height: AppSpacing.xl),
            const Text('BLOQUE SELECCIONADO'),
            const SizedBox(height: AppSpacing.sm),
            if (selectedBlock != null) ...[
              Text('Anchura · ${selectedBlock.layout.colSpan}/12'),
              Slider(
                value: selectedBlock.layout.colSpan.toDouble(),
                min: 1,
                max: 12,
                divisions: 11,
                onChanged: (value) => _updateBlock(
                  selectedBlock.copyWith(
                    layout: selectedBlock.layout.copyWith(
                      colSpan: value.round(),
                    ),
                  ),
                ),
              ),
              Text('Altura · ${selectedBlock.layout.rowSpan}'),
              Slider(
                value: selectedBlock.layout.rowSpan.toDouble().clamp(1, 8),
                min: 1,
                max: 8,
                divisions: 7,
                onChanged: (value) => _updateBlock(
                  selectedBlock.copyWith(
                    layout: selectedBlock.layout.copyWith(
                      rowSpan: value.round(),
                    ),
                  ),
                ),
              ),
            ],
            OutlinedButton.icon(
              onPressed: _deleteSelectedBlock,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar bloque'),
            ),
          ],
          const Spacer(),
          Text(
            'Las ediciones afectan solo al borrador de exportación.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

extension on BibleExportPage {
  String get formatLabel => format == BibleExportPageFormat.a4Portrait
      ? 'A4 vertical'
      : 'A4 apaisado';
}
