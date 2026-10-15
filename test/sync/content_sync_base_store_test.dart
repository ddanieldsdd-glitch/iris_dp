import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/content_sync_base_store.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/core/sync/sync_plan_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_mock_client.dart';

/// B2: las huellas de sincronización y el catálogo viven en la base.
void main() {
  late AppDatabase db;
  late int projectId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'lala'));
  });

  test('las huellas de las preferencias pasan a la base una vez', () async {
    SharedPreferences.setMockInitialValues({
      'iris_content_sync_base_local_$projectId': 'local-1',
      'iris_content_sync_base_cloud_$projectId': 'nube-1',
    });

    final base = await ContentSyncBaseStore.load(db, projectId);

    expect(base?.localHash, 'local-1');
    expect(base?.cloudHash, 'nube-1');
    final project = (await db.getProject(projectId))!;
    expect(project.contentSyncBaseLocal, 'local-1');
    expect(project.contentSyncBaseCloud, 'nube-1');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('iris_content_sync_base_local_$projectId'), isNull);
  });

  test('guardar escribe en el proyecto, no en las preferencias', () async {
    SharedPreferences.setMockInitialValues({});
    await ContentSyncBaseStore.save(
      db,
      projectId,
      const ContentSyncBase(localHash: 'a', cloudHash: 'b'),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    final base = await ContentSyncBaseStore.load(db, projectId);
    expect((base!.localHash, base.cloudHash), ('a', 'b'));
  });

  test('el catálogo propio del moodboard viaja en el bundle', () async {
    SharedPreferences.setMockInitialValues({});
    await (db.update(db.projects)..where((p) => p.id.equals(projectId))).write(
      const ProjectsCompanion(
        moodboardCatalogJson: Value('{"lightingLook":["Neón urbano"]}'),
      ),
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
    final bundle = await ProjectContentBundle.export(db, projectId);
    final target = await db.insertProject(
      ProjectsCompanion.insert(name: 'otro'),
    );

    await ProjectContentBundle.importBundle(db, target, bundle);

    expect(
      (await db.getProject(target))!.moodboardCatalogJson,
      '{"lightingLook":["Neón urbano"]}',
    );
  });

  test(
    'si aquí y en la nube coinciden, la base queda en el proyecto',
    () async {
      SharedPreferences.setMockInitialValues({
        'iris_content_sync_base_local_$projectId': 'huella-antigua',
        'iris_content_sync_base_cloud_$projectId': 'huella-antigua',
      });
      await (db.update(db.projects)..where((p) => p.id.equals(projectId)))
          .write(const ProjectsCompanion(cloudId: Value('cloud-1')));
      await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 1,
          name: 'INT. CASA - DÍA',
          locationCanonical: 'INT. CASA - DÍA',
          locationPureName: 'CASA',
        ),
      );
      final bundle = await ProjectContentBundle.export(db, projectId);
      final hash = ProjectContentBundle.hashBundle(bundle);
      final project = (await db.getProject(projectId))!;
      final client = createSupabaseMockClient(
        snapshotsTableMissing: false,
        snapshots: [
          {'project_id': 'cloud-1', 'content': bundle, 'content_hash': hash},
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

      final plan = await SyncPlanBuilder(db, client).build('ws');

      expect(plan.items.where((i) => i.isContentSync), isEmpty);
      final stored = (await db.getProject(projectId))!;
      expect(stored.contentSyncBaseLocal, hash);
      expect(stored.contentSyncBaseCloud, hash);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('iris_content_sync_base_local_$projectId'),
        isNull,
      );
    },
  );
}
