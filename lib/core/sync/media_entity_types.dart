/// Tipos de entidad con imagen sincronizable.
abstract final class MediaEntityType {
  static const moodboard = 'moodboard';
  static const shotReference = 'shot_reference';
  static const site = 'site';
  static const location = 'location';
  static const shootDocument = 'shoot_document';
  static const projectCover = 'project_cover';
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
