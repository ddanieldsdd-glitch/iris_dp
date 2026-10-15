import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';

/// Las migraciones no rompen con columnas que ya existen.
void main() {
  test('una base que ya tiene las columnas migra desde el esquema 1', () async {
    final dir = Directory.systemTemp.createTempSync('iris_migration_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/iris_dp.db');

    // Esquema de hoy, con datos.
    final fresh = AppDatabase.forTesting(NativeDatabase(file));
    final projectId = await fresh.insertProject(
      ProjectsCompanion.insert(name: 'lala'),
    );
    await fresh.close();

    // Se abre como si fuera del esquema 1: todos los pasos de migración se
    // encuentran sus tablas y columnas ya puestas, como pasa con las tablas
    // que `createTable` crea completas en una base antigua.
    final reopened = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (raw) => raw.execute('PRAGMA user_version = 1'),
      ),
    );
    addTearDown(reopened.close);

    final project = await reopened.getProject(projectId);
    expect(project?.name, 'lala');
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), kSchemaVersion);
  });
}
