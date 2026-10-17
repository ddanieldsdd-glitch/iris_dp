import 'dart:io';

/// «tamaño:modificado» de un archivo: cambia si se reescribe (un boceto
/// redibujado encima conserva la ruta, pero no el sello). Nulo si no existe.
String? mediaFileStamp(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  final stat = file.statSync();
  return '${stat.size}:${stat.modified.millisecondsSinceEpoch}';
}
