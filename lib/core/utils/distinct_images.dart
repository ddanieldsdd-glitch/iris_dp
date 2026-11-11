import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Las imágenes de [paths] sin repetir, en su orden. Dos rutas son la misma
/// imagen si apuntan al mismo archivo (con otras barras o mayúsculas en
/// Windows) o si sus archivos tienen los mismos bytes: «Usar el dibujo del
/// storyboard» y las reimportaciones copian la imagen con otro nombre.
/// Las que no existen en disco se quedan fuera.
Future<List<String>> distinctImagePaths(Iterable<String?> paths) async {
  final seenPaths = <String>{};
  final seenContent = <String>{};
  final result = <String>[];
  for (final path in paths) {
    if (path == null || path.trim().isEmpty) continue;
    if (!seenPaths.add(_pathKey(path))) continue;
    final file = File(path);
    if (!await file.exists()) continue;
    final key = await _contentKey(file);
    if (key != null && !seenContent.add(key)) continue;
    result.add(path);
  }
  return result;
}

String _pathKey(String path) {
  final normal = p.normalize(p.absolute(path));
  return Platform.isWindows || Platform.isMacOS ? normal.toLowerCase() : normal;
}

Future<String?> _contentKey(File file) async {
  try {
    final bytes = await file.readAsBytes();
    return '${bytes.length}:${md5.convert(bytes)}';
  } on FileSystemException {
    return null;
  }
}
