import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/settings/settings_sheet.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import 'create_project_sheet.dart';
import 'project_form_sheet.dart';
import 'project_overview.dart';
import 'project_overview_metrics.dart';
import '../project_hub/project_hub_screen.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/sync_status_indicator.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.lg),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IRIS DP', style: AppTypography.displayMedium(palette)),
                      Text('Proyectos', style: AppTypography.bodyMedium(palette)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ajustes',
                  icon: Icon(Icons.settings_outlined, color: palette.textSecondary),
                  onPressed: () => SettingsSheet.show(context),
                ),
                const SyncStatusIndicator(),
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
              ]),
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
                        return _EmptyState(
                            onTap: () => _showCreateProject(context, ref));
                      }

                      final ungrouped =
                          allProjects.where((p) => p.groupId == null).toList();

                      return ListView(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        children: [
                          if (ungrouped.isNotEmpty)
                            _ProjectGrid(
                              projects: ungrouped,
                              onTap: (p) => _openProject(context, p),
                              onEdit: (p) => _showEditProject(context, p),
                              onDuplicate: (p) async {
                                try {
                                  await db.duplicateProject(p.id);
                                  if (context.mounted) {
                                    AppSnackBar.show(context, 'Proyecto duplicado.');
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    AppSnackBar.show(context, userFriendlyError(e));
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
                                    AppSnackBar.show(context, 'Proyecto duplicado.');
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    AppSnackBar.show(context, userFriendlyError(e));
                                  }
                                }
                              },
                              onDelete: (p) => _confirmDelete(context, ref, p),
                              onDeleteGroup: () =>
                                  db.deleteGroup(group.id),
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
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProjectHubScreen(project: p)));
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
              child: Text('Cancelar', style: AppTypography.bodyMedium(palette))),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: Text('Crear',
                  style: AppTypography.bodyMedium(palette)
                      .copyWith(color: palette.accent))),
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
      BuildContext context, WidgetRef ref, Project p) async {
    final palette = context.palette;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text('Eliminar proyecto', style: AppTypography.titleLarge(palette)),
        content: Text(
            '¿Eliminar "${p.name}"? Esta acción no se puede deshacer.',
            style: AppTypography.bodyLarge(palette)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: AppTypography.bodyMedium(palette))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Eliminar',
                  style: AppTypography.bodyMedium(palette)
                      .copyWith(color: palette.error))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(databaseProvider).deleteProjectFully(p.id);
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
        Row(children: [
          Icon(Icons.folder_outlined,
              color: palette.textTertiary, size: 16),
          const SizedBox(width: 8),
          Text(group.name,
              style: AppTypography.label(palette)
                  .copyWith(color: palette.textSecondary)),
          const Spacer(),
          GestureDetector(
            onTap: onDeleteGroup,
            child: Icon(Icons.delete_outline,
                color: palette.textTertiary, size: 16),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        if (projects.isEmpty)
          Text('Sin proyectos en este grupo',
              style: AppTypography.caption(palette))
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.62,
      ),
      itemCount: projects.length,
      itemBuilder: (context, i) => _ProjectCard(
        project: projects[i],
        onTap: () => onTap(projects[i]),
        onEdit: () => onEdit(projects[i]),
        onDuplicate: () => onDuplicate(projects[i]),
        onDelete: () => onDelete(projects[i]),
      ),
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
  ProjectOverview? _overview;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  @override
  void didUpdateWidget(_ProjectCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _loadOverview();
    }
  }

  Future<void> _loadOverview() async {
    final db = ref.read(databaseProvider);
    final overview = await loadProjectOverview(db, widget.project.id);
    if (mounted) setState(() => _overview = overview);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final project = widget.project;
    final icon = IconData(project.iconCode, fontFamily: 'MaterialIcons');
    final coverPath = project.coverImagePath;
    final hasCover = coverPath != null &&
        coverPath.isNotEmpty &&
        File(coverPath).existsSync();
    final overview = _overview;
    final directionText = overview?.directionSummary;

    return AppCard(
      onTap: widget.onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Stack(children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16)),
                child: hasCover
                    ? Image.file(
                        File(coverPath),
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: palette.surfaceOverlay,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                        ),
                        child: Center(
                          child: Icon(icon,
                              color: palette.textTertiary, size: 48),
                        ),
                      ),
              ),
              if (hasCover)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.35),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 8, right: 8,
                child: PopupMenuButton<String>(
                  color: palette.surfaceElevated,
                  icon: Icon(Icons.more_horiz,
                      color: palette.textSecondary, size: 18),
                  onSelected: (v) {
                    if (v == 'edit') widget.onEdit();
                    if (v == 'duplicate') widget.onDuplicate();
                    if (v == 'delete') widget.onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined,
                            color: palette.textSecondary, size: 16),
                        const SizedBox(width: 8),
                        Text('Editar', style: AppTypography.bodyMedium(palette)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Row(children: [
                        Icon(Icons.copy_outlined,
                            color: palette.textSecondary, size: 16),
                        const SizedBox(width: 8),
                        Text('Duplicar', style: AppTypography.bodyMedium(palette)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            color: palette.error, size: 16),
                        const SizedBox(width: 8),
                        Text('Eliminar',
                            style: AppTypography.bodyMedium(palette)
                                .copyWith(color: palette.error)),
                      ]),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          Expanded(
            flex: 6,
            child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.name,
                    style: AppTypography.titleMedium(palette),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (project.director != null) ...[
                  const SizedBox(height: 2),
                  Text(project.director!,
                      style: AppTypography.caption(palette),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
                if (directionText != null && directionText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    directionText,
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.textSecondary,
                      height: 1.35,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else if (overview != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Añade la intención en Biblia → Dirección',
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                if (overview != null) ...[
                  ProjectStateChip(
                    overview: overview,
                    status: project.status,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: ProjectOverviewMetrics(overview: overview),
                    ),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          ),
          ),
        ],
      ),
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.movie_creation_outlined,
            color: palette.textTertiary, size: 64),
        const SizedBox(height: 24),
        Text('Sin proyectos', style: AppTypography.titleLarge(palette)),
        const SizedBox(height: 8),
        Text('Crea tu primer proyecto para empezar',
            style: AppTypography.bodyMedium(palette)),
        const SizedBox(height: 32),
        AppButton(label: 'Crear proyecto', icon: Icons.add, onTap: onTap),
      ]),
    );
  }
}
