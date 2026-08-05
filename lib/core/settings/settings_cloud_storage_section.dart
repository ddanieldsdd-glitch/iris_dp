import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloudinary_config.dart';
import '../cloud/supabase_config.dart';
import '../sync/media_sync_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Métricas de almacenamiento en Cloudinary (Ajustes).
class SettingsCloudStorageSection extends ConsumerWidget {
  const SettingsCloudStorageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    if (!SupabaseConfig.isConfigured) {
      return const SizedBox.shrink();
    }

    final progress = ref.watch(mediaUploadProgressProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Almacenamiento en nube', style: AppTypography.titleMedium(palette)),
        const SizedBox(height: AppSpacing.sm),
        if (!CloudinaryConfig.isConfigured)
          Text(
            'Cloudinary no configurado. Las imágenes solo se guardan en local.',
            style: AppTypography.caption(palette).copyWith(
              color: palette.warning,
            ),
          )
        else
          progress.when(
            data: (p) {
              if (!p.hasWork && p.completed == 0) {
                return Text(
                  'Cloudinary activo · sin subidas pendientes',
                  style: AppTypography.caption(palette),
                );
              }
              final savedMb =
                  (p.bytesSaved / 1024 / 1024).toStringAsFixed(1);
              return Text(
                '↑ ${p.pending} pendientes · ${p.completed} subidas'
                '${p.failed > 0 ? ' · ${p.failed} fallidas' : ''}'
                '${p.bytesSaved > 0 ? ' · $savedMb MB ahorrados' : ''}',
                style: AppTypography.caption(palette),
              );
            },
            loading: () => Text(
              'Comprobando cola de imágenes…',
              style: AppTypography.caption(palette),
            ),
            error: (_, __) => Text(
              'Cloudinary activo',
              style: AppTypography.caption(palette),
            ),
          ),
      ],
    );
  }
}
