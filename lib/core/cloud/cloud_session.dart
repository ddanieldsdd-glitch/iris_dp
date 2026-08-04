import 'package:shared_preferences/shared_preferences.dart';

/// Sesión cloud persistida (workspace activo, modo).
class CloudSessionStore {
  static const _workspaceKey = 'iris_cloud_workspace_id';
  static const _workspaceNameKey = 'iris_cloud_workspace_name';
  static const _userRoleKey = 'iris_cloud_user_role';
  static const _onboardingDoneKey = 'iris_onboarding_complete';
  static const _migrationDoneKey = 'iris_cloud_migration_done';
  static const _lastSyncedVersionKey = 'iris_last_synced_app_version';

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
