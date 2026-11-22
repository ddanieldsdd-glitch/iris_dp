import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_access.dart';

/// La nube aún no tiene la migración 016: nadie queda fuera por ello.
class AccessCheckUnavailable implements Exception {
  const AccessCheckUnavailable();
}

/// Pregunta a la nube por el acceso de la cuenta con sesión.
class AppAccessService {
  AppAccessService(this._client);

  final SupabaseClient _client;

  Future<AccessCheck> fetch() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sin sesión');
    try {
      final raw = await _client.rpc('iris_access_check');
      return AccessCheck.fromServer(
        Map<String, dynamic>.from(raw as Map),
        userId: user.id,
        checkedAt: DateTime.now(),
      );
    } on PostgrestException catch (e) {
      if (isMissingFunction(e)) throw const AccessCheckUnavailable();
      rethrow;
    }
  }

  static bool isMissingFunction(PostgrestException e) =>
      e.code == 'PGRST202' || e.code == '42883';
}

/// Última comprobación buena, para entrar sin conexión unos días.
abstract final class AccessCheckCache {
  static const _key = 'iris_access_check';

  static Future<AccessCheck?> load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final check = AccessCheck.fromCache(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      return check?.userId == userId ? check : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(AccessCheck check) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(check.toJson()));
  }
}

/// La última comprobación de esta sesión (la deja la puerta de acceso).
final accessCheckProvider = StateProvider<AccessCheck?>((ref) => null);

/// La cuenta con sesión es la del administrador.
final isAppAdminProvider = Provider<bool>(
  (ref) => ref.watch(accessCheckProvider)?.isAdmin ?? false,
);
