import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import 'sidestore_install_store.dart';

/// Guía rápida para instalar/actualizar con SideStore.
class SideStoreGuideSheet extends StatelessWidget {
  final String? ipaDownloadUrl;

  const SideStoreGuideSheet({super.key, this.ipaDownloadUrl});

  static Future<void> show(
    BuildContext context, {
    String? ipaDownloadUrl,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SideStoreGuideSheet(ipaDownloadUrl: ipaDownloadUrl),
    );
  }

  Future<void> _openIpaUrl() async {
    final url = ipaDownloadUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    await SideStoreInstallStore.markInstalledNow();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Instalar con SideStore',
                style: AppTypography.titleLarge(palette),
              ),
              const SizedBox(height: AppSpacing.md),
              const _Step(
                number: 1,
                title: 'Configura SideStore (solo la primera vez)',
                body:
                    'En el Mac: instala SideServer y empareja tu iPad por USB. '
                    'En el iPad: instala SideStore desde sidestore.io.',
              ),
              const _Step(
                number: 2,
                title: 'Descarga el IPA',
                body:
                    'Pulsa «Descargar IPA». Safari guardará el archivo. '
                    'Si ya lo tienes, ábrelo desde Archivos.',
              ),
              const _Step(
                number: 3,
                title: 'Abrir con SideStore',
                body:
                    'Compartir → SideStore, o arrastra el .ipa en SideStore. '
                    'SideStore re-firma la app con tu Apple ID.',
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: palette.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.warning.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'Con Apple ID gratuito la firma dura ~7 días. Abre SideStore '
                  'en Wi‑Fi antes de que caduque para refrescar automáticamente.',
                  style: AppTypography.caption(palette),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (ipaDownloadUrl != null && ipaDownloadUrl!.isNotEmpty)
                AppButton(
                  label: 'Descargar IPA',
                  icon: Icons.download_outlined,
                  onTap: _openIpaUrl,
                ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String body;

  const _Step({
    required this.number,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: palette.accent.withValues(alpha: 0.15),
            child: Text(
              '$number',
              style: AppTypography.caption(palette).copyWith(
                color: palette.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.label(palette)),
                const SizedBox(height: 2),
                Text(body, style: AppTypography.caption(palette)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
