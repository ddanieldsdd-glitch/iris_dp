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
import '../../shared/pdf_export/camera_plan_pdf.dart';
import 'camera_plan_grouping.dart';
import 'camera_plan_scene_badge.dart';
import 'floor_plan_repository.dart';
import 'light_setup_actions.dart';
import 'plan_data.dart';
import 'plan_global_map.dart';
import 'plan_target.dart';
import 'plan_workspace_screen.dart';

enum _PlanView { map, script }

/// Entrada a las plantas de luz y cámara: un mapa global con miniaturas de
/// localizaciones, sets y esquemas de luz, y una vista por orden de guion.
class CameraPlanScreen extends ConsumerStatefulWidget {
  final int projectId;

  const CameraPlanScreen({super.key, required this.projectId});

  @override
  ConsumerState<CameraPlanScreen> createState() => _CameraPlanScreenState();
}

class _CameraPlanScreenState extends ConsumerState<CameraPlanScreen> {
  _PlanView _view = _PlanView.map;

  int get projectId => widget.projectId;

  void _open(PlanTarget target) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PlanWorkspaceScreen(projectId: projectId, initial: target),
      ),
    );
  }

  Future<void> _onNew(String action) async {
    final db = ref.read(databaseProvider);
    switch (action) {
      case 'site':
        final name = await askPlanName(
          context,
          title: 'Nueva localización',
          hint: 'Bosque, hospital, casa de Gala…',
        );
        if (name == null) return;
        await db.insertSite(
          LocationSitesCompanion.insert(projectId: projectId, name: name),
        );
      case 'free':
        final setup = await FloorPlanRepository(
          db,
        ).createLightSetup(projectId: projectId);
        if (!mounted) return;
        _open(PlanTarget.lightSetup(setup.id, setup.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text(
          'Plantas de luz y cámara',
          style: AppTypography.titleLarge(palette),
        ),
        actions: [
          SegmentedButton<_PlanView>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _PlanView.map,
                icon: Icon(Icons.map_outlined, size: 18),
                label: Text('Mapa'),
              ),
              ButtonSegment(
                value: _PlanView.script,
                icon: Icon(Icons.view_list_outlined, size: 18),
                label: Text('Guion'),
              ),
            ],
            selected: {_view},
            onSelectionChanged: (v) => setState(() => _view = v.first),
          ),
          PopupMenuButton<String>(
            tooltip: 'Nuevo',
            icon: Icon(Icons.add, color: palette.textSecondary),
            onSelected: _onNew,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'site', child: Text('Nueva localización')),
              PopupMenuItem(value: 'free', child: Text('Nueva planta libre')),
            ],
          ),
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
      body: PlanDataBuilder(
        projectId: projectId,
        builder: (context, data) => switch (_view) {
          _PlanView.map => PlanGlobalMap(
            projectId: projectId,
            data: data,
            onOpen: _open,
          ),
          _PlanView.script => _ScriptOrderList(
            projectId: projectId,
            data: data,
          ),
        },
      ),
    );
  }
}

/// Todos los planos, escena a escena, en el orden del guion.
class _ScriptOrderList extends StatelessWidget {
  final int projectId;
  final PlanProjectData data;

  const _ScriptOrderList({required this.projectId, required this.data});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scenes = scenesInScriptOrder(data.scenes);
    if (scenes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'Sin escenas todavía. Las plantas se pueden empezar desde el '
            'mapa y vincular a los planos después.',
            style: AppTypography.bodyMedium(palette),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final sitesById = {for (final s in data.sites) s.id: s};
    final setsById = {for (final s in data.sets) s.id: s};
    final wide = AppLayout.isWide(context);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: scenes.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
      itemBuilder: (context, i) => _ScriptOrderSceneSection(
        scene: scenes[i],
        sitesById: sitesById,
        setsById: setsById,
        colors: data.colors,
        projectId: projectId,
        wide: wide,
      ),
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

  const _ScriptOrderSceneSection({
    required this.scene,
    required this.sitesById,
    required this.setsById,
    required this.colors,
    required this.projectId,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final site = scene.locationSiteId != null
        ? sitesById[scene.locationSiteId]
        : null;
    final set = scene.locationId != null ? setsById[scene.locationId] : null;
    final siteName =
        site?.name ??
        (scene.locationPureName.trim().isNotEmpty
            ? scene.locationPureName.trim()
            : 'Sin localización');
    final setName =
        set?.locationName ??
        (scene.locationPureName.trim().isNotEmpty
            ? scene.locationPureName.trim()
            : 'Sin set');
    final sceneColor = colors.sceneColor(scene);

    return Column(
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

class _SceneSection extends ConsumerWidget {
  final Scene scene;
  final int projectId;
  final ProjectColorScheme colors;
  final bool wide;
  final bool flatLayout;

  const _SceneSection({
    required this.scene,
    required this.projectId,
    required this.colors,
    required this.wide,
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
          padding: const EdgeInsets.only(left: 44, bottom: AppSpacing.sm),
          child: AppCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlanWorkspaceScreen(
                    projectId: projectId,
                    initial: PlanTarget.shot(shot.id, _label),
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
                          color: hasPlan
                              ? palette.accent
                              : palette.textTertiary,
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
