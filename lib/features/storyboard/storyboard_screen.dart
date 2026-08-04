import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../core/utils/scene_format.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/shot_reference_gallery.dart';
import '../camera_plan/camera_plan_grouping.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import '../look_bible/look_bible_model.dart';
import '../pdf_export/storyboard_pdf.dart';
import '../technical_script/technical_script_screen.dart';
import 'storyboard_export_options_sheet.dart';
import 'storyboard_shot_export_service.dart';
import '../../core/widgets/app_snackbar.dart';

enum _StoryboardLayout { linear, grid, list }

enum _StoryboardFilter { all, missing, withImage }

/// Storyboard del proyecto: un fotograma por plano con sus referencias visuales.
class StoryboardScreen extends ConsumerStatefulWidget {
  final int projectId;

  const StoryboardScreen({super.key, required this.projectId});

  @override
  ConsumerState<StoryboardScreen> createState() => _StoryboardScreenState();
}

class _StoryboardScreenState extends ConsumerState<StoryboardScreen> {
  _StoryboardLayout _layout = _StoryboardLayout.linear;
  _StoryboardFilter _filter = _StoryboardFilter.all;
  bool _exporting = false;

  Future<void> _exportPdf(BuildContext context) async {
    if (_exporting) return;
    final db = ref.read(databaseProvider);

    setState(() => _exporting = true);
    try {
      final project = await db.getProject(widget.projectId);
      if (project == null) return;

      final scenes = scenesInScriptOrder(
        await db.watchScenesForProject(widget.projectId).first,
      );
      if (scenes.isEmpty) {
        if (!context.mounted) return;
        AppSnackBar.show(context, 'No hay escenas para exportar.');
        return;
      }

      final shotsByScene = <int, List<Shot>>{};
      for (final scene in scenes) {
        shotsByScene[scene.id] =
            await db.watchShotsForScene(scene.id).first;
      }

      final hasShots = shotsByScene.values.any((s) => s.isNotEmpty);
      if (!hasShots) {
        if (!context.mounted) return;
        AppSnackBar.show(context, 'Añade planos en el guion técnico antes de exportar.');
        return;
      }

      if (!context.mounted) return;
      if (mounted) setState(() => _exporting = false);
      final choice = await showStoryboardGroupExportOptionsSheet(context);
      if (choice == null) return;
      if (mounted) setState(() => _exporting = true);

      final path = await StoryboardPdfExporter.exportAndSave(
        project: project,
        scenes: scenes,
        shotsByScene: shotsByScene,
        groupChoice: choice,
        db: db,
      );

      if (!context.mounted) return;
      if (path != null) {
        final isDir = Directory(path).existsSync();
        AppSnackBar.show(
          context,
          isDir
              ? 'PDFs exportados en $path (un archivo _SB/_SL por escena)'
              : 'Storyboard exportado en $path',
        );
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('Storyboard export error: $e\n$st');
      if (!context.mounted) return;
      AppSnackBar.showError(context, userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Storyboard', style: AppTypography.titleMedium(palette)),
        actions: [
          GoodNotesPdfActions(
            projectId: widget.projectId,
            moduleType: GoodNotesModuleType.storyboard,
            filenameBase: 'storyboard',
            buildPdfBytes: () async {
              final db = ref.read(databaseProvider);
              final project = await db.getProject(widget.projectId);
              if (project == null) return Uint8List(0);
              if (!context.mounted) return Uint8List(0);
              final choice = await showStoryboardGroupExportOptionsSheet(context);
              if (choice == null) return Uint8List(0);
              final scenes =
                  await db.watchScenesForProject(widget.projectId).first;
              final shotsByScene = <int, List<Shot>>{};
              for (final scene in scenes) {
                shotsByScene[scene.id] =
                    await db.watchShotsForScene(scene.id).first;
              }
              return StoryboardPdfExporter.buildBytes(
                project: project,
                scenes: scenes,
                shotsByScene: shotsByScene,
                groupChoice: choice,
                db: db,
              );
            },
          ),
          IconButton(
            tooltip: 'Exportar PDF',
            icon: _exporting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.accent,
                    ),
                  )
                : Icon(Icons.picture_as_pdf_outlined, color: palette.accent),
            onPressed: _exporting ? null : () => _exportPdf(context),
          ),
          IconButton(
            tooltip: 'Guion técnico',
            icon: Icon(Icons.table_rows_outlined, color: palette.accent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    TechnicalScriptScreen(projectId: widget.projectId),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Scene>>(
        stream: db.watchScenesForProject(widget.projectId),
        builder: (context, sceneSnap) {
          if (!sceneSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final scenes = scenesInScriptOrder(sceneSnap.data!);
          if (scenes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Añade escenas y planos en el guion técnico para '
                  'montar el storyboard.',
                  style: AppTypography.bodyMedium(palette),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<List<LocationSite>>(
            stream: db.watchSitesForProject(widget.projectId),
            builder: (context, siteSnap) {
              return StreamBuilder<List<LocationBasePlan>>(
                stream: db.watchLocationsForProject(widget.projectId),
                builder: (context, setSnap) {
                  final colors = ProjectColorScheme.resolve(
                    sites: siteSnap.data ?? [],
                    sets: setSnap.data ?? [],
                    scenes: scenes,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          0,
                        ),
                        child: _StoryboardToolbar(
                          layout: _layout,
                          filter: _filter,
                          onLayoutChanged: (l) => setState(() => _layout = l),
                          onFilterChanged: (f) => setState(() => _filter = f),
                        ),
                      ),
                      Expanded(
                        child: _StoryboardBody(
                          projectId: widget.projectId,
                          scenes: scenes,
                          colors: colors,
                          layout: _layout,
                          filter: _filter,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _StoryboardToolbar extends StatelessWidget {
  final _StoryboardLayout layout;
  final _StoryboardFilter filter;
  final ValueChanged<_StoryboardLayout> onLayoutChanged;
  final ValueChanged<_StoryboardFilter> onFilterChanged;

  const _StoryboardToolbar({
    required this.layout,
    required this.filter,
    required this.onLayoutChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Modo storyboard con datos del guion técnico. '
          'Edita aquí o en la tabla: los cambios se sincronizan al instante.',
          style: AppTypography.bodyMedium(palette),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            SegmentedButton<_StoryboardLayout>(
              segments: const [
                ButtonSegment(
                  value: _StoryboardLayout.linear,
                  icon: Icon(Icons.view_timeline_outlined, size: 18),
                  label: Text('Lineal'),
                ),
                ButtonSegment(
                  value: _StoryboardLayout.grid,
                  icon: Icon(Icons.grid_view_outlined, size: 18),
                  label: Text('Rejilla'),
                ),
                ButtonSegment(
                  value: _StoryboardLayout.list,
                  icon: Icon(Icons.view_list_outlined, size: 18),
                  label: Text('Lista'),
                ),
              ],
              selected: {layout},
              showSelectedIcon: false,
              onSelectionChanged: (s) => onLayoutChanged(s.first),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: DropdownButtonFormField<_StoryboardFilter>(
                value: filter,
                dropdownColor: palette.surfaceElevated,
                style: AppTypography.bodyMedium(palette),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: _StoryboardFilter.all,
                    child: Text('Todos los planos'),
                  ),
                  DropdownMenuItem(
                    value: _StoryboardFilter.withImage,
                    child: Text('Con imagen'),
                  ),
                  DropdownMenuItem(
                    value: _StoryboardFilter.missing,
                    child: Text('Sin imagen'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) onFilterChanged(v);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StoryboardBody extends ConsumerWidget {
  final int projectId;
  final List<Scene> scenes;
  final ProjectColorScheme colors;
  final _StoryboardLayout layout;
  final _StoryboardFilter filter;

  const _StoryboardBody({
    required this.projectId,
    required this.scenes,
    required this.colors,
    required this.layout,
    required this.filter,
  });

  bool _passesFilter(Shot shot) {
    final path = shot.referenceImagePath;
    final hasImage = path != null && File(path).existsSync();
    return switch (filter) {
      _StoryboardFilter.all => true,
      _StoryboardFilter.withImage => hasImage,
      _StoryboardFilter.missing => !hasImage,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (layout == _StoryboardLayout.linear) {
      return _StoryboardLinearStrip(
        projectId: projectId,
        scenes: scenes,
        colors: colors,
        filter: filter,
      );
    }

    if (layout == _StoryboardLayout.grid) {
      return _StoryboardContinuousGrid(
        projectId: projectId,
        scenes: scenes,
        colors: colors,
        filter: filter,
      );
    }

    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: scenes.length,
      itemBuilder: (context, sceneIndex) {
        final scene = scenes[sceneIndex];
        final sceneColor = colors.sceneColor(scene);
        final location = locationFromCanonical(scene.locationCanonical);

        return StreamBuilder<List<Shot>>(
          stream: db.watchShotsForScene(scene.id),
          builder: (context, shotSnap) {
            final allShots = shotSnap.data ?? [];
            final shots = allShots.where(_passesFilter).toList();
            if (shots.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: sceneColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Esc ${scene.number} · $location',
                          style: AppTypography.titleMedium(palette).copyWith(
                            color: sceneColor,
                          ),
                        ),
                      ),
                      Text(
                        '${shots.length} plano${shots.length == 1 ? '' : 's'}',
                        style: AppTypography.caption(palette),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...shots.map(
                    (shot) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _StoryboardFrame(
                        scene: scene,
                        shot: shot,
                        sceneColor: sceneColor,
                        listLayout: true,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _GridShotEntry {
  final Scene scene;
  final Shot shot;
  final bool isFirstInScene;

  const _GridShotEntry({
    required this.scene,
    required this.shot,
    required this.isFirstInScene,
  });
}

/// Rejilla continua: planos en orden de guion, 3 columnas sin huecos entre escenas.
class _StoryboardContinuousGrid extends ConsumerWidget {
  final int projectId;
  final List<Scene> scenes;
  final ProjectColorScheme colors;
  final _StoryboardFilter filter;

  const _StoryboardContinuousGrid({
    required this.projectId,
    required this.scenes,
    required this.colors,
    required this.filter,
  });

  bool _passesFilter(Shot shot) {
    final path = shot.referenceImagePath;
    final hasImage = path != null && File(path).existsSync();
    return switch (filter) {
      _StoryboardFilter.all => true,
      _StoryboardFilter.withImage => hasImage,
      _StoryboardFilter.missing => !hasImage,
    };
  }

  int _crossAxisCount(double width) {
    if (width >= AppLayout.wideBreakpoint) return 3;
    if (width >= 640) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<Shot>>(
      stream: db.watchShotsForProject(projectId),
      builder: (context, shotSnap) {
        if (!shotSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allShots = shotSnap.data!;
        final entries = <_GridShotEntry>[];

        for (final scene in scenes) {
          final shots = allShots
              .where((s) => s.sceneId == scene.id && _passesFilter(s))
              .toList()
            ..sort((a, b) => a.number.compareTo(b.number));

          for (var i = 0; i < shots.length; i++) {
            entries.add(
              _GridShotEntry(
                scene: scene,
                shot: shots[i],
                isFirstInScene: i == 0,
              ),
            );
          }
        }

        if (entries.isEmpty) {
          return Center(
            child: Text(
              'No hay planos que coincidan con el filtro.',
              style: AppTypography.bodyMedium(palette),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = _crossAxisCount(constraints.maxWidth);
            final rows = <List<_GridShotEntry>>[];
            for (var i = 0; i < entries.length; i += crossAxisCount) {
              final end = (i + crossAxisCount).clamp(0, entries.length);
              rows.add(entries.sublist(i, end));
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, rowIndex) {
                final row = rows[rowIndex];
                final showRowSceneHeader = row.first.isFirstInScene;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showRowSceneHeader) ...[
                      _SceneGridBreakHeader(
                        scene: row.first.scene,
                        color: colors.sceneColor(row.first.scene),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var col = 0; col < row.length; col++)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: col > 0 &&
                                          row[col].isFirstInScene &&
                                          !showRowSceneHeader
                                      ? AppSpacing.sm
                                      : 0,
                                  right: col < row.length - 1
                                      ? AppSpacing.md
                                      : 0,
                                ),
                                child: _StoryboardFrame(
                                  scene: row[col].scene,
                                  shot: row[col].shot,
                                  sceneColor: colors.sceneColor(row[col].scene),
                                  gridLayout: true,
                                  sceneStart: row[col].isFirstInScene,
                                  sceneHeaderAbove: showRowSceneHeader &&
                                      row[col].isFirstInScene,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SceneGridBreakHeader extends StatelessWidget {
  final Scene scene;
  final Color color;

  const _SceneGridBreakHeader({
    required this.scene,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final location = locationFromCanonical(scene.locationCanonical);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Esc ${scene.number} · $location',
              style: AppTypography.label(palette).copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tira horizontal: todos los planos en orden de guion, con marcas de escena.
class _StoryboardLinearStrip extends ConsumerWidget {
  final int projectId;
  final List<Scene> scenes;
  final ProjectColorScheme colors;
  final _StoryboardFilter filter;

  const _StoryboardLinearStrip({
    required this.projectId,
    required this.scenes,
    required this.colors,
    required this.filter,
  });

  bool _passesFilter(Shot shot) {
    final path = shot.referenceImagePath;
    final hasImage = path != null && File(path).existsSync();
    return switch (filter) {
      _StoryboardFilter.all => true,
      _StoryboardFilter.withImage => hasImage,
      _StoryboardFilter.missing => !hasImage,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<Shot>>(
      stream: db.watchShotsForProject(projectId),
      builder: (context, shotSnap) {
        if (!shotSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allShots = shotSnap.data!;
        final children = <Widget>[];

        for (final scene in scenes) {
          final shots = allShots
              .where((s) => s.sceneId == scene.id && _passesFilter(s))
              .toList()
            ..sort((a, b) => a.number.compareTo(b.number));
          if (shots.isEmpty) continue;

          children.add(
            _SceneBreakMarker(
              scene: scene,
              color: colors.sceneColor(scene),
            ),
          );

          for (final shot in shots) {
            children.add(
              SizedBox(
                width: 220,
                child: _StoryboardFrame(
                  scene: scene,
                  shot: shot,
                  sceneColor: colors.sceneColor(scene),
                  linearLayout: true,
                ),
              ),
            );
          }
        }

        if (children.isEmpty) {
          return Center(
            child: Text(
              'No hay planos que coincidan con el filtro.',
              style: AppTypography.bodyMedium(palette),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Text(
                'Secuencia completa en orden de guion · desliza horizontalmente',
                style: AppTypography.caption(palette),
              ),
            ),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: children.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                itemBuilder: (_, i) => children[i],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SceneBreakMarker extends StatelessWidget {
  final Scene scene;
  final Color color;

  const _SceneBreakMarker({
    required this.scene,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final location = locationFromCanonical(scene.locationCanonical);

    return SizedBox(
      width: 52,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ESC',
                  style: AppTypography.caption(palette).copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${scene.number}',
                  style: AppTypography.titleMedium(palette).copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: AppTypography.caption(palette).copyWith(
                    fontSize: 9,
                    height: 1.15,
                    color: palette.textSecondary,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryboardFrame extends ConsumerWidget {
  final Scene scene;
  final Shot shot;
  final Color sceneColor;
  final bool listLayout;
  final bool linearLayout;
  final bool gridLayout;
  final bool sceneStart;
  final bool sceneHeaderAbove;

  const _StoryboardFrame({
    required this.scene,
    required this.shot,
    required this.sceneColor,
    this.listLayout = false,
    this.linearLayout = false,
    this.gridLayout = false,
    this.sceneStart = false,
    this.sceneHeaderAbove = false,
  });

  Future<void> _import(
    BuildContext context,
    WidgetRef ref, {
    required String source,
  }) async {
    final db = ref.read(databaseProvider);
    try {
      await pickAndImportShotReference(
        db: db,
        shot: shot,
        source: source,
        dialogTitle: 'Referencia · Plano ${shot.number}',
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(context, userFriendlyError(e));
      }
    }
  }

  Future<void> _openPrimaryViewer(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    try {
      final current = await db.getShotById(shot.id) ?? shot;
      final path = current.referenceImagePath;
      final hasImage = path != null && File(path).existsSync();

      if (!hasImage) {
        if (!context.mounted) return;
        _openFrameSheet(context, ref);
        return;
      }

      final refs = await ensureShotReferencesSynced(db: db, shot: current);
      if (refs.isEmpty) {
        if (!context.mounted) return;
        _openFrameSheet(context, ref);
        return;
      }

      var initial = refs.first;
      for (final r in refs) {
        if (r.imagePath == path) {
          initial = r;
          break;
        }
      }
      if (!context.mounted) return;

      await showShotReferenceViewer(
        context,
        ref: ref,
        scene: scene,
        shot: current,
        initialReference: initial,
        onImport: (source) => _import(context, ref, source: source),
      );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.showError(context, userFriendlyError(e));
    }
  }

  void _openFrameSheet(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.surfaceElevated,
      builder: (ctx) => _FrameDetailSheet(
        scene: scene,
        shot: shot,
        sceneColor: sceneColor,
        onImport: (source) {
          Navigator.pop(ctx);
          _import(context, ref, source: source);
        },
        onExport: () async {
          Navigator.pop(ctx);
          await _exportFrame(context, ref);
        },
      ),
    );
  }

  Future<void> _exportFrame(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final style = await showStoryboardExportOptionsSheet(
      context,
      singleShot: true,
    );
    if (style == null) return;

    try {
      final project = await db.getProject(scene.projectId);
      if (project == null) return;
      final path = await StoryboardShotExportService.exportSingle(
        project: project,
        scene: scene,
        shot: shot,
        style: style,
        db: db,
      );
      if (!context.mounted || path == null) return;
      AppSnackBar.show(context, 'Plano exportado en $path');
    } catch (e, st) {
      if (kDebugMode) debugPrint('Single shot export error: $e\n$st');
      if (!context.mounted) return;
      AppSnackBar.showError(context, userFriendlyError(e));
    }
  }

  String _metaLine() {
    return [
      if (shot.framing?.isNotEmpty == true) shot.framing,
      if (shot.lens?.isNotEmpty == true) shot.lens,
      if (shot.movement?.isNotEmpty == true) shot.movement,
    ].whereType<String>().join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final path = shot.referenceImagePath;
    final hasImage = path != null && File(path).existsSync();
    final meta = _metaLine();
    final showSceneStrip =
        gridLayout && sceneStart && !sceneHeaderAbove;
    final sceneLocation = locationFromCanonical(scene.locationCanonical);
    final showSceneBadge = gridLayout || linearLayout || hasImage;

    final imageArea = AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: sceneColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasImage
                ? sceneColor.withValues(alpha: 0.35)
                : palette.divider,
            width: sceneStart && gridLayout ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.file(File(path), fit: BoxFit.cover)
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 32, color: palette.textTertiary),
                    const SizedBox(height: 4),
                    Text(
                      'Sin referencia',
                      style: AppTypography.caption(palette),
                    ),
                  ],
                ),
              ),
            if (showSceneBadge)
              Positioned(
                left: 8,
                top: 8,
                child: _FrameBadge(
                  label: 'Esc ${scene.number} · ${shot.number}',
                  color: sceneColor,
                ),
              ),
            if (hasImage)
              StreamBuilder<List<ShotReference>>(
                stream: db.watchReferencesForShot(shot.id),
                builder: (context, refSnap) {
                  final count = refSnap.data?.length ?? 0;
                  if (count <= 1) return const SizedBox.shrink();
                  return Positioned(
                    right: 8,
                    top: 8,
                    child: _FrameBadge(
                      label: '+${count - 1}',
                      color: palette.accent,
                    ),
                  );
                },
              ),
            if (sceneStart && gridLayout)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  color: sceneColor,
                ),
              ),
          ],
        ),
      ),
    );

    final interactiveImage = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (hasImage) {
            _openPrimaryViewer(context, ref);
          } else {
            _openFrameSheet(context, ref);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: imageArea,
      ),
    );

    if (listLayout) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 160, child: interactiveImage),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: InkWell(
                onTap: () => _openFrameSheet(context, ref),
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plano ${shot.number}',
                      style: AppTypography.titleMedium(palette),
                    ),
                    if (meta.isNotEmpty)
                      Text(meta, style: AppTypography.bodyMedium(palette)),
                    if (shot.action?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        shot.action!,
                        style: AppTypography.caption(palette),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (linearLayout) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            interactiveImage,
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: () => _openFrameSheet(context, ref),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Plano ${shot.number}',
                    style: AppTypography.label(palette),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      style: AppTypography.caption(palette),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (shot.action?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      shot.action!,
                      style: AppTypography.caption(palette).copyWith(
                        color: palette.textSecondary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showSceneStrip)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: sceneColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: sceneColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Esc ${scene.number} · $sceneLocation',
                style: AppTypography.caption(palette).copyWith(
                  color: sceneColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          interactiveImage,
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: () => _openFrameSheet(context, ref),
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Plano ${shot.number}',
                  style: AppTypography.label(palette),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: AppTypography.caption(palette),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _FrameBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: AppTypography.caption(context.palette).copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _FrameDetailSheet extends ConsumerWidget {
  final Scene scene;
  final Shot shot;
  final Color sceneColor;
  final void Function(String source) onImport;
  final Future<void> Function() onExport;

  const _FrameDetailSheet({
    required this.scene,
    required this.shot,
    required this.sceneColor,
    required this.onImport,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final location = locationFromCanonical(scene.locationCanonical);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Text(
              'Esc ${scene.number} · Plano ${shot.number}',
              style: AppTypography.titleLarge(palette),
            ),
            Text(
              location,
              style: AppTypography.bodyMedium(palette),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ShotReferenceGallery(
                shotId: shot.id,
                sceneId: scene.id,
                scene: scene,
                shot: shot,
                onImport: onImport,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Añadir referencia', style: AppTypography.label(palette)),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Captura Artemis',
              icon: Icons.photo_camera_outlined,
              variant: AppButtonVariant.secondary,
              onTap: () => onImport(ShotReferenceSource.artemisCapture),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Imagen manual',
              icon: Icons.add_photo_alternate_outlined,
              variant: AppButtonVariant.ghost,
              onTap: () => onImport(ShotReferenceSource.manual),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Render Unreal',
              icon: Icons.view_in_ar_outlined,
              variant: AppButtonVariant.ghost,
              onTap: () => onImport(ShotReferenceSource.unrealRender),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Exportar plano',
              icon: Icons.ios_share_outlined,
              variant: AppButtonVariant.secondary,
              onTap: onExport,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
