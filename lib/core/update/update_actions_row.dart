import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cloud/app_version_sync.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import 'app_release.dart';
import 'app_update_installer.dart';
import 'app_update_providers.dart';
import 'sidestore_guide_sheet.dart';
import 'sidestore_install_store.dart';

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

Future<void> _downloadIpa(BuildContext context, AppRelease release) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _UpdateDownloadDialog(
      release: release,
      onComplete: (path) async {
        await SideStoreInstallStore.markInstalledNow();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'IPA descargado en ${path.split('/').last}. '
                'Ábrelo con SideStore desde Archivos.',
              ),
            ),
          );
        }
      },
    ),
  );
}

Future<void> _runDesktopUpdate(
  BuildContext context,
  WidgetRef ref,
  AppRelease release,
) async {
  if (!supportsInAppUpdate) {
    await openAppReleaseDownload(release.downloadUrl);
    return;
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _UpdateDownloadDialog(release: release),
  );
}

class _UpdateDownloadDialog extends StatefulWidget {
  final AppRelease release;
  final void Function(String path)? onComplete;

  const _UpdateDownloadDialog({
    required this.release,
    this.onComplete,
  });

  @override
  State<_UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<_UpdateDownloadDialog> {
  AppUpdateDownloadProgress? _progress;
  String _status = 'Descargando…';
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final path = await downloadAppRelease(
        widget.release,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _status = 'Abriendo instalador…');
      if (widget.onComplete != null) {
        if (mounted) {
          Navigator.of(context).pop();
          widget.onComplete!(path);
        }
        return;
      }
      await launchDownloadedUpdate(path);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fraction = _progress?.fraction;

    return AlertDialog(
      title: const Text('Descargando actualización'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error == null) ...[
            if (fraction != null)
              LinearProgressIndicator(value: fraction)
            else
              const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.sm),
            Text(_status, style: AppTypography.bodyMedium(palette)),
          ] else
            Text(
              'Error: $_error',
              style: AppTypography.bodyMedium(palette).copyWith(
                color: palette.error,
              ),
            ),
        ],
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
      ],
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
    if (Platform.isIOS) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          AppButton(
            label: 'Descargar IPA',
            icon: Icons.download_outlined,
            onTap: () => _downloadIpa(context, release),
          ),
          AppButton(
            label: 'Guía SideStore',
            variant: AppButtonVariant.secondary,
            onTap: () => SideStoreGuideSheet.show(
              context,
              ipaDownloadUrl: release.downloadUrl,
            ),
          ),
          if (showDismissLater)
            AppButton(
              label: 'Más tarde',
              variant: AppButtonVariant.secondary,
              onTap: () => ref.read(appUpdateProvider.notifier).dismissLater(),
            ),
        ],
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (supportsInAppUpdate)
          AppButton(
            label: 'Actualizar ahora',
            icon: Icons.system_update_alt,
            onTap: () => _runDesktopUpdate(context, ref, release),
          )
        else
          AppButton(
            label: 'Descargar',
            icon: Icons.download_outlined,
            onTap: () => openAppReleaseDownload(release.downloadUrl),
          ),
        AppButton(
          label: 'Abrir en navegador',
          variant: AppButtonVariant.secondary,
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

/// Enlace para compartir el IPA de iPad (Mac/Windows).
class IpadDownloadLinkRow extends StatelessWidget {
  final String downloadUrl;
  final String version;

  const IpadDownloadLinkRow({
    super.key,
    required this.downloadUrl,
    required this.version,
  });

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: downloadUrl));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace IPA copiado al portapapeles')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppButton(
          label: 'Descargar para iPad ($version)',
          icon: Icons.tablet_mac_outlined,
          variant: AppButtonVariant.secondary,
          onTap: () => openAppReleaseDownload(downloadUrl),
        ),
        AppButton(
          label: 'Copiar enlace',
          variant: AppButtonVariant.secondary,
          onTap: () => _copyLink(context),
        ),
      ],
    );
  }
}
