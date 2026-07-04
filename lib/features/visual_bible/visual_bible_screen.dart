import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_snackbar.dart';
import '../look_bible/look_bible_model.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import 'visual_bible_model.dart';
import 'visual_bible_pdf_service.dart';
import 'widgets/moodboard_section.dart';
import 'widgets/visual_bible_tab_sections.dart';

class VisualBibleScreen extends ConsumerStatefulWidget {
  final int projectId;

  const VisualBibleScreen({super.key, required this.projectId});

  @override
  ConsumerState<VisualBibleScreen> createState() => _VisualBibleScreenState();
}

class _VisualBibleScreenState extends ConsumerState<VisualBibleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VisualBibleData? _data;
  Project? _project;
  bool _loading = true;
  bool _saving = false;
  Timer? _saveDebounce;

  final _sections = const [
    _Section('Concepto', Icons.auto_stories_outlined),
    _Section('Color', Icons.palette_outlined),
    _Section('Luz', Icons.wb_sunny_outlined),
    _Section('Cámara', Icons.videocam_outlined),
    _Section('Óptica', Icons.camera_outlined),
    _Section('Formato', Icons.aspect_ratio_outlined),
    _Section('Textura', Icons.grain_outlined),
    _Section('LUT', Icons.tune_outlined),
    _Section('Localización', Icons.location_on_outlined),
    _Section('Moodboard', Icons.photo_library_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _sections.length, vsync: this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final db = ref.read(databaseProvider);
    final bible = await db.ensureVisualBibleForProject(widget.projectId);
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
    _tabController.dispose();
    super.dispose();
  }

  void _scheduleSave(VisualBibleData data) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () => _save(data));
  }

  Future<void> _save(VisualBibleData data) async {
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final id = await db.upsertVisualBible(data.toCompanion());
      data.id = id;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<({VisualBibleData data, List<ColorBlockModel> blocks, List<MoodboardImageModel> moodboard})>
      _loadExportBundle() async {
    final db = ref.read(databaseProvider);
    final bible = await db.ensureVisualBibleForProject(widget.projectId);
    final data = _data ?? VisualBibleData.fromRow(bible);
    final colorRows = await db.watchColorBlocksForBible(bible.id).first;
    final moodRows = await db.watchMoodboardImages(widget.projectId).first;
    return (
      data: data,
      blocks: colorRows.map(ColorBlockModel.fromRow).toList(),
      moodboard: moodRows.map(MoodboardImageModel.fromRow).toList(),
    );
  }

  Future<void> _exportPdf() async {
    final project = _project;
    if (project == null || _data == null) return;
    try {
      final bundle = await _loadExportBundle();
      final path = await VisualBiblePdfService.exportFull(
        projectName: project.name,
        director: project.director,
        data: bundle.data,
        colorBlocks: bundle.blocks,
        moodboard: bundle.moodboard,
      );
      if (!mounted || path == null) return;
      AppSnackBar.show(context, 'Biblia Visual exportada en $path');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, userFriendlyError(e));
    }
  }

  Future<void> _shareWithTeam() async {
    final project = _project;
    if (project == null || _data == null) return;

    final dept = await showModalBottomSheet<String>(
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
                child: Text('Compartir con equipo', style: AppTypography.titleMedium(palette)),
              ),
              ...VisualBibleDepartment.all.map(
                (id) => ListTile(
                  title: Text(VisualBibleDepartment.label(id)),
                  onTap: () => Navigator.pop(ctx, id),
                ),
              ),
              ListTile(
                title: const Text('Documento completo'),
                onTap: () => Navigator.pop(ctx, '__full__'),
              ),
            ],
          ),
        );
      },
    );

    if (dept == null || !mounted) return;
    try {
      final bundle = await _loadExportBundle();
      String? path;
      if (dept == '__full__') {
        path = await VisualBiblePdfService.exportFull(
          projectName: project.name,
          director: project.director,
          data: bundle.data,
          colorBlocks: bundle.blocks,
          moodboard: bundle.moodboard,
        );
      } else {
        path = await VisualBiblePdfService.exportDepartment(
          department: dept,
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Biblia Visual', style: AppTypography.titleMedium(palette)),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (_data != null && _project != null)
            GoodNotesPdfActions(
              projectId: widget.projectId,
              moduleType: GoodNotesModuleType.visualBible,
              filenameBase:
                  '${_project!.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim()}_biblia_visual',
              buildPdfBytes: () async {
                final bundle = await _loadExportBundle();
                return VisualBiblePdfService.buildFullBytes(
                  projectName: _project!.name,
                  director: _project!.director,
                  data: bundle.data,
                  colorBlocks: bundle.blocks,
                  moodboard: bundle.moodboard,
                );
              },
            ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf_outlined, color: palette.textSecondary),
            tooltip: 'Exportar PDF',
            onPressed: _exportPdf,
          ),
          IconButton(
            icon: Icon(Icons.ios_share_outlined, color: palette.textSecondary),
            tooltip: 'Compartir con equipo',
            onPressed: _shareWithTeam,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: palette.accent,
          unselectedLabelColor: palette.textTertiary,
          indicatorColor: palette.accent,
          labelStyle: AppTypography.label(palette),
          tabs: _sections
              .map((s) => Tab(icon: Icon(s.icon, size: 16), text: s.title))
              .toList(),
        ),
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

          final data = _data!;
          final bibleId = data.id > 0 ? data.id : snap.data?.id ?? 0;

          return TabBarView(
            controller: _tabController,
            children: [
              ConceptSection(
                data: data,
                onChanged: (d) {
                  _scheduleSave(d);
                  setState(() {});
                },
              ),
              ColorSection(bibleId: bibleId, onChanged: () => setState(() {})),
              LightingSection(
                data: data,
                onChanged: (d) {
                  _scheduleSave(d);
                  setState(() {});
                },
              ),
              CameraSection(
                data: data,
                onChanged: (d) {
                  _scheduleSave(d);
                  setState(() {});
                },
              ),
              OpticsSection(
                data: data,
                onChanged: (d) {
                  _scheduleSave(d);
                  setState(() {});
                },
              ),
              FormatSection(
                data: data,
                onChanged: (d) {
                  _scheduleSave(d);
                  setState(() {});
                },
              ),
              TextureSection(
                data: data,
                onChanged: (d) {
                  _scheduleSave(d);
                  setState(() {});
                },
              ),
              LutSection(
                data: data,
                onChanged: (d) {
                  _scheduleSave(d);
                  setState(() {});
                },
              ),
              ByLocationSection(projectId: widget.projectId, bibleId: bibleId),
              MoodboardSection(projectId: widget.projectId, bibleId: bibleId),
            ],
          );
        },
      ),
    );
  }
}

class _Section {
  final String title;
  final IconData icon;
  const _Section(this.title, this.icon);
}
