import 'package:shared_preferences/shared_preferences.dart';

/// Progreso del tutorial inicial y tour de inicio.
abstract final class AppTutorialStore {
  static const _introKey = 'iris_tutorial_intro_done';
  static const _homeTourKey = 'iris_tutorial_home_tour_done';

  static Future<bool> isIntroComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_introKey) ?? false;
  }

  static Future<bool> isHomeTourComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_homeTourKey) ?? false;
  }

  static Future<void> setIntroComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introKey, value);
  }

  static Future<void> setHomeTourComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_homeTourKey, value);
  }

  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_introKey);
    await prefs.remove(_homeTourKey);
  }
}
