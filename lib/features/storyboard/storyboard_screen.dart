import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/realtime_hub.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/clipboard_image_reader.dart';
import '../../core/utils/photo_source_picker.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../core/utils/scene_format.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/sized_file_image.dart';
import '../../core/widgets/stable_stream_builder.dart';
import '../../core/widgets/shot_reference_gallery.dart';
import '../camera_plan/camera_plan_grouping.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import '../look_bible/look_bible_model.dart';
import '../../shared/pdf_export/storyboard_pdf.dart';
import '../shoot_documents/shoot_document_import_actions.dart';
import '../artemis_import/artemis_import_screen.dart';
import '../export_center/export_center_screen.dart';
import '../export_center/export_selection.dart';
import '../technical_script/technical_script_screen.dart';
import 'storyboard_export_options_sheet.dart';
import 'storyboard_viewer.dart';
import 'storyboard_prefs.dart';
import '../../core/settings/app_prefs.dart';
import '../settings/settings_launcher.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/history/edit_history.dart';
import '../../shared/history/shot_edits.dart';
import '../../shared/rich_text/script_markup.dart';
import '../../shared/shot_images/shot_image_menu.dart';
import '../camera_plan/plan_data.dart';
import '../camera_plan/plan_target.dart';
import '../camera_plan/plan_view_picker.dart';
import '../camera_plan/plan_workspace_screen.dart';
import '../camera_plan/shot_plan_preview.dart';
import '../shots/shot_params_editor.dart';

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
  late _StoryboardLayout _layout = _StoryboardLayout.values.firstWhere(
    (l) =>
        l.name ==
        _prefs.get(StoryboardPrefs.layout, projectId: widget.projectId),
    orElse: () => _StoryboardLayout.linear,
  );
  late _StoryboardFilter _filter = _StoryboardFilter.values.firstWhere(
    (f) =>
        f.name ==
        _prefs.get(StoryboardPrefs.filter, projectId: widget.projectId),
    orElse: () => _StoryboardFilter.all,
  );

  AppPrefs get _prefs => AppPrefs.instance;

  /// Planos elegidos para exportar. Nulo: no se está seleccionando.
  final _selection = ValueNotifier<Set<int>?>(null);

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _openExport({Set<int>? only}) => ExportCenterScreen.open(
    context,
    projectId: widget.projectId,
    document: ExportDocument.storyboard,
    shotIds: only,
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Storyboard', style: AppTypography.titleMedium(palette)),
        actions: [
          ScreenSettingsButton(
            sectionId: SettingsSectionIds.storyboard,
            projectId: widget.projectId,
          ),
          GoodNotesPdfActions(
            projectId: widget.projectId,
            moduleType: GoodNotesModuleType.storyboard,
            filenameBase: 'storyboard',
            buildPdfBytes: () async {
              final db = ref.read(databaseProvider);
              final project = await db.getProject(widget.projectId);
              if (project == null) return Uint8List(0);
              if (!context.mounted) return Uint8List(0);
              final choice = await showStoryboardGroupExportOptionsSheet(
                context,
              );
              if (choice == null) return Uint8List(0);
              final scenes = await db
                  .watchScenesForProject(widget.projectId)
                  .first;
              final shotsByScene = <int, List<Shot>>{};
              for (final scene in scenes) {
                shotsByScene[scene.id] = await db
                    .watchShotsForScene(scene.id)
                    .first;
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
            tooltip: 'Importar de Artemis',
            icon: Icon(Icons.add_a_photo_outlined, color: palette.accent),
            onPressed: () =>
                importFromArtemis(context, projectId: widget.projectId),
          ),
          ValueListenableBuilder<Set<int>?>(
            valueListenable: _selection,
            builder: (context, selected, _) => IconButton(
              tooltip: selected == null
                  ? 'Elegir planos'
                  : 'Dejar de elegir planos',
              icon: Icon(
                selected == null ? Icons.checklist : Icons.close,
                color: palette.accent,
              ),
              onPressed: () =>
                  _selection.value = selected == null ? <int>{} : null,
            ),
          ),
          IconButton(
            tooltip: 'Exportar',
            icon: Icon(Icons.ios_share, color: palette.accent),
            onPressed: _openExport,
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
      body: PlanDataBuilder(
        projectId: widget.projectId,
        builder: (context, plans) {
          final scenes = scenesInScriptOrder(plans.scenes);
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

          final colors = ProjectColorScheme.resolve(
            sites: plans.sites,
            sets: plans.sets,
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
                child: PlanDataScope(
                  data: plans,
                  child: _SelectionScope(
                    notifier: _selection,
                    child: _StoryboardBody(
                      scenes: scenes,
                      colors: colors,
                      layout: _layout,
                      filter: _filter,
                    ),
                  ),
                ),
              ),
              _SelectionBar(
                selection: _selection,
                onExport: (only) => _openExport(only: only),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SelectionScope extends InheritedNotifier<ValueNotifier<Set<int>?>> {
  const _SelectionScope({required super.notifier, required super.child});

  static ValueNotifier<Set<int>?> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SelectionScope>()!.notifier!;
}

/// Barra inferior mientras se eligen planos.
class _SelectionBar extends StatelessWidget {
  final ValueNotifier<Set<int>?> selection;
  final void Function(Set<int> only) onExport;

  const _SelectionBar({required this.selection, required this.onExport});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ValueListenableBuilder<Set<int>?>(
      valueListenable: selection,
      builder: (context, selected, _) {
        if (selected == null) return const SizedBox.shrink();
        final count = selected.length;
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: palette.surfaceElevated,
            border: Border(top: BorderSide(color: palette.divider)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    count == 0
                        ? 'Toca los planos que quieres exportar'
                        : '$count plano${count == 1 ? '' : 's'} elegido'
                              '${count == 1 ? '' : 's'}',
                    style: AppTypography.bodyMedium(palette),
                  ),
                ),
                if (count > 0)
                  TextButton(
                    onPressed: () => selection.value = <int>{},
                    child: const Text('Vaciar'),
                  ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: count == 0 ? null : () => onExport(selected),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Exportar selección'),
                ),
              ],
            ),
          ),
        );
      },
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
    // En el iPhone: sin la explicación y con el modo solo en iconos.
    final compact = AppLayout.isCompact(context);
    final modes = SegmentedButton<_StoryboardLayout>(
      segments: [
        ButtonSegment(
          value: _StoryboardLayout.linear,
          icon: const Icon(Icons.view_timeline_outlined, size: 18),
          label: compact ? null : const Text('Lineal'),
          tooltip: 'Lineal',
        ),
        ButtonSegment(
          value: _StoryboardLayout.grid,
          icon: const Icon(Icons.grid_view_outlined, size: 18),
          label: compact ? null : const Text('Rejilla'),
          tooltip: 'Rejilla',
        ),
        ButtonSegment(
          value: _StoryboardLayout.list,
          icon: const Icon(Icons.view_list_outlined, size: 18),
          label: compact ? null : const Text('Lista'),
          tooltip: 'Lista',
        ),
      ],
      selected: {layout},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onLayoutChanged(s.first),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Text(
            'Modo storyboard con datos del guion técnico. '
            'Edita un plano aquí o en la tabla: los cambios llegan a todas '
            'las pantallas al instante.',
            style: AppTypography.bodyMedium(palette),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: [
            modes,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: DropdownButtonFormField<_StoryboardFilter>(
                initialValue: filter,
                isExpanded: true,
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

/// Si un plano entra en el filtro. Con «todos» ni se mira el disco.
bool _passesFilter(Shot shot, _StoryboardFilter filter) {
  if (filter == _StoryboardFilter.all) return true;
  final path = storyboardImageOf(shot);
  final hasImage = path != null && FileExistsCache.exists(path);
  return filter == _StoryboardFilter.withImage ? hasImage : !hasImage;
}

class _StoryboardBody extends ConsumerWidget {
  final List<Scene> scenes;
  final ProjectColorScheme colors;
  final _StoryboardLayout layout;
  final _StoryboardFilter filter;

  const _StoryboardBody({
    required this.scenes,
    required this.colors,
    required this.layout,
    required this.filter,
  });

  Widget _sceneHeader(
    BuildContext context,
    Scene scene,
    Color sceneColor,
    int shotCount,
  ) {
    final palette = context.palette;
    final location = locationFromCanonical(scene.locationCanonical);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
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
              'Esc ${scene.label} · $location',
              style: AppTypography.titleMedium(
                palette,
              ).copyWith(color: sceneColor),
            ),
          ),
          Text(
            '$shotCount plano${shotCount == 1 ? '' : 's'}',
            style: AppTypography.caption(palette),
          ),
        ],
      ),
    );
  }

  Widget _newShotButton(
    BuildContext context,
    WidgetRef ref,
    Scene scene,
    List<Shot> allShots,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
    child: Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () async {
          final db = ref.read(databaseProvider);
          final id = await createStoryboardShot(db, scene, allShots);
          final shot = await db.getShotById(id);
          if (shot == null || !context.mounted) return;
          // Se abre ya en el visor: título, y elegir o dibujar su imagen.
          await showStoryboardViewer(
            context,
            projectId: scene.projectId,
            shot: shot,
          );
        },
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Plano nuevo'),
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (layout == _StoryboardLayout.linear) {
      return _StoryboardLinearStrip(
        scenes: scenes,
        colors: colors,
        filter: filter,
      );
    }

    if (layout == _StoryboardLayout.grid) {
      return _StoryboardContinuousGrid(
        scenes: scenes,
        colors: colors,
        filter: filter,
      );
    }

    final plans = PlanDataScope.of(context);

    // Cada plano es un elemento de la lista: los que no se ven ni se crean.
    final items = <WidgetBuilder>[];
    for (final scene in scenes) {
      final sceneColor = colors.sceneColor(scene);
      final allShots = plans.shotsByScene[scene.id] ?? const <Shot>[];
      final shots = [
        for (final shot in allShots)
          if (_passesFilter(shot, filter)) shot,
      ];
      // Una escena aún sin planos se queda a la vista: desde aquí se le pone
      // el primero.
      if (shots.isEmpty && allShots.isNotEmpty) continue;
      items.add(
        (context) => _sceneHeader(context, scene, sceneColor, shots.length),
      );
      for (final shot in shots) {
        items.add(
          (context) => Padding(
            key: ValueKey(shot.id),
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _StoryboardFrame(
              scene: scene,
              shot: shot,
              sceneColor: sceneColor,
              listLayout: true,
            ),
          ),
        );
      }
      items.add((context) => _newShotButton(context, ref, scene, allShots));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: items.length,
      itemBuilder: (context, i) => items[i](context),
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
class _StoryboardContinuousGrid extends StatelessWidget {
  final List<Scene> scenes;
  final ProjectColorScheme colors;
  final _StoryboardFilter filter;

  const _StoryboardContinuousGrid({
    required this.scenes,
    required this.colors,
    required this.filter,
  });

  int _crossAxisCount(double width) {
    if (width >= AppLayout.wideBreakpoint) return 3;
    if (width >= 640) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final plans = PlanDataScope.of(context);
    final entries = <_GridShotEntry>[];

    for (final scene in scenes) {
      final shots = [
        for (final shot in plans.shotsByScene[scene.id] ?? const <Shot>[])
          if (_passesFilter(shot, filter)) shot,
      ];

      for (var i = 0; i < shots.length; i++) {
        entries.add(
          _GridShotEntry(scene: scene, shot: shots[i], isFirstInScene: i == 0),
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
                              left:
                                  col > 0 &&
                                      row[col].isFirstInScene &&
                                      !showRowSceneHeader
                                  ? AppSpacing.sm
                                  : 0,
                              right: col < row.length - 1 ? AppSpacing.md : 0,
                            ),
                            child: _StoryboardFrame(
                              scene: row[col].scene,
                              shot: row[col].shot,
                              sceneColor: colors.sceneColor(row[col].scene),
                              gridLayout: true,
                              sceneStart: row[col].isFirstInScene,
                              sceneHeaderAbove:
                                  showRowSceneHeader && row[col].isFirstInScene,
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
  }
}

class _SceneGridBreakHeader extends StatelessWidget {
  final Scene scene;
  final Color color;

  const _SceneGridBreakHeader({required this.scene, required this.color});

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
        border: Border(left: BorderSide(color: color, width: 4)),
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
              'Esc ${scene.label} · $location',
              style: AppTypography.label(
                palette,
              ).copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tira horizontal: todos los planos en orden de guion, con marcas de escena.
class _StoryboardLinearStrip extends StatelessWidget {
  final List<Scene> scenes;
  final ProjectColorScheme colors;
  final _StoryboardFilter filter;

  const _StoryboardLinearStrip({
    required this.scenes,
    required this.colors,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final plans = PlanDataScope.of(context);
    final children = <Widget>[];

    for (final scene in scenes) {
      final shots = [
        for (final shot in plans.shotsByScene[scene.id] ?? const <Shot>[])
          if (_passesFilter(shot, filter)) shot,
      ];
      if (shots.isEmpty) continue;

      children.add(
        _SceneBreakMarker(scene: scene, color: colors.sceneColor(scene)),
      );

      for (final shot in shots) {
        children.add(
          SizedBox(
            width: 280,
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
  }
}

class _SceneBreakMarker extends StatelessWidget {
  final Scene scene;
  final Color color;

  const _SceneBreakMarker({required this.scene, required this.color});

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
                  '${scene.label}',
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
      // En el iPhone y el iPad: cámara, fototeca o archivos.
      if (PhotoSourcePicker.isMobile) {
        final paths = await PhotoSourcePicker.pickImages(
          context,
          allowMultiple: false,
          title: 'Referencia · Plano ${shot.number}',
        );
        if (paths.isEmpty) return;
        await importShotReferenceImage(
          db: db,
          shot: shot,
          sourcePath: paths.first,
          source: source,
        );
        return;
      }
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

  Future<void> _exportFrame(BuildContext context, WidgetRef ref) =>
      ExportCenterScreen.open(
        context,
        projectId: scene.projectId,
        document: ExportDocument.storyboard,
        shotIds: {shot.id},
      );

  /// «Plano 2 · PP de ALI»: el número y el título (su encuadre).
  String _title() {
    final framing = scriptMarkupToPlain(shot.framing).trim();
    return framing.isEmpty
        ? 'Plano ${shot.number}'
        : 'Plano ${shot.number} · $framing';
  }

  String _metaLine() {
    return [
      if (shot.lens?.isNotEmpty == true) shot.lens,
      if (shot.movement?.isNotEmpty == true) shot.movement,
    ].whereType<String>().join(' · ');
  }

  /// Datos del plano en píldoras, para leerlos de un vistazo.
  Widget _metaChips(BuildContext context) {
    final palette = context.palette;
    final items = [
      shot.lens,
      shot.movement,
      shot.angle,
      if (shot.fStop?.isNotEmpty == true) 'T${shot.fStop}',
    ].where((v) => v != null && v.isNotEmpty).cast<String>();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: palette.surfaceOverlay,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item,
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textPrimary, fontSize: 11),
            ),
          ),
      ],
    );
  }

  /// Cambios en la imagen o los datos: si otro equipo edita el plano, se
  /// espera a que termine.
  bool _free(BuildContext context, WidgetRef ref) {
    final holder = ref.read(liveEditingProvider).holderOf(shot.uid);
    if (holder == null) return true;
    AppSnackBar.show(
      context,
      'Lo está editando ${holder.device}. Podrás cambiarlo en cuanto termine.',
    );
    return false;
  }

  Future<void> _frameAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String? image,
    PlanProjectData plans,
  ) async {
    final db = ref.read(databaseProvider);
    switch (action) {
      case 'image':
        if (!_free(context, ref)) return;
        await showShotImageMenu(
          context,
          shot,
          target: ShotImageTarget.storyboard,
        );
      case 'copy':
        final done =
            image != null && await ClipboardImageReader.copyImageFile(image);
        if (!context.mounted) return;
        AppSnackBar.show(
          context,
          done
              ? 'Imagen copiada. Pégala en otra casilla.'
              : 'No se ha podido copiar la imagen.',
        );
      case 'paste':
        if (!_free(context, ref)) return;
        final problem = await recordShotImages(
          db,
          ref.read(editHistoryProvider),
          shot.id,
          () => pasteShotImageFromClipboard(
            db,
            shot,
            target: ShotImageTarget.storyboard,
          ),
        );
        if (problem != null && context.mounted) {
          AppSnackBar.showError(context, problem);
        }
      case 'remove':
        if (image == null || !_free(context, ref)) return;
        await recordShotImages(
          db,
          ref.read(editHistoryProvider),
          shot.id,
          () async => removeVisibleShotImage(
            db: db,
            shot: await db.getShotById(shot.id) ?? shot,
            path: image,
          ),
          label: 'quitar imagen del plano',
        );
      case 'params':
        if (!_free(context, ref)) return;
        await showShotParamsSheet(context, shot);
      case 'section':
        await showPlanViewPicker(context, data: plans, shot: shot);
      case 'camera3d':
        // ED.5: el 3D del plano mirando por su cámara; «Para el storyboard»
        // guarda esa vista y «Dibujar» la pone debajo.
        await PlanWorkspaceScreen.openStage(
          context,
          projectId: scene.projectId,
          target: PlanTarget.shot(shot.id, plans.shotLabel(shot)),
          lookThrough: true,
        );
      case 'export':
        await _exportFrame(context, ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final path = storyboardImageOf(shot);
    final hasImage = path != null && FileExistsCache.exists(path);
    final meta = _metaLine();
    final plans = PlanDataScope.of(context);
    final selection = _SelectionScope.of(context);
    final selecting = selection.value != null;
    final selected = selection.value?.contains(shot.id) ?? false;
    void toggle() {
      final next = {...?selection.value};
      if (!next.remove(shot.id)) next.add(shot.id);
      selection.value = next;
    }

    final showSceneStrip = gridLayout && sceneStart && !sceneHeaderAbove;
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
              SizedFileImage(path, fit: BoxFit.cover)
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 32,
                      color: palette.textTertiary,
                    ),
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
                  label: 'Esc ${scene.label} · ${shot.number}',
                  color: sceneColor,
                ),
              ),
            if (selecting)
              Positioned(
                right: 8,
                bottom: 8,
                child: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? palette.accent : Colors.white,
                  size: 24,
                ),
              )
            else
              Positioned(
                right: 2,
                bottom: 2,
                child: _FrameMenu(
                  hasImage: hasImage,
                  onSelected: (action) => _frameAction(
                    context,
                    ref,
                    action,
                    hasImage ? path : null,
                    plans,
                  ),
                ),
              ),
            if (hasImage)
              StableStreamBuilder<List<ShotReference>>(
                streamKey: (db, shot.id),
                stream: () => db.watchReferencesForShot(shot.id),
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
                child: Container(width: 4, color: sceneColor),
              ),
          ],
        ),
      ),
    );

    final interactiveImage = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: selecting
            ? toggle
            : () => showStoryboardViewer(
                context,
                projectId: scene.projectId,
                shot: shot,
              ),
        borderRadius: BorderRadius.circular(8),
        child: ShotImagePasteTarget(
          shot: shot,
          target: ShotImageTarget.storyboard,
          child: imageArea,
        ),
      ),
    );

    final planPreview = ShotPlanPreview(
      shot: shot,
      label: 'Esc ${scene.label} · Plano ${shot.number}',
    );

    Widget details({int actionLines = 3}) => InkWell(
      onTap: selecting ? toggle : () => _openFrameSheet(context, ref),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _title(),
            style: AppTypography.titleMedium(palette),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            _metaChips(context),
          ],
          if (shot.action?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              scriptMarkupToPlain(shot.action),
              style: AppTypography.bodyMedium(palette),
              maxLines: actionLines,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    Widget outlined(Widget card) => selected
        ? DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.all(color: palette.accent, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: card,
          )
        : card;

    if (listLayout) {
      return outlined(
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 640;
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: interactiveImage),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: planPreview,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    details(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 240, child: interactiveImage),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(width: 180, height: 135, child: planPreview),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: details(actionLines: 4)),
                ],
              );
            },
          ),
        ),
      );
    }

    if (linearLayout) {
      return outlined(
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                interactiveImage,
                const SizedBox(height: AppSpacing.sm),
                SizedBox(height: 120, child: planPreview),
                const SizedBox(height: AppSpacing.sm),
                details(),
              ],
            ),
          ),
        ),
      );
    }

    return outlined(
      AppCard(
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
                  'Esc ${scene.label} · $sceneLocation',
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
              onTap: selecting ? toggle : () => _openFrameSheet(context, ref),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _title(),
                    style: AppTypography.label(palette),
                    maxLines: 2,
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
      ),
    );
  }
}

