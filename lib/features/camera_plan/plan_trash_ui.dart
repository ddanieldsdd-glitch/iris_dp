import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'floor_plan_scope.dart';
import 'plan_item_actions.dart';
import 'plan_trash_service.dart';

/// Borra con [delete] y ofrece «Deshacer» un rato. Lo borrado queda además
/// en la Papelera de plantas.
Future<void> deleteWithUndo(
  BuildContext context,
  AppDatabase db, {
  required String done,
  required Future<int?> Function(PlanTrashService trash) delete,
  VoidCallback? onRestored,
}) async {
  // El aviso sobrevive al elemento borrado: se toma antes.
  final messenger = ScaffoldMessenger.maybeOf(context);
  final trash = PlanTrashService(db);
  final trashId = await delete(trash);
  if (trashId == null || messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$done Está en la Papelera de plantas.'),
        duration: const Duration(seconds: 8),
        // Con botón no se queda fijo: se va solo a su tiempo.
        persist: false,
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            final result = await trash.restore(trashId);
            onRestored?.call();
            final notice = result.notice;
            if (notice != null) {
              messenger.showSnackBar(SnackBar(content: Text(notice)));
            }
          },
        ),
      ),
    );
}

/// Pide confirmación (diciendo qué se pierde) y borra la localización con
/// todos sus sets.
Future<void> confirmDeleteSite(
  BuildContext context,
  AppDatabase db,
  LocationSite site,
) async {
  final impact = await PlanTrashService(db).impactOfSite(site.id);
  if (!context.mounted) return;
  final ok = await confirmPlanDelete(
    context,
    title: '¿Borrar la localización «${site.name}»?',
    body:
        'Se borra la localización con su plano maestro. '
        '${impact.describe()}',
  );
  if (!ok || !context.mounted) return;
  await deleteWithUndo(
    context,
    db,
    done: 'Localización «${site.name}» borrada.',
    delete: (trash) => trash.deleteSite(site.id),
  );
}

/// Pide confirmación (diciendo qué planos pierden la planta) y borra el set
/// con sus esquemas.
Future<void> confirmDeleteSet(
  BuildContext context,
  AppDatabase db,
  LocationBasePlan set,
) async {
  final impact = await PlanTrashService(db).impactOfSet(set.id);
  if (!context.mounted) return;
  final ok = await confirmPlanDelete(
    context,
    title: '¿Borrar el set «${set.locationName}»?',
    body:
        'Se borra el set con su planta. ${impact.describe()} '
        'También desaparece de Localizaciones.',
  );
  if (!ok || !context.mounted) return;
  await deleteWithUndo(
    context,
    db,
    done: 'Set «${set.locationName}» borrado.',
    delete: (trash) => trash.deleteSet(set.id),
  );
}

/// Vacía una planta para empezarla de cero, pidiendo confirmación.
/// Devuelve si se vació.
Future<bool> confirmClearPlan(
  BuildContext context,
  AppDatabase db, {
  required FloorPlanScope scope,
  required int id,
  required String name,
  VoidCallback? onRestored,
}) async {
  final what = switch (scope) {
    FloorPlanScope.site =>
      'el plano maestro (paredes, puertas, terreno, props), su dibujo y '
          'sus imágenes. '
          'Los sets y sus zonas se quedan',
    FloorPlanScope.set => 'la planta del set, su dibujo y sus imágenes. Sus esquemas y '
        'planos se quedan',
    FloorPlanScope.lightSetup => 'las luces, el grip, el ambiente y las '
        'imágenes del esquema. Sus planos siguen asignados',
    FloorPlanScope.shot => 'las cámaras, los actores, las imágenes y los '
        'ajustes de luz propios del plano. Sigue en su set y su esquema',
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final palette = ctx.palette;
      return AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text(
          '¿Vaciar la planta de «$name»?',
          style: AppTypography.titleMedium(palette),
        ),
        content: Text(
          'Se quita $what. Podrás recuperarla desde la Papelera de plantas.',
          style: AppTypography.bodyMedium(palette),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Vaciar', style: TextStyle(color: palette.error)),
          ),
        ],
      );
    },
  );
  if (ok != true || !context.mounted) return false;
  var cleared = false;
  await deleteWithUndo(
    context,
    db,
    done: 'Planta de «$name» vaciada.',
    onRestored: onRestored,
    delete: (trash) async {
      final id0 = await trash.clearPlan(scope, id);
      cleared = id0 != null;
      return id0;
    },
  );
  if (!cleared && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('La planta ya estaba vacía.')),
    );
  }
  return cleared;
}

/// Papelera de plantas: lo borrado o vaciado en los últimos 30 días.
class PlanTrashScreen extends ConsumerStatefulWidget {
  final int projectId;

  const PlanTrashScreen({super.key, required this.projectId});

