import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart' hide BibleSectionGroup;
import '../../core/database/app_database.dart' as app_db show BibleSectionGroup;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_snackbar.dart';
import '../look_bible/look_bible_model.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import 'moodboard_association.dart';
import '../locations/locations_screen.dart';
import 'bible_style_guide_sheet.dart';
import 'data/visual_bible_repository.dart';
import 'state/visual_bible_providers.dart';
import 'visual_bible_model.dart';
import 'visual_bible_pdf_service.dart';
import 'widgets/bible_navigation_scope.dart';
import 'widgets/bible_structure_editor.dart';
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
      });
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
      if (mounted) setState(() => _saved = true);
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

  Future<void> _exportPdf({String mode = VisualBibleExportMode.full}) async {
    final project = _project;
    if (project == null || _data == null) return;
    try {
      final bundle = await _loadExportBundle();
      final path = await VisualBiblePdfService.export(
        mode: mode,
        projectName: project.name,
        director: project.director,
        data: bundle.data,
        colorBlocks: bundle.blocks,
        exposureBlocks: bundle.exposureBlocks,
        lightingSetups: bundle.lightingSetups,
        cameraTests: bundle.cameraTests,
        moodboard: bundle.moodboard,
      );
      if (!mounted || path == null) return;
      AppSnackBar.show(context, 'Biblia de Fotografía exportada en $path');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, userFriendlyError(e));
    }
  }

  Future<void> _shareWithTeam() async {
    final project = _project;
    if (project == null || _data == null) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.palette.surfaceElevated,
      builder: (ctx) {
        final palette = context.palette;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text('Exportar / Compartir',
                    style: AppTypography.titleMedium(palette)),
              ),
              ListTile(
                title: Text(VisualBibleExportMode.label(VisualBibleExportMode.pitch)),
                subtitle: const Text('Para dirección y producción'),
                onTap: () => Navigator.pop(ctx, VisualBibleExportMode.pitch),
              ),
              ListTile(
                title: Text(
                    VisualBibleExportMode.label(VisualBibleExportMode.techScout)),
                subtitle: const Text('Para gaffer, AC y eléctricos'),
                onTap: () => Navigator.pop(ctx, VisualBibleExportMode.techScout),
              ),
              ...VisualBibleDepartment.all.map(
                (id) => ListTile(
                  title: Text(VisualBibleDepartment.label(id)),
                  onTap: () => Navigator.pop(ctx, id),
                ),
              ),
              ListTile(
                title: Text(VisualBibleExportMode.label(VisualBibleExportMode.full)),
                onTap: () => Navigator.pop(ctx, VisualBibleExportMode.full),
              ),
            ],
          ),
        );
      },
    );

    if (choice == null || !mounted) return;
    try {
      final bundle = await _loadExportBundle();
      String? path;
      if (choice == VisualBibleExportMode.pitch ||
          choice == VisualBibleExportMode.techScout ||
          choice == VisualBibleExportMode.full) {
        path = await VisualBiblePdfService.export(
          mode: choice,
          projectName: project.name,
          director: project.director,
          data: bundle.data,
          colorBlocks: bundle.blocks,
          exposureBlocks: bundle.exposureBlocks,
          lightingSetups: bundle.lightingSetups,
          cameraTests: bundle.cameraTests,
          moodboard: bundle.moodboard,
        );
      } else {
        path = await VisualBiblePdfService.exportDepartment(
          department: choice,
          projectName: project.name,
          data: bundle.data,
          colorBlocks: bundle.blocks,
        );
      }
      if (!mounted || path == null) return;
      AppSnackBar.show(context, 'PDF guardado en $path');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, userFriendlyError(e));
    }
  }

  void _onDataChanged(VisualBibleData data) {
    setState(() => _saved = false);
    _scheduleSave(data);
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
          sectionLabel: sectionDefsById[BibleSectionId.direction]?.label ??
              'Dirección',
          contentJson:
              sectionDefsById[BibleSectionId.direction]?.contentJson,
          onContentJsonChanged: (json) => _saveSectionContent(
              sectionDefsById, BibleSectionId.direction, json),
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final repo = ref.watch(visualBibleRepositoryProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Biblia de Fotografía',
            style: AppTypography.titleMedium(palette)),
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
            icon: Icon(Icons.picture_as_pdf_outlined, color: palette.textSecondary),
            tooltip: 'Exportar PDF',
            onPressed: () => _exportPdf(),
          ),
          IconButton(
            icon: Icon(Icons.ios_share_outlined, color: palette.textSecondary),
            tooltip: 'Compartir con equipo',
            onPressed: _shareWithTeam,
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
                          groups: groupSnap.data,
                          definitions: defs,
                          onSectionSelected: (id) =>
                              setState(() => _activeSection = id),
                          onEditStructure: bibleId > 0
                              ? () => showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => BibleStructureEditor(
                                      bibleId: bibleId,
                                      projectId: widget.projectId,
                                    ),
                                  )
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
    );
  }
}
