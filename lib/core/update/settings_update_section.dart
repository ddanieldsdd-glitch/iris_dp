import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/app_version_sync.dart';
import '../cloud/cloud_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
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
  String? _installedVersion;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final label = await currentAppVersionLabel();
    if (mounted) setState(() => _installedVersion = label);
  }

  Future<void> _checkUpdates() async {
    await ref.read(appUpdateProvider.notifier).check(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final user = ref.watch(currentUserProvider);
    final update = ref.watch(appUpdateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Actualizaciones', style: AppTypography.titleMedium(palette)),
        const SizedBox(height: AppSpacing.sm),
        if (_installedVersion != null)
          Text(
            'Versión instalada: $_installedVersion',
            style: AppTypography.bodyMedium(palette),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'IRIS DP comprueba la nube si hay una versión nueva. '
          'El instalador se descarga desde GitHub.',
          style: AppTypography.caption(palette),
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
            'Nueva versión ${release.version} disponible',
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

    return Row(
      children: [
        Icon(Icons.check_circle_outline, color: palette.accent, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Tienes la última versión',
            style: AppTypography.bodyMedium(palette),
          ),
        ),
      ],
    );
  }
}
