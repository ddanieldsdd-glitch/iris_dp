import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/sync/plan_scan_store.dart';

/// Escaneos importados en la planta. Se copian, no se enlazan: así siguen
/// ahí aunque el original se mueva o se borre. Con proyecto van a su
/// carpeta y viajan por la nube ([PlanScanStore]); los de antes de F6.12.5
/// están en la carpeta de la app y se pasan al proyecto al abrirlos.
class ScanStore {
  ScanStore._();

  /// Carpeta antigua, común a todos los proyectos.
  static Future<Directory> dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory(p.join(base.path, 'scans'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Nombre nuevo para un escaneo con la extensión de [sourcePath].
  static String newName(String sourcePath) {
    final ext = p.extension(sourcePath).replaceFirst('.', '').toLowerCase();
    final random = math.Random();
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
        '${random.nextInt(1 << 20).toRadixString(36)}.$ext';
  }

  /// Copia un escaneo (al proyecto [projectId], si lo hay) y devuelve su
  /// nombre allí.
  static Future<String> import(String sourcePath, {int? projectId}) async {
    final name = newName(sourcePath);
    if (projectId != null) {
      await PlanScanStore.save(
        projectId: projectId,
        key: name,
        sourcePath: sourcePath,
      );
      return name;
    }
    final d = await dir();
    await File(sourcePath).copy(p.join(d.path, name));
    return name;
  }

  /// Solo un nombre, nunca una ruta: no se lee nada fuera de las carpetas.
  static bool _safe(String file) =>
      !(file.contains('/') || file.contains(r'\') || file.contains('..'));

  /// Ruta local del escaneo, o `null` si no está en esta máquina (en otro
  /// equipo, hasta que lo baje la sincronización).
  static Future<String?> pathOf(String file, {int? projectId}) async {
    if (!_safe(file)) return null;
    if (projectId != null) {
      final synced = await PlanScanStore.resolve(projectId, file);
      if (synced != null) return synced;
    }
    final legacy = File(p.join((await dir()).path, file));
    if (!await legacy.exists()) return null;
    // Uno de antes: se pasa al proyecto para que viaje.
    if (projectId != null && PlanScanStore.isKey(file)) {
      try {
        return await PlanScanStore.save(
          projectId: projectId,
          key: file,
          sourcePath: legacy.path,
        );
      } catch (_) {
        // Sin carpeta de proyecto: se sigue leyendo de la antigua.
      }
    }
    return legacy.path;
  }

  /// Los bytes de un escaneo, o `null` si ya no está en esta máquina.
  static Future<List<int>?> bytesOf(String file, {int? projectId}) async {
    final path = await pathOf(file, projectId: projectId);
    return path == null ? null : File(path).readAsBytes();
  }
}
