import 'dart:convert';

import '../../core/database/app_database.dart';
import '../../core/settings/app_prefs.dart';

/// Lo que cada aparato oculta en la vista En set. Es solo una vista: no se
/// sincroniza ni cambia los PDF.
abstract final class OnSetViewPrefs {
  static const _hideFinished = PrefKey<bool>('onSet.hideFinished', false);

  static PrefKey<String> _hiddenKey(String dayKey) =>
      PrefKey<String>('onSet.hidden.$dayKey', '');

  /// La jornada por lo que no cambia al bajar de la nube (el id sí cambia).
  static String dayKey(ShootDocument day) =>
      '${day.name}|${day.shootDate ?? ''}';

  static String shotKey(Shot shot) => shot.uid ?? 'id:${shot.id}';

  static bool hideFinished(int projectId) =>
      AppPrefs.instance.get(_hideFinished, projectId: projectId);

  static Future<void> setHideFinished(int projectId, bool value) => AppPrefs
      .instance
      .setIn(_hideFinished, SettingsScope.project(projectId), value);

  static Set<String> hiddenShots(int projectId, String dayKey) {
    final raw = AppPrefs.instance.get(_hiddenKey(dayKey), projectId: projectId);
    if (raw.isEmpty) return const {};
    try {
      return (jsonDecode(raw) as List).whereType<String>().toSet();
    } catch (_) {
      return const {};
    }
  }

  static Future<void> setHiddenShots(
    int projectId,
    String dayKey,
    Set<String> shots,
  ) => AppPrefs.instance.setIn(
    _hiddenKey(dayKey),
    SettingsScope.project(projectId),
    shots.isEmpty ? '' : jsonEncode(shots.toList()..sort()),
  );
}

/// La jornada abierta entre las del proyecto. Al bajar de la nube las
/// jornadas se recrean con ids nuevos: si el id ya no está, se busca por tipo,
/// nombre y fecha.
ShootDocument? resolveOpenShootDay(
  List<ShootDocument> docs, {
  required int id,
  required ShootDocument? lastSeen,
}) {
  for (final d in docs) {
    if (d.id == id) return d;
  }
  if (lastSeen == null) return null;
  for (final d in docs) {
    if (d.kind == lastSeen.kind &&
        d.name == lastSeen.name &&
        d.shootDate == lastSeen.shootDate) {
      return d;
    }
  }
  return null;
}
