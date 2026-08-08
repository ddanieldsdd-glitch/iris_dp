import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/templates/user_template_models.dart';
import '../../../core/templates/user_template_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import 'visual_bible_model.dart';
import 'v2/bible_v2_policy.dart';
import 'v2/commands/bible_document_history.dart';
import 'v2/commands/bible_editor_commands.dart';
import 'v2/editor/bible_canvas_editor.dart';
import 'v2/migration/bible_migration_service.dart';
import 'v2/model/bible_document.dart';
import 'v2/model/bible_page.dart';
import 'v2/model/bible_page_mode.dart';
import 'v2/persistence/bible_document_store.dart';
import 'v2/templates/bible_professional_template_service.dart';
import 'v2/templates/bible_template_apply_service.dart';
import 'v2/templates/bible_template_preview_screen.dart';
import 'v2/templates/bible_v2_professional_templates.dart';
import 'v2/templates/bible_template_package.dart';
import 'v2/widgets/bible_v2_start_screen.dart';
import 'widgets/bible_v2_template_library_sheet.dart';

/// Pantalla principal del motor V2 (Document → Page → Block).
class VisualBibleV2Screen extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;
  final VisualBibleData? legacyData;
  final VoidCallback? onExportPdf;
  final VoidCallback? onOpenSettings;

  const VisualBibleV2Screen({
    super.key,
    required this.projectId,
    required this.bibleId,
    this.legacyData,
    this.onExportPdf,
    this.onOpenSettings,
  });

  @override
  ConsumerState<VisualBibleV2Screen> createState() =>
      _VisualBibleV2ScreenState();
}

class _VisualBibleV2ScreenState extends ConsumerState<VisualBibleV2Screen> {
  BibleDocumentHistory? _history;
  BibleDocumentAutosave? _autosave;
  bool _loading = true;
  String? _error;
  String _saveStatus = 'Guardado';
  bool _showStart = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = ref.read(databaseProvider);
      final store = BibleDocumentStore(db);
      var doc = await store.loadForBible(widget.bibleId);
      doc ??= BibleDocument.empty(
        projectId: widget.projectId,
        bibleId: widget.bibleId,
      );
      if (doc.bibleId == null) {
        doc = doc.copyWith(bibleId: widget.bibleId);
      }
      if ((await store.loadForBible(widget.bibleId)) == null) {
        await store.save(doc);
      }
      _history = BibleDocumentHistory(doc);
      _autosave = BibleDocumentAutosave(
        persist: (d) async {
          setState(() => _saveStatus = 'Guardando…');
          await store.save(d.copyWith(updatedAt: DateTime.now().toUtc()));
          if (mounted) setState(() => _saveStatus = 'Guardado');
        },
      );
      _showStart = doc.pages.isEmpty;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onDocChanged(BibleDocument doc) {
    setState(() {
      _saveStatus = 'Cambios pendientes';
      if (doc.pages.isNotEmpty) _showStart = false;
    });
    _autosave?.schedule(doc);
  }

  void _apply(BibleEditorCommand cmd) {
    final history = _history;
    if (history == null) return;
    final next = history.execute(cmd);
    _onDocChanged(next);
    setState(() {});
  }

