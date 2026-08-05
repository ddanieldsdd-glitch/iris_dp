import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../visual_bible/visual_bible_screen.dart';
import '../luka_export/luka_bridge_screen.dart';
import '../storyboard/storyboard_screen.dart';
import '../camera_plan/camera_plan_screen.dart';
import '../shoot_documents/shoot_documents_screen.dart';
import '../equipment/equipment_screen.dart';
import '../locations/locations_screen.dart';
import '../script_import/script_import_screen.dart';
import '../technical_script/technical_script_screen.dart';
import '../shoot_documents/shoot_document_import_actions.dart';
import '../shoot_documents/shoot_document_service.dart';
import 'project_hub_destinations.dart';
import 'project_hub_cover.dart';
import 'project_module_stub_screen.dart';

class ProjectHubScreen extends ConsumerStatefulWidget {
  final Project project;

  const ProjectHubScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectHubScreen> createState() => _ProjectHubScreenState();
}

class _ProjectHubScreenState extends ConsumerState<ProjectHubScreen> {
  int _sceneCount = 0;
  int _planCount = 0;
  ShootDocument? _primaryShootDoc;
  int _statsToken = 0;
  int _visualsToken = 0;
  List<String> _moodboardPaths = const [];
  List<String> _storyboardPaths = const [];

