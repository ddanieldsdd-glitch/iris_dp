import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'plan_item_actions.dart';
import 'plan_target.dart';

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

/// Menú «⋯» de un esquema de luz: renombrar, catalogar, estado, copiar,
/// duplicar, pegar al lado y borrar.
class LightSetupMenuButton extends ConsumerWidget {
  final LightSetup setup;
  final int shotCount;

  const LightSetupMenuButton({
    super.key,
    required this.setup,
    required this.shotCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.read(databaseProvider);
    return ValueListenableBuilder<PlanClip?>(
      valueListenable: PlanBoardClipboard.current,
      builder: (context, clip, _) => PopupMenuButton<String>(
        tooltip: 'Opciones del esquema',
        icon: Icon(Icons.more_vert, color: palette.textSecondary),
        onSelected: (action) => _onAction(context, db, action),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'rename', child: Text('Renombrar')),
          const PopupMenuItem(value: 'category', child: Text('Catalogar')),
          for (final status in kLightSetupStatuses)
            if (status != setup.status)
              PopupMenuItem(
                value: 'status:$status',
                child: Text(
                  'Marcar como ${lightSetupStatusLabel(status).toLowerCase()}',
                ),
              ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'copy',
            child: PlanMenuRow('Copiar', '⌘C'),
          ),
          const PopupMenuItem(
            value: 'duplicate',
            child: PlanMenuRow('Duplicar', '⌘D'),
          ),
          if (clip?.kind == PlanClipKind.setup)
            PopupMenuItem(
              value: 'paste',
              child: PlanMenuRow('Pegar «${clip!.name}» al lado', '⌘V'),
            ),
          const PopupMenuItem(
            value: 'delete',
            child: PlanMenuRow('Borrar', 'Supr'),
          ),
        ],
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
      case 'copy':
        LightSetupActions(context, db, setup, shotCount).copy();
      case 'duplicate':
        await LightSetupActions(context, db, setup, shotCount).duplicate();
      case 'paste':
        await LightSetupActions(context, db, setup, shotCount).pasteBeside();
      case 'delete':
        await LightSetupActions(context, db, setup, shotCount).delete();
    }
  }
}
