import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_editor.dart';
import 'floor_plan_repository.dart';

const kLightSetupStatuses = ['boceto', 'en_desarrollo', 'definitivo'];

String lightSetupOriginLabel(String origin) => switch (origin) {
  'biblia' => 'Biblia',
  'blush' => 'Blush',
  _ => '',
};

/// Pide un nombre. Devuelve `null` si se cancela o se deja vacío.
Future<String?> askPlanName(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
}) async {
  final palette = context.palette;
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(title, style: AppTypography.titleMedium(palette)),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
  final name = result?.trim();
  return name == null || name.isEmpty ? null : name;
}

/// Esquemas de luz de un set, de una localización o libres (sin ninguno),
/// con los planos que usa cada uno.
class LightSetupStrip extends ConsumerWidget {
  final int projectId;
  final int? setId;
  final int? siteId;
  final Color accentColor;

  const LightSetupStrip({
    super.key,
    required this.projectId,
    required this.accentColor,
    this.setId,
    this.siteId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final palette = context.palette;

    return StreamBuilder<List<LightSetup>>(
      stream: db.watchLightSetupsForProject(projectId),
      builder: (context, setupSnap) {
        final setups = (setupSnap.data ?? [])
            .where(
              (s) =>
                  s.locationBasePlanId == setId && s.locationSiteId == siteId,
            )
            .toList();
        return StreamBuilder<List<Shot>>(
          stream: db.watchShotsForProject(projectId),
          builder: (context, shotSnap) {
            final shots = shotSnap.data ?? [];
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final setup in setups)
                  _LightSetupCard(
                    setup: setup,
                    shotCount: shots
                        .where((s) => s.lightSetupId == setup.id)
                        .length,
                    accentColor: accentColor,
                  ),
                ActionChip(
                  avatar: Icon(Icons.add, size: 16, color: palette.accent),
                  label: const Text('Esquema de luz'),
                  onPressed: () async {
                    final setup = await FloorPlanRepository(db)
                        .createLightSetup(
                          projectId: projectId,
                          setId: setId,
                          siteId: siteId,
                        );
                    if (!context.mounted) return;
                    _open(context, setup);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

void _open(BuildContext context, LightSetup setup) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CameraPlanEditor.lightSetup(
        projectId: setup.projectId,
        lightSetupId: setup.id,
        setupName: setup.name,
      ),
    ),
  );
}

class _LightSetupCard extends ConsumerWidget {
  final LightSetup setup;
  final int shotCount;
  final Color accentColor;

  const _LightSetupCard({
    required this.setup,
    required this.shotCount,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.read(databaseProvider);
    final origin = lightSetupOriginLabel(setup.origin);
    final details = [
      lightSetupStatusLabel(setup.status),
      if (origin.isNotEmpty) origin,
      if (setup.category?.isNotEmpty == true) setup.category!,
      '$shotCount plano${shotCount == 1 ? '' : 's'}',
    ].join(' · ');

    return Material(
      color: accentColor.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _open(context, setup),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                setup.status == 'boceto'
                    ? Icons.draw_outlined
                    : Icons.wb_incandescent_outlined,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(setup.name, style: AppTypography.label(palette)),
                  Text(details, style: AppTypography.caption(palette)),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones del esquema',
                icon: Icon(Icons.more_vert, color: palette.textSecondary),
                onSelected: (action) => _onAction(context, db, action),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Renombrar'),
                  ),
                  const PopupMenuItem(
                    value: 'category',
                    child: Text('Catalogar'),
                  ),
                  for (final status in kLightSetupStatuses)
                    if (status != setup.status)
                      PopupMenuItem(
                        value: 'status:$status',
                        child: Text(
                          'Marcar como ${lightSetupStatusLabel(status).toLowerCase()}',
                        ),
                      ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Duplicar'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Borrar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    AppDatabase db,
    String action,
  ) async {
    if (action.startsWith('status:')) {
      await db.updateLightSetup(
        setup.copyWith(status: action.substring('status:'.length)),
      );
      return;
    }
    switch (action) {
      case 'rename':
        final name = await askPlanName(
          context,
          title: 'Nombre del esquema',
          initial: setup.name,
        );
        if (name != null) await db.updateLightSetup(setup.copyWith(name: name));
      case 'category':
        final palette = context.palette;
        final controller = TextEditingController(text: setup.category ?? '');
        final category = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: palette.surfaceElevated,
            title: Text(
              'Categoría del esquema',
              style: AppTypography.titleMedium(palette),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Noche, exterior día, contraluz…',
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
        if (category != null) {
          final trimmed = category.trim();
          await db.updateLightSetup(
            setup.copyWith(category: Value(trimmed.isEmpty ? null : trimmed)),
          );
        }
      case 'duplicate':
        await FloorPlanRepository(db).duplicateLightSetup(setup);
      case 'delete':
        final palette = context.palette;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: palette.surfaceElevated,
            title: Text(
              '¿Borrar «${setup.name}»?',
              style: AppTypography.titleMedium(palette),
            ),
            content: Text(
              shotCount == 0
                  ? 'Se borra el esquema de luz.'
                  : 'Se borra el esquema de luz. '
                        '$shotCount plano${shotCount == 1 ? '' : 's'} '
                        'se quedará${shotCount == 1 ? '' : 'n'} sin luz.',
              style: AppTypography.bodyMedium(palette),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Borrar'),
              ),
            ],
          ),
        );
        if (confirmed == true) await db.deleteLightSetup(setup.id);
    }
  }
}
