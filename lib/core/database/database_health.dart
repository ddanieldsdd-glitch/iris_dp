import 'app_database.dart';

/// Resultado de revisar la base de datos. Solo informa: no arregla ni borra.
class DatabaseHealthReport {
  const DatabaseHealthReport({
    required this.integrityProblems,
    required this.orphansByTable,
  });

  /// Lo que SQLite dice que está dañado. Vacío si está sana.
  final List<String> integrityProblems;

  /// Filas que apuntan a algo que ya no existe, por tabla.
  final Map<String, int> orphansByTable;

  bool get damaged => integrityProblems.isNotEmpty;
  int get orphans => orphansByTable.values.fold(0, (a, b) => a + b);
  bool get healthy => !damaged && orphans == 0;

  /// Para el usuario.
  String get summary {
    if (damaged) {
      return 'La base de datos tiene daños. Restaura una copia reciente.';
    }
    if (orphans > 0) {
      return 'La base está entera. Hay $orphans '
          '${orphans == 1 ? 'dato suelto' : 'datos sueltos'} sin su elemento '
          'de origen; no se ha borrado nada.';
    }
    return 'La base de datos está bien.';
  }

  /// Para el registro de errores.
  String get detail => [
    ...integrityProblems,
    for (final e in orphansByTable.entries) '${e.key}: ${e.value} huérfanas',
  ].join('\n');
}

abstract final class DatabaseHealth {
  /// Cuántos problemas pide a SQLite como mucho: con unos pocos ya se sabe.
  static const maxProblems = 20;

  /// Revisa la estructura del archivo y las referencias entre tablas.
  ///
  /// Corre en el hilo de la base, sin frenar la interfaz. Nunca lanza: un
  /// archivo dañado suele hacer fallar la propia consulta, y eso también es
  /// un resultado.
  static Future<DatabaseHealthReport> check(AppDatabase db) async {
    final problems = <String>[];
    final orphans = <String, int>{};
    try {
      final rows = await db
          .customSelect('PRAGMA quick_check($maxProblems)')
          .get();
      for (final row in rows) {
        final text = row.data.values.first?.toString() ?? '';
        if (text != 'ok') problems.add(text);
      }
    } on Exception catch (e) {
      problems.add('$e');
    }
    try {
      final rows = await db.customSelect('PRAGMA foreign_key_check').get();
      for (final row in rows) {
        final table = row.data['table'] as String;
        orphans[table] = (orphans[table] ?? 0) + 1;
      }
    } on Exception catch (e) {
      problems.add('$e');
    }
    return DatabaseHealthReport(
      integrityProblems: problems,
      orphansByTable: orphans,
    );
  }
}
