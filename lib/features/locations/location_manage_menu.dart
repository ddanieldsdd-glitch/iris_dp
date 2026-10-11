import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'location_admin.dart';

/// Menú «⋯» de una localización o de un set suelto: renombrar, meter en
/// otra localización o unir, y eliminar. Antes de aplicar avisa de las
/// escenas y planos del guion técnico a los que afecta.
class LocationManageMenu extends ConsumerWidget {
  final int projectId;

  /// La localización; nula si es un set suelto.
  final LocationSite? site;

  /// El set suelto, cuando no hay localización.
  final LocationBasePlan? looseSet;
  final Color? iconColor;

  const LocationManageMenu({
    super.key,
    required this.projectId,
    this.site,
    this.looseSet,
    this.iconColor,
  }) : assert(site != null || looseSet != null);

  String get _name => site?.name ?? looseSet!.locationName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return PopupMenuButton<String>(
      tooltip: 'Renombrar, unir o eliminar',
      color: palette.surfaceElevated,
      icon: Icon(Icons.more_horiz, color: iconColor ?? palette.textSecondary),
      onSelected: (action) => _run(context, ref, action),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'rename', child: Text('Renombrar')),
        PopupMenuItem(
          value: 'merge',
          child: Text(
            site == null
                ? 'Meter en una localización…'
                : 'Unir con otra localización…',
          ),
        ),
        const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
      ],
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, String action) async {
    final db = ref.read(databaseProvider);
    final admin = LocationAdmin(db);
    final usage = site != null
        ? await admin.usageOfSite(site!.id)
        : await admin.usageOfSet(looseSet!.id);
    if (!context.mounted) return;
    switch (action) {
      case 'rename':
        final name = await _askName(context, usage);
        if (name == null) return;
        site != null
            ? await admin.renameSite(site!.id, name)
            : await admin.renameSet(looseSet!.id, name);
      case 'merge':
        await _merge(context, db, admin, usage);
      case 'delete':
        await _delete(context, db, admin, usage);
    }
  }

  Future<String?> _askName(BuildContext context, LocationUsage usage) async {
    final palette = context.palette;
    final controller = TextEditingController(text: _name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: const Text('Renombrar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (v) => Navigator.pop(context, v.trim()),
            ),
            if (usage.inUse) ...[
              const SizedBox(height: 12),
              Text(
                'La usan ${usage.summary}: el nombre cambiará también en '
                'el título de esas escenas.',
                style: AppTypography.caption(palette),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Renombrar'),
          ),
        ],
      ),
    );
    return name == null || name.isEmpty || name == _name ? null : name;
  }

  /// Elige una localización de destino (distinta de esta).
  Future<LocationSite?> _pickSite(
    BuildContext context,
    AppDatabase db, {
    required String title,
    required String note,
  }) async {
    final palette = context.palette;
    final sites = [
      for (final s in await db.watchSitesForProject(projectId).first)
        if (s.id != site?.id) s,
    ];
    if (!context.mounted) return null;
    return showDialog<LocationSite>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text(title),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(note, style: AppTypography.caption(palette)),
          ),
          if (sites.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Text(
                'No hay otra localización en el proyecto.',
                style: AppTypography.bodyMedium(palette),
              ),
            ),
          for (final target in sites)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, target),
              child: Text(target.name),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// Pasa todo lo de esta localización (o este set) a [target] y la quita.
  Future<void> _moveInto(
    AppDatabase db,
    LocationAdmin admin,
    LocationSite target,
  ) async {
    final targetSets = await db.watchSetsForSite(target.id).first;
    LocationBasePlan? twin(String name) => targetSets
        .where(
          (s) =>
              s.locationName.trim().toLowerCase() == name.trim().toLowerCase(),
        )
        .firstOrNull;
    // El set que es «la localización entera» del destino.
    final whole = twin(target.name);

    final moving = site != null
        ? await db.watchSetsForSite(site!.id).first
        : [looseSet!];
    for (final set in moving) {
      final isWhole =
          set.locationName.trim().toLowerCase() == _name.trim().toLowerCase();
      final into = twin(set.locationName) ?? (isWhole ? whole : null);
      if (into != null) {
        await admin.mergeSetInto(set.id, into.id);
      } else {
        await admin.moveSetToSite(set.id, target.id);
      }
    }
    if (site != null) await db.deleteSite(site!.id);
  }

  Future<void> _merge(
    BuildContext context,
    AppDatabase db,
    LocationAdmin admin,
    LocationUsage usage,
  ) async {
    final target = await _pickSite(
      context,
      db,
      title: site == null ? 'Meter «$_name» en…' : 'Unir «$_name» con…',
      note: usage.inUse
          ? 'Sus ${usage.summary} pasan a la localización que elijas, con '
                'sus plantas y su luz.'
          : 'No la usa ninguna escena: solo se mueve lo escrito en ella.',
    );
    if (target == null) return;
    await _moveInto(db, admin, target);
  }

  Future<void> _delete(
    BuildContext context,
    AppDatabase db,
    LocationAdmin admin,
    LocationUsage usage,
  ) async {
    final palette = context.palette;
    if (usage.inUse) {
      // En uso: sus escenas tienen que ir a alguna parte.
      final target = await _pickSite(
        context,
        db,
        title: '«$_name» está en uso',
        note:
            'La usan ${usage.summary}. Para eliminarla, elige a qué '
            'localización pasan esas escenas.',
      );
      if (target == null) return;
      await _moveInto(db, admin, target);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text('¿Eliminar «$_name»?'),
        content: const Text(
          'No la usa ninguna escena del guion técnico. Se borra con lo que '
          'tenga escrito en la biblia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (site != null) {
      for (final set in await db.watchSetsForSite(site!.id).first) {
        await admin.deleteUnusedSet(set.id);
      }
      await db.deleteSite(site!.id);
    } else {
      await admin.deleteUnusedSet(looseSet!.id);
    }
  }
}