  static Future<void> open(BuildContext context, int projectId) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlanTrashScreen(projectId: projectId),
        ),
      );

  @override
  ConsumerState<PlanTrashScreen> createState() => _PlanTrashScreenState();
}

class _PlanTrashScreenState extends ConsumerState<PlanTrashScreen> {
  late final PlanTrashService _trash = PlanTrashService(
    ref.read(databaseProvider),
  );

  @override
  void initState() {
    super.initState();
    _trash.purgeExpired(widget.projectId);
  }

  Future<void> _restore(PlanTrashEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await _trash.restore(entry.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.notice ?? '${entry.label} ha vuelto a su sitio.'),
      ),
    );
  }

  Future<void> _purge(PlanTrashEntry entry) async {
    final ok = await _confirm(
      '¿Borrar para siempre ${entry.label}?',
      'No se podrá recuperar.',
    );
    if (ok) await _trash.purge(entry.id);
  }

  Future<void> _empty() async {
    final ok = await _confirm(
      '¿Vaciar la papelera?',
      'Todo lo que hay en ella se borra para siempre.',
    );
    if (ok) await _trash.emptyTrash(widget.projectId);
  }

  Future<bool> _confirm(String title, String body) async {
    final palette = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text(title, style: AppTypography.titleMedium(palette)),
        content: Text(body, style: AppTypography.bodyMedium(palette)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Borrar para siempre',
              style: TextStyle(color: palette.error),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return StreamBuilder<List<PlanTrashEntry>>(
      stream: _trash.watch(widget.projectId),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <PlanTrashEntry>[];
        return Scaffold(
          appBar: AppBar(
            backgroundColor: palette.surface,
            title: Text(
              'Papelera de plantas',
              style: AppTypography.titleLarge(palette),
            ),
            actions: [
              if (entries.isNotEmpty)
                TextButton(
                  onPressed: _empty,
                  child: Text(
                    'Vaciar papelera',
                    style: TextStyle(color: palette.error),
                  ),
                ),
            ],
          ),
          body: entries.isEmpty
              ? Center(
                  child: Text(
                    snapshot.hasData
                        ? 'No hay nada en la papelera.\n'
                              'Lo que borres o vacíes en la planta se guarda '
                              'aquí 30 días.'
                        : '',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium(
                      palette,
                    ).copyWith(color: palette.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _TrashRow(
                    entry: entries[i],
                    onRestore: () => _restore(entries[i]),
                    onPurge: () => _purge(entries[i]),
                  ),
                ),
        );
      },
    );
  }
}

class _TrashRow extends StatelessWidget {
  final PlanTrashEntry entry;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  const _TrashRow({
    required this.entry,
    required this.onRestore,
    required this.onPurge,
  });

  IconData get _icon => switch (entry.kind) {
    PlanTrashService.kindSite => Icons.map_outlined,
    PlanTrashService.kindSet => Icons.crop_square,
    PlanTrashService.kindLightSetup => Icons.wb_incandescent_outlined,
    _ => Icons.layers_clear_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final local = entry.deletedAt.toLocal();
    final when =
        '${local.day}/${local.month} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    final left = PlanTrashService.keepFor.inDays -
        DateTime.now().difference(entry.deletedAt).inDays;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(_icon, color: palette.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label, style: AppTypography.bodyLarge(palette)),
                const SizedBox(height: 2),
                Text(
                  [
                    ?entry.detail,
                    when,
                    'se borra en ${left < 1 ? 1 : left} '
                        'día${left == 1 ? '' : 's'}',
                  ].join(' · '),
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.textTertiary),
                ),
              ],
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Restaurar'),
            onPressed: onRestore,
          ),
          IconButton(
            tooltip: 'Borrar para siempre',
            icon: Icon(Icons.delete_forever_outlined, color: palette.error),
            onPressed: onPurge,
          ),
        ],
      ),
    );
  }
}

/// Menú «⋯» de una localización en la planta: vaciar su plano maestro o
/// borrarla con todos sus sets.
class SiteMenuButton extends ConsumerWidget {
  final LocationSite site;

  const SiteMenuButton({super.key, required this.site});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return PopupMenuButton<String>(
      tooltip: 'Opciones de la localización',
      icon: Icon(Icons.more_horiz, color: palette.textSecondary),
      onSelected: (action) {
        final db = ref.read(databaseProvider);
        switch (action) {
          case 'clear':
            confirmClearPlan(
              context,
              db,
              scope: FloorPlanScope.site,
              id: site.id,
              name: site.name,
            );
          case 'delete':
            confirmDeleteSite(context, db, site);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'clear',
          child: Text('Vaciar plano maestro…'),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            'Borrar localización…',
            style: TextStyle(color: palette.error),
          ),
        ),
      ],
    );
  }
}
