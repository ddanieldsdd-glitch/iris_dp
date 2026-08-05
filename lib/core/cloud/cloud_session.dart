import 'package:shared_preferences/shared_preferences.dart';

/// Sesión cloud persistida (workspace activo, modo).
class CloudSessionStore {
  static const _workspaceKey = 'iris_cloud_workspace_id';
  static const _workspaceNameKey = 'iris_cloud_workspace_name';
  static const _userRoleKey = 'iris_cloud_user_role';
  static const _onboardingDoneKey = 'iris_onboarding_complete';
  static const _migrationDoneKey = 'iris_cloud_migration_done';
  static const _lastSyncedVersionKey = 'iris_last_synced_app_version';
  static const _lastSyncAtKey = 'iris_last_cloud_sync_at';
  static const _deletedCloudProjectsKey = 'iris_deleted_cloud_project_ids';

  static Future<Set<String>> tombstonedCloudProjectIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_deletedCloudProjectsKey) ?? []).toSet();
  }

  static Future<void> tombstoneCloudProject(String cloudId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_deletedCloudProjectsKey) ?? [];
    if (!list.contains(cloudId)) {
      list.add(cloudId);
      await prefs.setStringList(_deletedCloudProjectsKey, list);
    }
  }

  static Future<void> clearTombstone(String cloudId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_deletedCloudProjectsKey) ?? [];
    if (list.remove(cloudId)) {
      await prefs.setStringList(_deletedCloudProjectsKey, list);
    }
  }

  static Future<String?> workspaceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_workspaceKey);
  }

  static Future<String?> workspaceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_workspaceNameKey);
  }

  static Future<String?> userRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingDoneKey) ?? false;
  }

  static Future<bool> isMigrationComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_migrationDoneKey) ?? false;
  }

  static Future<void> saveWorkspace({
    required String id,
    required String name,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workspaceKey, id);
    await prefs.setString(_workspaceNameKey, name);
    await prefs.setString(_userRoleKey, role);
  }

  static Future<void> setOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, value);
  }

  static Future<void> setMigrationComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migrationDoneKey, value);
  }

  static Future<String?> lastSyncedAppVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSyncedVersionKey);
  }

  static Future<void> setLastSyncedAppVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncedVersionKey, version);
  }

  static Future<DateTime?> lastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastSyncAtKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> setLastSyncAt(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncAtKey, time.millisecondsSinceEpoch);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_workspaceKey);
    await prefs.remove(_workspaceNameKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_onboardingDoneKey);
  }
}

/// Roles de usuario en la nube.
abstract final class CloudUserRole {
  static const dpOwner = 'owner';
  static const director = 'director';
  static const viewer = 'viewer';

  static bool isDp(String? role) => role == dpOwner || role == 'dp';
}