/// Acciones de un plano sobre su imagen.
class _FrameMenu extends StatelessWidget {
  final bool hasImage;
  final ValueChanged<String> onSelected;

  const _FrameMenu({required this.hasImage, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    PopupMenuItem<String> item(String value, IconData icon, String label) =>
        PopupMenuItem(
          value: value,
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(label),
            ],
          ),
        );

    return PopupMenuButton<String>(
      tooltip: 'Acciones del plano',
      onSelected: onSelected,
      itemBuilder: (_) => [
        item('params', Icons.tune, 'Datos del plano'),
        item('image', Icons.image_outlined, 'Elegir imagen…'),
        if (hasImage) item('copy', Icons.content_copy, 'Copiar imagen'),
        item('paste', Icons.content_paste, 'Pegar imagen'),
        if (hasImage) item('remove', Icons.delete_outline, 'Quitar imagen'),
        item('section', Icons.crop_free, 'Sección de la planta'),
        item('camera3d', Icons.videocam_outlined, 'Ver su cámara en 3D'),
        item('export', Icons.ios_share_outlined, 'Exportar plano'),
      ],
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_horiz, size: 18, color: Colors.white),
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
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Text(
              'Esc ${scene.label} · Plano ${shot.number}',
              style: AppTypography.titleLarge(palette),
            ),
            Text(location, style: AppTypography.bodyMedium(palette)),
            const SizedBox(height: AppSpacing.lg),
            ShotParamsEditor(shotId: shot.id),
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
              label: shot.storyboardImagePath == null
                  ? 'Imagen propia para el storyboard'
                  : 'Cambiar la imagen del storyboard',
              icon: Icons.photo_library_outlined,
              variant: AppButtonVariant.secondary,
              onTap: () async {
                // El menú se abre sobre la pantalla, no sobre esta hoja que
                // se cierra.
                final navigator = Navigator.of(context);
                final screen = navigator.context;
                final messenger = ScaffoldMessenger.maybeOf(screen);
                final live = ref.read(liveEditingProvider);
                navigator.pop();
                // Si otro equipo edita este plano, aquí no se cambia su
                // imagen hasta que termine.
                final holder = live.holderOf(shot.uid);
                if (holder != null) {
                  messenger?.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Lo está editando ${holder.device}. Podrás cambiarlo '
                        'en cuanto termine.',
                      ),
                    ),
                  );
                  return;
                }
                live.focusShot(shot.uid);
                await showShotImageMenu(
                  screen,
                  shot,
                  target: ShotImageTarget.storyboard,
                );
                live.blurShot(shot.uid);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Añadir al documento de rodaje',
              icon: Icons.description_outlined,
              variant: AppButtonVariant.secondary,
              onTap: () async {
                final db = ref.read(databaseProvider);
                final path = storyboardImageOf(shot);
                if (path != null) {
                  await ShootDocumentImportActions.addImageBlock(
                    context: context,
                    db: db,
                    projectId: scene.projectId,
                    imagePath: path,
                    shotId: shot.id,
                    sceneId: scene.id,
                  );
                } else {
                  await ShootDocumentImportActions.addShotBlock(
                    context: context,
                    db: db,
                    projectId: scene.projectId,
                    shot: shot,
                    scene: scene,
                  );
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
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
