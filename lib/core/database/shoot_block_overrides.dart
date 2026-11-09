import 'dart:convert';

/// El JSON de `contentOverridesJson` de un bloque, como mapa. Si no se puede
/// leer, vacío.
Map<String, dynamic> decodeBlockOverrides(String? json) {
  if (json == null || json.isEmpty) return {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return {};
}

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
