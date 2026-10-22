import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Carpeta de la app con los escaneos importados. Se copian, no se
/// enlazan: así siguen ahí aunque el original se mueva o se borre.
class ScanStore {
  ScanStore._();

  static Future<Directory> dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory(p.join(base.path, 'scans'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Copia un escaneo a la carpeta y devuelve su nombre allí.
  static Future<String> import(String sourcePath) async {
    final ext = p.extension(sourcePath).replaceFirst('.', '').toLowerCase();
    final random = math.Random();
    final name =
        '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
        '${random.nextInt(1 << 20).toRadixString(36)}.$ext';
    final d = await dir();
    await File(sourcePath).copy(p.join(d.path, name));
    return name;
  }

  /// Los bytes de un escaneo, o `null` si ya no está en esta máquina.
  static Future<List<int>?> bytesOf(String file) async {
    // Solo un nombre, nunca una ruta: no se lee nada fuera de la carpeta.
    if (file.contains('/') || file.contains('\\') || file.contains('..')) {
      return null;
    }
    final f = File(p.join((await dir()).path, file));
    return await f.exists() ? f.readAsBytes() : null;
  }
}
