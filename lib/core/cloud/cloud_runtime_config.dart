import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Modo nube opt-in: la app arranca 100 % local; el usuario vincula cuando quiera.
abstract final class CloudRuntimeConfig {
  static const _enabledKey = 'iris_cloud_enabled';
  static const _urlKey = 'iris_cloud_url';
  static const _anonKeyKey = 'iris_cloud_anon_key';

  static var _loaded = false;
  static var _enabled = false;
  static String? _url;
  static String? _anonKey;

  /// Nube activa (usuario vinculó + credenciales válidas).
  static bool get isActive =>
      _loaded && _enabled && url.isNotEmpty && anonKey.isNotEmpty;

  /// Credenciales embebidas en compile (--dart-define) sin activar aún.
  static bool get hasEmbeddedCredentials => SupabaseConfig.isConfigured;

  static String get url {
    if (_url != null && _url!.isNotEmpty) return _url!;
    if (_enabled && SupabaseConfig.url.isNotEmpty) return SupabaseConfig.url;
    return '';
  }

  static String get anonKey {
    if (_anonKey != null && _anonKey!.isNotEmpty) return _anonKey!;
    if (_enabled && SupabaseConfig.anonKey.isNotEmpty) {
      return SupabaseConfig.anonKey;
    }
    return '';
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _url = prefs.getString(_urlKey);
    _anonKey = prefs.getString(_anonKeyKey);
    _loaded = true;
  }

  /// Activa la nube. Si [url]/[anonKey] son null, usa las embebidas en compile.
  static Future<void> enable({String? url, String? anonKey}) async {
    final resolvedUrl = (url?.trim().isNotEmpty == true)
        ? url!.trim()
        : SupabaseConfig.url;
    final resolvedKey = (anonKey?.trim().isNotEmpty == true)
        ? anonKey!.trim()
        : SupabaseConfig.anonKey;

    if (resolvedUrl.isEmpty || resolvedKey.isEmpty) {
      throw StateError(
        'Indica SUPABASE_URL y SUPABASE_ANON_KEY o compila con --dart-define.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setString(_urlKey, resolvedUrl);
    await prefs.setString(_anonKeyKey, resolvedKey);
    _enabled = true;
    _url = resolvedUrl;
    _anonKey = resolvedKey;
    _loaded = true;

    await _ensureSupabaseInitialized();
  }

  static Future<void> disable() async {
    try {
      if (_isSupabaseInitialized()) {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    _enabled = false;
  }

  static Future<void> initializeIfActive() async {
    if (!isActive) return;
    await _ensureSupabaseInitialized();
  }

  static Future<void> _ensureSupabaseInitialized() async {
    if (_isSupabaseInitialized()) return;
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      debug: kDebugMode,
    );
  }

  static bool _isSupabaseInitialized() {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }
}
