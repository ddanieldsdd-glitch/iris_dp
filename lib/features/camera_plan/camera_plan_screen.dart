import 'dart:typed_data';

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
import '../../core/widgets/app_card.dart';
import '../../core/widgets/scene_meta_display.dart';
import '../goodnotes/goodnotes_pdf_actions.dart';
import '../look_bible/look_bible_model.dart';
import '../pdf_export/camera_plan_pdf.dart';
import 'camera_plan_editor.dart';
import 'camera_plan_grouping.dart';
import 'camera_plan_scene_badge.dart';
import 'floor_plan_json.dart';
import 'floor_plan_map_tile.dart';
import 'floor_plan_repository.dart';
import 'floor_plan_scope.dart';

enum _ContentIndexMode { location, script }

/// Registro de [GlobalKey] estables para scroll al índice lateral.
class _ScrollAnchorRegistry {
  final _locations = <String, GlobalKey>{};
  final _sets = <int, GlobalKey>{};
  final _scenes = <int, GlobalKey>{};

  GlobalKey location(String key) => _locations.putIfAbsent(key, GlobalKey.new);

  GlobalKey set(int id) => _sets.putIfAbsent(id, GlobalKey.new);

  GlobalKey scene(int id) => _scenes.putIfAbsent(id, GlobalKey.new);
}

class CameraPlanScreen extends ConsumerWidget {
  final int projectId;

