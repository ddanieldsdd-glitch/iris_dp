import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/content_sync_base_store.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/core/sync/sync_plan.dart';
import 'package:iris_dp/core/sync/sync_plan_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_mock_client.dart';

/// Proyectos sincronizados con la huella antigua (`String.hashCode`) no salen
/// como modificados al pasar a SHA-256.
void main() {
  late AppDatabase db;
  late int projectId;
  const cloudId = 'cloud-1';

  Future<void> addScene(int number) => db.insertScene(
    ScenesCompanion.insert(
      projectId: projectId,
      number: number,
      name: 'INT. CASA $number - DÍA',
      locationCanonical: 'INT. CASA $number - DÍA',
      locationPureName: 'CASA $number',
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'lala', cloudId: const Value(cloudId)),
    );
    await addScene(1);
  });

  /// La nube y la base guardadas por una versión anterior de la app.
  Future<Map<String, dynamic>> syncedWithLegacyHash() async {
    final bundle = await ProjectContentBundle.export(db, projectId);
    final legacy = ProjectContentBundle.legacyHashBundle(bundle);
    await ContentSyncBaseStore.save(db, projectId,
      ContentSyncBase(localHash: legacy, cloudHash: legacy),
    );
    return {'project_id': cloudId, 'content': bundle, 'content_hash': legacy};
  }

  Future<List<SyncPlanItem>> contentItems(Map<String, dynamic> snapshot) async {
    final project = (await db.getProject(projectId))!;
    final client = createSupabaseMockClient(
      snapshotsTableMissing: false,
      snapshots: [snapshot],
      cloudProjects: [
        {
          'id': cloudId,
          'workspace_id': 'ws',
          'name': project.name,
          'status': project.status,
          'sort_order': project.sortOrder,
          'updated_at': project.updatedAt.toIso8601String(),
        },
      ],
    );
    final plan = await SyncPlanBuilder(db, client).build('ws');
    return plan.items.where((i) => i.isContentSync).toList();
  }

  test(
    'la huella nueva es SHA-256 y la antigua se sigue reconociendo',
    () async {
      final bundle = await ProjectContentBundle.export(db, projectId);
      final hash = ProjectContentBundle.hashBundle(bundle);
      final legacy = ProjectContentBundle.legacyHashBundle(bundle);

      expect(hash, hasLength(64));
      expect(ProjectContentBundle.isLegacyHash(legacy), isTrue);
      expect(ProjectContentBundle.bundleMatchesHash(bundle, hash), isTrue);
      expect(ProjectContentBundle.bundleMatchesHash(bundle, legacy), isTrue);
    },
  );

  test(
    'sin cambios, un proyecto con huella antigua no sale en el plan',
    () async {
      final snapshot = await syncedWithLegacyHash();

      expect(await contentItems(snapshot), isEmpty);
    },
  );

  test('un cambio aquí con huella antigua se sube, sin conflicto', () async {
    final snapshot = await syncedWithLegacyHash();
    await addScene(2);

    final items = await contentItems(snapshot);

    expect(items.single.action, SyncPlanAction.pushContentLocal);
  });

  test(
    'la nube subida ya con SHA-256 y el mismo contenido no es un cambio',
    () async {
      final snapshot = await syncedWithLegacyHash();
      snapshot['content_hash'] = ProjectContentBundle.hashBundle(
        Map<String, dynamic>.from(snapshot['content'] as Map),
      );
      await addScene(2);

      final items = await contentItems(snapshot);

      expect(items.single.action, SyncPlanAction.pushContentLocal);
    },
  );

  test('las rutas de los archivos no cuentan para la huella', () async {
    // En iOS la carpeta de la app cambia con cada instalación.
    Map<String, dynamic> withPaths(String root) => {
      'shots': [
        {
          'shotKey': 'shot:1:1',
          'number': 1,
          'storyboardImagePath': '$root/projects/2/storyboard/sb.jpg',
          'cameraPlanImagePath': '["$root/projects/2/references/p.png"]',
        },
      ],
    };
    final before = withPaths('/var/mobile/Containers/Data/Application/AAA');
    final after = withPaths('/var/mobile/Containers/Data/Application/BBB');

    expect(
      ProjectContentBundle.hashBundle(before),
      ProjectContentBundle.hashBundle(after),
    );
    expect(
      ProjectContentBundle.hashBundle(before),
      isNot(
        ProjectContentBundle.hashBundle({
          'shots': [
            {...(before['shots'] as List).single as Map, 'number': 2},
          ],
        }),
      ),
    );
  });
}
