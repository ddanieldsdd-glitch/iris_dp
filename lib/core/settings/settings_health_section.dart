import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../cloud/cloud_providers.dart';
import '../cloud/connectivity_status_provider.dart';
import '../cloud/cloud_runtime_config.dart';
import '../cloud/supabase_health_check.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import '../update/app_release.dart';
import '../update/app_release_service.dart';
import '../update/app_update_providers.dart';
import '../update/update_actions_row.dart';

/// Panel de salud: conectividad, Supabase, versiones y descargas.
class SettingsHealthSection extends ConsumerStatefulWidget {
  const SettingsHealthSection({super.key});

  @override
  ConsumerState<SettingsHealthSection> createState() =>
      _SettingsHealthSectionState();
}

class _SettingsHealthSectionState extends ConsumerState<SettingsHealthSection> {
  SupabaseHealthResult? _health;
  AppRelease? _ipadRelease;
  String? _installedVersion;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final health = await checkSupabaseReachability();
    final ipad = await fetchIpadRelease(
      client: ref.read(supabaseClientProvider),
    );
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _health = health;
        _ipadRelease = ipad;
        _installedVersion = '${info.version} (${info.buildNumber})';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!CloudRuntimeConfig.isActive) return const SizedBox.shrink();

    final palette = context.palette;
    final online = ref.watch(isOnlineProvider);
    final update = ref.watch(appUpdateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Estado del sistema', style: AppTypography.titleMedium(palette)),
        const SizedBox(height: AppSpacing.sm),
        if (_loading)
          const LinearProgressIndicator()
        else ...[
          _HealthRow(
            label: 'Versión instalada',
            value: _installedVersion ?? '—',
            ok: true,
          ),
          _HealthRow(
            label: 'Internet',
            value: online ? 'Conectado' : 'Sin conexión',
            ok: online,
          ),
          _HealthRow(
            label: 'Supabase',
            value: _health?.ok == true ? 'Accesible' : (_health?.message ?? '—'),
            ok: _health?.ok == true,
          ),
          if (update.availableRelease != null)
            _HealthRow(
              label: 'Actualización',
              value: 'v${update.availableRelease!.version} disponible',
              ok: false,
            ),
          if (!Platform.isIOS && _ipadRelease != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Instalar en iPad',
              style: AppTypography.label(palette),
            ),
            const SizedBox(height: AppSpacing.sm),
            IpadDownloadLinkRow(
              downloadUrl: _ipadRelease!.downloadUrl,
              version: _ipadRelease!.version,
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Actualizar diagnóstico',
          icon: Icons.refresh,
          variant: AppButtonVariant.secondary,
          onTap: _loading ? null : _refresh,
        ),
      ],
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final String value;
  final bool ok;

  const _HealthRow({
    required this.label,
    required this.value,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.info_outline,
            size: 16,
            color: ok ? palette.success : palette.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTypography.caption(palette),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