  const CameraPlanScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text('Plantas de cámara', style: AppTypography.titleLarge(palette)),
        actions: [
          GoodNotesPdfActions(
            projectId: projectId,
            moduleType: GoodNotesModuleType.plantaCamara,
            filenameBase: 'planta_camara',
            buildPdfBytes: () async {
              final db = ref.read(databaseProvider);
              final project = await db.getProject(projectId);
              if (project == null) return Uint8List(0);
              final scenes = await db.watchScenesForProject(projectId).first;
              return CameraPlanPdfExporter.buildBytes(
                project: project,
                scenes: scenes,
                db: db,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Scene>>(
        stream: db.watchScenesForProject(projectId),
        builder: (context, sceneSnap) {
          if (!sceneSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final scenes = sceneSnap.data!;
          if (scenes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grid_on_outlined,
                        size: 48, color: palette.textTertiary),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Sin escenas todavía.',
                      style: AppTypography.titleMedium(palette),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Importa el guion o añade escenas desde el guion técnico.',
                      style: AppTypography.bodyMedium(palette),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return StreamBuilder<List<LocationSite>>(
            stream: db.watchSitesForProject(projectId),
            builder: (context, siteSnap) {
              return StreamBuilder<List<LocationBasePlan>>(
                stream: db.watchLocationsForProject(projectId),
                builder: (context, locSnap) {
                  final colors = ProjectColorScheme.resolve(
                    sites: siteSnap.data ?? [],
                    sets: locSnap.data ?? [],
                    scenes: scenes,
                  );
                  final hierarchy = buildCameraPlanHierarchy(
                    scenes: scenes,
                    sites: siteSnap.data ?? [],
                    allSets: locSnap.data ?? [],
                    colors: colors,
                  );

                  return _CameraPlanBody(
                    projectId: projectId,
                    hierarchy: hierarchy,
                    colors: colors,
                    scenes: scenes,
                    sites: siteSnap.data ?? [],
                    sets: locSnap.data ?? [],
                    palette: palette,
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

class _CameraPlanBody extends StatefulWidget {
  final int projectId;
  final List<CameraPlanHierarchy> hierarchy;
  final ProjectColorScheme colors;
  final List<Scene> scenes;
  final List<LocationSite> sites;
  final List<LocationBasePlan> sets;
  final AppPalette palette;

  const _CameraPlanBody({
    required this.projectId,
    required this.hierarchy,
    required this.colors,
    required this.scenes,
    required this.sites,
    required this.sets,
    required this.palette,
  });

  @override
  State<_CameraPlanBody> createState() => _CameraPlanBodyState();
}

class _CameraPlanBodyState extends State<_CameraPlanBody> {
  final _scrollController = ScrollController();
  final _anchors = _ScrollAnchorRegistry();
  _ContentIndexMode _indexMode = _ContentIndexMode.location;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToKey(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  void _scrollToLocation(CameraPlanHierarchy block) {
    final key = cameraPlanLocationKey(
      siteId: block.siteId,
      siteName: block.siteName,
    );
    _scrollToKey(_anchors.location(key));
  }

  void _scrollToSet(int setId) => _scrollToKey(_anchors.set(setId));

  void _scrollToScene(int sceneId) => _scrollToKey(_anchors.scene(sceneId));

  void _onIndexModeChanged(_ContentIndexMode mode) {
    if (mode == _indexMode) return;
    setState(() => _indexMode = mode);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Widget _buildMainContent(bool wide) {
    if (_indexMode == _ContentIndexMode.location) {
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: widget.hierarchy.length,
        itemBuilder: (context, i) {
          final block = widget.hierarchy[i];
          final locationKey = cameraPlanLocationKey(
            siteId: block.siteId,
            siteName: block.siteName,
          );
          return _LocationHierarchySection(
            hierarchy: block,
            colors: widget.colors,
            projectId: widget.projectId,
            wide: wide,
            locationAnchorKey: _anchors.location(locationKey),
            setAnchorKey: (setId) => _anchors.set(setId),
            sceneAnchorKey: (sceneId) => _anchors.scene(sceneId),
          );
        },
      );
    }

    final scriptScenes = scenesInScriptOrder(widget.scenes);
    final sitesById = {for (final s in widget.sites) s.id: s};
    final setsById = {for (final s in widget.sets) s.id: s};

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: scriptScenes.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
      itemBuilder: (context, i) {
        final scene = scriptScenes[i];
        return _ScriptOrderSceneSection(
          scene: scene,
          sitesById: sitesById,
          setsById: setsById,
          colors: widget.colors,
          projectId: widget.projectId,
          wide: wide,
          anchorKey: _anchors.scene(scene.id),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppLayout.wideBreakpoint;
        final content = _buildMainContent(wide);

        if (!wide) {
          return Stack(
            children: [
              content,
              Positioned(
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: FloatingActionButton.small(
                  heroTag: 'camera_plan_index',
                  onPressed: () => _showMobileIndex(context),
                  tooltip: 'Índice de contenido',
                  child: const Icon(Icons.list_alt),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: AppLayout.sidebarWidth,
              child: _PlanSummaryPanel(
                hierarchy: widget.hierarchy,
                colors: widget.colors,
                palette: widget.palette,
                scenes: widget.scenes,
                sites: widget.sites,
                sets: widget.sets,
                indexMode: _indexMode,
                onIndexModeChanged: _onIndexModeChanged,
                onLocationTap: _scrollToLocation,
                onSetTap: _scrollToSet,
                onSceneTap: _scrollToScene,
              ),
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  void _showMobileIndex(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.palette.surfaceElevated,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => StatefulBuilder(
          builder: (context, setSheetState) => _PlanSummaryPanel(
            hierarchy: widget.hierarchy,
            colors: widget.colors,
            palette: widget.palette,
            scenes: widget.scenes,
            sites: widget.sites,
            sets: widget.sets,
            indexMode: _indexMode,
            onIndexModeChanged: (mode) {
              _onIndexModeChanged(mode);
              setSheetState(() {});
            },
            onLocationTap: (block) {
              Navigator.pop(ctx);
              _scrollToLocation(block);
            },
            onSetTap: (setId) {
              Navigator.pop(ctx);
              _scrollToSet(setId);
            },
            onSceneTap: (sceneId) {
              Navigator.pop(ctx);
              _scrollToScene(sceneId);
            },
            scrollController: scrollCtrl,
            inSheet: true,
          ),
        ),
      ),
    );
  }
}

class _PlanSummaryPanel extends StatelessWidget {
  final List<CameraPlanHierarchy> hierarchy;
  final ProjectColorScheme colors;
  final AppPalette palette;
  final List<Scene> scenes;
  final List<LocationSite> sites;
  final List<LocationBasePlan> sets;
  final _ContentIndexMode indexMode;
  final ValueChanged<_ContentIndexMode> onIndexModeChanged;
  final void Function(CameraPlanHierarchy) onLocationTap;
  final void Function(int setId) onSetTap;
  final void Function(int sceneId) onSceneTap;
  final ScrollController? scrollController;
  final bool inSheet;

  const _PlanSummaryPanel({
    required this.hierarchy,
    required this.colors,
    required this.palette,
    required this.scenes,
    required this.sites,
    required this.sets,
    required this.indexMode,
    required this.onIndexModeChanged,
    required this.onLocationTap,
    required this.onSetTap,
    required this.onSceneTap,
    this.scrollController,
    this.inSheet = false,
  });

  @override
  Widget build(BuildContext context) {
    final locationCount = hierarchy.length;
    final sceneCount =
        hierarchy.fold<int>(0, (sum, h) => sum + h.sceneCount);
    final setCount =
        hierarchy.fold<int>(0, (sum, h) => sum + h.sets.length);
    final sitesById = {for (final s in sites) s.id: s};
    final setsById = {for (final s in sets) s.id: s};
    final scriptScenes = scenesInScriptOrder(scenes);

    final indexContent = indexMode == _ContentIndexMode.location
        ? ListView.separated(
            controller: scrollController,
            itemCount: hierarchy.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) {
              final block = hierarchy[i];
              final base = colors.siteColor(
                block.siteId,
                orphanSiteKey: block.siteId == null
                    ? block.siteName.toLowerCase()
                    : null,
              );
              return _NavLocationBlock(
                hierarchy: block,
                locationBase: base,
                colors: colors,
                palette: palette,
                onLocationTap: () => onLocationTap(block),
                onSetTap: onSetTap,
                onSceneTap: onSceneTap,
              );
            },
          )
        : ListView.separated(
            controller: scrollController,
            itemCount: scriptScenes.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, i) {
              final scene = scriptScenes[i];
              final site = scene.locationSiteId != null
                  ? sitesById[scene.locationSiteId]
                  : null;
              final set = scene.locationId != null
                  ? setsById[scene.locationId]
                  : null;
              final siteName = site?.name ??
                  (scene.locationPureName.trim().isNotEmpty
                      ? scene.locationPureName.trim()
                      : 'Sin localización');
              final setName = set?.locationName ??
                  (scene.locationPureName.trim().isNotEmpty
                      ? scene.locationPureName.trim()
                      : 'Sin set');
              return _NavScriptSceneRow(
                scene: scene,
                color: colors.sceneColor(scene),
                palette: palette,
                subtitle: '$siteName · $setName',
                onTap: () => onSceneTap(scene.id),
              );
            },
          );

    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!inSheet) ...[
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jerarquía de planos', style: AppTypography.titleMedium(palette)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Maestro → Set → Plano',
                  style: AppTypography.caption(palette),
                ),
                const SizedBox(height: AppSpacing.md),
                _SummaryRow(
                  icon: Icons.location_city_outlined,
                  label: 'Localizaciones',
                  value: '$locationCount',
                  palette: palette,
                ),
                const SizedBox(height: AppSpacing.sm),
                _SummaryRow(
                  icon: Icons.layers_outlined,
                  label: 'Sets',
                  value: '$setCount',
                  palette: palette,
                ),
                const SizedBox(height: AppSpacing.sm),
                _SummaryRow(
                  icon: Icons.movie_outlined,
                  label: 'Escenas',
                  value: '$sceneCount',
                  palette: palette,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Contenido', style: AppTypography.label(palette)),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<_ContentIndexMode>(
                  segments: const [
                    ButtonSegment(
                      value: _ContentIndexMode.location,
                      label: Text('Localizaciones'),
                      icon: Icon(Icons.location_city_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: _ContentIndexMode.script,
                      label: Text('Guion'),
                      icon: Icon(Icons.menu_book_outlined, size: 16),
                    ),
                  ],
                  selected: {indexMode},
                  onSelectionChanged: (selected) =>
                      onIndexModeChanged(selected.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(child: indexContent),
              ],
            ),
          ),
        ),
      ],
    );

    if (inSheet) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: panel,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        0,
        AppSpacing.lg,
      ),
      child: panel,
    );
  }
}

class _NavLocationBlock extends StatelessWidget {
  final CameraPlanHierarchy hierarchy;
  final Color locationBase;
  final ProjectColorScheme colors;
  final AppPalette palette;
  final VoidCallback onLocationTap;
  final void Function(int setId) onSetTap;
  final void Function(int sceneId) onSceneTap;

  const _NavLocationBlock({
    required this.hierarchy,
    required this.locationBase,
    required this.colors,
    required this.palette,
    required this.onLocationTap,
    required this.onSetTap,
    required this.onSceneTap,
  });

  @override
  Widget build(BuildContext context) {
    final setCount = hierarchy.sets.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NavTapTarget(
          palette: palette,
          onTap: onLocationTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: locationBase,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hierarchy.siteName,
                      style: AppTypography.titleMedium(palette).copyWith(
                        color: locationBase,
                      ),
                    ),
                    Text(
                      '$setCount set${setCount == 1 ? '' : 's'} · '
                      '${hierarchy.sceneCount} esc.',
                      style: AppTypography.caption(palette),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: palette.textTertiary),
            ],
          ),
        ),
        if (hierarchy.sets.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          ...List.generate(hierarchy.sets.length, (i) {
            final setNode = hierarchy.sets[i];
            final setColor = colors.setColor(setNode.set);
            return _NavSetBlock(
              setNode: setNode,
              setColor: setColor,
              colors: colors,
              palette: palette,
              onSetTap: () => onSetTap(setNode.set.id),
              onSceneTap: onSceneTap,
            );
          }),
        ],
        if (hierarchy.unassignedScenes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg),
            child: Text(
              'Sin set',
              style: AppTypography.caption(palette).copyWith(
                color: locationBase.withValues(alpha: 0.75),
              ),
            ),
          ),
          ...hierarchy.unassignedScenes.map(
            (scene) => _NavSceneRow(
              scene: scene,
              color: colors.sceneColor(scene),
              palette: palette,
              onTap: () => onSceneTap(scene.id),
            ),
          ),
        ],
      ],
    );
  }
}

class _NavSetBlock extends StatelessWidget {
  final SetPlanNode setNode;
  final Color setColor;
  final ProjectColorScheme colors;
  final AppPalette palette;
  final VoidCallback onSetTap;
  final void Function(int sceneId) onSceneTap;

  const _NavSetBlock({
    required this.setNode,
    required this.setColor,
    required this.colors,
    required this.palette,
    required this.onSetTap,
    required this.onSceneTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.lg, bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NavTapTarget(
            palette: palette,
            onTap: onSetTap,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: setColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    setNode.set.locationName,
                    style: AppTypography.bodyMedium(palette).copyWith(
                      fontWeight: FontWeight.w600,
                      color: setColor,
                    ),
                  ),
                ),
                Text(
                  '${setNode.scenes.length}',
                  style: AppTypography.caption(palette),
                ),
                Icon(Icons.chevron_right, size: 16, color: palette.textTertiary),
              ],
            ),
          ),
          if (setNode.scenes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 2),
              child: Text(
                'Sin escenas',
                style: AppTypography.caption(palette),
              ),
            )
          else
            ...setNode.scenes.map(
              (scene) => _NavSceneRow(
                scene: scene,
                color: colors.sceneColor(scene),
                palette: palette,
                onTap: () => onSceneTap(scene.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavSceneRow extends StatelessWidget {
  final Scene scene;
  final Color color;
  final AppPalette palette;
  final VoidCallback onTap;

  const _NavSceneRow({
    required this.scene,
    required this.color,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = scene.name.isNotEmpty
        ? scene.name
        : formatSceneTitle(
            number: scene.number,
            intExt: scene.intExt,
            dayNight: scene.dayNight,
            location: locationFromCanonical(scene.locationCanonical),
          );

    return Padding(
      padding: const EdgeInsets.only(left: 18, top: 2),
      child: _NavTapTarget(
        palette: palette,
        onTap: onTap,
        child: Row(
          children: [
            SceneNumberBadge(
              sceneNumber: scene.number,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: AppTypography.caption(palette),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavScriptSceneRow extends StatelessWidget {
  final Scene scene;
  final Color color;
  final AppPalette palette;
  final String subtitle;
  final VoidCallback onTap;

  const _NavScriptSceneRow({
    required this.scene,
    required this.color,
    required this.palette,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = scene.name.isNotEmpty
        ? scene.name
        : formatSceneTitle(
            number: scene.number,
            intExt: scene.intExt,
            dayNight: scene.dayNight,
            location: locationFromCanonical(scene.locationCanonical),
          );

    return _NavTapTarget(
      palette: palette,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SceneNumberBadge(
            sceneNumber: scene.number,
            color: color,
            size: 26,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyMedium(palette),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: AppTypography.caption(palette),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: palette.textTertiary),
        ],
      ),
    );
  }
}

class _NavTapTarget extends StatelessWidget {
  final AppPalette palette;
  final VoidCallback onTap;
  final Widget child;

  const _NavTapTarget({
    required this.palette,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: palette.accent.withValues(alpha: 0.08),
        splashColor: palette.accent.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: 4,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final AppPalette palette;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.accent),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: AppTypography.bodyMedium(palette)),
        ),
        Text(value, style: AppTypography.titleMedium(palette)),
      ],
    );
  }
}

class _ScriptOrderSceneSection extends StatelessWidget {
  final Scene scene;
  final Map<int, LocationSite> sitesById;
  final Map<int, LocationBasePlan> setsById;
  final ProjectColorScheme colors;
  final int projectId;
  final bool wide;
  final GlobalKey anchorKey;

  const _ScriptOrderSceneSection({
    required this.scene,
    required this.sitesById,
    required this.setsById,
    required this.colors,
    required this.projectId,
    required this.wide,
    required this.anchorKey,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final site = scene.locationSiteId != null
        ? sitesById[scene.locationSiteId]
        : null;
    final set = scene.locationId != null ? setsById[scene.locationId] : null;
    final siteName = site?.name ??
        (scene.locationPureName.trim().isNotEmpty
            ? scene.locationPureName.trim()
            : 'Sin localización');
    final setName = set?.locationName ??
        (scene.locationPureName.trim().isNotEmpty
            ? scene.locationPureName.trim()
            : 'Sin set');
    final sceneColor = colors.sceneColor(scene);

    return Column(
      key: anchorKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: sceneColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '$siteName · $setName',
                style: AppTypography.caption(palette).copyWith(
                  color: sceneColor.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _SceneSection(
          scene: scene,
          projectId: projectId,
          colors: colors,
          wide: wide,
          flatLayout: true,
        ),
      ],
    );
  }
}

class _LocationHierarchySection extends ConsumerWidget {
  final CameraPlanHierarchy hierarchy;
  final ProjectColorScheme colors;
  final int projectId;
  final bool wide;
  final GlobalKey locationAnchorKey;
  final GlobalKey Function(int setId) setAnchorKey;
  final GlobalKey Function(int sceneId) sceneAnchorKey;

  const _LocationHierarchySection({
    required this.hierarchy,
    required this.colors,
    required this.projectId,
    required this.wide,
    required this.locationAnchorKey,
    required this.setAnchorKey,
    required this.sceneAnchorKey,
  });

  Color get _locationBase => colors.siteColor(
        hierarchy.siteId,
        orphanSiteKey: hierarchy.siteId == null
            ? hierarchy.siteName.toLowerCase()
            : null,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final repo = FloorPlanRepository(ref.read(databaseProvider));
    final masterCount = hierarchy.siteFloorPlanJson != null
        ? FloorPlanJson.decode(hierarchy.siteFloorPlanJson).length
        : 0;
    final locationBase = _locationBase;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: locationAnchorKey,
            decoration: BoxDecoration(
              color: locationBase.withValues(alpha: 0.12),
              border: Border(
                left: BorderSide(color: locationBase, width: 5),
                bottom: BorderSide(color: palette.divider),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: locationBase,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.location_city_outlined,
                    size: 18, color: palette.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    hierarchy.siteName,
                    style: AppTypography.titleMedium(palette),
                  ),
                ),
                Text(
                  '${hierarchy.sceneCount} esc.',
                  style: AppTypography.caption(palette),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (hierarchy.siteId != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: FloorPlanMapTile(
                scope: FloorPlanScope.site,
                title: hierarchy.siteName,
                subtitle: 'Todos los sets de esta localización',
                accentColor: locationBase,
                hasPlan: repo.hasStoredPlan(
                  FloorPlanScope.site,
                  json: hierarchy.siteFloorPlanJson,
                ),
                elementCount: masterCount > 0 ? masterCount : null,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CameraPlanEditor.site(
                        projectId: projectId,
                        siteId: hierarchy.siteId!,
                        siteName: hierarchy.siteName,
                      ),
                    ),
                  );
                },
              ),
            ),
          ...List.generate(hierarchy.sets.length, (i) {
            final setNode = hierarchy.sets[i];
            final setColor = colors.setColor(setNode.set);
            return _SetSection(
              setNode: setNode,
              projectId: projectId,
              locationBase: locationBase,
              setColor: setColor,
              colors: colors,
              wide: wide,
              anchorKey: setAnchorKey(setNode.set.id),
              sceneAnchorKey: sceneAnchorKey,
            );
          }),
          if (hierarchy.unassignedScenes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                0,
                AppSpacing.sm,
              ),
              child: Text(
                'Escenas sin set',
                style: AppTypography.label(palette).copyWith(
                  color: locationBase.withValues(alpha: 0.8),
                ),
              ),
            ),
            ...hierarchy.unassignedScenes.map(
              (scene) => _SceneSection(
                scene: scene,
                projectId: projectId,
                colors: colors,
                wide: wide,
                anchorKey: sceneAnchorKey(scene.id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SetSection extends StatelessWidget {
  final SetPlanNode setNode;
  final int projectId;
  final Color locationBase;
  final Color setColor;
  final ProjectColorScheme colors;
  final bool wide;
  final GlobalKey anchorKey;
  final GlobalKey Function(int sceneId) sceneAnchorKey;

  const _SetSection({
    required this.setNode,
    required this.projectId,
    required this.locationBase,
    required this.setColor,
    required this.colors,
    required this.wide,
    required this.anchorKey,
    required this.sceneAnchorKey,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final planElementCount = setNode.hasPlan
        ? FloorPlanJson.decode(setNode.floorPlanJson).length
        : 0;

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: anchorKey,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: setColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: setColor, width: 3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: setColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    setNode.set.locationName,
                    style: AppTypography.titleMedium(palette).copyWith(
                      color: setColor,
                    ),
                  ),
                ),
                Text(
                  '${setNode.scenes.length} esc.',
                  style: AppTypography.caption(palette),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FloorPlanMapTile(
            scope: FloorPlanScope.set,
            title: setNode.set.locationName,
            subtitle: 'Arquitectura y props del set',
            accentColor: setColor,
            hasPlan: setNode.hasPlan,
            elementCount: planElementCount > 0 ? planElementCount : null,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CameraPlanEditor.set(
                    projectId: projectId,
                    setId: setNode.set.id,
                    setName: setNode.set.locationName,
                  ),
                ),
              );
            },
          ),
          if (setNode.scenes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md, top: 4),
              child: Text(
                'Sin escenas en este set.',
                style: AppTypography.bodyMedium(palette),
              ),
            )
          else
            ...setNode.scenes.map(
              (scene) => _SceneSection(
                scene: scene,
                projectId: projectId,
                colors: colors,
                wide: wide,
                anchorKey: sceneAnchorKey(scene.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _SceneSection extends ConsumerWidget {
  final Scene scene;
  final int projectId;
  final ProjectColorScheme colors;
  final bool wide;
  final GlobalKey? anchorKey;
  final bool flatLayout;

  const _SceneSection({
    required this.scene,
    required this.projectId,
    required this.colors,
    required this.wide,
    this.anchorKey,
    this.flatLayout = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final palette = context.palette;
    final location = locationFromCanonical(scene.locationCanonical);
    final sceneColor = colors.sceneColor(scene);

    return Padding(
      padding: EdgeInsets.only(
        left: flatLayout ? 0 : AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      child: Container(
        key: anchorKey,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: sceneColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sceneColor.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SceneHeaderRow(
              sceneNumber: scene.number,
              sceneColor: sceneColor,
              title: scene.name.isNotEmpty
                  ? scene.name
                  : formatSceneTitle(
                      number: scene.number,
                      intExt: scene.intExt,
                      dayNight: scene.dayNight,
                      location: location,
                    ),
              subtitleWidget: SceneMetaDisplay(
                intExt: scene.intExt,
                dayNight: scene.dayNight,
                location: location,
                style: AppTypography.caption(palette),
              ),
              palette: palette,
            ),
            const SizedBox(height: AppSpacing.sm),
            StreamBuilder<List<Shot>>(
              stream: db.watchShotsForScene(scene.id),
              builder: (context, shotSnap) {
                final shots = shotSnap.data ?? [];
                if (shots.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 44),
                    child: Text(
                      'Sin planos en esta escena.',
                      style: AppTypography.bodyMedium(palette),
                    ),
                  );
                }

                final tiles = shots
                    .map(
                      (s) => _ShotTile(
                        shot: s,
                        scene: scene,
                        projectId: projectId,
                        sceneColor: sceneColor,
                        wide: wide,
                      ),
                    )
                    .toList();

                if (wide) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 44),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: tiles
                          .map((t) => SizedBox(width: 360, child: t))
                          .toList(),
                    ),
                  );
                }

                return Column(children: tiles);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ShotTile extends ConsumerWidget {
  final Shot shot;
  final Scene scene;
  final int projectId;
  final Color sceneColor;
  final bool wide;

  const _ShotTile({
    required this.shot,
    required this.scene,
    required this.projectId,
    required this.sceneColor,
    required this.wide,
  });

  String get _label => 'Esc ${scene.number} · Plano ${shot.number}';

  String get _subtitle {
    final parts = <String>[
      if (shot.framing?.isNotEmpty == true) shot.framing!,
      if (shot.lens?.isNotEmpty == true) shot.lens!,
      if (shot.movement?.isNotEmpty == true) shot.movement!,
    ];
    return parts.isEmpty ? 'Sin datos técnicos' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final palette = context.palette;

    return StreamBuilder<List<CameraPlanElement>>(
      stream: db.watchCameraPlanElementsForShot(shot.id),
      builder: (context, planSnap) {
        final elementCount = planSnap.data?.length ?? 0;
        final hasPlan = elementCount > 0;

        return Padding(
          padding: const EdgeInsets.only(
            left: 44,
            bottom: AppSpacing.sm,
          ),
          child: AppCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CameraPlanEditor.shot(
                    projectId: projectId,
                    shotId: shot.id,
                    shotLabel: _label,
                  ),
                ),
              );
            },
            child: Row(
              children: [
                SceneNumberBadge(
                  sceneNumber: scene.number,
                  color: sceneColor,
                  size: 36,
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hasPlan
                        ? palette.accent.withValues(alpha: 0.15)
                        : palette.surfaceOverlay.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasPlan ? palette.accent : palette.divider,
                    ),
                  ),
                  child: Icon(
                    Icons.grid_on_outlined,
                    color: hasPlan ? palette.accent : palette.textTertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plano ${shot.number}',
                        style: AppTypography.titleMedium(palette),
                      ),
                      const SizedBox(height: 2),
                      Text(_subtitle, style: AppTypography.bodyMedium(palette)),
                      Text(
                        hasPlan
                            ? '$elementCount elemento${elementCount == 1 ? '' : 's'}'
                            : 'Heredará del set al abrir',
                        style: AppTypography.caption(palette).copyWith(
                          color: hasPlan ? palette.accent : palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: palette.textTertiary),
              ],
            ),
          ),
        );
      },
    );
  }
}
