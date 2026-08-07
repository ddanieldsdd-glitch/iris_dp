import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
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
import '../../core/templates/user_template_service.dart';
import 'bible_style_guide_sheet.dart';
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
  Map<String, BibleSectionDefinition> _sectionDefsById = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final db = ref.read(databaseProvider);
    final hadBible = await db.getVisualBibleForProject(widget.projectId) != null;
    final bible = await db.ensureVisualBibleForProject(widget.projectId);
    if (!hadBible) {
      await UserTemplateService.maybeApplyBibleTemplateOnCreate(
        db: db,
        projectId: widget.projectId,
        bibleId: bible.id,
      );
    }
    final project = await db.getProject(widget.projectId);
    if (mounted) {
      setState(() {
        _project = project;
        _data = VisualBibleData.fromRow(bible);
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
    final db = ref.read(databaseProvider);
    final id = await db.upsertVisualBible(data.toCompanion());
    data.id = id;
  }

  Future<void> _save(VisualBibleData data) async {
    setState(() {
      _saving = true;
      _saved = false;
    });
    try {
      final db = ref.read(databaseProvider);
      final id = await db.upsertVisualBible(data.toCompanion());
      data.id = id;
      if (mounted) setState(() => _saved = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<
      ({
        VisualBibleData data,
        List<ColorBlockModel> blocks,
        List<ExposureBlockModel> exposureBlocks,
        List<LightingSetupModel> lightingSetups,
        List<CameraTestModel> cameraTests,
        List<MoodboardImageModel> moodboard,
      })> _loadExportBundle() async {
    final db = ref.read(databaseProvider);
    final bible = await db.ensureVisualBibleForProject(widget.projectId);
    final data = _data ?? VisualBibleData.fromRow(bible);
    final colorRows = await db.watchColorBlocksForBible(bible.id).first;
    final exposureRows = await db.watchExposureBlocksForBible(bible.id).first;
    final lightingRows = await db.watchLightingSetupsForBible(bible.id).first;
    final testRows = await db.watchCameraTestsForBible(bible.id).first;
    final moodRows = await db.watchMoodboardImages(widget.projectId).first;
    return (
      data: data,
      blocks: colorRows.map(ColorBlockModel.fromRow).toList(),
      exposureBlocks: exposureRows.map(ExposureBlockModel.fromRow).toList(),
      lightingSetups: lightingRows.map(LightingSetupModel.fromRow).toList(),
      cameraTests: testRows.map(CameraTestModel.fromRow).toList(),
      moodboard: moodRows.map(MoodboardImageModel.fromRow).toList(),
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

  Future<void> _saveSectionContent(String sectionId, String? contentJson) async {
    final db = ref.read(databaseProvider);
    final def = _sectionDefsById[sectionId];
    if (def == null || _data == null) return;
    await db.upsertBibleSectionDefinition(
      def.copyWith(contentJson: Value(contentJson)),
    );
  }

  String? _sectionContentJson(String sectionId) =>
      _sectionDefsById[sectionId]?.contentJson;

  Widget _buildSection(int bibleId) {
    final data = _data!;
    final customDef = _sectionDefsById[_activeSection];
    if (customDef != null && customDef.template == 'freeform') {
      return CustomBibleSection(
        projectId: widget.projectId,
        sectionId: customDef.id,
        label: customDef.label,
        contentJson: customDef.contentJson,
        onContentChanged: (json) => _saveSectionContent(customDef.id, json),
      );
    }

    return switch (_activeSection) {
      BibleSectionId.direction => DirectionSection(
          data: data,
          projectId: widget.projectId,
          sectionLabel: _sectionDefsById[BibleSectionId.direction]?.label ??
              'Dirección',
          contentJson:
              _sectionDefsById[BibleSectionId.direction]?.contentJson,
          onChanged: _onDataChanged,
        ),
      BibleSectionId.concept => ConceptSection(
          data: data,
          projectId: widget.projectId,
          sectionContentJson: _sectionContentJson(BibleSectionId.concept),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.camera => CameraSensorSection(
          data: data,
          projectId: widget.projectId,
          sectionContentJson: _sectionContentJson(BibleSectionId.camera),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.optics => OpticsSection(
          data: data,
          projectId: widget.projectId,
          sectionContentJson: _sectionContentJson(BibleSectionId.optics),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.exposure => ExposureSection(
          data: data,
          projectId: widget.projectId,
          bibleId: bibleId,
          sectionContentJson: _sectionContentJson(BibleSectionId.exposure),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.lighting => LightingSection(
          data: data,
          projectId: widget.projectId,
          bibleId: bibleId,
          sectionContentJson: _sectionContentJson(BibleSectionId.lighting),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.colorImage => ColorImageSection(
          data: data,
          projectId: widget.projectId,
          bibleId: bibleId,
          sectionContentJson: _sectionContentJson(BibleSectionId.colorImage),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.format => FormatSection(
          data: data,
          projectId: widget.projectId,
          sectionContentJson: _sectionContentJson(BibleSectionId.format),
          onChanged: _onDataChanged,
        ),
      BibleSectionId.texture => TextureSection(
          data: data,
          projectId: widget.projectId,
          sectionContentJson: _sectionContentJson(BibleSectionId.texture),
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
          bibleId: bibleId,
          onChanged: _onDataChanged,
        ),
      BibleSectionId.moodboard => MoodboardSection(
          projectId: widget.projectId,
          bibleId: bibleId,
          initialFilter: _moodboardInitialFilter,
        ),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

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
      body: StreamBuilder<VisualBible?>(
        stream: db.watchVisualBibleForProject(widget.projectId),
        builder: (context, snap) {
          if (_loading && snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_data == null) {
            final row = snap.data;
            if (row != null) {
              _data = VisualBibleData.fromRow(row);
            } else {
              _data = VisualBibleData(projectId: widget.projectId);
            }
            _loading = false;
          }

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
                  ? db.watchBibleSectionGroups(bibleId)
                  : Stream.value([]),
              builder: (context, groupSnap) {
                return StreamBuilder<List<BibleSectionDefinition>>(
                  stream: bibleId > 0
                      ? db.watchBibleSectionDefinitions(bibleId)
                      : Stream.value([]),
                  builder: (context, defSnap) {
                    final defs = defSnap.data ?? [];
                    _sectionDefsById = {for (final d in defs) d.id: d};

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
                        Expanded(child: _buildSection(bibleId)),
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
