import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_health.dart';
import 'package:path/path.dart' as p;

void main() {
  test('una base recién creada está bien', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final report = await DatabaseHealth.check(db);
    expect(report.healthy, isTrue, reason: report.detail);
    expect(report.summary, 'La base de datos está bien.');
  });

  test('cuenta los huérfanos y no borra ninguno', () async {
    final raw = NativeDatabase.memory(
      setup: (d) => d.execute('PRAGMA foreign_keys = OFF'),
    );
    final db = AppDatabase.forTesting(raw);
    addTearDown(db.close);
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
      "INSERT INTO scenes (project_id, number, name, location_canonical, "
      "location_pure_name) VALUES (999, 1, 'a', 'b', 'c')",
    );
    final report = await DatabaseHealth.check(db);
    expect(report.damaged, isFalse);
    expect(report.orphansByTable['scenes'], 1);
    expect(report.summary, contains('no se ha borrado nada'));
    expect(await db.select(db.scenes).get(), hasLength(1));
  });

  test('un archivo dañado se informa sin lanzar', () async {
    final dir = Directory.systemTemp.createTempSync('iris_health_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'a.sqlite');
    final first = AppDatabase.forTesting(NativeDatabase(File(path)));
    await first.customSelect('SELECT 1').get();
    await first.close();
    // Se machaca el centro del archivo: las páginas de las tablas.
    final bytes = File(path).readAsBytesSync();
    bytes.fillRange(bytes.length ~/ 3, bytes.length, 0x5a);
    File(path).writeAsBytesSync(bytes);

    final damaged = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(() async {
      try {
        await damaged.close();
      } on Exception {
        // El archivo está roto a propósito.
      }
    });
    final report = await DatabaseHealth.check(damaged);
    expect(report.damaged, isTrue);
    expect(report.summary, contains('copia'));
  });

  test('hay instantánea del esquema actual y coincide con las tablas', () {
    final file = File('drift_schemas/drift_schema_v$kSchemaVersion.json');
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'Al subir kSchemaVersion, guarda su esquema: dart run drift_dev '
          'schema dump lib/core/database/app_database.dart '
          'drift_schemas/drift_schema_v$kSchemaVersion.json',
    );
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final saved = <String, Set<String>>{
      for (final e in (json['entities'] as List).cast<Map<String, dynamic>>())
        if (e['type'] == 'table')
          (e['data'] as Map)['name'] as String: {
            for (final c in ((e['data'] as Map)['columns'] as List))
              (c as Map)['name'] as String,
          },
    };
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final live = <String, Set<String>>{
      for (final t in db.allTables)
        t.actualTableName: {for (final c in t.$columns) c.$name},
    };
    expect(saved, live);
  });
}
