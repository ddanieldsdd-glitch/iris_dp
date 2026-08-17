import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart' hide BibleSectionGroup;
import '../../core/database/app_database.dart' as app_db show BibleSectionGroup;
import '../../core/database/database_provider.dart';
import '../../core/templates/user_template_models.dart';
import '../../core/templates/user_template_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/export_file_saver.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_snackbar.dart';
import '../look_bible/look_bible_model.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import 'moodboard_association.dart';
import '../locations/locations_screen.dart';
import 'bible_edit_history.dart';
import 'bible_preset_bundle.dart';
import 'bible_preset_service.dart';
import 'bible_style_guide_sheet.dart';
import 'bible_tutorial.dart';
import 'data/visual_bible_repository.dart';
import 'export/builder/bible_export_composition_builder.dart';
import 'export/composer/bible_export_composer_screen.dart';
import 'export/composer/bible_export_pdf_preview_screen.dart';
import 'export/model/bible_export_composition.dart';
import 'export/pdf/bible_export_pdf_renderer.dart';
import 'export/store/bible_export_composition_store.dart';
import 'state/visual_bible_providers.dart';
import 'v2/persistence/bible_document_store.dart';
import 'v2/sync/bible_domain_sync_service.dart';
import 'moodboard_export_layout.dart';
import 'visual_bible_export_config.dart';
import 'visual_bible_export_config_sheet.dart';
import 'visual_bible_model.dart';
import 'visual_bible_pdf_service.dart';
import '../goodnotes/goodnotes_export_service.dart';
import 'widgets/bible_navigation_scope.dart';
import 'visual_bible_v2_screen.dart';
import 'v2/bible_v2_policy.dart';
import 'widgets/bible_overview_section.dart';
import 'widgets/bible_screen_library_sheet.dart';
import 'widgets/bible_sidebar.dart';
import 'widgets/bible_start_screen.dart';
import 'widgets/bible_template_library_sheet.dart';
import 'widgets/moodboard_section.dart';
import 'widgets/sections/custom_bible_section.dart';
import 'widgets/sections/camera_sensor_section.dart';
import 'widgets/sections/camera_tests_section.dart';
import 'widgets/sections/color_image_section.dart';
import 'widgets/sections/direction_section.dart';
import 'widgets/sections/concept_section.dart';
import 'widgets/sections/exposure_section.dart';
import 'widgets/sections/format_section.dart';
import 'widgets/sections/lighting_section.dart';
import 'widgets/sections/location_section.dart';
import 'widgets/sections/optics_section.dart';
import 'widgets/sections/texture_section.dart';
import 'widgets/sections/workflow_section.dart';
import 'widgets/bible_live_customize_panel.dart';
import '../../core/project/project_shoot_context.dart';
import 'widgets/sections/bible_settings_section.dart';

class VisualBibleScreen extends ConsumerStatefulWidget {
  final int projectId;
  final String? initialSectionId;
  final int? initialPlanId;

  const VisualBibleScreen({
    super.key,
    required this.projectId,
    this.initialSectionId,
    this.initialPlanId,
  });

  @override
  ConsumerState<VisualBibleScreen> createState() => _VisualBibleScreenState();
}

