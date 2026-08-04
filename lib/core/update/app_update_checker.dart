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
  final bool skippedThrottle;
  final String? error;

  const AppUpdateCheckResult({
    this.availableRelease,
    this.skippedThrottle = false,
    this.error,
  });

  bool get hasUpdate => availableRelease != null;
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

  if (!force) {
    final last = await AppUpdateStore.lastCheckAt();
    if (last != null &&
        DateTime.now().difference(last) < const Duration(hours: 24)) {
      final cached = await _resolveCachedUpdate(platform);
      return AppUpdateCheckResult(
        availableRelease: cached,
        skippedThrottle: true,
      );
    }
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
      return const AppUpdateCheckResult();
    }

    final release = AppRelease.fromJson(Map<String, dynamic>.from(row));
    final info = await PackageInfo.fromPlatform();
    final localBuild = int.tryParse(info.buildNumber) ?? 0;

    if (!isRemoteNewer(
      localBuild: localBuild,
      localVersion: info.version,
      remoteBuild: release.buildNumber,
      remoteVersion: release.version,
    )) {
      await AppUpdateStore.clearCachedRelease();
      return const AppUpdateCheckResult();
    }

    final dismissed = await AppUpdateStore.dismissedBuild(platform);
    if (dismissed != null && release.buildNumber <= dismissed) {
      return const AppUpdateCheckResult();
    }

    await AppUpdateStore.cacheRelease(release);
    return AppUpdateCheckResult(availableRelease: release);
  } catch (e, st) {
    debugPrint('checkForAppUpdate: $e\n$st');
    return AppUpdateCheckResult(error: e.toString());
  }
}

SupabaseClient? _tryClient() {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

Future<AppRelease?> _resolveCachedUpdate(String platform) async {
  final cached = await AppUpdateStore.cachedRelease();
  if (cached == null || cached.platform != platform) return null;

  final info = await PackageInfo.fromPlatform();
  final localBuild = int.tryParse(info.buildNumber) ?? 0;

  if (!isRemoteNewer(
    localBuild: localBuild,
    localVersion: info.version,
    remoteBuild: cached.buildNumber,
    remoteVersion: cached.version,
  )) {
    await AppUpdateStore.clearCachedRelease();
    return null;
  }

  final dismissed = await AppUpdateStore.dismissedBuild(platform);
  if (dismissed != null && cached.buildNumber <= dismissed) return null;

  return cached;
}
