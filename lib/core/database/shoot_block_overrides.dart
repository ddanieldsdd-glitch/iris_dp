import 'dart:convert';

import '../utils/error_log.dart';
/// El JSON de `contentOverridesJson` de un bloque, como mapa. Si no se puede
/// leer, vacío. Quien lo usa suele escribir el bloque encima: lo ilegible se
/// guarda antes aparte, una vez, para no perderlo sin rastro (FI.4).
Map<String, dynamic> decodeBlockOverrides(String? json) {
  if (json == null || json.isEmpty) return {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    if (_damagedSeen.add(json)) {
      ErrorLog.preserveDamaged('bloque-de-jornada', json);
    }
  }
  return {};
}

final _damagedSeen = <String>{};

/// Lo de [restored] con la marca de En set de [current]. Deshacer un cambio
/// del plan devuelve el orden, pero un «Hecho» apuntado después no se pierde.
String? keepOnSetMark(String? restored, String? current) {
  const key = 'onSet';
  final mark = decodeBlockOverrides(current)[key];
  final all = decodeBlockOverrides(restored);
  if (mark == all[key]) return restored;
  if (mark == null) {
    all.remove(key);
  } else {
    all[key] = mark;
  }
  return jsonEncode(all);
}
