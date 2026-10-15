import 'media_entity_types.dart';

/// Claves para `media_assets.entity_key` (independientes del dispositivo).
///
/// Desde B1 las imágenes se identifican por su `uid` permanente
/// ([byUid]). Las claves por posición ([moodboard], [shotReference],
/// [siteImage], [locationImage]) quedan para reconocer lo subido antes: dos
/// imágenes en el mismo puesto compartían clave y reordenar la cambiaba.
abstract final class MediaEntityKeys {
  static const uidPrefix = 'uid:';

  /// Clave de una imagen por su uid: `uid:<uid>`. El tipo va aparte, en
  /// `media_assets.entity_type`.
  static String byUid(String uid) => '$uidPrefix$uid';

  /// El uid de una clave [byUid], o nulo si es de las de posición.
  static String? uidOf(String entityKey) =>
      entityKey.startsWith(uidPrefix)
          ? entityKey.substring(uidPrefix.length)
          : null;

  /// La clave de una imagen: por uid si lo tiene; si no (filas aún sin
  /// migrar), la de posición.
  static String forImage(String? uid, String Function() positional) =>
      uid != null && uid.isNotEmpty ? byUid(uid) : positional();

  static String moodboard({
    String? groupKey,
    required int sortOrder,
  }) =>
      'moodboard:${groupKey ?? 'ungrouped'}:$sortOrder';

  static String shotReference({
    required String shotKey,
    required int sortOrder,
  }) =>
      'shot:$shotKey:ref:$sortOrder';

  static String siteImage({
    required String siteKey,
    required int sortOrder,
  }) =>
      'site:$siteKey:$sortOrder';

  static String locationImage({
    required String setKey,
    required int sortOrder,
  }) =>
      'set:$setKey:$sortOrder';

  static String shootDocumentBlock({
    required String documentKey,
    required int sortOrder,
  }) =>
      'doc:$documentKey:block:$sortOrder';

  static const projectCover = 'project:cover';
}

/// Subcarpeta local según tipo de entidad.
String mediaSubfolderForEntity(String entityType) {
  return switch (entityType) {
    MediaEntityType.moodboard => 'visual_bible/moodboard',
    MediaEntityType.shotReference => 'references',
    MediaEntityType.site => 'sites/cloud',
    MediaEntityType.location => 'locations/cloud',
    MediaEntityType.shootDocument => 'shoot_documents/cloud',
    MediaEntityType.projectCover => 'cover',
    _ => 'cloud_cache',
  };
}
