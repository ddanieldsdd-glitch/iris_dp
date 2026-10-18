import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/sync_merge_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('una base en 53 sin las tablas de la mezcla las recupera al abrir',
      () async {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('iris_merge_tables');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/iris_dp.db');

    // Base al día y sin las tablas, como la que se encontró en el Mac.
    var db = AppDatabase.forTesting(NativeDatabase(file));
    await db.customStatement('DROP TABLE sync_content_bases');
    await db.customStatement('DROP TABLE sync_conflict_log');
    await db.close();

    db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    expect(await ContentBaseBundleStore.has(db, 1), isFalse);
    expect(await SyncConflictLog.list(db), isEmpty);
  });
}
