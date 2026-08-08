import 'package:shared_preferences/shared_preferences.dart';

import 'bible_v2_policy.dart';

/// Feature flag por proyecto: motor Page→Block vs secciones legacy.
///
/// Default: **off**. Activar no borra datos legacy; genera/lee documento v2.
abstract final class BibleEngineV2Flag {
  static String _key(int projectId) =>
      '${kBibleV2PrefsPrefix}engine_enabled_$projectId';

  static Future<bool> isEnabled(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(projectId)) ?? false;
  }

  static Future<void> setEnabled(int projectId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(projectId), enabled);
  }

  /// Notifier ligero para refrescar UI tras toggle.
  static final ValueNotifierBridge revision = ValueNotifierBridge();
}

/// Evita importar Flutter en tests de flag puro; la UI usa [ValueNotifier].
class ValueNotifierBridge {
  int value = 0;
  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void notify() {
    value++;
    for (final l in List.of(_listeners)) {
      l();
    }
  }
}
