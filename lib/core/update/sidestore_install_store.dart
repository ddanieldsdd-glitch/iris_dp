import 'package:shared_preferences/shared_preferences.dart';

/// Fecha de última instalación vía SideStore (recordatorio de refresco ~7 días).
class SideStoreInstallStore {
  static const _lastInstallKey = 'iris_sidestore_last_install_at';

  static Future<DateTime?> lastInstallAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastInstallKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> markInstalledNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastInstallKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// True si han pasado más de [days] desde la última instalación registrada.
  static Future<bool> shouldShowRefreshReminder({int days = 5}) async {
    final last = await lastInstallAt();
    if (last == null) return false;
    return DateTime.now().difference(last).inDays >= days;
  }
}
