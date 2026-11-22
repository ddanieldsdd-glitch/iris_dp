import 'dart:io';

import 'package:path/path.dart' as p;

/// Modo de diario de la base (R6).
///
/// En WAL, escribir pasa de unos 17 ms a 0,1 ms y leer no bloquea a quien
/// escribe: se acaba el «database is locked» entre la versión que se cierra y
/// la que se abre tras una actualización. Pero WAL necesita memoria
/// compartida entre procesos (`-shm`) y que nadie copie el `.db` sin su
/// `-wal`: en una carpeta elegida a mano (disco externo, de red o
/// sincronizado con iCloud, Dropbox u OneDrive) no es seguro. Ahí la base
/// sigue en el modo de siempre.
abstract final class DatabaseJournal {
  DatabaseJournal._();

  /// Archivos que acompañan a la base en WAL. Copiar o mover la base sin
  /// ellos pierde lo último que se escribió.
  static const sidecars = ['-wal', '-shm'];

  /// WAL solo en la carpeta propia de la app en este equipo.
  static bool useWal({
    required String databasePath,
    required String defaultDatabasePath,
  }) => p.equals(p.normalize(databasePath), p.normalize(defaultDatabasePath));

  /// Pone la base en WAL o en el modo de siempre. Si otro proceso la tiene
  /// abierta y no se puede cambiar ahora, se queda como estaba: los dos
  /// modos funcionan, y se vuelve a intentar al abrirla la próxima vez.
  /// Devuelve el modo en que queda.
  ///
  /// [firstValue] devuelve la primera columna de la primera fila de una
  /// consulta; [execute] ejecuta una orden (las dos sobre la conexión que se
  /// está abriendo).
  static String apply({
    required bool wal,
    required Object? Function(String sql) firstValue,
    required void Function(String sql) execute,
  }) {
    String read(String sql) => '${firstValue(sql)}'.toLowerCase();
    try {
      final mode = read('PRAGMA journal_mode = ${wal ? 'WAL' : 'DELETE'}');
      // En WAL basta con sincronizar al volcar: un corte de luz puede perder
      // lo último, nunca estropear la base.
      if (mode == 'wal') execute('PRAGMA synchronous = NORMAL');
      return mode;
    } catch (_) {
      try {
        return read('PRAGMA journal_mode');
      } catch (_) {
        return 'unknown';
      }
    }
  }

  /// Última vez que se escribió la base, contando su `-wal`: en WAL el
  /// `.db` no cambia hasta que se vuelca.
  static DateTime lastWrite(String databasePath) {
    var latest = File(databasePath).lastModifiedSync();
    for (final suffix in sidecars) {
      final extra = File('$databasePath$suffix');
      if (!extra.existsSync()) continue;
      final at = extra.lastModifiedSync();
      if (at.isAfter(latest)) latest = at;
    }
    return latest;
  }

  /// Copia la base con sus `-wal` y `-shm`, y quita los que hubiera en el
  /// destino (son de otra base y la estropearían).
  static void copy(String from, String to) {
    for (final suffix in sidecars) {
      final stale = File('$to$suffix');
      if (stale.existsSync()) stale.deleteSync();
    }
    File(from).copySync(to);
    for (final suffix in sidecars) {
      final extra = File('$from$suffix');
      if (extra.existsSync()) extra.copySync('$to$suffix');
    }
  }
}
