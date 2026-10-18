import 'dart:convert';

import 'media_entity_types.dart';

/// Cómo se sube un archivo: las imágenes van a Cloudinary (optimizadas); el
/// resto (guion, PDF, escaneos, modelos 3D) a Supabase Storage tal cual.
enum MediaKind { image, file }

/// Un sitio de la base que guarda la ruta de un archivo del proyecto y que la
/// sincronización sube y baja. La clave en la nube es `uid:<uid>` de la fila
/// (o `uid:<uid>#<n>` en las listas), así que no depende de la posición.
class MediaSlot {
  final String entityType;
  final MediaKind kind;
  final String table;
  final String column;

  /// `SELECT id, uid, <ruta> AS path` de las filas de un proyecto (`?`).
  final String selectForProject;

  /// La columna guarda una lista JSON de rutas (pruebas de cámara).
  final bool isList;

  /// La columna admite nulo: al importar, una ruta que no existe en este
  /// dispositivo se vacía hasta que la descarga la rellene.
  final bool nullable;

  final String subfolder;

  const MediaSlot({
    required this.entityType,
    required this.kind,
    required this.table,
    required this.column,
    required this.selectForProject,
    required this.subfolder,
    this.isList = false,
    this.nullable = true,
  });

  /// Archivos más grandes no se suben (límite de Supabase Storage).
  static const maxFileBytes = 50 * 1024 * 1024;
}

