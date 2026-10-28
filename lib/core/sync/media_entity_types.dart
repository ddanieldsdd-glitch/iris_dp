/// Tipos de entidad con imagen sincronizable.
abstract final class MediaEntityType {
  static const moodboard = 'moodboard';
  static const shotReference = 'shot_reference';
  static const site = 'site';
  static const location = 'location';
  static const shootDocument = 'shoot_document';
  static const projectCover = 'project_cover';

  // Archivos de huecos (ver `kMediaSlots`).
  static const shotStoryboard = 'shot_storyboard';
  static const shotPlanImage = 'shot_plan_image';
  /// Ya no se usa: la principal es una de las referencias del plano. Lo
  /// subido con este tipo se ignora al bajar.
  static const shotMainReference = 'shot_main_reference';
  static const lightSketch = 'light_sketch';
  static const planImage = 'plan_image';
  static const lightingReference = 'lighting_reference';
  static const setPlan = 'set_plan';
  static const bibleEvidence = 'bible_evidence';
  static const opticsSample = 'optics_sample';
  static const cameraTest = 'camera_test';
  static const script = 'script';
  static const annotatedPdf = 'annotated_pdf';
  static const setScan = 'set_scan';
  static const setModel3d = 'set_model3d';
  static const siteScan = 'site_scan';
  static const colorBlockImage = 'color_block_image';
  static const exposureBlockImage = 'exposure_block_image';
  static const locationRefImage = 'location_ref_image';

  /// Miniatura de un asset de Unreal (cenital o 3/4), por ruta del asset:
  /// ver `UnrealThumbStore`. Va como archivo, no por Cloudinary.
  static const unrealThumb = 'unreal_thumb';

  /// Trazos editables de un boceto (`<imagen>.trazos.json`), que viajan con
  /// su imagen. Clave: `<tipo de la imagen>|<clave de la imagen>`.
  static const sketchStrokes = 'sketch_strokes';
}

/// Origen de una imagen ingerida.
abstract final class MediaIngestSource {
  static const paste = 'paste';
  static const filePicker = 'file_picker';
  static const drag = 'drag';
  static const url = 'url';
  static const sync = 'sync';
}

/// Slug seguro para rutas Cloudinary.
String mediaSlug(String input, {int maxLen = 32}) {
  final lower = input.toLowerCase();
  final buf = StringBuffer();
  for (final c in lower.runes) {
    final ch = String.fromCharCode(c);
    if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
      buf.write(ch);
    } else if (ch == ' ' || ch == '-' || ch == '_') {
      buf.write('_');
    }
  }
  var s = buf.toString();
  while (s.contains('__')) {
    s = s.replaceAll('__', '_');
  }
  s = s.replaceAll(RegExp(r'^_+|_+$'), '');
  if (s.isEmpty) return 'item';
  if (s.length > maxLen) return s.substring(0, maxLen);
  return s;
}

String sortOrderPad(int order, {int width = 4}) =>
    order.toString().padLeft(width, '0');
