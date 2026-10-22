import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/profile_providers.dart';
import '../cloud/cloud_session.dart';
import '../cloud/cloud_runtime_config.dart';
import '../cloud/cloudinary_config.dart';
import '../sync/pending_sync_queue_provider.dart';
import '../sync/media_sync_providers.dart';
import '../sync/sync_engine.dart';
import 'sync/sync_conflict_history_sheet.dart';
import 'sync/sync_flow_coordinator.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

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
      final result = await SyncFlowCoordinator.runWithConfirmation(
        context,
        ref,
      );
      if (mounted) {
        final msg = result.pendingReview
            ? result.message ?? 'Revisión pendiente'
            : result.message ?? 'Sync: ↑${result.pushed} ↓${result.pulled}';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!CloudRuntimeConfig.isActive) {
      return Tooltip(
        message: 'Modo local',
        child: Icon(
          Icons.storage_outlined,
          size: 18,
          color: context.palette.textTertiary,
        ),
      );
    }

    // Sin sesión, el aviso «Iniciar sesión» lo da el avatar de la cuenta.
    if (ref.watch(signedInAccountProvider) == null) {
      return const SizedBox.shrink();
    }

    final pendingCount = ref.watch(pendingSyncQueueCountProvider);
    final lastEdit = ref.watch(lastCloudEditProvider);
    final unseen = ref.watch(unseenConflictCountProvider).valueOrNull ?? 0;
    final mediaProgress = ref.watch(mediaUploadProgressProvider);
    final mediaPending = mediaProgress.maybeWhen(
      data: (p) => p.pending,
      orElse: () => 0,
    );
    final mediaUploading = mediaProgress.maybeWhen(
      data: (p) => p.isProcessing,
      orElse: () => false,
    );

    return FutureBuilder<DateTime?>(
      future: CloudSessionStore.lastSyncAt(),
      builder: (context, syncSnap) {
        final lastSync = syncSnap.data;
        final queueCount = pendingCount.valueOrNull ?? 0;
        final hasPending = queueCount > 0 || mediaPending > 0;
        final mediaOff = !CloudinaryConfig.isConfigured;
        final iconColor = hasPending || mediaOff
            ? context.palette.warning
            : context.palette.success;

        var tooltip = 'Sincronizar';
        if (lastSync != null) {
          final mins = DateTime.now().difference(lastSync).inMinutes;
          tooltip = mins < 1
              ? 'Sincronizado ahora'
              : 'Sincronizado hace $mins min';
        }
        if (lastEdit != null) {
          tooltip += ' · ${lastEdit.describe(DateTime.now())}';
        }
        if (queueCount > 0) {
          tooltip += ' · $queueCount cambio(s) pendiente(s)';
        }
        if (mediaPending > 0) {
          tooltip += ' · ↑$mediaPending img en cola';
        }
        if (mediaOff) {
          tooltip += ' · imágenes desactivadas en esta versión';
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<_CloudAction>(
              tooltip: tooltip,
              position: PopupMenuPosition.under,
              color: context.palette.surfaceElevated,
              onSelected: (action) => switch (action) {
                _CloudAction.sync => _runSync(),
                _CloudAction.history => SyncConflictHistorySheet.show(context),
              },
              itemBuilder: (context) => [
                PopupMenuItem<_CloudAction>(
                  enabled: false,
                  child: Text(
                    tooltip,
                    style: AppTypography.caption(context.palette),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _CloudAction.sync,
                  child: _MenuRow(
                    icon: Icons.sync,
                    label: _syncing ? 'Sincronizando…' : 'Sincronizar ahora',
                  ),
                ),
                PopupMenuItem(
                  value: _CloudAction.history,
                  child: _MenuRow(
                    icon: Icons.history,
                    label: 'Historial de conflictos',
                    count: unseen,
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Badge(
                  isLabelVisible: unseen > 0,
                  label: Text('$unseen'),
                  backgroundColor: context.palette.warning,
                  child: _syncing || mediaUploading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: iconColor,
                          ),
                        )
                      : Icon(
                          Icons.cloud_sync_outlined,
                          size: 20,
                          color: iconColor,
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _CloudAction { sync, history }

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _MenuRow({required this.icon, required this.label, this.count = 0});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: AppTypography.bodyMedium(palette)),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: palette.warning.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.warning),
            ),
          ),
        ],
      ],
    );
  }
}
