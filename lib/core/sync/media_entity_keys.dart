import 'media_entity_types.dart';

/// Claves estables para `media_assets.entity_key` (independientes del dispositivo).
abstract final class MediaEntityKeys {
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
