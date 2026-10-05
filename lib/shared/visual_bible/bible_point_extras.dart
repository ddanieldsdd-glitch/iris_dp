import 'dart:convert';

/// Complementos que el usuario puede añadir a cualquier punto de la biblia
/// desde su menú «⋯»: imágenes del moodboard y un texto.
///
/// Se guardan junto al punto, en `values['<clave>__extra']`.
class BiblePointExtras {
  final List<int> imageIds;

  /// `null` si el punto no lleva texto complementario; vacío si el usuario
  /// lo ha añadido y aún no ha escrito.
  final String? text;

  const BiblePointExtras({this.imageIds = const [], this.text});

  static String keyFor(String pointKey) => '${pointKey}__extra';

  bool get hasText => text != null;

  bool get isEmpty => imageIds.isEmpty && (text ?? '').trim().isEmpty;

  /// Complementos de [pointKey]. Mientras no se hayan guardado, las imágenes
  /// son [legacyImages]: las que el punto tuviera antes de este formato.
  factory BiblePointExtras.read(
    Map<String, String> values,
    String pointKey, {
    List<int> legacyImages = const [],
  }) {
    final raw = values[keyFor(pointKey)];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final images = decoded['images'];
          return BiblePointExtras(
            imageIds: [
              if (images is List)
                for (final id in images)
                  if (id is num) id.toInt(),
            ],
            text: decoded['text']?.toString(),
          );
        }
      } catch (_) {}
    }
    return BiblePointExtras(imageIds: legacyImages);
  }

  /// Siempre devuelve un valor, aunque esté vacío, para que no vuelvan las
  /// imágenes anteriores.
  String encode() =>
      jsonEncode({'images': imageIds, if (text != null) 'text': text});

  BiblePointExtras withImages(List<int> ids) =>
      BiblePointExtras(imageIds: ids, text: text);

  BiblePointExtras withText(String? value) =>
      BiblePointExtras(imageIds: imageIds, text: value);

  /// Imágenes de todos los complementos guardados en [values].
  static Set<int> allImageIds(Map<String, String> values) => {
    for (final key in values.keys)
      if (key.endsWith('__extra'))
        ...BiblePointExtras.read(
          values,
          key.substring(0, key.length - '__extra'.length),
        ).imageIds,
  };
}
