import 'package:drift/drift.dart' show OpeningDetails, QueryExecutor, QueryExecutorUser;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/storage/ios_container_paths.dart';

const _old = '/var/mobile/Containers/Data/Application/'
    '11111111-2222-3333-4444-555555555555';
const _new = '/var/mobile/Containers/Data/Application/'
    'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE';

class _Opener extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

void main() {
  group('rootOf / rebase', () {
    test('saca la raíz del contenedor de una ruta de iOS', () {
      expect(
        IosContainerPaths.rootOf('$_old/Documents/iris_dp/a.png'),
        _old,
      );
      expect(IosContainerPaths.rootOf(_old), _old);
    });

    test('también en el simulador', () {
      const sim = '/Users/x/Library/Developer/CoreSimulator/Devices/'
          '0F0F0F0F-0000-1111-2222-333333333333/data/Containers/Data/'
          'Application/11111111-2222-3333-4444-555555555555';
      expect(IosContainerPaths.rootOf('$sim/Library/x.db'), sim);
    });

    test('ignora rutas fuera de un contenedor', () {
      expect(IosContainerPaths.rootOf('/Users/daniel/Documents/a.png'), isNull);
      expect(
        IosContainerPaths.rebase('/Users/daniel/Documents/a.png', _new),
        '/Users/daniel/Documents/a.png',
      );
    });

    test('cambia solo el contenedor', () {
      expect(
        IosContainerPaths.rebase(
          '$_old/Library/Application Support/iris_dp/app_data',
          _new,
        ),
        '$_new/Library/Application Support/iris_dp/app_data',
      );
    });
  });

  test('rewriteDatabase cambia rutas en columnas y JSON, y nada más', () async {
    late List<Map<String, Object?>> rows;
    final db = NativeDatabase.memory(
      setup: (raw) {
        raw.execute(
          'CREATE TABLE stills (id INTEGER, image_path TEXT, meta TEXT, n INTEGER)',
        );
        raw.execute(
          'INSERT INTO stills VALUES (?, ?, ?, ?)',
          [1, '$_old/Documents/a.png', '{"src":"$_old/Documents/b.png"}', 7],
        );
        raw.execute(
          'INSERT INTO stills VALUES (?, ?, ?, ?)',
          [2, '/Users/daniel/c.png', 'sin rutas', 8],
        );
        IosContainerPaths.rewriteDatabase(
          select: (sql) => raw.select(sql).toList(),
          execute: raw.execute,
          oldRoot: _old,
          newRoot: _new,
        );
        rows = raw.select('SELECT * FROM stills ORDER BY id').toList();
      },
    );
    await db.ensureOpen(_Opener());
    await db.close();

    expect(rows[0]['image_path'], '$_new/Documents/a.png');
    expect(rows[0]['meta'], '{"src":"$_new/Documents/b.png"}');
    expect(rows[0]['n'], 7);
    expect(rows[1]['image_path'], '/Users/daniel/c.png');
    expect(rows[1]['meta'], 'sin rutas');
  });
}