class _VisualBibleScreenState extends ConsumerState<VisualBibleScreen> {
  VisualBibleData? _data;
  Project? _project;
  bool _loading = true;
  bool _saving = false;
  bool _saved = true;
  Timer? _saveDebounce;
  String _activeSection = BibleSidebar.overviewSectionId;
  int? _pendingPlanId;
  String? _pendingFocus;
  String? _moodboardInitialFilter;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _livePanelOpen = false;
  double _livePanelWidth = 320;
  BibleLivePanelTab _livePanelTab = BibleLivePanelTab.style;
  final _history = BibleEditHistory();
  VisualBibleData? _historyBaseline;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSectionId != null) {
      _activeSection = widget.initialSectionId!;
    }
    if (widget.initialPlanId != null) {
      _pendingPlanId = widget.initialPlanId;
    }
    _registerTutorialActions();
    _bootstrap();
  }

  @override
  void dispose() {
    BibleTutorialActions.goToStep = null;
    _saveDebounce?.cancel();
    if (!_saved && _data != null) {
      unawaited(_persistNow(_data!));
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(visualBibleRepositoryProvider);
    final result = await repo.bootstrap(widget.projectId);
    if (mounted) {
      setState(() {
        _project = result.project;
        _data = result.data;
        _needsOnboarding = result.needsOnboarding;
        _loading = false;
        _historyBaseline = result.data.copy();
      });
      unawaited(_loadLivePanelPrefs());
      unawaited(BibleTutorial.maybeShow(context, widget.projectId));
    }
  }

  Future<void> _loadLivePanelPrefs() async {
    final width = await BibleLiveCustomizePanel.loadWidth(widget.projectId);
    final open = await BibleLiveCustomizePanel.loadOpen(widget.projectId);
    if (mounted) {
      setState(() {
        _livePanelWidth = width.clamp(280, 420);
        _livePanelOpen = open;
      });
    }
  }

  void _registerTutorialActions() {
    BibleTutorialActions.goToStep = (step) {
      if (!mounted) return;
      switch (step) {
        case 1:
          _openLivePanel(tab: BibleLivePanelTab.style);
        case 2:
          _openLivePanel(tab: BibleLivePanelTab.structure);
        case 3:
          setState(() => _activeSection = BibleSectionId.moodboard);
          _openLivePanel(tab: BibleLivePanelTab.style);
        default:
          break;
      }
    };
  }

  Future<void> _startEmptyBible() async {
    final data = _data;
    if (data == null || data.id <= 0) return;
    await ref.read(visualBibleRepositoryProvider).initializeEmpty(data.id);
    if (!mounted) return;
    setState(() {
      data.structureInitialized = true;
      _needsOnboarding = false;
    });
  }

  void _onStructureReset() {
    if (!mounted) return;
    setState(() {
      _needsOnboarding = true;
      _data?.structureInitialized = false;
    });
  }

  Future<void> _reloadBible() async {
    final result = await ref
        .read(visualBibleRepositoryProvider)
        .bootstrap(widget.projectId);
    if (!mounted) return;
    setState(() {
      _project = result.project;
      _data = result.data;
      _historyBaseline = result.data.copy();
      _needsOnboarding = result.needsOnboarding;
    });
  }

  Future<void> _openScreenLibrary(int bibleId) async {
    final db = ref.read(databaseProvider);
    final defs = await db.watchBibleSectionDefinitions(bibleId).first;
    if (!mounted) return;
    final added = await BibleScreenLibrarySheet.show(
      context,
      existingSectionIds: defs.map((d) => d.id).toSet(),
      onAdd: (sectionId) =>
          db.addBuiltinBibleSection(bibleId: bibleId, sectionId: sectionId),
    );
    if (added == null || !mounted) return;
    setState(() {
      _activeSection = added;
      _needsOnboarding = false;
      _data?.structureInitialized = true;
    });
  }

  Future<void> _openTemplateLibrary({
    required int bibleId,
    required bool examplesMode,
  }) async {
    final db = ref.read(databaseProvider);
    final userTemplates = await UserTemplateService.listTemplates(
      db,
      UserTemplateType.bibleLayout,
    );
    if (!mounted) return;

    final choices = <BibleTemplateChoice>[
      for (final preset in BibleBuiltinPresets.all)
        BibleTemplateChoice(
          id: preset.id,
          name: preset.isAvailable
              ? preset.name
              : '${preset.name} · Próximamente',
          description: preset.isAvailable
              ? preset.description
              : 'Disponible próximamente. Usa Plantilla 1 (Ficción · Cinematic).',
          category: examplesMode ? 'Cinematography' : 'IRIS',
          screenCount: BibleSectionId.all.length - 1,
        ),
      if (!examplesMode)
        for (final template in userTemplates)
          BibleTemplateChoice(
            id: template.id,
            name: template.name,
            description: template.description ?? 'Plantilla personalizada',
            category: 'Mis plantillas',
          ),
    ];

    final applied = await BibleTemplateLibrarySheet.show(
      context,
      templates: choices,
      examplesMode: examplesMode,
      onUse: (template) async {
        final bundle = BibleBuiltinPresets.byId(template.id);
        if (bundle != null && !bundle.isAvailable) {
          throw StateError('Plantilla no disponible todavía');
        }
        await BiblePresetService.applyById(
          db: db,
          projectId: widget.projectId,
          bibleId: bibleId,
          templateId: template.id,
          applySampleSeed: examplesMode,
        );
      },
    );
    if (applied == null || !mounted) return;
    await BibleDomainSyncService.syncFromLegacy(
      db: db,
      projectId: widget.projectId,
      bibleId: bibleId,
      data: _data,
    );
    await _reloadBible();
    if (!mounted) return;
    setState(() => _activeSection = BibleSectionId.direction);
  }

  void _scheduleSave(VisualBibleData data) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () => _save(data));
  }

  Future<void> _persistNow(VisualBibleData data) async {
    await ref.read(visualBibleRepositoryProvider).save(data);
  }

  Future<void> _save(VisualBibleData data) async {
    setState(() {
      _saving = true;
      _saved = false;
    });
    try {
      await ref.read(visualBibleRepositoryProvider).save(data);
      if (mounted) {
        setState(() {
          _saved = true;
          _historyBaseline = data.copy();
        });
        unawaited(
          BibleDomainSyncService.syncFromLegacy(
            db: ref.read(databaseProvider),
            projectId: widget.projectId,
            bibleId: data.id,
            data: data,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<VisualBibleExportBundle> _loadExportBundle() async {
    return ref
        .read(visualBibleRepositoryProvider)
        .loadExportBundle(projectId: widget.projectId, cached: _data);
  }

  Future<void> _openExportConfig({
    VisualBibleExportDestination? preferredDestination,
  }) async {
    final project = _project;
    if (project == null || _data == null) return;

    final config = await showVisualBibleExportConfigSheet(
      context,
      projectId: widget.projectId,
      preferredDestination: preferredDestination,
    );
    if (config == null || !mounted) return;
    final useComposer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preparar exportación'),
        content: const Text(
          'Puedes montar y anotar las páginas antes de generar el PDF, '
          'o continuar con la exportación clásica.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Exportación clásica'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.dashboard_customize_outlined),
            label: const Text('Abrir compositor'),
          ),
        ],
      ),
    );
    if (useComposer == null || !mounted) return;
    if (useComposer) {
      await _openExportComposer(config);
    } else {
      await _runExport(config);
    }
  }

  Future<void> _openExportComposer(VisualBibleExportConfig config) async {
    if (_data == null) return;
    try {
      final bundle = await _loadExportBundle();
      final db = ref.read(databaseProvider);
      final preferences = await SharedPreferences.getInstance();
      final store = BibleExportCompositionStore(preferences);
      final compositionId = 'config_${config.id}';
      final existing = await store.loadLatest(widget.projectId, compositionId);
      final sourceDocument = await BibleDocumentStore(
        db,
      ).loadForBible(bundle.data.id);
      final builder = BibleExportCompositionBuilder();
      final sourceHash = BibleDomainSyncService.computeExportSourceHash(
        data: bundle.data,
        document: sourceDocument,
        moodboardCount: bundle.moodboard.length,
        colorBlockCount: bundle.blocks.length,
        lightingSetupCount: bundle.lightingSetups.length,
        cameraTestCount: bundle.cameraTests.length,
        formatSectionContentJson:
            bundle.sectionContentJsonById[BibleSectionId.format],
        cameraSectionContentJson:
            bundle.sectionContentJsonById[BibleSectionId.camera],
      );
      final built = builder.build(
        projectId: widget.projectId,
        config: config,
        bundle: bundle,
        sourceDocument: sourceDocument,
        compositionId: compositionId,
      );
      final composition =
          existing != null &&
              existing.metadata['sourceHash']?.toString() == sourceHash
          ? existing.copyWith(config: config)
          : built.copyWith(
              metadata: {...built.metadata, 'sourceHash': sourceHash},
            );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => BibleExportComposerScreen(
            initialComposition: composition,
            store: store,
            database: db,
            onRequestPdf: _runCompositionExport,
            loadExportBundle: _loadExportBundle,
            loadSourceDocument: () => BibleDocumentStore(db).loadForBible(
              bundle.data.id,
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        AppSnackBar.showError(context, userFriendlyError(error));
      }
    }
  }

  Future<void> _runCompositionExport(BibleExportComposition composition) async {
    final project = _project;
    if (project == null) return;
    try {
      final db = ref.read(databaseProvider);
      final bytes = await BibleExportPdfRenderer(
        database: db,
      ).buildBytes(composition);
      final safe = project.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final baseName = safe.isEmpty ? 'proyecto' : safe;
      final filename = '${baseName}_biblia_montada';
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => BibleExportPdfPreviewScreen(
            bytes: bytes,
            title: composition.config.name,
            onConfirm: () async {
              if (composition.config.destination ==
                  VisualBibleExportDestination.share) {
                await GoodNotesExportService.shareForAnnotation(
                  pdfBytes: bytes,
                  filename: filename,
                  documentType: GoodNotesModuleType.visualBible,
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                AppSnackBar.show(context, 'Montaje listo para compartir');
                return;
              }
              final path = await ExportFileSaver.saveBytes(
                bytes: bytes,
                dialogTitle: 'Guardar montaje de Biblia',
                fileName: filename,
                extension: 'pdf',
              );
              if (!mounted || path == null) return;
              Navigator.of(context).pop();
              AppSnackBar.show(context, 'PDF guardado en $path');
            },
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        AppSnackBar.showError(context, userFriendlyError(error));
      }
    }
  }

  Future<void> _runExport(VisualBibleExportConfig config) async {
    final project = _project;
    if (project == null || _data == null) return;

    try {
      final bundle = await _loadExportBundle();
      final safe = project.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final baseName = safe.isEmpty ? 'proyecto' : safe;
      final bytes = config.isDepartment
          ? await VisualBiblePdfService.buildDepartmentBytes(
              department: config.department!,
              projectName: project.name,
              data: bundle.data,
              colorBlocks: bundle.blocks,
            )
          : await VisualBiblePdfService.buildBytes(
              mode: config.mode,
              projectName: project.name,
              director: project.director,
              data: bundle.data,
              colorBlocks: bundle.blocks,
              exposureBlocks: bundle.exposureBlocks,
              lightingSetups: bundle.lightingSetups,
              cameraTests: bundle.cameraTests,
              moodboard: bundle.moodboard,
              includedSections: config.sections,
              sectionContentJsonById: bundle.sectionContentJsonById,
              primaryCameraLabel: bundle.primaryCameraLabel,
              moodboardLayout: config.resolvedMoodboardLayout,
              includeAllMoodboardImages: config.includeAllMoodboardImages,
            );
      final suffix = config.isDepartment
          ? VisualBibleDepartment.label(
              config.department!,
            ).toLowerCase().replaceAll(' ', '_')
          : switch (config.mode) {
              VisualBibleExportMode.pitch => 'pitch',
              VisualBibleExportMode.techScout => 'tech_scout',
              _ => 'biblia_fotografia',
            };
      final filename = '${baseName}_$suffix';
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => BibleExportPdfPreviewScreen(
            bytes: bytes,
            title: config.name,
            onConfirm: () async {
              if (config.destination == VisualBibleExportDestination.share) {
                await GoodNotesExportService.shareForAnnotation(
                  pdfBytes: bytes,
                  filename: filename,
                  documentType: GoodNotesModuleType.visualBible,
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                AppSnackBar.show(
                  context,
                  'PDF revisado y listo para compartir',
                );
                return;
              }
              final path = await ExportFileSaver.saveBytes(
                bytes: bytes,
                dialogTitle: 'Guardar Biblia de Fotografía',
                fileName: filename,
                extension: 'pdf',
              );
              if (!mounted || path == null) return;
              Navigator.of(context).pop();
              AppSnackBar.show(context, 'PDF guardado en $path');
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, userFriendlyError(e));
    }
  }

  Future<void> _exportPdf() => _openExportConfig(
    preferredDestination: VisualBibleExportDestination.saveFile,
  );

  Future<void> _shareWithTeam() => _openExportConfig(
    preferredDestination: VisualBibleExportDestination.share,
  );

  void _onDataChanged(VisualBibleData data) {
    final baseline = _historyBaseline;
    if (baseline != null && !_history.isRestoring) {
      _history.push(baseline);
      _historyBaseline = null;
    }
    setState(() {
      _data = data;
      _saved = false;
    });
    _scheduleSave(data);
  }

  void _undo() {
    final current = _data;
    if (current == null) return;
    final prev = _history.undo(current);
    if (prev == null) {
      AppSnackBar.show(context, 'Nada que deshacer');
      return;
    }
    setState(() {
      _data = prev;
      _historyBaseline = prev.copy();
      _saved = false;
    });
    _scheduleSave(prev);
  }

  void _redo() {
    final current = _data;
    if (current == null) return;
    final next = _history.redo(current);
    if (next == null) {
      AppSnackBar.show(context, 'Nada que rehacer');
      return;
    }
    setState(() {
      _data = next;
      _historyBaseline = next.copy();
      _saved = false;
    });
    _scheduleSave(next);
  }

  void _openMoodboard({String? sectionId, String? moodboardFilter}) {
    setState(() {
      _activeSection = BibleSectionId.moodboard;
      _moodboardInitialFilter =
          moodboardFilter ??
          (sectionId != null
              ? MoodboardAssociation.categoryForSection(sectionId)
              : null);
    });
  }

  void _openSection(String sectionId, {int? planId, String? focus}) {
    setState(() {
      _activeSection = sectionId;
      _pendingPlanId = planId;
      _pendingFocus = focus;
    });
  }

  void _openBibleLocation({int? planId}) {
    setState(() {
      _activeSection = BibleSectionId.location;
      _pendingPlanId = planId;
    });
  }

  void _openLocations({int? siteId, int? setId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocationsScreen(
          projectId: widget.projectId,
          initialSiteId: siteId,
          initialSetId: setId,
        ),
      ),
    );
  }

  String? _sectionContentJson(
    Map<String, BibleSectionDefinition> defsById,
    String sectionId,
  ) => defsById[sectionId]?.contentJson;

  Future<void> _saveSectionContent(
    Map<String, BibleSectionDefinition> defsById,
    String sectionId,
    String? contentJson,
  ) async {
    final repo = ref.read(visualBibleRepositoryProvider);
    final def = defsById[sectionId];
    if (def == null || _data == null) return;
    await repo.upsertSectionDefinition(
      def.copyWith(contentJson: Value(contentJson)),
    );
  }

  Widget _buildSection(
    int bibleId,
    Map<String, BibleSectionDefinition> sectionDefsById,
    BibleContentSnapshot contentSnapshot,
  ) {
    final data = _data!;
    final customDef = sectionDefsById[_activeSection];
    if (customDef != null && customDef.template == 'freeform') {
      return CustomBibleSection(
        projectId: widget.projectId,
        sectionId: customDef.id,
        label: customDef.label,
        contentJson: customDef.contentJson,
        onContentChanged: (json) =>
            _saveSectionContent(sectionDefsById, customDef.id, json),
      );
    }

    return switch (_activeSection) {
      BibleSidebar.overviewSectionId => BibleOverviewSection(
        data: data,
        project: _project,
        definitions: sectionDefsById.values.toList(),
        snapshot: contentSnapshot,
        onOpenSection: (sectionId) => _onSectionSelected(sectionId, bibleId),
      ),
      BibleSectionId.direction => DirectionSection(
        data: data,
        projectId: widget.projectId,
        sectionContentJson: _sectionContentJson(
          sectionDefsById,
          BibleSectionId.direction,
        ),
        onChanged: _onDataChanged,
      ),
      BibleSectionId.concept => ConceptSection(
        data: data,
        projectId: widget.projectId,
        sectionContentJson: _sectionContentJson(
          sectionDefsById,
          BibleSectionId.concept,
        ),
        formatSectionContentJson: _sectionContentJson(
          sectionDefsById,
          BibleSectionId.format,
        ),
        onChanged: _onDataChanged,
      ),
      BibleSectionId.camera => CameraSensorSection(
        data: data,
        projectId: widget.projectId,
        sectionContentJson: _sectionContentJson(
          sectionDefsById,
          BibleSectionId.camera,
        ),
        onChanged: _onDataChanged,
      ),
      BibleSectionId.optics => OpticsSection(
        data: data,
        projectId: widget.projectId,
        sectionContentJson: _sectionContentJson(
          sectionDefsById,
          BibleSectionId.optics,
        ),
        formatSectionContentJson: _sectionContentJson(
          sectionDefsById,
          BibleSectionId.format,
        ),
        onChanged: _onDataChanged,
      ),
      BibleSectionId.exposure => ExposureSection(
        data: data,
        projectId: widget.projectId,
        bibleId: bibleId,
        sectionContentJson: _sectionContentJson(
          sectionDefsById,
          BibleSectionId.exposure,
        ),
        onChanged: _onDataChanged,
      ),
      BibleSectionId.lighting => LightingSection(
        data: data,
        projectId: widget.projectId,
        bibleId: bibleId,
        initialPlanId: _pendingPlanId,
        initialFocus: _pendingFocus,
        sectionContentJson: _sectionContentJson(
          sectionDefsById,
          BibleSectionId.lighting,
        ),
        onChanged: _onDataChanged,
      ),
      BibleSectionId.colorImage => ColorImageSection(
        data: data,
        projectId: widget.projectId,
        bibleId: bibleId,
        sectionContentJson: _sectionContentJson(
          sectionDefsById,
          BibleSectionId.colorImage,
        ),
        onChanged: _onDataChanged,
      ),
      BibleSectionId.format => FormatSection(
        data: data,
        projectId: widget.projectId,
        sectionContentJson: _sectionContentJson(
          sectionDefsById,
          BibleSectionId.format,
        ),
        onChanged: _onDataChanged,
      ),
      BibleSectionId.texture => TextureSection(
        data: data,
        projectId: widget.projectId,
        sectionContentJson: _sectionContentJson(
          sectionDefsById,
          BibleSectionId.texture,
        ),
        onChanged: _onDataChanged,
      ),
      BibleSectionId.location => LocationSection(
        projectId: widget.projectId,
        bibleId: bibleId,
        sectionContentJson: _sectionContentJson(
          sectionDefsById,
          BibleSectionId.location,
        ),
      ),
      BibleSectionId.cameraTests => CameraTestsSection(
        projectId: widget.projectId,
        bibleId: bibleId,
      ),
      BibleSectionId.workflow => WorkflowSection(
        data: data,
        projectId: widget.projectId,
        sectionContentJson: _sectionContentJson(
          sectionDefsById,
          BibleSectionId.workflow,
        ),
        onChanged: _onDataChanged,
      ),
      BibleSectionId.moodboard => MoodboardSection(
        projectId: widget.projectId,
        bibleId: bibleId,
        initialFilter: _moodboardInitialFilter,
      ),
      BibleSectionId.settings => BibleSettingsSection(
        bibleId: bibleId,
        projectId: widget.projectId,
        onStructureReset: _onStructureReset,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  void _openLivePanel({BibleLivePanelTab tab = BibleLivePanelTab.style}) {
    final bibleId = _data?.id ?? 0;
    if (bibleId <= 0) {
      AppSnackBar.show(
        context,
        'La biblia se está inicializando. Espera un momento.',
      );
      return;
    }
    setState(() {
      _livePanelOpen = true;
      _livePanelTab = tab;
    });
    unawaited(BibleLiveCustomizePanel.saveOpen(widget.projectId, true));
  }

  void _closeLivePanel() {
    setState(() => _livePanelOpen = false);
    unawaited(BibleLiveCustomizePanel.saveOpen(widget.projectId, false));
  }

  void _toggleLivePanel({BibleLivePanelTab tab = BibleLivePanelTab.style}) {
    if (_livePanelOpen) {
      _closeLivePanel();
    } else {
      _openLivePanel(tab: tab);
    }
  }

  void _openMasterConfig(int bibleId) {
    if (bibleId <= 0) {
      AppSnackBar.show(
        context,
        'La biblia se está inicializando. Espera un momento.',
      );
      return;
    }
    setState(() {
      _activeSection = BibleSectionId.settings;
    });
  }

  Future<void> _removeSection(BibleSectionDefinition def) async {
    if (def.id == BibleSectionId.settings) return;
    final palette = context.palette;
    final isCustom = !def.isBuiltIn;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCustom ? 'Eliminar pantalla' : 'Quitar pantalla'),
        content: Text(
          isCustom
              ? '¿Eliminar «${def.label}» de forma permanente?'
              : '¿Ocultar «${def.label}» de esta biblia?\n'
                    'Podrás volver a mostrarla desde Personalizar Biblia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: palette.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isCustom ? 'Eliminar' : 'Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final db = ref.read(databaseProvider);
    final bibleId = _data?.id ?? 0;
    if (bibleId <= 0) return;
    if (isCustom) {
      await db.deleteCustomBibleSection(bibleId: bibleId, sectionId: def.id);
    } else {
      await db.setBibleSectionHidden(
        bibleId: bibleId,
        sectionId: def.id,
        hidden: true,
      );
    }
    if (!mounted) return;
    if (_activeSection == def.id) {
      setState(() => _activeSection = BibleSectionId.direction);
    }
    AppSnackBar.show(
      context,
      isCustom ? 'Pantalla eliminada' : 'Pantalla ocultada',
    );
  }

  void _onSectionSelected(String id, int bibleId) {
    setState(() => _activeSection = id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final repo = ref.watch(visualBibleRepositoryProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compactAppBar = screenWidth < 1180;
    final narrowAppBar = screenWidth < 900;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): _UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            _RedoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            _RedoIntent(),
        SingleActivator(LogicalKeyboardKey.keyY, control: true): _RedoIntent(),
      },
      child: Actions(
        actions: {
          _UndoIntent: CallbackAction<_UndoIntent>(
            onInvoke: (_) {
              _undo();
              return null;
            },
          ),
          _RedoIntent: CallbackAction<_RedoIntent>(
            onInvoke: (_) {
              _redo();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: palette.background,
            appBar: AppBar(
              backgroundColor: palette.surface.withValues(alpha: 0.85),
              title: Row(
                children: [
                  Text(
                    narrowAppBar ? 'Biblia' : 'Biblia de Fotografía',
                    style: AppTypography.titleMedium(palette),
                  ),
                  if (!compactAppBar) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surfaceOverlay,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'V1.0',
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (!compactAppBar)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Center(
                      child: Text(
                        _saving
                            ? 'Guardando…'
                            : _saved
                            ? 'Guardado'
                            : 'Cambios pendientes',
                        style: AppTypography.caption(palette).copyWith(
                          color: _saving
                              ? palette.accent
                              : _saved
                              ? palette.success
                              : palette.textSecondary,
                        ),
                      ),
                    ),
                  ),
                Consumer(
                  builder: (context, ref, _) {
                    final shoot = ref.watch(
                      activeShootLocationProvider(widget.projectId),
                    );
                    return shoot.when(
                      data: (loc) {
                        final label = loc.set?.locationName ??
                            loc.site?.name;
                        if (label == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ActionChip(
                            label: Text('Set: $label'),
                            onPressed: () => _openSection(BibleSectionId.location),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
                if (_saving && !compactAppBar)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (_data != null && _project != null && !narrowAppBar)
                  GoodNotesPdfActions(
                    projectId: widget.projectId,
                    moduleType: GoodNotesModuleType.visualBible,
                    filenameBase:
                        '${_project!.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim()}_biblia_fotografia',
                    buildPdfBytes: () async {
                      final bundle = await _loadExportBundle();
                      final last = await VisualBibleExportConfigStore.loadLast(
                        widget.projectId,
                      );
                      return VisualBiblePdfService.buildBytes(
                        mode: VisualBibleExportMode.full,
                        projectName: _project!.name,
                        director: _project!.director,
                        data: bundle.data,
                        colorBlocks: bundle.blocks,
                        exposureBlocks: bundle.exposureBlocks,
                        lightingSetups: bundle.lightingSetups,
                        cameraTests: bundle.cameraTests,
                        moodboard: bundle.moodboard,
                        sectionContentJsonById: bundle.sectionContentJsonById,
                        primaryCameraLabel: bundle.primaryCameraLabel,
                        moodboardLayout:
                            last?.moodboardLayout ?? MoodboardExportLayout.defaults,
                      );
                    },
                  ),
                if (!compactAppBar)
                  IconButton(
                    icon: Icon(
                      Icons.cloud_done_outlined,
                      color: palette.textSecondary,
                    ),
                    tooltip: 'Estado de sincronización',
                    onPressed: () {},
                  ),
                if (!compactAppBar)
                  IconButton(
                    icon: Icon(Icons.palette_outlined, color: palette.accent),
                    tooltip: 'Guía visual del proyecto',
                    onPressed: () {
                      final bibleId = _data?.id ?? 0;
                      BibleStyleGuideSheet.show(
                        context,
                        projectId: widget.projectId,
                        bibleId: bibleId > 0 ? bibleId : null,
                      );
                    },
                  ),
                IconButton(
                  icon: Icon(Icons.tune, color: palette.textSecondary),
                  tooltip: 'Ajustes de pantalla',
                  onPressed: () => _toggleLivePanel(),
                ),
                if (!compactAppBar)
                  IconButton(
                    icon: Icon(
                      Icons.ios_share_outlined,
                      color: palette.textSecondary,
                    ),
                    tooltip: 'Compartir con equipo',
                    onPressed: _shareWithTeam,
                  ),
                if (compactAppBar)
                  PopupMenuButton<String>(
                    tooltip: 'Más acciones',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) {
                      if (action == 'guide') {
                        final bibleId = _data?.id ?? 0;
                        BibleStyleGuideSheet.show(
                          context,
                          projectId: widget.projectId,
                          bibleId: bibleId > 0 ? bibleId : null,
                        );
                      } else if (action == 'share') {
                        _shareWithTeam();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'guide',
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                          leading: Icon(Icons.palette_outlined),
                          title: Text('Guía visual'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                          leading: Icon(Icons.ios_share_outlined),
                          title: Text('Compartir'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        ),
                      ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 12, left: 4),
                  child: compactAppBar
                      ? IconButton.filled(
                          onPressed: _exportPdf,
                          tooltip: 'Exportar PDF',
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          style: IconButton.styleFrom(
                            backgroundColor: palette.accent,
                            foregroundColor: Colors.white,
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: _exportPdf,
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Exportar PDF'),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                        ),
                ),
              ],
            ),
            body: _loading || _data == null
                ? const Center(child: CircularProgressIndicator())
                : _data!.engineVersion == kBibleEngineV2
                ? VisualBibleV2Screen(
                    projectId: widget.projectId,
                    bibleId: _data!.id,
                    legacyData: _data,
                    onExportPdf: _exportPdf,
                  )
                : StreamBuilder<VisualBible?>(
                    stream: repo.watchBible(widget.projectId),
                    builder: (context, bibleSnap) {
                      final showOnboarding =
                          _needsOnboarding ||
                          (bibleSnap.data?.structureInitialized == false);
                      if (showOnboarding) {
                        return BibleStartScreen(
                          onStartEmpty: _startEmptyBible,
                          onBrowseTemplates: () => _openTemplateLibrary(
                            bibleId: _data!.id,
                            examplesMode: false,
                          ),
                          onExploreExamples: () => _openTemplateLibrary(
                            bibleId: _data!.id,
                            examplesMode: true,
                          ),
                        );
                      }

                      final bibleId = _data!.id > 0
                          ? _data!.id
                          : bibleSnap.data?.id ?? 0;

                      return BibleNavigationScope(
                        openMoodboard: ({sectionId, moodboardFilter}) =>
                            _openMoodboard(
                              sectionId: sectionId,
                              moodboardFilter: moodboardFilter,
                            ),
                        openLocations: _openLocations,
                        openSection: _openSection,
                        openBibleLocation: _openBibleLocation,
                        child: StreamBuilder<List<app_db.BibleSectionGroup>>(
                          stream: bibleId > 0
                              ? repo.watchSectionGroups(bibleId)
                              : Stream.value([]),
                          builder: (context, groupSnap) {
                            return StreamBuilder<List<BibleSectionDefinition>>(
                              stream: bibleId > 0
                                  ? repo.watchSectionDefinitions(bibleId)
                                  : Stream.value([]),
                              builder: (context, defSnap) {
                                final defs = defSnap.data ?? [];
                                final sectionDefsById = {
                                  for (final d in defs) d.id: d,
                                };

                                if (defs.isEmpty) {
                                  return EmptyBibleState(
                                    onAddScreen: () =>
                                        _openScreenLibrary(bibleId),
                                    onBrowseTemplates: () =>
                                        _openTemplateLibrary(
                                          bibleId: bibleId,
                                          examplesMode: false,
                                        ),
                                  );
                                }

                                return BibleContentSnapshotBuilder(
                                  database: ref.read(databaseProvider),
                                  projectId: widget.projectId,
                                  bibleId: bibleId,
                                  builder: (context, contentSnapshot) =>
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final sidebarWidth =
                                              constraints.maxWidth < 900
                                              ? 208.0
                                              : constraints.maxWidth < 1200
                                              ? 232.0
                                              : 280.0;

                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              BibleSidebar(
                                                width: sidebarWidth,
                                                activeSection: _activeSection,
                                                data: _data,
                                                project: _project,
                                                groups: groupSnap.data,
                                                definitions: defs,
                                                contentSnapshot:
                                                    contentSnapshot,
                                                onSectionSelected: (id) =>
                                                    _onSectionSelected(
                                                      id,
                                                      bibleId,
                                                    ),
                                                onAddSection: () =>
                                                    _openScreenLibrary(bibleId),
                                                onOpenSettings: () =>
                                                    _toggleLivePanel(),
                                                onRemoveSection: bibleId > 0
                                                    ? (def) =>
                                                          _removeSection(def)
                                                    : null,
                                                onEditStructure: bibleId > 0
                                                    ? () => _openMasterConfig(
                                                        bibleId,
                                                      )
                                                    : null,
                                              ),
                                              Expanded(
                                                child: _buildSection(
                                                  bibleId,
                                                  sectionDefsById,
                                                  contentSnapshot,
                                                ),
                                              ),
                                              if (_livePanelOpen && bibleId > 0) ...[
                                                BibleLiveCustomizePanel(
                                                  bibleId: bibleId,
                                                  projectId: widget.projectId,
                                                  sectionId: _activeSection,
                                                  width: _livePanelWidth,
                                                  initialTab: _livePanelTab,
                                                  onClose: _closeLivePanel,
                                                  onOpenMasterConfig: () =>
                                                      _openMasterConfig(bibleId),
                                                ),
                                              ],
                                              BibleLivePanelHandle(
                                                open: _livePanelOpen,
                                                onToggle: () =>
                                                    _toggleLivePanel(),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
          ), // Scaffold
        ), // Focus
      ), // Actions
    ); // Shortcuts
  }
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}