  ProjectHubStats get _stats => ProjectHubStats(
        sceneCount: _sceneCount,
        planCount: _planCount,
        projectStatus: widget.project.status,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadStats());
        unawaited(_loadVisuals());
      }
    });
  }

  @override
  void dispose() {
    _statsToken++;
    _visualsToken++;
    super.dispose();
  }

  Future<void> _loadVisuals() async {
    final token = ++_visualsToken;
    final db = ref.read(databaseProvider);
    final visuals = await db.getProjectHubVisuals(widget.project.id);
    if (!mounted || token != _visualsToken) return;
    setState(() {
      _moodboardPaths = visuals.moodboard;
      _storyboardPaths = visuals.storyboard;
    });
  }

  Future<void> _loadStats() async {
    final token = ++_statsToken;
    final db = ref.read(databaseProvider);
    final scenes = await (db.select(db.scenes)
          ..where((s) => s.projectId.equals(widget.project.id)))
        .get();
    if (!mounted || token != _statsToken) return;
    final plans = await db.countShotsWithCameraPlan(widget.project.id);
    if (!mounted || token != _statsToken) return;
    final primaryDoc = await ShootDocumentService.primaryDocument(
      db,
      widget.project.id,
    );
    if (!mounted || token != _statsToken) return;
    setState(() {
      _sceneCount = scenes.length;
      _planCount = plans;
      _primaryShootDoc = primaryDoc;
    });
  }

  Future<void> _openDestination(ProjectHubDestination destination) async {
    if (!destination.isAvailable(_stats)) {
      await _openStub(destination);
      return;
    }

    final projectId = widget.project.id;
    final Widget screen = switch (destination.id) {
      ProjectHubDestinationId.scriptImport =>
        ScriptImportScreen(projectId: projectId),
      ProjectHubDestinationId.locations =>
        LocationsScreen(projectId: projectId),
      ProjectHubDestinationId.cameraPlans =>
        CameraPlanScreen(projectId: projectId),
      ProjectHubDestinationId.technicalScript =>
        TechnicalScriptScreen(projectId: projectId),
      ProjectHubDestinationId.dailyOrder => ShootDocumentsScreen(
          projectId: projectId,
          projectName: widget.project.name,
          projectStatus: widget.project.status,
        ),
      ProjectHubDestinationId.equipment =>
        EquipmentScreen(projectId: projectId),
      ProjectHubDestinationId.storyboard =>
        StoryboardScreen(projectId: projectId),
      ProjectHubDestinationId.lukaBridge => LukaBridgeScreen(
          projectId: projectId,
          projectName: widget.project.name,
        ),
      ProjectHubDestinationId.lookBible =>
        VisualBibleScreen(projectId: projectId),
    };

    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );

    unawaited(_loadVisuals());
    if (destination.id == ProjectHubDestinationId.scriptImport ||
        destination.id == ProjectHubDestinationId.cameraPlans) {
      _loadStats();
    }
  }

  Future<void> _openStub(ProjectHubDestination destination) async {
    final planned = switch (destination.id) {
      ProjectHubDestinationId.equipment => const [
          'Asignación por plano desde guion técnico',
          'Sincronización con plantas LUKA',
        ],
      ProjectHubDestinationId.storyboard => null,
      ProjectHubDestinationId.dailyOrder => const [
          'Selección de planos por jornada',
          'Orden real de grabación del día',
          'Export PDF call sheet',
        ],
      ProjectHubDestinationId.lukaBridge => const [
          'Export JSON → Unreal Engine 5',
          'Gaussian Splat (Luma AI) + ARRI LUKA',
          'Reimportación de renders como referencias',
        ],
      ProjectHubDestinationId.lookBible => const [
          'Moodboard hub del proyecto',
          'Paletas por bloque narrativo',
          'PDF por departamento (gaffer, colorista…)',
        ],
      _ => null,
    };

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProjectModuleStubScreen(
          title: destination.title,
          icon: destination.icon,
          description: destination.subtitle(_stats),
          plannedFeatures: planned,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final destinations = buildProjectHubDestinations()
        .where((d) => d.visible())
        .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: palette.surface,
            iconTheme: IconThemeData(color: palette.textPrimary),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 14, right: 16),
              title: Text(
                widget.project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium(palette).copyWith(
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.75),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              background: ProjectHubCover(
                project: widget.project,
                moodboardPaths: _moodboardPaths,
                storyboardPaths: _storyboardPaths,
                onMoodboardTap: () => _openDestination(
                  buildProjectHubDestinations().firstWhere(
                    (d) => d.id == ProjectHubDestinationId.locations,
                  ),
                ),
                onStoryboardTap: () => _openDestination(
                  buildProjectHubDestinations().firstWhere(
                    (d) => d.id == ProjectHubDestinationId.storyboard,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Workflow', style: AppTypography.titleLarge(palette)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Maestro → Set → Plano: guion, localizaciones, plantas y guion técnico.',
                    style: AppTypography.bodyMedium(palette),
                  ),
                  if (_stats.isShooting && _primaryShootDoc != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      onTap: () => ShootDocumentImportActions.openEditor(
                        context,
                        projectId: widget.project.id,
                        documentId: _primaryShootDoc!.id,
                      ),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      focused: true,
                      child: Row(
                        children: [
                          Icon(Icons.star, color: palette.accent, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Documento activo hoy',
                                  style: AppTypography.label(palette),
                                ),
                                Text(
                                  _primaryShootDoc!.name,
                                  style: AppTypography.titleMedium(palette),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: palette.textSecondary),
                        ],
                      ),
                    ),
                  ],
                  if (_stats.hasScenes) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(
                            Icons.insights_outlined,
                            color: palette.accent,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '$_sceneCount escena${_sceneCount == 1 ? '' : 's'} · '
                              '$_planCount planta${_planCount == 1 ? '' : 's'} de cámara',
                              style: AppTypography.bodyMedium(palette),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: palette.accent,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Empieza importando el guion literario para crear escenas.',
                              style: AppTypography.bodyMedium(palette),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.crossAxisExtent >=
                        AppLayout.wideBreakpoint
                    ? 3
                    : constraints.crossAxisExtent >= 640
                        ? 2
                        : 1;

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: crossAxisCount == 1 ? 2.4 : 1.25,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final destination = destinations[index];
                      return _HubCard(
                        destination: destination,
                        stats: _stats,
                        onTap: () => _openDestination(destination),
                      );
                    },
                    childCount: destinations.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final ProjectHubDestination destination;
  final ProjectHubStats stats;
  final VoidCallback onTap;

  const _HubCard({
    required this.destination,
    required this.stats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final available = destination.isAvailable(stats);
    final highlighted = destination.highlight(stats);
    final subtitle = destination.subtitle(stats);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      focused: highlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: destination.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: highlighted
                      ? Border.all(
                          color: destination.accentColor.withValues(alpha: 0.55),
                        )
                      : null,
                ),
                child: Icon(
                  destination.icon,
                  color: available
                      ? destination.accentColor
                      : palette.textTertiary,
                  size: 24,
                ),
              ),
              const Spacer(),
              if (highlighted)
                _Badge(
                  label: stats.isShooting ? 'En rodaje' : 'Empezar aquí',
                  color: destination.accentColor,
                  palette: palette,
                )
              else if (!available)
                _Badge(
                  label: 'Próximamente',
                  color: palette.textTertiary,
                  palette: palette,
                ),
            ],
          ),
          const Spacer(),
          Text(
            destination.title,
            style: AppTypography.titleMedium(palette).copyWith(
              color: available ? null : palette.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.bodyMedium(palette).copyWith(
              color: palette.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final AppPalette palette;

  const _Badge({
    required this.label,
    required this.color,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTypography.caption(palette).copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}
