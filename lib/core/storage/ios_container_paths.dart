import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Rutas absolutas que sobreviven a que iOS mueva el contenedor de la app.
///
/// En iOS todo lo de la app vive en `…/Data/Application/<UUID>/`, y ese UUID
/// puede cambiar al actualizar o reinstalar (con SideStore pasa a menudo).
/// La configuración de almacenamiento y la base guardan rutas absolutas, así
/// que al arrancar se detecta el contenedor anterior y se reescriben.
abstract final class IosContainerPaths {
  IosContainerPaths._();

  static final _rootPattern =
      RegExp(r'^(.*?/Data/Application/[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12})(?=/|$)');

  /// Contenedor de este arranque (solo iOS).
  static String? currentRoot;

  /// Contenedor anterior, si iOS lo ha movido desde el último arranque.
  static String? previousRoot;

  static String? _markerPath;

  /// Raíz del contenedor dentro de [path], o null si no está en uno.
  static String? rootOf(String path) => _rootPattern.firstMatch(path)?.group(1);

  /// [path] con su contenedor cambiado por [newRoot].
  static String rebase(String path, String newRoot) {
    final old = rootOf(path);
    if (old == null || old == newRoot) return path;
    return newRoot + path.substring(old.length);
  }

  /// Averigua si el contenedor ha cambiado. [configuredPath] es una ruta de
  /// la configuración guardada; sirve de pista la primera vez, cuando aún no
  /// existe el marcador.
  static Future<void> detect({String? configuredPath}) async {
    if (!Platform.isIOS) return;
    final docs = await getApplicationDocumentsDirectory();
    final current = rootOf(docs.path);
    if (current == null) return;
    currentRoot = current;

    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'iris_dp'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final marker = File(p.join(dir.path, 'container_root'));
    _markerPath = marker.path;

    String? last;
    if (await marker.exists()) {
      last = (await marker.readAsString()).trim();
    } else if (configuredPath != null) {
      last = rootOf(configuredPath);
    }

    if (last != null && last.isNotEmpty && last != current) {
      previousRoot = last;
    } else {
      // Sin cambio: se apunta ya. Con cambio, se apunta cuando la base se ha
      // reescrito, para que un fallo a medias se reintente en el siguiente
      // arranque.
      await marker.writeAsString(current, flush: true);
    }
  }

  /// Ruta del marcador y contenedor actual, para que la base los apunte tras
  /// reescribirse (corre en otro isolate, no ve estos campos).
  static String? get markerPath => _markerPath;

  /// Cambia [oldRoot] por [newRoot] en todas las columnas de texto de la base,
  /// JSON incluidos, en una sola transacción. El UUID del contenedor hace que
  /// no pueda coincidir con nada que no sea una ruta.
  static void rewriteDatabase({
    required List<Map<String, Object?>> Function(String sql) select,
    required void Function(String sql, List<Object?> args) execute,
    required String oldRoot,
    required String newRoot,
  }) {
    final tables = select(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%'",
    ).map((row) => row['name']! as String);

    execute('BEGIN', const []);
    try {
      for (final table in tables) {
        final columns = select('PRAGMA table_info("$table")')
            .where((c) => (c['type'] as String? ?? '').toUpperCase().contains('TEXT'))
            .map((c) => c['name']! as String);
        for (final column in columns) {
          execute(
            'UPDATE "$table" SET "$column" = replace("$column", ?, ?) '
            'WHERE instr("$column", ?) > 0',
            [oldRoot, newRoot, oldRoot],
          );
        }
      }
      execute('COMMIT', const []);
    } catch (_) {
      execute('ROLLBACK', const []);
      rethrow;
    }
  }

  /// Apunta [root] como contenedor conocido.
  static void writeMarker(String markerPath, String root) {
    File(markerPath).writeAsStringSync(root, flush: true);
  }
}
