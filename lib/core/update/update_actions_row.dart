import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cloud/app_version_sync.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import 'app_release.dart';
import 'app_update_providers.dart';

Future<void> openAppReleaseDownload(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> markAppUpdatedAndSync(BuildContext context, WidgetRef ref) async {
  await ref.read(appUpdateProvider.notifier).markUpdated();
  final syncResult = await syncAfterAppUpdateIfNeeded(ref);
  if (syncResult.message != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(syncResult.message!)),
    );
  }
}

/// Acciones comunes cuando hay una actualización disponible.
class UpdateActionsRow extends ConsumerWidget {
  final AppRelease release;
  final bool showDismissLater;
  final bool compact;

  const UpdateActionsRow({
    super.key,
    required this.release,
    this.showDismissLater = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppButton(
          label: 'Descargar',
          icon: Icons.download_outlined,
          onTap: () => openAppReleaseDownload(release.downloadUrl),
        ),
        if (showDismissLater)
          AppButton(
            label: 'Más tarde',
            variant: AppButtonVariant.secondary,
            onTap: () => ref.read(appUpdateProvider.notifier).dismissLater(),
          ),
        AppButton(
          label: 'Ya actualicé',
          variant: AppButtonVariant.secondary,
          onTap: () => markAppUpdatedAndSync(context, ref),
        ),
      ],
    );
  }
}
