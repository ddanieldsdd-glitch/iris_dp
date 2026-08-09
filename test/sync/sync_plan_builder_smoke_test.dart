import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/sync_plan.dart';
import 'package:iris_dp/core/sync/sync_plan_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_mock_client.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('build planifica pushNewLocal para proyectos sin cloudId', () async {
    await db.insertProject(ProjectsCompanion.insert(name: 'Solo en SQLite'));

    final client = createSupabaseMockClient();
    final plan = await SyncPlanBuilder(db, client).build('ws-smoke');

    expect(plan.items, hasLength(1));
    expect(plan.items.single.action, SyncPlanAction.pushNewLocal);
    expect(plan.items.single.title, 'Solo en SQLite');
  });

  test('build planifica importFromCloud cuando la fila solo existe en nube', () async {
    const cloudId = 'cloud-import-only';
    final client = createSupabaseMockClient(
      cloudProjects: [
        {
          'id': cloudId,
          'workspace_id': 'ws-smoke',
          'name': 'Proyecto remoto',
          'director_display': null,
          'description': null,
          'client_name': null,
          'status': 'preproduction',
          'sort_order': 0,
          'updated_at': '2026-08-08T10:00:00.000Z',
        },
      ],
    );

    final plan = await SyncPlanBuilder(db, client).build('ws-smoke');

    expect(plan.items, hasLength(1));
    expect(plan.items.single.action, SyncPlanAction.importFromCloud);
    expect(plan.items.single.cloudId, cloudId);
    expect(plan.items.single.title, 'Proyecto remoto');
  });

  test('build planifica updateCloudFromLocal cuando el local es más reciente', () async {
    const cloudId = 'cloud-linked';
    final localUpdated = DateTime.utc(2026, 8, 9, 12);
    final cloudUpdated = DateTime.utc(2026, 8, 8, 10);

    await db.into(db.projects).insert(
          ProjectsCompanion.insert(
            name: 'Nombre local',
            cloudId: const Value(cloudId),
            syncUpdatedAt: Value(localUpdated),
            updatedAt: Value(localUpdated),
          ),
        );

    final client = createSupabaseMockClient(
      cloudProjects: [
        {
          'id': cloudId,
          'workspace_id': 'ws-smoke',
          'name': 'Nombre nube',
          'director_display': null,
          'description': null,
          'client_name': null,
          'status': 'preproduction',
          'sort_order': 0,
          'updated_at': cloudUpdated.toIso8601String(),
        },
      ],
    );

    final plan = await SyncPlanBuilder(db, client).build('ws-smoke');

    expect(plan.items, hasLength(1));
    final item = plan.items.single;
    expect(item.action, SyncPlanAction.updateCloudFromLocal);
    expect(item.cloudId, cloudId);
    expect(item.diffs.single.field, 'name');
    expect(item.diffs.single.localValue, 'Nombre local');
    expect(item.diffs.single.cloudValue, 'Nombre nube');
  });
}
