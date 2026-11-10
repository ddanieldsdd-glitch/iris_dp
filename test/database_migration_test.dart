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

  test('la migración 60 → 61 añade grupos y columnas', () async {
    final dir = Directory.systemTemp.createTempSync('iris_sg_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/iris_dp.db');

    // Una base del esquema 60: sin la tabla ni las columnas nuevas.
    final fresh = AppDatabase.forTesting(NativeDatabase(file));
    final pid = await fresh.insertProject(
      ProjectsCompanion.insert(name: 'Kebab'),
    );
    final setupId = await fresh.insertLightSetup(
      LightSetupsCompanion.insert(projectId: pid, name: 'Setup A'),
    );
    await fresh.customStatement('DROP TABLE set_groups');
    for (final column in ['group_id', 'env_overrides_json', 'shoot_order']) {
      await fresh.customStatement(
        'ALTER TABLE light_setups DROP COLUMN $column',
      );
    }
    await fresh.customStatement(
      'ALTER TABLE location_sites DROP COLUMN set_order_mode',
    );
    await fresh.close();

    final reopened = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (raw) => raw.execute('PRAGMA user_version = 60'),
      ),
    );
    addTearDown(reopened.close);

    final setup = await reopened.getLightSetupById(setupId);
    expect(setup?.name, 'Setup A');
    expect(setup?.groupId, isNull);
    final groupId = await reopened.insertSetGroup(
      SetGroupsCompanion.insert(projectId: pid, name: 'Fondo'),
    );
    await reopened.assignLightSetupToGroup(setupId, groupId);
    await reopened.setLightSetupShootOrder(setupId, 3);
    await reopened.setLightSetupEnvOverrides(setupId, '{}');
    final after = (await reopened.getLightSetupById(setupId))!;
    expect(after.groupId, groupId);
    expect(after.shootOrder, 3);
    expect(after.envOverridesJson, '{}');
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), kSchemaVersion);
  });

  test(
    'la migración 61 → 62 añade sección de planta y orden de jornada',
    () async {
      final dir = Directory.systemTemp.createTempSync('iris_ex_migration');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/iris_dp.db');

      final fresh = AppDatabase.forTesting(NativeDatabase(file));
      final pid = await fresh.insertProject(
        ProjectsCompanion.insert(name: 'Kebab'),
      );
      final docId = await fresh
          .into(fresh.shootDocuments)
          .insert(
            ShootDocumentsCompanion.insert(projectId: pid, name: 'Jornada 1'),
          );
      await fresh.customStatement(
        'ALTER TABLE shots DROP COLUMN plan_view_json',
      );
      await fresh.customStatement(
        'ALTER TABLE shoot_documents DROP COLUMN day_order',
      );
      await fresh.close();

      final reopened = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (raw) => raw.execute('PRAGMA user_version = 61'),
        ),
      );
      addTearDown(reopened.close);

      final doc = await reopened.getShootDocument(docId);
      expect(doc?.name, 'Jornada 1');
      expect(doc?.dayOrder, isNull);
      final version = await reopened
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), kSchemaVersion);
    },
  );

  test('la migración 62 → 63 crea las reservas y se puede repetir', () async {
    final dir = Directory.systemTemp.createTempSync('iris_migration_63');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/iris_dp.db');

    final fresh = AppDatabase.forTesting(NativeDatabase(file));
    final projectId = await fresh.insertProject(
      ProjectsCompanion.insert(name: 'lala'),
    );
    await fresh.customStatement('DROP TABLE rental_items');
    await fresh.customStatement('DROP TABLE rental_reservations');
    await fresh.customStatement('DROP TABLE rental_houses');
    await fresh.close();

    for (var pass = 0; pass < 2; pass++) {
      final db = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (raw) => raw.execute('PRAGMA user_version = 62'),
        ),
      );
      expect((await db.getProject(projectId))?.name, 'lala');
      expect(await db.select(db.rentalReservations).get(), isEmpty);
      await db.close();
    }
  });
}
