import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../cloud/cloud_session.dart';
import '../cloud/supabase_config.dart';
import '../sync/sync_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../features/auth/auth_screen.dart';

/// Indicador nube / sync en barra superior.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return FutureBuilder<String?>(
      future: CloudSessionStore.userRole(),
      builder: (context, roleSnap) {
        final role = roleSnap.data;
        final isDp = CloudUserRole.isDp(role);

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
              tooltip: 'Sincronizar',
              icon: Icon(Icons.cloud_sync_outlined,
                  size: 20, color: context.palette.success),
              onPressed: () async {
                final result = await ref.read(syncEngineProvider).syncAll();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.ok
                            ? 'Sync: ↑${result.pushed} ↓${result.pulled}'
                            : result.message ?? 'Sync omitido',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
