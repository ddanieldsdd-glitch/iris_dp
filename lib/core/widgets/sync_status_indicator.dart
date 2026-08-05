import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../cloud/cloud_session.dart';
import '../cloud/supabase_config.dart';
import '../sync/pending_sync_queue_provider.dart';
import '../sync/sync_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../features/auth/auth_screen.dart';

/// Indicador nube / sync en barra superior.
class SyncStatusIndicator extends ConsumerStatefulWidget {
  const SyncStatusIndicator({super.key});

  @override
  ConsumerState<SyncStatusIndicator> createState() =>
      _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends ConsumerState<SyncStatusIndicator> {
  bool _syncing = false;

  Future<void> _runSync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final result =
          await ref.read(syncEngineProvider).syncWithConfirmation(context);
      if (mounted) {
        final msg = result.pendingReview
            ? result.message ?? 'Revisión pendiente'
            : result.message ?? 'Sync: ↑${result.pushed} ↓${result.pulled}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured) {
      return Tooltip(
        message: 'Modo local',
        child: Icon(Icons.storage_outlined,
            size: 18, color: context.palette.textTertiary),
      );
    }

    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return TextButton.icon(
        onPressed: () => openAuthScreen(context),
        icon: Icon(Icons.login, size: 18, color: context.palette.warning),
        label: Text(
          'Iniciar sesión',
          style: AppTypography.caption(context.palette).copyWith(
            color: context.palette.warning,
          ),
        ),
      );
    }

    final pendingCount = ref.watch(pendingSyncQueueCountProvider);

    return FutureBuilder<String?>(
      future: CloudSessionStore.userRole(),
      builder: (context, roleSnap) {
        final role = roleSnap.data;
        final isDp = CloudUserRole.isDp(role);

        return FutureBuilder<DateTime?>(
          future: CloudSessionStore.lastSyncAt(),
          builder: (context, syncSnap) {
            final lastSync = syncSnap.data;
            final queueCount = pendingCount.valueOrNull ?? 0;
            final hasPending = queueCount > 0;
            final iconColor = hasPending
                ? context.palette.warning
                : context.palette.success;

            var tooltip = 'Sincronizar';
            if (lastSync != null) {
              final mins = DateTime.now().difference(lastSync).inMinutes;
              tooltip = mins < 1
                  ? 'Última sync: ahora'
                  : 'Última sync: hace $mins min';
            }
            if (hasPending) {
              tooltip += ' · $queueCount pendiente(s)';
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (role != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      isDp ? 'DP' : 'Director',
                      style: AppTypography.caption(context.palette).copyWith(
                        color: context.palette.accent,
                        fontSize: 10,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: tooltip,
                  icon: _syncing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: iconColor,
                          ),
                        )
                      : Icon(Icons.cloud_sync_outlined,
                          size: 20, color: iconColor),
                  onPressed: _syncing ? null : _runSync,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
