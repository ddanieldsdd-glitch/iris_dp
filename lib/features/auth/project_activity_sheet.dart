import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/cloud_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/sync/project_activity_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/activity/activity_providers.dart';
import '../../core/widgets/app_snackbar.dart';

/// Abre «Actividad» de un proyecto que está en la nube.
Future<void> openProjectActivity(BuildContext context, Project project) async {
  final db = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(databaseProvider);
  final cloudId = await projectCloudIdOf(db, project.id);
  if (!context.mounted) return;
  if (cloudId == null) {
    AppSnackBar.show(
      context,
      'Este proyecto aún no está en la nube: la actividad empieza cuando '
      'se sube.',
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surfaceElevated,
    builder: (_) => ProjectActivitySheet(
      projectCloudId: cloudId,
      projectName: project.name,
    ),
  );
}

/// Quién cambió qué en el proyecto, lo más reciente arriba (021).
class ProjectActivitySheet extends ConsumerStatefulWidget {
  const ProjectActivitySheet({
    super.key,
    required this.projectCloudId,
    required this.projectName,
  });

  final String projectCloudId;
  final String projectName;

  @override
  ConsumerState<ProjectActivitySheet> createState() =>
      _ProjectActivitySheetState();
}

class _ProjectActivitySheetState extends ConsumerState<ProjectActivitySheet> {
  static const _page = 100;
  final _entries = <ActivityEntry>[];
  bool _loading = true;
  bool _more = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool older = false}) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    setState(() => _loading = true);
    try {
      final page = await ProjectActivityService(client).recent(
        widget.projectCloudId,
        limit: _page,
        before: older && _entries.isNotEmpty ? _entries.last.at : null,
      );
      if (!mounted) return;
      setState(() {
        _entries.addAll(page);
        _more = page.length == _page;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = ProjectActivityService.isMissing(e)
            ? 'Falta la migración 021 en Supabase: aún no se anota la '
                  'actividad.'
            : 'No se pudo cargar la actividad. Revisa la conexión.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final children = <Widget>[
      Text('Actividad', style: AppTypography.titleMedium(palette)),
      Text(widget.projectName, style: AppTypography.caption(palette)),
      const SizedBox(height: AppSpacing.md),
    ];
    if (_error != null) {
      children.add(Text(_error!, style: AppTypography.caption(palette)));
    } else if (_entries.isEmpty && !_loading) {
      children.add(
        Text(
          'Aún no hay cambios anotados. Se anotan al sincronizar, a partir de '
          'esta versión.',
          style: AppTypography.caption(palette),
        ),
      );
    }
    String? day;
    for (final e in _entries) {
      final d = _dayLabel(e.at);
      if (d != day) {
        day = d;
        children.add(
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.xs,
            ),
            child: Text(d, style: AppTypography.label(palette)),
          ),
        );
      }
      children.add(_Row(entry: e));
    }
    if (_loading) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (_more) {
      children.add(
        TextButton(
          onPressed: () => _load(older: true),
          child: const Text('Ver más antiguos'),
        ),
      );
    }
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: children,
        ),
      ),
    );
  }

  static String _dayLabel(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    if (day == today) return 'Hoy';
    if (day == today.subtract(const Duration(days: 1))) return 'Ayer';
    return '${day.day}-${day.month}-${day.year}';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final icon = switch (entry.action) {
      'added' => Icons.add_circle_outline,
      'removed' => Icons.remove_circle_outline,
      _ => Icons.edit_outlined,
    };
    final hm =
        '${entry.at.hour.toString().padLeft(2, '0')}:'
        '${entry.at.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry.sentence,
              style: AppTypography.bodyMedium(palette),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            entry.device == null ? hm : '$hm · ${entry.device}',
            style: AppTypography.caption(palette),
          ),
        ],
      ),
    );
  }
}
