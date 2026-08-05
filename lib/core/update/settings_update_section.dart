import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../storage/app_storage_config.dart';
import '../storage/legacy_storage_discovery.dart';
import '../storage/storage_relocation_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import 'app_update_checker.dart';
import 'app_update_providers.dart';
import 'update_actions_row.dart';
import '../../features/auth/auth_screen.dart';

/// Sección de Ajustes para comprobar actualizaciones manualmente.
class SettingsUpdateSection extends ConsumerStatefulWidget {
  const SettingsUpdateSection({super.key});

  @override
  ConsumerState<SettingsUpdateSection> createState() =>
      _SettingsUpdateSectionState();
}

class _SettingsUpdateSectionState extends ConsumerState<SettingsUpdateSection> {
  Future<void> _checkUpdates() async {
    await ref.read(appUpdateProvider.notifier).check(force: true);
  }

  Future<void> _scanLegacyStorage() async {
    final proposal = await LegacyStorageDiscovery.findRelocationProposal();
    if (!mounted) return;

    if (proposal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay datos en otras ubicaciones que mover.'),
        ),
      );
      return;
    }

    await runStorageRelocationFlow(context, proposal);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final user = ref.watch(currentUserProvider);
    final update = ref.watch(appUpdateProvider);
    final installedLabel = update.localVersionLabel.isNotEmpty
        ? update.localVersionLabel
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Actualizaciones', style: AppTypography.titleMedium(palette)),
        const SizedBox(height: AppSpacing.sm),
        if (installedLabel != null)
          Text(
            'Versión en ejecución: $installedLabel',
            style: AppTypography.bodyMedium(palette),
          )
        else
          Text(
            'Pulsa «Buscar actualizaciones» para leer la versión instalada.',
            style: AppTypography.caption(palette),
          ),
        if (update.remoteVersionLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            'Última publicada en nube: ${update.remoteVersionLabel}',
            style: AppTypography.caption(palette),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          'La versión en ejecución es la del binario instalado (.app / .exe). '
          'Si compilaste código nuevo sin reinstalar, seguirá mostrando la anterior.',
          style: AppTypography.caption(palette).copyWith(
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (user == null) ...[
          Text(
            'Inicia sesión para comprobar si hay actualizaciones.',
            style: AppTypography.caption(palette),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await openAuthScreen(context);
            },
            icon: const Icon(Icons.login),
            label: const Text('Iniciar sesión'),
          ),
        ] else ...[
          AppButton(
            label: update.checking
                ? 'Comprobando…'
                : 'Buscar actualizaciones',
            icon: Icons.system_update_alt,
            onTap: update.checking ? null : _checkUpdates,
            loading: update.checking,
          ),
          if (update.checkCompleted && !update.checking) ...[
            const SizedBox(height: AppSpacing.md),
            _buildCheckResult(context, palette, update),
          ],
        ],
        if (AppStorageConfig.isConfigured) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Datos del proyecto', style: AppTypography.titleMedium(palette)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Carpeta actual: ${AppStorageConfig.current!.documentsPath}',
            style: AppTypography.caption(palette).copyWith(
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Buscar datos en otras ubicaciones',
            icon: Icons.folder_shared_outlined,
            variant: AppButtonVariant.secondary,
            onTap: _scanLegacyStorage,
          ),
        ],
      ],
    );
  }

  Widget _buildCheckResult(
    BuildContext context,
    AppPalette palette,
    AppUpdateState update,
  ) {
    if (update.error != null) {
      return Text(
        'No se pudo comprobar: ${update.error}',
        style: AppTypography.caption(palette).copyWith(color: palette.error),
      );
    }

    final release = update.availableRelease;
    if (release != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nueva versión ${release.version} (${release.buildNumber}) disponible',
            style: AppTypography.label(palette),
          ),
          if (release.releaseNotes?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              release.releaseNotes!,
              style: AppTypography.caption(palette),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          UpdateActionsRow(
            release: release,
            showDismissLater: false,
          ),
        ],
      );
    }

    if (update.remoteLatest == null) {
      return Text(
        'No hay releases registradas en Supabase para '
        '${currentReleasePlatform()}. Publica un tag (v*) o ejecuta '
        'register_app_release.sh.',
        style: AppTypography.caption(palette).copyWith(color: palette.warning),
      );
    }

    if (update.installedIsNewerThanPublished) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu app (${update.localVersionLabel}) es más reciente que la '
            'última publicada en nube (${update.remoteVersionLabel}).',
            style: AppTypography.bodyMedium(palette).copyWith(
              color: palette.warning,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Registra la versión en Supabase tras crear el GitHub Release, '
            'o reinstala el .dmg/.exe del release publicado.',
            style: AppTypography.caption(palette),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: palette.accent, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Tienes la última versión publicada',
                style: AppTypography.bodyMedium(palette),
              ),
            ),
          ],
        ),
        if (update.skippedThrottle) ...[
          const SizedBox(height: 4),
          Text(
            'Comprobación reciente en caché (máx. 1/día). '
            'El botón fuerza consulta completa.',
            style: AppTypography.caption(palette),
          ),
        ],
      ],
    );
  }
}
