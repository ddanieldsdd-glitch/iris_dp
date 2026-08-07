import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/connectivity_status_provider.dart';
import '../cloud/cloud_providers.dart';
import '../cloud/cloud_runtime_config.dart';
import '../sync/sync_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Dispara sync al reconectar y muestra banner offline.
class ConnectivityGate extends ConsumerStatefulWidget {
  final Widget child;

  const ConnectivityGate({super.key, required this.child});

  @override
  ConsumerState<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends ConsumerState<ConnectivityGate> {
  NetworkStatus? _previous;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<NetworkStatus>>(connectivityStatusProvider,
        (previous, next) {
      final status = next.value;
      if (status == null) return;

      if (_previous == NetworkStatus.offline &&
          status == NetworkStatus.online) {
        _onReconnect();
      }
      _previous = status;
    });

    return widget.child;
  }

  Future<void> _onReconnect() async {
    if (!CloudRuntimeConfig.isActive) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await ref.read(syncEngineProvider).syncOnStartup();
    } catch (_) {}
  }
}

/// Banner cuando no hay conexión a internet.
class OfflineStatusBanner extends ConsumerWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!CloudRuntimeConfig.isActive) return const SizedBox.shrink();

    final online = ref.watch(isOnlineProvider);
    if (online) return const SizedBox.shrink();

    final palette = context.palette;

    return Material(
      color: palette.warning.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: palette.warning, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Sin conexión — los cambios se guardan localmente',
                style: AppTypography.caption(palette).copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
