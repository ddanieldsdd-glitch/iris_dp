import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/scene_format.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../camera_plan/camera_plan_grouping.dart';
import 'iris_dp_export_service.dart';
import 'luka_bridge_preview_panel.dart';
import 'luka_export_preview.dart';
import 'unreal_render_import.dart';
import '../../core/widgets/app_snackbar.dart';

/// Puente IRIS DP → Unreal Engine 5 (Gaussian Splat + ARRI LUKA).
class LukaBridgeScreen extends ConsumerStatefulWidget {
  final int projectId;
  final String projectName;

  const LukaBridgeScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  ConsumerState<LukaBridgeScreen> createState() => _LukaBridgeScreenState();
}

class _LukaBridgeScreenState extends ConsumerState<LukaBridgeScreen> {
  Scene? _selectedScene;
  bool _exporting = false;
  bool _importing = false;
  double _canvasScale = 0.01;
  LukaExportPreview? _scenePreview;
  LukaExportPreview? _projectPreview;
  bool _previewLoading = false;
  bool _showProjectSummary = false;
  StreamSubscription<void>? _sceneWatchSub;
  StreamSubscription<void>? _projectWatchSub;
  Timer? _previewDebounce;
  int _previewGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProjectPreview();
    });
  }

  @override
  void dispose() {
    _sceneWatchSub?.cancel();
    _projectWatchSub?.cancel();
    _previewDebounce?.cancel();
    super.dispose();
  }

  void _updateExportWatchers() {
    _sceneWatchSub?.cancel();
    _sceneWatchSub = null;
    _projectWatchSub?.cancel();
    _projectWatchSub = null;

    final db = ref.read(databaseProvider);
    if (_showProjectSummary) {
      _projectWatchSub = LukaExportPreviewService.watchProjectExportTriggers(
        db,
        widget.projectId,
      ).listen((_) => _scheduleProjectPreviewRefresh());
    } else if (_selectedScene != null) {
      _sceneWatchSub = LukaExportPreviewService.watchSceneExportTriggers(
        db,
        sceneId: _selectedScene!.id,
        projectId: widget.projectId,
      ).listen((_) => _scheduleScenePreviewRefresh());
    }
  }

  void _scheduleScenePreviewRefresh({bool immediate = false}) {
    if (_selectedScene == null || _showProjectSummary) return;
    _previewDebounce?.cancel();
    if (immediate) {
      _refreshScenePreview();
      return;
    }
    _previewDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _refreshScenePreview();
    });
  }

  void _scheduleProjectPreviewRefresh({bool immediate = false}) {
    if (!_showProjectSummary) return;
    _previewDebounce?.cancel();
    if (immediate) {
      _loadProjectPreview();
      return;
    }
    _previewDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _loadProjectPreview();
    });
  }

  Future<void> _loadProjectPreview() async {
    final db = ref.read(databaseProvider);
    final preview = await LukaExportPreviewService(db).buildForProject(
      projectId: widget.projectId,
      canvasScale: _canvasScale,
    );
    if (mounted) setState(() => _projectPreview = preview);
  }

  Future<void> _selectScene(Scene scene) async {
    setState(() {
      _selectedScene = scene;
      _showProjectSummary = false;
      _previewLoading = true;
      _scenePreview = null;
    });

    final db = ref.read(databaseProvider);
    final previewService = LukaExportPreviewService(db);
    final scaleInfo = await previewService.resolveScaleForScene(scene);
    final preview = await previewService.buildForScene(
      scene: scene,
      canvasScale: scaleInfo.scale,
    );

    if (!mounted) return;
    setState(() {
      _canvasScale = scaleInfo.scale;
      _scenePreview = preview;
      _previewLoading = false;
    });
    _updateExportWatchers();
  }

  Future<void> _refreshScenePreview() async {
    final scene = _selectedScene;
    if (scene == null) return;
    final gen = ++_previewGeneration;
    if (mounted) setState(() => _previewLoading = true);
    final db = ref.read(databaseProvider);
    final freshScene = await db.getSceneById(scene.id) ?? scene;
    final preview = await LukaExportPreviewService(db).buildForScene(
      scene: freshScene,
      canvasScale: _canvasScale,
    );
    if (!mounted || gen != _previewGeneration) return;
    setState(() {
      _selectedScene = freshScene;
      _scenePreview = preview;
      _previewLoading = false;
    });
  }

  void _onScaleChanged(double v) {
    setState(() => _canvasScale = v);
    if (_selectedScene != null && !_showProjectSummary) {
      _refreshScenePreview();
    } else {
      _loadProjectPreview();
    }
  }

  LukaExportPreview? get _activePreview =>
      _showProjectSummary ? _projectPreview : _scenePreview;

  Future<void> _exportScene() async {
    final scene = _selectedScene;
    if (scene == null || _exporting) return;

    final palette = context.palette;
    final db = ref.read(databaseProvider);
    setState(() => _exporting = true);

    try {
      final project = await db.getProject(widget.projectId);
      if (project == null) return;

      final exporter = IrisDpExportService(db);
      final payload = await exporter.buildSceneExport(
        project: project,
        scene: scene,
        canvasScale: _canvasScale,
      );
      final json = exporter.encodePretty(payload);

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar escena a Unreal',
        fileName: exporter.defaultFilename(scene),
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (path == null) return;

      final file = File(path.endsWith('.json') ? path : '$path.json');
      await file.writeAsString(json);

      if (!mounted) return;
      AppSnackBar.show(context, 'JSON exportado en ${file.path}');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportProject() async {
    if (_exporting) return;

    final palette = context.palette;
    final db = ref.read(databaseProvider);
    setState(() => _exporting = true);

    try {
      final project = await db.getProject(widget.projectId);
      if (project == null) return;

      final exporter = IrisDpExportService(db);
      final payload = await exporter.buildProjectExport(
        project: project,
        canvasScale: _canvasScale,
      );
      final json = exporter.encodePretty(payload);

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar proyecto completo a Unreal',
        fileName: exporter.defaultProjectFilename(project),
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (path == null) return;

      final file = File(path.endsWith('.json') ? path : '$path.json');
      await file.writeAsString(json);

      if (!mounted) return;
      AppSnackBar.show(context, 'Proyecto exportado (${payload['scenes']?.length ?? 0} escenas)');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importRenders() async {
    if (_importing) return;

    final palette = context.palette;
    final db = ref.read(databaseProvider);
    setState(() => _importing = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Importar renders Unreal (PNG)',
        type: FileType.custom,
        allowedExtensions: ['png'],
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      final paths = result.files
          .map((f) => f.path)
          .whereType<String>()
          .where((p) => p.isNotEmpty)
          .toList();
      if (paths.isEmpty) return;

      final importResult = await importUnrealRenderBatch(
        db: db,
        projectId: widget.projectId,
        filePaths: paths,
      );

      if (!mounted) return;

      final summary =
          '${importResult.imported} importados, ${importResult.skipped} omitidos';
      AppSnackBar.show(
        context,
        summary,
        duration: const Duration(seconds: 4),
      );

      if (importResult.errors.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Detalle de importación'),
            content: SingleChildScrollView(
              child: Text(importResult.errors.join('\n')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Unreal / LUKA Bridge', style: AppTypography.titleMedium(palette)),
      ),
      body: StreamBuilder<List<Scene>>(
        stream: db.watchScenesForProject(widget.projectId),
        builder: (context, snap) {
          final scenes = scenesInScriptOrder(snap.data ?? []);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previsualización 3D',
                      style: AppTypography.titleMedium(palette),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Exporta la escena a JSON para importarla en Unreal Engine 5 '
                      'con el script iris_dp_import.py. Combina tu Gaussian Splat '
                      '(Luma AI) con cámaras, luces LUKA y actores del guion.',
                      style: AppTypography.bodyMedium(palette),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Escena a exportar', style: AppTypography.label(palette)),
              const SizedBox(height: AppSpacing.sm),
              if (scenes.isEmpty)
                Text(
                  'Importa el guion y crea escenas antes de exportar.',
                  style: AppTypography.bodyMedium(palette),
                )
              else
                ...scenes.map((scene) {
                  final location = locationFromCanonical(scene.locationCanonical);
                  final selected = _selectedScene?.id == scene.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _selectScene(scene),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? palette.accent
                                  : palette.divider,
                              width: selected ? 2 : 1,
                            ),
                            color: selected
                                ? palette.accent.withValues(alpha: 0.08)
                                : palette.surfaceElevated.withValues(alpha: 0.5),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: selected
                                    ? palette.accent
                                    : palette.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Esc ${scene.number} · $location',
                                      style: AppTypography.bodyLarge(palette),
                                    ),
                                    Text(
                                      scene.locationCanonical,
                                      style: AppTypography.caption(palette),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              if (_selectedScene != null || _projectPreview != null) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Vista previa del export',
                        style: AppTypography.label(palette),
                      ),
                    ),
                    if (_selectedScene != null)
                      TextButton(
                        onPressed: () {
                          setState(() => _showProjectSummary = false);
                          _updateExportWatchers();
                          _scheduleScenePreviewRefresh(immediate: true);
                        },
                        child: Text(
                          'Escena',
                          style: AppTypography.caption(palette).copyWith(
                            color: !_showProjectSummary
                                ? palette.accent
                                : palette.textSecondary,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () {
                        setState(() => _showProjectSummary = true);
                        _loadProjectPreview();
                        _updateExportWatchers();
                      },
                      child: Text(
                        'Proyecto',
                        style: AppTypography.caption(palette).copyWith(
                          color: _showProjectSummary
                              ? palette.accent
                              : palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                LukaBridgePreviewPanel(
                  preview: _activePreview ?? LukaExportPreview.empty,
                  loading: _previewLoading &&
                      !_showProjectSummary &&
                      _selectedScene != null,
                  canvasScale: _canvasScale,
                  projectWide: _showProjectSummary,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text('Escala del lienzo 2D', style: AppTypography.label(palette)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '1 px en planta = ${_canvasScale}m en Unreal (${(_canvasScale * 100).toStringAsFixed(0)} cm)',
                style: AppTypography.caption(palette),
              ),
              if (_scenePreview?.scaleSource == 'scan' &&
                  !_showProjectSummary &&
                  _selectedScene != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Escala sincronizada con el scan del set',
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.accent,
                    ),
                  ),
                ),
              Slider(
                value: _canvasScale,
                min: 0.005,
                max: 0.05,
                divisions: 9,
                label: _canvasScale.toStringAsFixed(3),
                onChanged: _onScaleChanged,
              ),
              if (_scenePreview?.suggestedScale != null &&
                  _scenePreview!.suggestedScale != _canvasScale &&
                  !_showProjectSummary)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        _onScaleChanged(_scenePreview!.suggestedScale!),
                    icon: Icon(Icons.sync, size: 16, color: palette.accent),
                    label: Text(
                      'Usar escala del scan (${_scenePreview!.suggestedScale}m/px)',
                      style: AppTypography.caption(palette).copyWith(
                        color: palette.accent,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: _exporting ? 'Exportando…' : 'Exportar JSON para Unreal',
                icon: Icons.upload_file_outlined,
                onTap: _selectedScene == null || _exporting ? null : _exportScene,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: _exporting ? 'Exportando…' : 'Exportar proyecto completo',
                icon: Icons.folder_outlined,
                variant: AppButtonVariant.secondary,
                onTap: _exporting ? null : _exportProject,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Reimportar renders', style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Selecciona PNG nombrados iris_dp_s{escenaId}_p{plano}.png '
                'desde Movie Render Queue. Se añaden como referencias de plano.',
                style: AppTypography.bodyMedium(palette),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: _importing ? 'Importando…' : 'Importar renders Unreal',
                icon: Icons.download_outlined,
                variant: AppButtonVariant.secondary,
                onTap: _importing ? null : _importRenders,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Workflow', style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.sm),
              const _WorkflowStep(
                number: '1',
                title: 'Captura la localización',
                body: 'Luma AI o Polycam en iPhone → exporta .ply/.luma',
              ),
              const _WorkflowStep(
                number: '2',
                title: 'Importa el Gaussian Splat en UE5',
                body: 'Plugin Luma AI → arrastra el .ply al Level',
              ),
              const _WorkflowStep(
                number: '3',
                title: 'Exporta desde IRIS DP',
                body: 'Genera el JSON de la escena con el botón de arriba',
              ),
              const _WorkflowStep(
                number: '4',
                title: 'Ejecuta iris_dp_import.py',
                body: 'Tools → Execute Python Script en Unreal (Windows para LUKA)',
              ),
              const _WorkflowStep(
                number: '5',
                title: 'Renderiza y reimporta',
                body: 'Movie Render Queue → frames PNG → REFERENCIA en IRIS DP',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _WorkflowStep({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: AppTypography.label(palette).copyWith(
                color: palette.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyLarge(palette)),
                Text(body, style: AppTypography.caption(palette)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
