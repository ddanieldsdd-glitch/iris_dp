import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cloud/app_version_sync.dart';
import '../cloud/cloud_providers.dart';
import '../cloud/supabase_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import 'app_update_providers.dart';

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
                        : 'Descarga la actualización desde GitHub e instala '
                            'como siempre. Tus proyectos siguen en la nube.',
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppButton(
                  label: 'Descargar',
                  icon: Icons.download_outlined,
                  onTap: () => _openDownload(release.downloadUrl),
                ),
                AppButton(
                  label: 'Más tarde',
                  variant: AppButtonVariant.secondary,
                  onTap: () =>
                      ref.read(appUpdateProvider.notifier).dismissLater(),
                ),
                AppButton(
                  label: 'Ya actualicé',
                  variant: AppButtonVariant.secondary,
                  onTap: () => _onAlreadyUpdated(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDownload(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _onAlreadyUpdated(BuildContext context, WidgetRef ref) async {
    await ref.read(appUpdateProvider.notifier).markUpdated();
    final syncResult = await syncAfterAppUpdateIfNeeded(ref);
    if (syncResult.message != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(syncResult.message!)),
      );
    }
  }
}
