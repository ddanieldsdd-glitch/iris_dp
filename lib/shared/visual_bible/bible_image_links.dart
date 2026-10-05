import 'dart:convert';

/// Enlaces del contenido de la biblia a imágenes del moodboard.
///
/// El contenido guarda ids de imagen (referencias, imágenes de un punto,
/// actos, paletas, tiras de imágenes). Cuando las imágenes se vuelven a
/// crear, por ejemplo al descargar un proyecto de la nube, esos ids cambian
/// y hay que reescribirlos.
abstract final class BibleImageLinks {
  /// Claves cuyo valor es un id de imagen o una lista de ellos.
  static const _imageKeys = {'imageIds', 'imageId', 'images', 'coverImageId'};

  /// Reescribe en [contentJson] los ids de imagen según [idMap] (id anterior
  /// → id nuevo). Devuelve el mismo texto si no hay nada que cambiar.
  static String? remap(String? contentJson, Map<int, int> idMap) {
    if (contentJson == null || contentJson.isEmpty || idMap.isEmpty) {
      return contentJson;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(contentJson);
    } catch (_) {
      return contentJson;
    }
    if (decoded is! Map) return contentJson;

    final doc = Map<String, dynamic>.from(decoded);
    var changed = false;

    // Tiras de imágenes: su valor es una lista de ids como texto.
    final values = doc['values'];
    final fields = doc['fields'];
    if (values is Map && fields is List) {
      final next = Map<String, dynamic>.from(values);
      for (final field in fields) {
        if (field is! Map || field['type'] != 'gallery') continue;
        final raw = next[field['key']];
        if (raw is! String) continue;
        try {
          final ids = jsonDecode(raw);
          if (ids is! List) continue;
          final fixed = [
            for (final id in ids)
              '${idMap[int.tryParse('$id')] ?? id}',
          ];
          if (fixed.join(',') != ids.join(',')) {
            next[field['key'] as String] = jsonEncode(fixed);
            changed = true;
          }
        } catch (_) {}
      }
      doc['values'] = next;
    }

    Object? walk(Object? node, {bool image = false}) {
      if (node is Map) {
        return {
          for (final entry in node.entries)
            entry.key: entry.key == 'pointImages' && entry.value is Map
                ? {
                    for (final point in (entry.value as Map).entries)
                      point.key: walk(point.value, image: true),
                  }
                : walk(entry.value, image: _imageKeys.contains(entry.key)),
        };
      }
      if (node is List) {
        return [for (final item in node) walk(item, image: image)];
      }
      if (image && node is int && idMap.containsKey(node)) {
        if (idMap[node] != node) changed = true;
        return idMap[node];
      }
      // Los valores de los puntos son JSON dentro de un texto.
      if (node is String && (node.startsWith('{') || node.startsWith('['))) {
        try {
          final before = changed;
          changed = false;
          final inner = walk(jsonDecode(node), image: image);
          final innerChanged = changed;
          changed = before || innerChanged;
          return innerChanged ? jsonEncode(inner) : node;
        } catch (_) {
          return node;
        }
      }
      return node;
    }

    final result = walk(doc);
    return changed ? jsonEncode(result) : contentJson;
  }
}
