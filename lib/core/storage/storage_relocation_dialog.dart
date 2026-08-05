import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import 'legacy_storage_discovery.dart';
import 'local_storage_migration_service.dart';

/// Diálogo para mover proyectos detectados en otra ubicación.
Future<bool?> showStorageRelocationDialog(
  BuildContext context,
  StorageRelocationProposal proposal,
) {
  final palette = context.palette;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(
        'Datos encontrados en otra ubicación',
        style: AppTypography.titleLarge(palette),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hay contenido de proyectos guardado fuera de tu carpeta '
              'actual de documentos. ¿Quieres moverlo al almacenamiento '
              'configurado ahora?',
              style: AppTypography.bodyMedium(palette),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Origen', style: AppTypography.label(palette)),
            Text(
              proposal.source.label,
              style: AppTypography.caption(palette),
            ),
            Text(
              proposal.source.documentsPath,
              style: AppTypography.caption(palette).copyWith(
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Destino', style: AppTypography.label(palette)),
            Text(
              proposal.target.documentsPath,
              style: AppTypography.caption(palette).copyWith(
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final reason in proposal.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: palette.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reason,
                        style: AppTypography.caption(palette),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Ahora no'),
        ),
        AppButton(
          label: 'Mover aquí',
          icon: Icons.drive_file_move_outline,
          onTap: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
}

Future<void> runStorageRelocationFlow(
  BuildContext context,
  StorageRelocationProposal proposal,
) async {
  final confirmed = await showStorageRelocationDialog(context, proposal);
  if (confirmed != true) {
    await LocalStorageMigrationService.dismissProposal(
      proposal.source.databasePath,
    );
    return;
  }

  if (!context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  final result = await LocalStorageMigrationService.migrateToCurrentStorage(
    proposal,
  );

  if (context.mounted) Navigator.pop(context);

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final palette = context.palette;
      return AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text(
          result.success ? 'Datos movidos' : 'No se pudo mover',
          style: AppTypography.titleLarge(palette),
        ),
        content: Text(
          result.message,
          style: AppTypography.bodyMedium(palette),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      );
    },
  );
}
