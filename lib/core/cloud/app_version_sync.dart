import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'cloud_providers.dart';
import 'cloud_session.dart';
import 'cloud_runtime_config.dart';
import '../sync/sync_engine.dart';

/// Resultado de comprobar si la app se actualizó y necesita sync.
class AppVersionSyncResult {
  final bool versionChanged;
  final bool syncRan;
  final String? message;

  const AppVersionSyncResult({
    required this.versionChanged,
    required this.syncRan,
    this.message,
  });
}

/// Tras actualizar la app, sincroniza automáticamente con Supabase.
Future<AppVersionSyncResult> syncAfterAppUpdateIfNeeded(WidgetRef ref) async {
  if (!CloudRuntimeConfig.isActive) {
    return const AppVersionSyncResult(
      versionChanged: false,
      syncRan: false,
    );
  }

  final user = ref.read(supabaseClientProvider)?.auth.currentUser;
  if (user == null) {
    return const AppVersionSyncResult(
      versionChanged: false,
      syncRan: false,
    );
  }

  final info = await PackageInfo.fromPlatform();
  final current = '${info.version}+${info.buildNumber}';
  final last = await CloudSessionStore.lastSyncedAppVersion();

  if (last == null) {
    await CloudSessionStore.setLastSyncedAppVersion(current);
    return const AppVersionSyncResult(versionChanged: false, syncRan: false);
  }

  if (last == current) {
    return const AppVersionSyncResult(versionChanged: false, syncRan: false);
  }

  try {
    final result = await ref.read(syncEngineProvider).syncOnStartup();
    await CloudSessionStore.setLastSyncedAppVersion(current);
    return AppVersionSyncResult(
      versionChanged: true,
      syncRan: !result.pendingReview,
      message: result.pendingReview
          ? result.message
          : result.ok
              ? 'App actualizada (v${info.version}). Proyectos sincronizados.'
              : result.message ??
                  'App actualizada. Revisa la conexión e intenta sync de nuevo.',
    );
  } catch (e) {
    return AppVersionSyncResult(
      versionChanged: true,
      syncRan: false,
      message: 'App actualizada. No se pudo sincronizar: $e',
    );
  }
}

Future<String> currentAppVersionLabel() async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
}
