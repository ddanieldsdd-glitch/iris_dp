import 'dart:io';

/// «tamaño:modificado» de un archivo: cambia si se reescribe (un boceto
/// redibujado encima conserva la ruta, pero no el sello). Nulo si no existe.
String? mediaFileStamp(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  final stat = file.statSync();
  return '${stat.size}:${stat.modified.millisecondsSinceEpoch}';
}

/// Los trazos editables de un boceto, junto a su imagen (ver `sketch_pad.dart`).
String sketchStrokesPathOf(String imagePath) => '$imagePath.trazos.json';

/// Clave de los trazos de una imagen: `<tipo>|<clave>` de la imagen.
String sketchStrokesKey(String imageType, String imageKey) =>
    '$imageType|$imageKey';

/// El tipo y la clave de la imagen de unos trazos.
(String type, String key)? parseSketchStrokesKey(String key) {
  final bar = key.indexOf('|');
  if (bar <= 0) return null;
  return (key.substring(0, bar), key.substring(bar + 1));
}
