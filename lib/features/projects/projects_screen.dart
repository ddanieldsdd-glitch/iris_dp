
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sync/project_cloud_actions.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/settings/settings_sheet.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_button.dart';
import 'create_project_sheet.dart';
import '../auth/auth_screen.dart';
import '../migration/cloud_migration_wizard.dart';
import '../onboarding/app_tutorial_store.dart';
import '../onboarding/auth_required_banner.dart';
import '../onboarding/initial_tutorial_flow.dart';
import '../onboarding/install_update_guide_screen.dart';
import 'project_form_sheet.dart';
import 'project_card_actions.dart';
import 'project_card_stats.dart';
import 'project_poster_card.dart';
import '../project_hub/project_hub_screen.dart';
import '../shoot_documents/shoot_template_editor_screen.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/sync/sync_conflict_resolution_sheet.dart';
import '../../core/widgets/sync/sync_flow_coordinator.dart';
import '../../core/sync/media_sync_providers.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/widgets/account/account_menu_button.dart';
import '../../core/widgets/sync_status_indicator.dart';
import '../../core/update/update_available_banner.dart';
import '../../core/update/sidestore_reminder_banner.dart';
import '../../core/cloud/connectivity_gate.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OfflineStatusBanner(),
            const UpdateAvailableBanner(),
            const SideStoreReminderBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IRIS',
                          style: AppTypography.displayMedium(palette),
                        ),
                        Text(
                          'Proyectos',
                          style: AppTypography.bodyMedium(palette),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ajustes',
                    icon: Icon(
                      Icons.settings_outlined,
                      color: palette.textSecondary,
                    ),
                    onPressed: () => SettingsSheet.show(
                      context,
                      onLoginAction: () => openAuthScreen(context),
                      onMigrationAction: () async {
                        final done = await showDialog<bool>(
                          context: context,
                          builder: (_) => Dialog(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: CloudMigrationWizard(
                                onComplete: () => Navigator.pop(context, true),
                                onSkip: () => Navigator.pop(context, false),
                              ),
                            ),
                          ),
                        );

                        if (done == true && context.mounted) {
                          AppSnackBar.show(
                            context,
                            'Proyectos locales subidos a la nube.',
                          );
                        }
                      },
                      onReplayTutorial: () async {
                        Navigator.pop(context);
                        await AppTutorialStore.resetAll();

                        if (!context.mounted) return;

                        await Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => InitialTutorialFlow(
                              replayFromStart: true,
                              homeContentBuilder: (_) => const Column(
                                children: [
                                  AuthRequiredBanner(),
                                  Expanded(child: ProjectsScreen()),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      onInstallGuide: () {
                        Navigator.pop(context);
                        Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const InstallUpdateGuideScreen(),
                          ),
                        );
                      },
                      onCreateShootTemplate: () async =>
                          await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ShootTemplateEditorScreen(),
                            ),
                          ) ??
                          false,
                      onEditShootTemplate: (templateId) async =>
                          await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShootTemplateEditorScreen(
                                templateId: templateId,
                              ),
                            ),
                          ) ??
                          false,
                    ),
                  ),
                  const SyncStatusIndicator(),
                  AccountMenuButton(
                    onLoginAction: () => openAuthScreen(context),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: 'Nuevo grupo',
                    icon: Icons.create_new_folder_outlined,
                    variant: AppButtonVariant.secondary,
                    onTap: () => _createGroup(context, ref),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppButton(
                    label: 'Nuevo proyecto',
                    icon: Icons.add,
                    onTap: () => _showCreateProject(context, ref),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ProjectGroup>>(
                stream: db.watchAllGroups(),
                builder: (context, groupSnap) {
                  final groups = groupSnap.data ?? [];

                  return StreamBuilder<List<Project>>(
                    stream: db.watchProjects(),
                    builder: (context, projectSnap) {
                      final allProjects = projectSnap.data ?? [];

                      if (allProjects.isEmpty) {
                        return ListView(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          children: [
                            if (pendingPlan != null) ...[
                              PendingSyncBanner(
                                plan: pendingPlan,
                                onReview: reviewSync,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            _EmptyState(
                              onTap: () => _showCreateProject(context, ref),
                            ),
                          ],
                        );
                      }

                      final ungrouped = allProjects
                          .where((p) => p.groupId == null)
                          .toList();

                      return ListView(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        children: [
                          if (pendingPlan != null) ...[
                            PendingSyncBanner(
                              plan: pendingPlan,
                              onReview: reviewSync,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          if (ungrouped.isNotEmpty)
                            _ProjectGrid(
                              projects: ungrouped,
                              onTap: (p) => _openProject(context, p),
                              onEdit: (p) => _showEditProject(context, p),
                              onDuplicate: (p) async {
                                try {
                                  await db.duplicateProject(p.id);
                                  if (context.mounted) {
                                    AppSnackBar.show(
                                      context,
                                      'Proyecto duplicado.',
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    AppSnackBar.show(
                                      context,
                                      userFriendlyError(e),
                                    );
                                  }
                                }
                              },
                              onDelete: (p) => _confirmDelete(context, ref, p),
                            ),
                          ...groups.map((group) {
                            final groupProjects = allProjects
                                .where((p) => p.groupId == group.id)
                                .toList();
                            return _GroupSection(
                              group: group,
                              projects: groupProjects,
                              onTap: (p) => _openProject(context, p),
                              onEdit: (p) => _showEditProject(context, p),
                              onDuplicate: (p) async {
                                try {
                                  await db.duplicateProject(p.id);
                                  if (context.mounted) {
                                    AppSnackBar.show(
                                      context,
                                      'Proyecto duplicado.',
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    AppSnackBar.show(
                                      context,
                                      userFriendlyError(e),
                                    );
                                  }
                                }
                              },
                              onDelete: (p) => _confirmDelete(context, ref, p),
                              onDeleteGroup: () => db.deleteGroup(group.id),
                            );
                          }),
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProjectHubScreen(project: p)),
    );
  }

  void _showCreateProject(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateProjectSheet(),
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
                  final width = size.width > available
                      ? available
                      : size.width;
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
