import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_release.dart';

/// Preferencias locales para comprobación de actualizaciones.
class AppUpdateStore {
  static const _lastCheckKey = 'iris_last_update_check_at';
  static const _dismissedBuildPrefix = 'iris_dismissed_build_';
  static const _cachedReleaseKey = 'iris_cached_release_json';

  static Future<DateTime?> lastCheckAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastCheckKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> setLastCheckAt(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckKey, time.millisecondsSinceEpoch);
  }

  static Future<int?> dismissedBuild(String platform) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_dismissedBuildPrefix$platform');
  }

  static Future<void> dismissBuild(String platform, int buildNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_dismissedBuildPrefix$platform', buildNumber);
  }

  static Future<void> clearDismissed(String platform) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_dismissedBuildPrefix$platform');
  }

  static Future<void> cacheRelease(AppRelease release) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedReleaseKey, jsonEncode({
      'platform': release.platform,
      'version': release.version,
      'build_number': release.buildNumber,
      'download_url': release.downloadUrl,
      'release_notes': release.releaseNotes,
    }));
  }

  static Future<AppRelease?> cachedRelease() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedReleaseKey);
    if (raw == null) return null;
    try {
      return AppRelease.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearCachedRelease() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedReleaseKey);
  }
}
