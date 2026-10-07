import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';

void main() {
  test('migrar desde 44 no falla si las columnas ya existen', () async {
    // Caso real: una base con latitude y longitude sobrantes en
    // location_sites dejaba la migración a 46 a medias y la app sin
    // proyectos.
    final dir = await Directory.systemTemp.createTemp('iris_schema');
    final file = File('${dir.path}/db.sqlite');
    addTearDown(() => dir.delete(recursive: true));

    var db = AppDatabase.forTesting(NativeDatabase(file));
    await db.into(db.projects).insert(ProjectsCompanion.insert(name: 'P'));
    await db.customStatement('PRAGMA user_version = 44');
    await db.close();

    db = AppDatabase.forTesting(NativeDatabase(file));
    final projects = await db.select(db.projects).get();
    expect(projects.single.name, 'P');
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data['user_version'], 46);
    await db.close();
  });
}
