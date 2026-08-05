import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../cloud/supabase_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_update_providers.dart';
import 'update_actions_row.dart';

/// Banner cuando hay una versión más nueva en GitHub (metadatos en Supabase).
class UpdateAvailableBanner extends ConsumerWidget {
  const UpdateAvailableBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!SupabaseConfig.isConfigured) return const SizedBox.shrink();

    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final update = ref.watch(appUpdateProvider);
    final release = update.availableRelease;
    if (release == null) return const SizedBox.shrink();

    final palette = context.palette;

    return Material(
      color: palette.accent.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.system_update_alt, color: palette.accent),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nueva versión ${release.version} disponible',
                    style: AppTypography.titleMedium(palette),
                  ),
                  Text(
                    release.releaseNotes?.isNotEmpty == true
                        ? release.releaseNotes!
                        : 'Descarga e instala la actualización. '
                            'Tus proyectos siguen en la nube.',
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            UpdateActionsRow(release: release),
          ],
        ),
      ),
    );
  }
}
