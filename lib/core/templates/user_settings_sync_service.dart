import 'package:drift/drift.dart' show Value;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import 'user_template_models.dart';
import 'user_template_preferences.dart';

/// Sincroniza plantillas y preferencias de usuario con Supabase `user_settings`.
abstract final class UserSettingsSyncService {
  UserSettingsSyncService._();

  static const _lastSyncKey = 'iris_user_settings_last_sync';

  static Future<DateTime?> lastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSyncKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> _markSynced(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, at.toUtc().toIso8601String());
  }

  static Future<bool> push({
    required AppDatabase db,
    required SupabaseClient client,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false;

    final templates = await db.select(db.userTemplates).get();
    final prefs = await UserTemplatePreferences.load();
    final now = DateTime.now().toUtc();

    final templatesJson = templates
        .map(
          (t) => {
            'id': t.id,
            'type': t.type,
            'name': t.name,
            'description': t.description,
            'payloadJson': t.payloadJson,
            'isDefault': t.isDefault,
            'createdAt': t.createdAt.toUtc().toIso8601String(),
            'updatedAt': t.updatedAt.toUtc().toIso8601String(),
          },
        )
        .toList();

    final preferencesJson = {
      'defaultBibleLayoutTemplateId': prefs.defaultBibleLayoutTemplateId,
      'defaultShootDocTemplateId': prefs.defaultShootDocTemplateId,
      'bibleAutoApply': prefs.bibleAutoApply.storageKey,
      'shootDocAutoApply': prefs.shootDocAutoApply.storageKey,
      'projectBibleTemplateIds': prefs.projectBibleTemplateIds.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'projectShootDocTemplateIds': prefs.projectShootDocTemplateIds.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
    };

    await client.from('user_settings').upsert({
      'user_id': userId,
      'templates_json': templatesJson,
      'preferences_json': preferencesJson,
      'updated_at': now.toIso8601String(),
    });

    await _markSynced(now);
    return true;
  }

  static Future<bool> pull({
    required AppDatabase db,
    required SupabaseClient client,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false;

    final row = await client
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return false;

    final cloudUpdated =
        DateTime.tryParse(row['updated_at'] as String? ?? '')?.toUtc();
    final localSync = (await lastSyncAt())?.toUtc();
    if (cloudUpdated != null &&
        localSync != null &&
        !cloudUpdated.isAfter(localSync)) {
      return false;
    }

    final templatesRaw = row['templates_json'];
    if (templatesRaw is List) {
      await db.transaction(() async {
        await db.delete(db.userTemplates).go();
        for (final item in templatesRaw) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          await db.into(db.userTemplates).insertOnConflictUpdate(
                UserTemplatesCompanion.insert(
                  id: map['id'] as String,
                  type: map['type'] as String,
                  name: map['name'] as String,
                  description: Value(map['description'] as String?),
                  payloadJson: map['payloadJson'] as String,
                  isDefault: Value(map['isDefault'] as bool? ?? false),
                  createdAt: Value(
                    DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                        DateTime.now(),
                  ),
                  updatedAt: Value(
                    DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
                        DateTime.now(),
                  ),
                ),
              );
        }
      });
    }

    final prefsRaw = row['preferences_json'];
    if (prefsRaw is Map) {
      final map = Map<String, dynamic>.from(prefsRaw);
      final prefs = UserTemplatePreferences(
        defaultBibleLayoutTemplateId:
            map['defaultBibleLayoutTemplateId'] as String?,
        defaultShootDocTemplateId:
            map['defaultShootDocTemplateId'] as String?,
        bibleAutoApply: TemplateAutoApplyModeX.fromStorageKey(
          map['bibleAutoApply'] as String?,
        ),
        shootDocAutoApply: TemplateAutoApplyModeX.fromStorageKey(
          map['shootDocAutoApply'] as String?,
        ),
        projectBibleTemplateIds: _decodeIntMap(map['projectBibleTemplateIds']),
        projectShootDocTemplateIds:
            _decodeIntMap(map['projectShootDocTemplateIds']),
      );
      await prefs.save();
    }

    if (cloudUpdated != null) await _markSynced(cloudUpdated);
    return true;
  }

  static Map<int, String> _decodeIntMap(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map(
      (k, v) => MapEntry(int.parse(k.toString()), v.toString()),
    );
  }

  static Future<({bool pulled, bool pushed})> sync({
    required AppDatabase db,
    required SupabaseClient client,
  }) async {
    final pulled = await pull(db: db, client: client);
    final pushed = await push(db: db, client: client);
    return (pulled: pulled, pushed: pushed);
  }
}