/// Todo lo que lleva archivo además de las imágenes de siempre (moodboard,
/// referencias de plano, fotos de localización y de set, documentos de
/// rodaje y portada), que tienen su propio camino.
const kMediaSlots = <MediaSlot>[
  MediaSlot(
    entityType: MediaEntityType.shotStoryboard,
    kind: MediaKind.image,
    table: 'shots',
    column: 'storyboard_image_path',
    selectForProject:
        'SELECT id, uid, storyboard_image_path AS path FROM shots '
        'WHERE project_id = ?',
    subfolder: 'storyboard',
  ),
  MediaSlot(
    entityType: MediaEntityType.shotPlanImage,
    kind: MediaKind.image,
    table: 'shots',
    column: 'camera_plan_image_path',
    selectForProject:
        'SELECT id, uid, camera_plan_image_path AS path FROM shots '
        'WHERE project_id = ?',
    subfolder: 'camera_plans',
    // Una ruta o una lista JSON (bocetos del plano).
    isList: true,
  ),
  MediaSlot(
    entityType: MediaEntityType.lightSketch,
    kind: MediaKind.image,
    table: 'light_setups',
    column: 'sketch_image_path',
    selectForProject:
        'SELECT id, uid, sketch_image_path AS path FROM light_setups '
        'WHERE project_id = ?',
    subfolder: 'light_sketches',
  ),
  MediaSlot(
    entityType: MediaEntityType.planImage,
    kind: MediaKind.image,
    table: 'plan_images',
    column: 'path',
    selectForProject:
        'SELECT id, uid, path AS path FROM plan_images WHERE project_id = ?',
    subfolder: 'plan_images',
  ),
  MediaSlot(
    entityType: MediaEntityType.lightingReference,
    kind: MediaKind.image,
    table: 'lighting_setups',
    column: 'reference_image_path',
    selectForProject:
        'SELECT t.id, t.uid, t.reference_image_path AS path '
        'FROM lighting_setups t JOIN visual_bibles b ON b.id = t.bible_id '
        'WHERE b.project_id = ?',
    subfolder: 'visual_bible/lighting',
  ),
  MediaSlot(
    entityType: MediaEntityType.setPlan,
    kind: MediaKind.image,
    table: 'location_base_plans',
    column: 'image_path',
    selectForProject:
        'SELECT id, uid, image_path AS path FROM location_base_plans '
        'WHERE project_id = ?',
    subfolder: 'locations/plans',
  ),
  MediaSlot(
    entityType: MediaEntityType.bibleEvidence,
    kind: MediaKind.image,
    table: 'bible_section_evidence',
    column: 'image_path',
    selectForProject:
        'SELECT t.id, t.uid, t.image_path AS path '
        'FROM bible_section_evidence t JOIN visual_bibles b '
        'ON b.id = t.bible_id WHERE b.project_id = ?',
    subfolder: 'visual_bible/evidence',
    nullable: false,
  ),
  MediaSlot(
    entityType: MediaEntityType.opticsSample,
    kind: MediaKind.image,
    table: 'optics_lab_samples',
    column: 'image_path',
    selectForProject:
        'SELECT id, uid, image_path AS path FROM optics_lab_samples '
        'WHERE project_id = ?',
    subfolder: 'optics_lab',
    nullable: false,
  ),
  MediaSlot(
    entityType: MediaEntityType.cameraTest,
    kind: MediaKind.image,
    table: 'camera_tests',
    column: 'image_paths',
    selectForProject:
        'SELECT t.id, t.uid, t.image_paths AS path FROM camera_tests t '
        'JOIN visual_bibles b ON b.id = t.bible_id WHERE b.project_id = ?',
    subfolder: 'visual_bible/camera_tests',
    isList: true,
    nullable: false,
  ),
  MediaSlot(
    entityType: MediaEntityType.script,
    kind: MediaKind.file,
    table: 'projects',
    column: 'script_file_path',
    // El proyecto solo tiene un guion: su «uid» es fijo.
    selectForProject:
        "SELECT id, 'script' AS uid, script_file_path AS path FROM projects "
        'WHERE id = ?',
    subfolder: 'script',
  ),
  MediaSlot(
    entityType: MediaEntityType.annotatedPdf,
    kind: MediaKind.file,
    table: 'project_annotated_pdfs',
    column: 'pdf_path',
    selectForProject:
        'SELECT id, uid, pdf_path AS path FROM project_annotated_pdfs '
        'WHERE project_id = ?',
    subfolder: 'annotated_pdfs',
    nullable: false,
  ),
  MediaSlot(
    entityType: MediaEntityType.setScan,
    kind: MediaKind.file,
    table: 'location_base_plans',
    column: 'scan_path',
    selectForProject:
        'SELECT id, uid, scan_path AS path FROM location_base_plans '
        'WHERE project_id = ?',
    subfolder: 'locations/scans',
  ),
  MediaSlot(
    entityType: MediaEntityType.setModel3d,
    kind: MediaKind.file,
    table: 'location_base_plans',
    column: 'model3d_path',
    selectForProject:
        'SELECT id, uid, model3d_path AS path FROM location_base_plans '
        'WHERE project_id = ?',
    subfolder: 'locations/models',
  ),
  MediaSlot(
    entityType: MediaEntityType.siteScan,
    kind: MediaKind.file,
    table: 'location_sites',
    column: 'scan_path',
    selectForProject:
        'SELECT id, uid, scan_path AS path FROM location_sites '
        'WHERE project_id = ?',
    subfolder: 'sites/scans',
  ),
];

MediaSlot? mediaSlotFor(String entityType) {
  for (final slot in kMediaSlots) {
    if (slot.entityType == entityType) return slot;
  }
  return null;
}

/// Clave de un archivo de un hueco: `uid:<uid>` o, en listas, `uid:<uid>#<n>`.
String mediaSlotKey(String uid, [int? index]) =>
    index == null ? 'uid:$uid' : 'uid:$uid#$index';

/// El uid y la posición de una clave de hueco.
(String uid, int? index)? parseMediaSlotKey(String key) {
  if (!key.startsWith('uid:')) return null;
  final rest = key.substring(4);
  final hash = rest.lastIndexOf('#');
  if (hash < 0) return (rest, null);
  final index = int.tryParse(rest.substring(hash + 1));
  if (index == null) return (rest, null);
  return (rest.substring(0, hash), index);
}

/// Las rutas de un hueco de lista: acepta una lista JSON o una ruta suelta.
List<String> decodeSlotPaths(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return [];
  if (value.startsWith('[')) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return [for (final e in decoded) '$e'];
    } catch (_) {}
    return [];
  }
  return [value];
}

