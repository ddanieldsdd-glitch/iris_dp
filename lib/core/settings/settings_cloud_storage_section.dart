import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloudinary_config.dart';
import '../cloud/cloud_runtime_config.dart';
import '../sync/media_sync_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Métricas de cola Cloudinary (Ajustes). El estado base está en CloudLinkPanel.
class SettingsCloudStorageSection extends ConsumerWidget {
  const SettingsCloudStorageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    if (!CloudRuntimeConfig.isActive || !CloudinaryConfig.isConfigured) {
      return const SizedBox.shrink();
    }

    final progress = ref.watch(mediaUploadProgressProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cola de imágenes', style: AppTypography.titleMedium(palette)),
        const SizedBox(height: AppSpacing.sm),
        progress.when(
          data: (p) {
            if (!p.hasWork && p.completed == 0) {
              return Text(
                'Sin subidas pendientes',
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
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
