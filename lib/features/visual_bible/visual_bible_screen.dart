import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart' hide BibleSectionGroup;
import '../../core/database/app_database.dart' as app_db show BibleSectionGroup;
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_snackbar.dart';
import '../look_bible/look_bible_model.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import 'moodboard_association.dart';
import '../locations/locations_screen.dart';
import 'bible_edit_history.dart';
import 'bible_style_guide_sheet.dart';
import 'bible_tutorial.dart';
import 'data/visual_bible_repository.dart';
import 'state/visual_bible_providers.dart';
import 'visual_bible_export_config.dart';
import 'visual_bible_export_config_sheet.dart';
import 'visual_bible_model.dart';
import 'visual_bible_pdf_service.dart';
import '../goodnotes/goodnotes_export_service.dart';
import 'widgets/bible_navigation_scope.dart';
import 'widgets/bible_sidebar.dart';
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
import 'widgets/bible_settings_drawer.dart';
import 'widgets/sections/bible_settings_section.dart';

class VisualBibleScreen extends ConsumerStatefulWidget {
  final int projectId;

  const VisualBibleScreen({super.key, required this.projectId});

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
  String _activeSection = BibleSectionId.direction;
  String? _moodboardInitialFilter;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _drawerBibleId = 0;
  final _history = BibleEditHistory();
  VisualBibleData? _historyBaseline;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(visualBibleRepositoryProvider);
    final result = await repo.bootstrap(widget.projectId);
    if (mounted) {
      setState(() {
        _project = result.project;
        _data = result.data;
        _loading = false;
        _historyBaseline = result.data.copy();
      });
      unawaited(BibleTutorial.maybeShow(context, widget.projectId));
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    if (!_saved && _data != null) {
      unawaited(_persistNow(_data!));
    }
    super.dispose();
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
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<VisualBibleExportBundle> _loadExportBundle() async {
    return ref.read(visualBibleRepositoryProvider).loadExportBundle(
          projectId: widget.projectId,
          cached: _data,
        );
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
    await _runExport(config);
  }

  Future<void> _runExport(VisualBibleExportConfig config) async {
    final project = _project;
    if (project == null || _data == null) return;

    try {
      final bundle = await _loadExportBundle();
      final safe = project.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final baseName = safe.isEmpty ? 'proyecto' : safe;

      if (config.destination == VisualBibleExportDestination.share) {
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
              );

        final suffix = config.isDepartment
            ? VisualBibleDepartment.label(config.department!)
                .toLowerCase()
                .replaceAll(' ', '_')
            : switch (config.mode) {
                VisualBibleExportMode.pitch => 'pitch',
                VisualBibleExportMode.techScout => 'tech_scout',
                _ => 'biblia_fotografia',
              };

        await GoodNotesExportService.shareForAnnotation(
          pdfBytes: bytes,
          filename: '${baseName}_$suffix',
          documentType: GoodNotesModuleType.visualBible,
        );
        if (!mounted) return;
        final who = config.recipients.trim().isEmpty
            ? config.summaryLabel
            : '${config.summaryLabel} → ${config.recipients.trim()}';
        AppSnackBar.show(context, 'PDF listo para compartir ($who)');
        return;
      }

      String? path;
      if (config.isDepartment) {
        path = await VisualBiblePdfService.exportDepartment(
          department: config.department!,
          projectName: project.name,
          data: bundle.data,
          colorBlocks: bundle.blocks,
        );
      } else {
        path = await VisualBiblePdfService.export(
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
        );
      }
      if (!mounted || path == null) return;
      AppSnackBar.show(context, 'PDF guardado en $path');
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
      _moodboardInitialFilter = moodboardFilter ??
          (sectionId != null
              ? MoodboardAssociation.categoryForSection(sectionId)
              : null);
    });
  }

  void _openSection(String sectionId, {int? planId, String? focus}) {
    setState(() => _activeSection = sectionId);
  }

  void _openBibleLocation({int? planId}) {
    setState(() => _activeSection = BibleSectionId.location);
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
  ) =>
      defsById[sectionId]?.contentJson;

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
      BibleSectionId.direction => DirectionSection(
          data: data,
          projectId: widget.projectId,
          sectionContentJson:
              _sectionContentJson(sectionDefsById, BibleSectionId.direction),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.concept => ConceptSection(
          data: data,
          projectId: widget.projectId,
          sectionContentJson:
              _sectionContentJson(sectionDefsById, BibleSectionId.concept),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.camera => CameraSensorSection(
          data: data,
          projectId: widget.projectId,
          sectionContentJson:
              _sectionContentJson(sectionDefsById, BibleSectionId.camera),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.optics => OpticsSection(
          data: data,
          projectId: widget.projectId,
          sectionContentJson:
              _sectionContentJson(sectionDefsById, BibleSectionId.optics),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.exposure => ExposureSection(
          data: data,
          projectId: widget.projectId,
          bibleId: bibleId,
          sectionContentJson:
              _sectionContentJson(sectionDefsById, BibleSectionId.exposure),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.lighting => LightingSection(
          data: data,
          projectId: widget.projectId,
          bibleId: bibleId,
          sectionContentJson:
              _sectionContentJson(sectionDefsById, BibleSectionId.lighting),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.colorImage => ColorImageSection(
          data: data,
          projectId: widget.projectId,
          bibleId: bibleId,
          sectionContentJson:
              _sectionContentJson(sectionDefsById, BibleSectionId.colorImage),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.format => FormatSection(
          data: data,
          projectId: widget.projectId,
          sectionContentJson:
              _sectionContentJson(sectionDefsById, BibleSectionId.format),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.texture => TextureSection(
          data: data,
          projectId: widget.projectId,
          sectionContentJson:
              _sectionContentJson(sectionDefsById, BibleSectionId.texture),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.location => LocationSection(
          projectId: widget.projectId,
          bibleId: bibleId,
          sectionContentJson:
              _sectionContentJson(sectionDefsById, BibleSectionId.location),
        ),
      BibleSectionId.cameraTests => CameraTestsSection(
          projectId: widget.projectId,
          bibleId: bibleId,
        ),
      BibleSectionId.workflow => WorkflowSection(
          data: data,
          projectId: widget.projectId,
          sectionContentJson:
              _sectionContentJson(sectionDefsById, BibleSectionId.workflow),
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
        ),
      _ => const SizedBox.shrink(),
    };
  }

  void _openSettingsDrawer(int bibleId) {
    if (bibleId <= 0) {
      AppSnackBar.show(
        context,
        'La biblia se está inicializando. Espera un momento.',
      );
      return;
    }
    setState(() => _drawerBibleId = bibleId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openEndDrawer();
    });
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
      _drawerBibleId = bibleId;
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
                  'Podrás volver a mostrarla desde Master Config.',
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
      await db.deleteCustomBibleSection(
        bibleId: bibleId,
        sectionId: def.id,
      );
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
          _UndoIntent: CallbackAction<_UndoIntent>(onInvoke: (_) {
            _undo();
            return null;
          }),
          _RedoIntent: CallbackAction<_RedoIntent>(onInvoke: (_) {
            _redo();
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: palette.background,
      endDrawer: _drawerBibleId > 0
          ? BibleSettingsDrawer(
              bibleId: _drawerBibleId,
              projectId: widget.projectId,
              sectionId: _activeSection,
              onOpenMasterConfig: () => _openMasterConfig(_drawerBibleId),
            )
          : null,
      appBar: AppBar(
        backgroundColor: palette.surface.withValues(alpha: 0.85),
        title: Row(
          children: [
            Text(
              'Biblia de Fotografía',
              style: AppTypography.titleMedium(palette),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (_data != null && _project != null)
            GoodNotesPdfActions(
              projectId: widget.projectId,
              moduleType: GoodNotesModuleType.visualBible,
              filenameBase:
                  '${_project!.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim()}_biblia_fotografia',
              buildPdfBytes: () async {
                final bundle = await _loadExportBundle();
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
                );
              },
            ),
          IconButton(
            icon: Icon(Icons.cloud_done_outlined, color: palette.textSecondary),
            tooltip: 'Estado de sincronización',
            onPressed: () {},
          ),
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
            tooltip: 'Ajuste rápido',
            onPressed: () {
              final id = _data?.id ?? 0;
              _openSettingsDrawer(id);
            },
          ),
          IconButton(
            icon: Icon(Icons.ios_share_outlined, color: palette.textSecondary),
            tooltip: 'Compartir con equipo',
            onPressed: _shareWithTeam,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: FilledButton.icon(
              onPressed: () => _exportPdf(),
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Exportar PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
        ],
      ),
      body: _loading || _data == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<VisualBible?>(
        stream: repo.watchBible(widget.projectId),
        builder: (context, snap) {
          final bibleId = _data!.id > 0 ? _data!.id : snap.data?.id ?? 0;

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

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BibleSidebar(
                          activeSection: _activeSection,
                          data: _data,
                          project: _project,
                          groups: groupSnap.data,
                          definitions: defs,
                          onSectionSelected: (id) =>
                              _onSectionSelected(id, bibleId),
                          onOpenSettings: () => _openSettingsDrawer(bibleId),
                          onRemoveSection: bibleId > 0
                              ? (def) => _removeSection(def)
                              : null,
                          onEditStructure: bibleId > 0
                              ? () => _openMasterConfig(bibleId)
                              : null,
                        ),
                        Expanded(
                          child: _buildSection(bibleId, sectionDefsById),
                        ),
                      ],
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