  Future<void> _createFirstPage() async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final page = BiblePage(
      id: 'page_$stamp',
      groupId: 'main',
      label: 'Página 1',
      sortOrder: 0,
      pageMode: BiblePageMode.freeform,
      layoutRecipeId: 'freeform_grid_v1',
      blocks: const [],
    );
    _apply(AddPageCommand(page));
    setState(() => _showStart = false);
  }

  Future<void> _openTemplateLibrary({required bool examplesMode}) async {
    final packages = BibleV2ProfessionalTemplates.all;
    await BibleV2TemplateLibrarySheet.show(
      context,
      packages: packages,
      examplesMode: examplesMode,
      onPreview: (pack) => _previewTemplate(pack, examplesMode: examplesMode),
    );
  }

  Future<void> _previewTemplate(
    BibleTemplatePackage pack, {
    required bool examplesMode,
  }) async {
    await BibleTemplatePreviewScreen.push(
      context,
      package: pack,
      isExample: examplesMode,
      onUse: () async {
        final history = _history;
        if (history == null) return;
        final previous = history.current;
        final db = ref.read(databaseProvider);
        final applied = await BibleProfessionalTemplateService.applyProfessionalPackage(
          db: db,
          projectId: widget.projectId,
          bibleId: widget.bibleId,
          package: pack,
          applySampleSeed: examplesMode,
          includeContent: examplesMode || pack.legacyBundle == null,
        );
        _apply(
          ApplyDocumentCommand(previous: previous, next: applied),
        );
        if (mounted) {
          AppSnackBar.show(context, 'Plantilla «${pack.name}» aplicada');
        }
      },
    );
  }

  Future<void> _saveAsTemplate() async {
    final history = _history;
    if (history == null || history.current.pages.isEmpty) return;
    final db = ref.read(databaseProvider);
    final applyService = BibleTemplateApplyService(
      BibleDocumentStore(db),
    );
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final pack = applyService.saveAsPackage(
      document: history.current,
      id: 'user_$stamp',
      name: 'Mi plantilla',
      description: 'Guardada desde la Biblia actual',
      category: 'Mis plantillas',
    );
    await UserTemplateService.upsertRaw(
      db: db,
      type: UserTemplateType.bibleLayout,
      name: pack.name,
      description: pack.description,
      payloadJson: pack.encode(),
      existingId: pack.id,
    );
    if (mounted) {
      AppSnackBar.show(
        context,
        'Plantilla «${pack.name}» guardada (${pack.document?.pages.length ?? 0} páginas)',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _history == null) {
      return Center(child: Text('Error: $_error'));
    }

    if (_showStart && _history!.current.pages.isEmpty) {
      return BibleV2StartScreen(
        onCreateFirstPage: _createFirstPage,
        onBrowseTemplates: () => _openTemplateLibrary(examplesMode: false),
        onExploreExamples: () => _openTemplateLibrary(examplesMode: true),
      );
    }

    return Column(
      children: [
        Material(
          color: palette.surfaceOverlay,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text(
                  'BIBLIA MODULAR',
                  style: AppTypography.label(palette),
                ),
                const SizedBox(width: 12),
                Text(_saveStatus, style: AppTypography.caption(palette)),
                const Spacer(),
                TextButton(
                  onPressed: () => _openTemplateLibrary(examplesMode: false),
                  child: const Text('Plantillas'),
                ),
                TextButton(
                  onPressed: _saveAsTemplate,
                  child: const Text('Guardar plantilla'),
                ),
                if (widget.onExportPdf != null)
                  TextButton(
                    onPressed: widget.onExportPdf,
                    child: const Text('Exportar'),
                  ),
                if (widget.onOpenSettings != null)
                  IconButton(
                    tooltip: 'Configuración',
                    onPressed: widget.onOpenSettings,
                    icon: const Icon(Icons.settings_outlined),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _history!.current.pages.isEmpty
              ? BibleV2EmptyDocumentState(
                  onCreateFirstPage: _createFirstPage,
                  onBrowseTemplates: () =>
                      _openTemplateLibrary(examplesMode: false),
                )
              : BibleCanvasEditor(
                  document: _history!.current,
                  history: _history!,
                  onDocumentChanged: _onDocChanged,
                  onBrowseTemplates: () =>
                      _openTemplateLibrary(examplesMode: false),
                  projectId: widget.projectId,
                  bibleId: widget.bibleId,
                ),
        ),
      ],
    );
  }
}

/// Indica si una biblia usa el motor V2.
bool bibleUsesV2Engine(VisualBibleData? data) =>
    data?.engineVersion == kBibleEngineV2;

/// Migra un proyecto legacy a V2 bajo demanda.
Future<void> migrateProjectBibleToV2({
  required WidgetRef ref,
  required int projectId,
  required int bibleId,
  VisualBibleData? data,
}) async {
  final db = ref.read(databaseProvider);
  final service = BibleMigrationService(db, BibleDocumentStore(db));
  await service.migrateLegacyToV2(
    projectId: projectId,
    bibleId: bibleId,
    data: data,
  );
}
