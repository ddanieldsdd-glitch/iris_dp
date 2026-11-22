import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/sync/project_cloud_actions.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../settings/settings_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_button.dart';
import 'create_project_sheet.dart';
import '../auth/auth_screen.dart';
import 'project_form_sheet.dart';
import 'project_card_actions.dart';
import 'project_card_stats.dart';
import 'projects_header.dart';
import '../../core/theme/app_layout.dart';
import 'project_poster_card.dart';
import 'project_my_role.dart';
import '../light_crew/light_crew_screen.dart';
import '../../core/cloud/project_role.dart';
import '../project_hub/project_hub_screen.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/sync/sync_conflict_resolution_sheet.dart';
import '../../core/widgets/sync/sync_flow_coordinator.dart';
import '../../core/sync/media_sync_providers.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/widgets/account/account_menu_button.dart';
import '../../core/widgets/sync_status_indicator.dart';
import '../../core/update/update_available_banner.dart';
import '../../core/cloud/connectivity_gate.dart';
import '../../core/access/app_access_service.dart';
import '../../core/access/guest_projects_screen.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

/// Última página abierta (LZ.2).
const _pageKey = 'iris_projects_role_page';

class _ProjectsScreenState extends ConsumerState<ProjectsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: MyProjectRole.values.length,
    vsync: this,
  );

  MyProjectRole get _role => MyProjectRole.values[_tabs.index];

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_rememberPage);
    _restorePage();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _restorePage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = MyProjectRole.fromCode(prefs.getString(_pageKey));
      if (role != null && mounted) _tabs.index = role.index;
    } catch (_) {
      // Sin preferencias, la primera página.
    }
  }

  Future<void> _rememberPage() async {
    if (_tabs.indexIsChanging) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pageKey, _role.code);
    } catch (_) {
      // La próxima vez se abre la primera.
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final palette = context.palette;
    final pendingPlan = ref.watch(pendingSyncPlanProvider);

    Future<void> reviewSync() async {
      final syncResult = await SyncFlowCoordinator.runWithConfirmation(
        context,
        ref,
      );
      if (!context.mounted) return;
      final msg =
          syncResult.message ??
          (syncResult.pendingReview
              ? 'Revisión pendiente'
              : 'Sincronizado correctamente');
      AppSnackBar.show(
        context,
        msg,
        isError:
            syncResult.pendingReview &&
            syncResult.message?.contains('quedan') == true,
      );
    }

    Future<void> duplicate(Project p) async {
      try {
        await db.duplicateProject(p.id);
        if (context.mounted) AppSnackBar.show(context, 'Proyecto duplicado.');
      } catch (e) {
        if (context.mounted) AppSnackBar.show(context, userFriendlyError(e));
      }
    }

    final gutter = AppLayout.gutter(context, regular: AppSpacing.xl);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OfflineStatusBanner(),
            const UpdateAvailableBanner(),
            ProjectsHeader(
              statusActions: [
                if (ref.watch(isAppAdminProvider))
                  IconButton(
                    tooltip: 'Proyectos de invitados',
                    icon: Icon(
                      Icons.group_outlined,
                      color: palette.textSecondary,
                    ),
                    onPressed: () => GuestProjectsScreen.open(context),
                  ),
                IconButton(
                  tooltip: 'Ajustes',
                  icon: Icon(
                    Icons.settings_outlined,
                    color: palette.textSecondary,
                  ),
                  onPressed: () => openSettingsCenter(context),
                ),
                const SyncStatusIndicator(),
                AccountMenuButton(onLoginAction: () => openAuthScreen(context)),
              ],
              onNewProject: () => _showCreateProject(context, _role),
              onNewGroup: () => _createGroup(context, ref),
            ),
            Expanded(
              child: StreamBuilder<List<ProjectGroup>>(
                stream: db.watchAllGroups(),
                builder: (context, groupSnap) {
                  final groups = groupSnap.data ?? [];

                  return StreamBuilder<List<Project>>(
                    stream: db.watchProjects(),
                    builder: (context, projectSnap) {
                      // Las copias de invitados van en su propia pantalla.
                      final allProjects = [
                        for (final p in projectSnap.data ?? const <Project>[])
                          if (p.mirrorCloudId == null) p,
                      ];

                      if (allProjects.isEmpty) {
                        return ListView(
                          padding: EdgeInsets.all(gutter),
                          children: [
                            if (pendingPlan != null) ...[
                              PendingSyncBanner(
                                plan: pendingPlan,
                                onReview: reviewSync,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            _EmptyState(
                              onTap: () => _showCreateProject(context, _role),
                            ),
                          ],
                        );
                      }

                      Widget page(MyProjectRole role) {
                        final projects = role.filter(allProjects);
                        final ungrouped = projects
                            .where((p) => p.groupId == null)
                            .toList();
                        // Un grupo sale en la página si tiene proyectos de
                        // ese papel, o si aún está vacío.
                        final shownGroups = [
                          for (final g in groups)
                            if (projects.any((p) => p.groupId == g.id) ||
                                !allProjects.any((p) => p.groupId == g.id))
                              g,
                        ];
                        return ListView(
                          key: PageStorageKey('projects-${role.code}'),
                          padding: EdgeInsets.all(gutter),
                          children: [
                            if (pendingPlan != null) ...[
                              PendingSyncBanner(
                                plan: pendingPlan,
                                onReview: reviewSync,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            if (projects.isEmpty)
                              _EmptyRolePage(
                                role: role,
                                onCreate: () =>
                                    _showCreateProject(context, role),
                              ),
                            if (ungrouped.isNotEmpty)
                              _ProjectGrid(
                                projects: ungrouped,
                                onTap: (p) => _openProject(context, p),
                                onEdit: (p) => _showEditProject(context, p),
                                onDuplicate: duplicate,
                                onDelete: (p) =>
                                    _confirmDelete(context, ref, p),
                              ),
                            for (final group in shownGroups)
                              _GroupSection(
                                group: group,
                                projects: [
                                  for (final p in projects)
                                    if (p.groupId == group.id) p,
                                ],
                                onTap: (p) => _openProject(context, p),
                                onEdit: (p) => _showEditProject(context, p),
                                onDuplicate: duplicate,
                                onDelete: (p) =>
                                    _confirmDelete(context, ref, p),
                                onDeleteGroup: () => db.deleteGroup(group.id),
                              ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: gutter),
                            child: _RoleTabs(
                              controller: _tabs,
                              counts: [
                                for (final r in MyProjectRole.values)
                                  r.filter(allProjects).length,
                              ],
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabs,
                              children: [
                                for (final r in MyProjectRole.values) page(r),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openProject(BuildContext context, Project p) {
    // Los eléctricos solo consultan la luz (LZ.3).
    if (ProjectRole.fromCode(p.memberRole)?.isLightCrew ?? false) {
      LightCrewScreen.open(context, p);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProjectHubScreen(project: p)),
    );
  }

  void _showCreateProject(BuildContext context, MyProjectRole role) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateProjectSheet(initialRole: role),
    );
  }

  void _showEditProject(BuildContext context, Project project) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProjectFormSheet(project: project),
    );
  }

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final palette = context.palette;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text('Nuevo grupo', style: AppTypography.titleLarge(palette)),
        content: TextField(
          controller: ctrl,
          style: AppTypography.bodyLarge(palette),
          decoration: const InputDecoration(hintText: 'Nombre del grupo'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(
              'Crear',
              style: AppTypography.bodyMedium(
                palette,
              ).copyWith(color: palette.accent),
            ),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref
          .read(databaseProvider)
          .insertGroup(ProjectGroupsCompanion.insert(name: name));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Project p,
  ) async {
    final palette = context.palette;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text(
          'Eliminar proyecto',
          style: AppTypography.titleLarge(palette),
        ),
        content: Text(
          '¿Eliminar "${p.name}"? Esta acción no se puede deshacer.',
          style: AppTypography.bodyLarge(palette),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Eliminar',
              style: AppTypography.bodyMedium(
                palette,
              ).copyWith(color: palette.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ProjectCloudActions.deleteProject(ref, p);
      } catch (e) {
        if (context.mounted) {
          AppSnackBar.show(context, userFriendlyError(e));
        }
      }
    }
  }
}

class _GroupSection extends StatelessWidget {
  final ProjectGroup group;
  final List<Project> projects;
  final ValueChanged<Project> onTap;
  final ValueChanged<Project> onEdit;
  final ValueChanged<Project> onDuplicate;
  final ValueChanged<Project> onDelete;
  final VoidCallback onDeleteGroup;

  const _GroupSection({
    required this.group,
    required this.projects,
    required this.onTap,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onDeleteGroup,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Icon(Icons.folder_outlined, color: palette.textTertiary, size: 16),
            const SizedBox(width: 8),
            Text(
              group.name,
              style: AppTypography.label(
                palette,
              ).copyWith(color: palette.textSecondary),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onDeleteGroup,
              child: Icon(
                Icons.delete_outline,
                color: palette.textTertiary,
                size: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (projects.isEmpty)
          Text(
            'Sin proyectos en este grupo',
            style: AppTypography.caption(palette),
          )
        else
          _ProjectGrid(
            projects: projects,
            onTap: onTap,
            onEdit: onEdit,
            onDuplicate: onDuplicate,
            onDelete: onDelete,
          ),
      ],
    );
  }
}

class _ProjectGrid extends StatelessWidget {
  final List<Project> projects;
  final ValueChanged<Project> onTap;
  final ValueChanged<Project> onEdit;
  final ValueChanged<Project> onDuplicate;
  final ValueChanged<Project> onDelete;

  const _ProjectGrid({
    required this.projects,
    required this.onTap,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Tarjetas grandes: son la portada de cada trabajo. Cada proyecto elige
    // su tamaño (S, M, L, XL) y las filas se rellenan solas.
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        return Wrap(
          spacing: 28,
          runSpacing: 28,
          children: [
            for (final project in projects)
              Builder(
                builder: (_) {
                  final size = ProjectCardSize.of(project.cardSize);
                  final width = size.width > available ? available : size.width;
                  return SizedBox(
                    width: width,
                    height: width * 10 / 16,
                    child: _ProjectCard(
                      project: project,
                      onTap: () => onTap(project),
                      onEdit: () => onEdit(project),
                      onDuplicate: () => onDuplicate(project),
                      onDelete: () => onDelete(project),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _ProjectCard extends ConsumerStatefulWidget {
  final Project project;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  ConsumerState<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends ConsumerState<_ProjectCard> {
  ProjectCardStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(_ProjectCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project != widget.project) _loadStats();
  }

  Future<void> _loadStats() async {
    final db = ref.read(databaseProvider);
    final stats = await loadProjectCardStats(db, widget.project.id);
    if (mounted) setState(() => _stats = stats);
  }

  @override
  Widget build(BuildContext context) {
    // Tras sincronizar o subir imágenes cambia el estado de la nube.
    ref.listen(pendingSyncPlanProvider, (_, _) => _loadStats());
    ref.listen(mediaUploadProgressProvider, (_, _) => _loadStats());
    final stats = _stats;

    return ProjectPosterCard(
      project: widget.project,
      stats: stats,
      metrics: ProjectCardMetric.of(widget.project.cardMetricsJson),
      onChangeImage: () => changeProjectCardImage(
        context,
        ref.read(databaseProvider),
        widget.project,
      ),
      onChooseColor: () => chooseProjectCardColor(
        context,
        ref.read(databaseProvider),
        widget.project,
      ),
      onSetSize: (size) =>
          setProjectCardSize(ref.read(databaseProvider), widget.project, size),
      onChooseData: () async {
        await chooseProjectCardData(
          context,
          ref.read(databaseProvider),
          widget.project,
        );
        _loadStats();
      },
      syncState: stats == null
          ? null
          : projectSyncState(
              project: widget.project,
              stats: stats,
              pendingPlan: ref.watch(pendingSyncPlanProvider),
            ),
      onTap: widget.onTap,
      onEdit: widget.onEdit,
      onDuplicate: widget.onDuplicate,
      onDelete: widget.onDelete,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.movie_creation_outlined,
            color: palette.textTertiary,
            size: 64,
          ),
          const SizedBox(height: 24),
          Text('Sin proyectos', style: AppTypography.titleLarge(palette)),
          const SizedBox(height: 8),
          Text(
            'Crea tu primer proyecto para empezar',
            style: AppTypography.bodyMedium(palette),
          ),
          const SizedBox(height: 32),
          AppButton(label: 'Crear proyecto', icon: Icons.add, onTap: onTap),
        ],
      ),
    );
  }
}

/// Las páginas por papel (LZ.2): se pasan con el dedo o tocando la pestaña.
class _RoleTabs extends StatelessWidget {
  final TabController controller;
  final List<int> counts;

  const _RoleTabs({required this.controller, required this.counts});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: palette.accent,
      unselectedLabelColor: palette.textSecondary,
      indicatorColor: palette.accent,
      dividerColor: palette.border,
      labelStyle: AppTypography.label(palette),
      tabs: [
        for (final (i, r) in MyProjectRole.values.indexed)
          Tab(
            child: Tooltip(
              message: r.label,
              child: Text(counts[i] == 0 ? r.tab : '${r.tab} · ${counts[i]}'),
            ),
          ),
      ],
    );
  }
}

class _EmptyRolePage extends StatelessWidget {
  final MyProjectRole role;
  final VoidCallback onCreate;

  const _EmptyRolePage({required this.role, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Text(
            'Ningún proyecto de '
            '${role.label[0].toLowerCase()}${role.label.substring(1)}',
            style: AppTypography.bodyLarge(palette),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Crea uno aquí, o cambia el papel de otro en «Editar».',
            style: AppTypography.caption(palette),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Nuevo proyecto',
            icon: Icons.add,
            onTap: onCreate,
          ),
        ],
      ),
    );
  }
}
