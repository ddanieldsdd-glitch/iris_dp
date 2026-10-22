import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un ajuste de la app: identificador estable y valor de fábrica.
///
/// Admite `bool`, `int`, `double` y `String` (los enums se guardan por
/// nombre, como `String`).
class PrefKey<T extends Object> {
  final String id;
  final T defaultValue;

  const PrefKey(this.id, this.defaultValue);
}

/// Dónde se lee o escribe un ajuste: para toda la app o solo un proyecto.
@immutable
class SettingsScope {
  final int? projectId;

  const SettingsScope.global() : projectId = null;
  const SettingsScope.project(int this.projectId);

  bool get isProject => projectId != null;

  @override
  bool operator ==(Object other) =>
      other is SettingsScope && other.projectId == projectId;

  @override
  int get hashCode => projectId.hashCode;
}

/// Ajustes con alcance: un valor general y, si hace falta, una excepción
/// por proyecto. Se resuelven proyecto → general → valor de fábrica.
///
/// Se cargan una vez al arrancar ([ensureLoaded]) para leerlos sin esperas
/// desde cualquier pantalla. Avisa a quien escucha cada vez que cambia algo.
class AppPrefs extends ChangeNotifier {
  AppPrefs._();

  static final AppPrefs instance = AppPrefs._();

  static const _prefix = 'iris_pref_';

  SharedPreferences? _prefs;

  bool get isLoaded => _prefs != null;

  static Future<void> ensureLoaded() async {
    instance._prefs ??= await SharedPreferences.getInstance();
  }

  /// Vuelve a leer el almacén (pruebas).
  @visibleForTesting
  static Future<void> reloadForTest() async {
    instance._prefs = await SharedPreferences.getInstance();
    instance.notifyListeners();
  }

  static String storageKey(String id, [int? projectId]) =>
      projectId == null ? '$_prefix$id' : '$_prefix$id@$projectId';

  T? _read<T extends Object>(String key) {
    final value = _prefs?.get(key);
    if (value is T) return value;
    // Un double guardado como entero exacto vuelve como int.
    if (T == double && value is int) return value.toDouble() as T;
    return null;
  }

  /// Valor general, sin mirar ningún proyecto.
  T globalValue<T extends Object>(PrefKey<T> key) =>
      _read<T>(storageKey(key.id)) ?? key.defaultValue;

  /// Excepción del proyecto, o `null` si sigue el valor general.
  T? projectValue<T extends Object>(PrefKey<T> key, int projectId) =>
      _read<T>(storageKey(key.id, projectId));

  bool hasOverride(PrefKey key, int projectId) =>
      _prefs?.containsKey(storageKey(key.id, projectId)) ?? false;

  /// Valor que manda en un proyecto (o el general si no se indica).
  T get<T extends Object>(PrefKey<T> key, {int? projectId}) =>
      (projectId == null ? null : projectValue(key, projectId)) ??
      globalValue(key);

  /// Valor que ve quien edita en [scope].
  T valueIn<T extends Object>(PrefKey<T> key, SettingsScope scope) =>
      get(key, projectId: scope.projectId);

  Future<void> setIn<T extends Object>(
    PrefKey<T> key,
    SettingsScope scope,
    T value,
  ) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final storage = storageKey(key.id, scope.projectId);
    switch (value) {
      case bool v:
        await prefs.setBool(storage, v);
      case int v:
        await prefs.setInt(storage, v);
      case double v:
        await prefs.setDouble(storage, v);
      case String v:
        await prefs.setString(storage, v);
      default:
        throw ArgumentError('Tipo de ajuste no admitido: ${value.runtimeType}');
    }
    notifyListeners();
  }

  /// El proyecto vuelve a seguir el valor general.
  Future<void> clearOverride(PrefKey key, int projectId) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.remove(storageKey(key.id, projectId));
    notifyListeners();
  }

  int overrideCount(Iterable<PrefKey> keys, int projectId) =>
      keys.where((k) => hasOverride(k, projectId)).length;
}

/// Expone [AppPrefs.instance] y redibuja a quien lo mira cuando cambia.
/// No es dueño del almacén: al cerrarse el contenedor solo deja de escuchar.
final appPrefsProvider = Provider<AppPrefs>((ref) {
  final prefs = AppPrefs.instance;
  void notify() => ref.notifyListeners();
  prefs.addListener(notify);
  ref.onDispose(() => prefs.removeListener(notify));
  return prefs;
});
