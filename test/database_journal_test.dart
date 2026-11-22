import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_journal.dart';
import 'package:iris_dp/core/database/local_database_backup.dart';
import 'package:path/path.dart' as p;

AppDatabase _open(String path, {required bool wal}) => AppDatabase.forTesting(
  NativeDatabase(
    File(path),
    setup: (raw) => DatabaseJournal.apply(
      wal: wal,
      firstValue: (sql) => raw.select(sql).first.values.first,
      execute: raw.execute,
    ),
  ),
);

Future<String> _mode(AppDatabase db) async =>
    (await db.customSelect('PRAGMA journal_mode').getSingle()).data.values.first
        .toString();

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('iris_wal_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('WAL solo en la carpeta propia de la app', () {
    final home = p.join('a', 'iris_dp', 'app_data', 'iris_dp.db');
    expect(
      DatabaseJournal.useWal(databasePath: home, defaultDatabasePath: home),
      isTrue,
    );
    expect(
      DatabaseJournal.useWal(
        databasePath: p.join('a', 'iris_dp', '.', 'app_data', 'iris_dp.db'),
        defaultDatabasePath: home,
      ),
      isTrue,
    );
    expect(
      DatabaseJournal.useWal(
        databasePath: p.join('Volumes', 'Disco', 'iris_dp.db'),
        defaultDatabasePath: home,
      ),
      isFalse,
    );
  });

  test('abre en WAL y vuelve al modo de siempre fuera de su carpeta', () async {
    final path = p.join(dir.path, 'iris_dp.db');
    var db = _open(path, wal: true);
    expect(await _mode(db), 'wal');
    await db.close();

    db = _open(path, wal: false);
    expect(await _mode(db), 'delete');
    await db.close();
    expect(File('$path-wal').existsSync(), isFalse);
  });

  test('copiar con el -wal no pierde lo último escrito', () async {
    final path = p.join(dir.path, 'iris_dp.db');
    final db = _open(path, wal: true);
    await db.into(db.projects).insert(
      ProjectsCompanion.insert(name: 'Corto de prueba'),
    );
    // Lo escrito sigue en el -wal mientras la base está abierta.
    expect(File('$path-wal').lengthSync(), greaterThan(0));
    expect(
      DatabaseJournal.lastWrite(path).isBefore(
        File(path).lastModifiedSync(),
      ),
      isFalse,
    );

    final copy = p.join(dir.path, 'copia.db');
    File('$copy-wal').writeAsStringSync('de otra base');
    DatabaseJournal.copy(path, copy);
    await db.close();

    final other = _open(copy, wal: true);
    final names = (await other.select(other.projects).get()).map((r) => r.name);
    expect(names, contains('Corto de prueba'));
    await other.close();
  });

  test('reubicar: la copia preparada entra al reiniciar, sin el -wal viejo',
      () async {
    final path = p.join(dir.path, 'iris_dp.db');
    final current = _open(path, wal: true);
    await current.into(current.projects).insert(
      ProjectsCompanion.insert(name: 'Proyecto de aquí'),
    );

    final legacy = p.join(dir.path, 'antigua.db');
    final old = _open(legacy, wal: true);
    await old.into(old.projects).insert(
      ProjectsCompanion.insert(name: 'Proyecto de la carpeta antigua'),
    );
    final staged = '$path.reubicada-1';
    DatabaseJournal.copy(legacy, staged);
    await old.close();
    await LocalDatabaseBackup.scheduleReplace(
      staged,
      databaseFileOverride: path,
    );
    // La app se cierra con la base actual aún en WAL.
    await current.close();

    expect(LocalDatabaseBackup.applyPendingRestore(path), isTrue);
    final reopened = _open(path, wal: true);
    final names =
        (await reopened.select(reopened.projects).get()).map((r) => r.name);
    expect(names, ['Proyecto de la carpeta antigua']);
    await reopened.close();
  });
}
