import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloud_runtime_config.dart';
import 'app_release.dart';
import 'app_update_checker.dart';

/// Consulta releases remotas por plataforma.
Future<AppRelease?> fetchLatestReleaseForPlatform(
  String platform, {
  SupabaseClient? client,
}) async {
  if (!CloudRuntimeConfig.isActive) return null;

  final supabase = client ?? _tryClient();
  if (supabase == null) return null;

  try {
    final row = await supabase
        .from('app_releases')
        .select('platform, version, build_number, download_url, release_notes')
        .eq('platform', platform)
        .order('build_number', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;
    return AppRelease.fromJson(Map<String, dynamic>.from(row));
  } catch (_) {
    return null;
  }
}

SupabaseClient? _tryClient() {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

Future<AppRelease?> fetchIpadRelease({SupabaseClient? client}) =>
    fetchLatestReleaseForPlatform('ipad', client: client);

Future<AppRelease?> fetchCurrentPlatformRelease({SupabaseClient? client}) =>
    fetchLatestReleaseForPlatform(currentReleasePlatform(), client: client);
