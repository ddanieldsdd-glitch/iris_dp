import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../cloud/supabase_config.dart';
import 'app_release.dart';
import 'app_update_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado de comprobar si hay una versión más nueva en la nube.
class AppUpdateCheckResult {
  final AppRelease? availableRelease;
  final AppRelease? remoteLatest;
  final String localVersion;
  final int localBuild;
  final int? dismissedBuild;
  final bool skippedThrottle;
  final String? error;

  const AppUpdateCheckResult({
    this.availableRelease,
    this.remoteLatest,
    this.localVersion = '',
    this.localBuild = 0,
    this.dismissedBuild,
    this.skippedThrottle = false,
    this.error,
  });

  bool get hasUpdate => availableRelease != null;

  bool get hasRemoteRelease => remoteLatest != null;

  /// La app en ejecución es más nueva que lo publicado en Supabase.
  bool get installedIsNewerThanPublished {
    final remote = remoteLatest;
    if (remote == null) return false;
    return !isRemoteNewer(
      localBuild: localBuild,
      localVersion: localVersion,
      remoteBuild: remote.buildNumber,
      remoteVersion: remote.version,
    ) &&
        (localBuild > remote.buildNumber ||
            _compareSemver(localVersion, remote.version) > 0);
  }

  String get localVersionLabel =>
      localVersion.isEmpty ? '—' : '$localVersion ($localBuild)';

  String? get remoteVersionLabel {
    final remote = remoteLatest;
    if (remote == null) return null;
    return '${remote.version} (${remote.buildNumber})';
  }
}

/// Plataforma actual para consultar `app_releases`.
String currentReleasePlatform() {
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isIOS) return 'ipad';
  return 'macos';
}

/// Compara versión local vs remota (prioriza build_number).
bool isRemoteNewer({
  required int localBuild,
  required String localVersion,
  required int remoteBuild,
  required String remoteVersion,
}) {
  if (remoteBuild > localBuild) return true;
  if (remoteBuild < localBuild) return false;
  return _compareSemver(remoteVersion, localVersion) > 0;
}

int _compareSemver(String a, String b) {
  final pa = a.split('.').map(int.tryParse).toList();
  final pb = b.split('.').map(int.tryParse).toList();
  for (var i = 0; i < 3; i++) {
    final va = i < pa.length ? (pa[i] ?? 0) : 0;
    final vb = i < pb.length ? (pb[i] ?? 0) : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

/// Consulta Supabase (máx. 1 vez / 24 h salvo [force]).
Future<AppUpdateCheckResult> checkForAppUpdate({
  SupabaseClient? client,
  bool force = false,
}) async {
  if (!SupabaseConfig.isConfigured) {
    return const AppUpdateCheckResult();
  }

  final supabase = client ?? _tryClient();
  if (supabase == null) {
    return const AppUpdateCheckResult(error: 'Supabase no inicializado');
  }

  if (supabase.auth.currentUser == null) {
    return const AppUpdateCheckResult();
  }

  final platform = currentReleasePlatform();

  final info = await PackageInfo.fromPlatform();
  final localBuild = int.tryParse(info.buildNumber) ?? 0;
  final localVersion = info.version;

  if (!force) {
    final last = await AppUpdateStore.lastCheckAt();
    if (last != null &&
        DateTime.now().difference(last) < const Duration(hours: 6)) {
      final cached = await _resolveCachedUpdate(
        platform,
        localBuild: localBuild,
        localVersion: localVersion,
        ignoreDismissed: false,
      );
      return AppUpdateCheckResult(
        availableRelease: cached,
        remoteLatest: cached,
        localVersion: localVersion,
        localBuild: localBuild,
        skippedThrottle: true,
      );
    }
  } else {
    await AppUpdateStore.clearCachedRelease();
  }

  try {
    final row = await supabase
        .from('app_releases')
        .select('platform, version, build_number, download_url, release_notes')
        .eq('platform', platform)
        .order('build_number', ascending: false)
        .limit(1)
        .maybeSingle();

    await AppUpdateStore.setLastCheckAt(DateTime.now());

    if (row == null) {
      return AppUpdateCheckResult(
        localVersion: localVersion,
        localBuild: localBuild,
      );
    }

    final release = AppRelease.fromJson(Map<String, dynamic>.from(row));
    final dismissed = await AppUpdateStore.dismissedBuild(platform);

    if (!isRemoteNewer(
      localBuild: localBuild,
      localVersion: localVersion,
      remoteBuild: release.buildNumber,
      remoteVersion: release.version,
    )) {
      await AppUpdateStore.clearCachedRelease();
      return AppUpdateCheckResult(
        remoteLatest: release,
        localVersion: localVersion,
        localBuild: localBuild,
        dismissedBuild: dismissed,
      );
    }

    if (!force &&
        dismissed != null &&
        release.buildNumber <= dismissed) {
      return AppUpdateCheckResult(
        remoteLatest: release,
        localVersion: localVersion,
        localBuild: localBuild,
        dismissedBuild: dismissed,
      );
    }

    await AppUpdateStore.cacheRelease(release);
    return AppUpdateCheckResult(
      availableRelease: release,
      remoteLatest: release,
      localVersion: localVersion,
      localBuild: localBuild,
      dismissedBuild: dismissed,
    );
  } catch (e, st) {
    debugPrint('checkForAppUpdate: $e\n$st');
    return AppUpdateCheckResult(
      localVersion: localVersion,
      localBuild: localBuild,
      error: e.toString(),
    );
  }
}

SupabaseClient? _tryClient() {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

Future<AppRelease?> _resolveCachedUpdate(
  String platform, {
  required int localBuild,
  required String localVersion,
  required bool ignoreDismissed,
}) async {
  final cached = await AppUpdateStore.cachedRelease();
  if (cached == null || cached.platform != platform) return null;

  if (!isRemoteNewer(
    localBuild: localBuild,
    localVersion: localVersion,
    remoteBuild: cached.buildNumber,
    remoteVersion: cached.version,
  )) {
    await AppUpdateStore.clearCachedRelease();
    return null;
  }

  if (!ignoreDismissed) {
    final dismissed = await AppUpdateStore.dismissedBuild(platform);
    if (dismissed != null && cached.buildNumber <= dismissed) return null;
  }

  return cached;
}
