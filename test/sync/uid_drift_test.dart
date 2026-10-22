import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/core/sync/sync_plan.dart';
import 'package:iris_dp/core/sync/sync_plan_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_mock_client.dart';

/// Un equipo que bajó el proyecto antes de que los uid viajaran tiene los
/// mismos datos con otros uid: la sincronización le propone descargar.
void main() {
  late AppDatabase db;
  late int projectId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'lala', cloudId: const Value('cloud-1')),
    );
    await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'INT. CASA - DÍA',
        locationCanonical: 'INT. CASA - DÍA',
        locationPureName: 'CASA',
      ),
    );
  });

  Future<List<SyncPlanItem>> plan(Map<String, dynamic> cloudBundle) async {
    final project = (await db.getProject(projectId))!;
    final client = createSupabaseMockClient(
      snapshotsTableMissing: false,
      snapshots: [
        {
          'project_id': 'cloud-1',
          'content': cloudBundle,
          'content_hash': ProjectContentBundle.hashBundle(cloudBundle),
        },
      ],
      cloudProjects: [
        {
          'id': 'cloud-1',
          'workspace_id': 'ws',
          'name': project.name,
          'status': project.status,
          'sort_order': project.sortOrder,
          'updated_at': project.updatedAt.toIso8601String(),
        },
      ],
    );
    final built = await SyncPlanBuilder(db, client).build('ws');
    return built.items.where((i) => i.isContentSync).toList();
  }

  test('con los mismos uid no hay nada que hacer', () async {
    final bundle = await ProjectContentBundle.export(db, projectId);
    expect(await plan(bundle), isEmpty);
  });

  test('mismo contenido con otros uid: propone descargar', () async {
    final cloud = await ProjectContentBundle.export(db, projectId);
    await db.customStatement("UPDATE scenes SET uid = 'uid-de-este-equipo'");

    final items = await plan(cloud);

    expect(items.single.action, SyncPlanAction.pullContentCloud);
  });

  test('la nube sin uid (bundle antiguo) no cuenta como distinta', () async {
    final cloud = await ProjectContentBundle.export(db, projectId);
    for (final row in cloud['scenes'] as List) {
      (row as Map).remove('uid');
    }
    expect(await plan(cloud), isEmpty);
  });
}
