import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/local_database_backup.dart';

void main() {
  test('dos copias en el mismo segundo no chocan', () async {
    // Visto en el Mac (2026-10-17): dos descargas en una pasada pedían la
    // copia a la vez y la segunda fallaba con «output file already exists».
    final dir = Directory.systemTemp.createTempSync('iris_backup_clash');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/iris_dp.db';
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);
    await db.insertProject(ProjectsCompanion.insert(name: 'lala'));

    final first = await LocalDatabaseBackup.create(
      db,
      label: 'antes-de-descargar',
      databaseFileOverride: path,
    );
    final second = await LocalDatabaseBackup.create(
      db,
      label: 'antes-de-descargar',
      databaseFileOverride: path,
    );

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(second, isNot(first));
    expect(File(first!).existsSync(), isTrue);
    expect(File(second!).existsSync(), isTrue);
  });
}
