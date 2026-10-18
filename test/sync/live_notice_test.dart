import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/auto_sync_scheduler.dart';
import 'package:iris_dp/core/sync/content_sync_base_store.dart';
import 'package:iris_dp/core/sync/realtime_hub.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late int projectId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'KEBAB', cloudId: const Value('c1')),
    );
    await ContentSyncBaseStore.save(
      db,
      projectId,
      const ContentSyncBase(localHash: 'aqui', cloudHash: 'nube-1'),
    );
  });

  test('una versión que aquí ya se conoce no hace bajar nada', () async {
    expect(
      await liveNoticeIsNew(
        db,
        const SnapshotNotice(projectCloudId: 'c1', hash: 'nube-1'),
      ),
      isFalse,
    );
  });

  test('una versión nueva, o un proyecto que aquí no está, sí', () async {
    expect(
      await liveNoticeIsNew(
        db,
        const SnapshotNotice(projectCloudId: 'c1', hash: 'nube-2'),
      ),
      isTrue,
    );
    expect(
      await liveNoticeIsNew(
        db,
        const SnapshotNotice(projectCloudId: 'otro', hash: 'x'),
      ),
      isTrue,
    );
  });

  test('el id de la instalación se guarda y no cambia', () async {
    final a = await InstallId.get();
    expect(a, hasLength(16));
    expect(await InstallId.get(), a);
  });
}
