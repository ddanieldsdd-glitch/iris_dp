import 'package:shared_preferences/shared_preferences.dart';

/// Huellas del contenido de un proyecto en la última sincronización: la de
/// este dispositivo y la de la nube.
///
/// Con ellas se sabe quién ha cambiado desde entonces sin comparar horas, que
/// se guardan redondeadas y dependen del reloj de cada dispositivo.
class ContentSyncBase {
  final String localHash;
  final String cloudHash;

  const ContentSyncBase({required this.localHash, required this.cloudHash});
}

abstract final class ContentSyncBaseStore {
  static String _localKey(int projectId) =>
      'iris_content_sync_base_local_$projectId';
  static String _cloudKey(int projectId) =>
      'iris_content_sync_base_cloud_$projectId';

  static Future<ContentSyncBase?> load(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString(_localKey(projectId));
    final cloud = prefs.getString(_cloudKey(projectId));
    if (local == null || cloud == null) return null;
    return ContentSyncBase(localHash: local, cloudHash: cloud);
  }

  static Future<void> save(int projectId, ContentSyncBase base) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey(projectId), base.localHash);
    await prefs.setString(_cloudKey(projectId), base.cloudHash);
  }

  static Future<void> clear(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localKey(projectId));
    await prefs.remove(_cloudKey(projectId));
  }
}
