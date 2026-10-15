import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/content_sync_base_store.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/core/sync/project_content_sync_service.dart';
import 'package:iris_dp/core/sync/sync_plan.dart';
import 'package:iris_dp/core/sync/sync_plan_applier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `cloud_project_snapshots` en memoria, con los filtros que usa la app:
/// `eq`, `in` e `is.null`, insert que choca con la clave y update con
/// `select`.
class _FakeSnapshots {
  final rows = <String, Map<String, dynamic>>{};
  int writes = 0;

  bool _matches(Map<String, dynamic> row, Map<String, String> query) {
    for (final entry in query.entries) {
      final column = entry.key;
      final filter = entry.value;
      if (const {'select', 'limit', 'order'}.contains(column)) continue;
      if (filter.startsWith('eq.')) {
        if ('${row[column]}' != filter.substring(3)) return false;
      } else if (filter == 'is.null') {
        if (row[column] != null) return false;
      } else if (filter.startsWith('in.(')) {
        final values = filter
            .substring(4, filter.length - 1)
            .split(',')
            .map((v) => v.replaceAll('"', ''));
        if (!values.contains('${row[column]}')) return false;
      }
    }
    return true;
  }

  http.Response _json(Object body, http.Request request, [int status = 200]) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );

  SupabaseClient client() => SupabaseClient(
    'http://127.0.0.1:9',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSJ9.test',
    httpClient: MockClient((request) async {
      if (!request.url.path.contains('cloud_project_snapshots')) {
        return _json(<Object>[], request);
      }
      final query = request.url.queryParameters;
      final matching = rows.values.where((r) => _matches(r, query)).toList();
      switch (request.method) {
        case 'GET':
          return _json(matching, request);
        case 'POST':
          final row = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          final upsert =
              (request.headers['Prefer'] ?? request.headers['prefer'] ?? '')
                  .contains('merge-duplicates');
          if (rows.containsKey(row['project_id']) && !upsert) {
            return _json(
              {
                'code': '23505',
                'message': 'duplicate key value violates unique constraint',
                'details': null,
                'hint': null,
              },
              request,
              409,
            );
          }
          rows[row['project_id'] as String] = row;
          writes++;
          return _json([row], request, 201);
        case 'PATCH':
          final patch = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          for (final row in matching) {
            row.addAll(patch);
            writes++;
          }
          return _json(matching, request);
      }
      return _json(<Object>[], request);
    }),
  );
}

void main() {
  late AppDatabase db;
  late _FakeSnapshots cloud;
  late SupabaseClient client;
  late int projectId;
  const cloudId = 'cloud-1';

  Future<void> addScene(int number) => db.insertScene(
    ScenesCompanion.insert(
      projectId: projectId,
      number: number,
      name: 'INT. CASA $number - DÍA',
      locationCanonical: 'INT. CASA $number - DÍA',
      locationPureName: 'CASA $number',
      sortOrder: Value(number),
    ),
  );

  /// Deja este dispositivo y la nube sincronizados con el contenido actual.
  Future<String> syncedState() async {
    final bundle = await ProjectContentBundle.export(db, projectId);
    final hash = ProjectContentBundle.hashBundle(bundle);
    cloud.rows[cloudId] = {
      'project_id': cloudId,
      'content': bundle,
      'content_hash': hash,
    };
    await ContentSyncBaseStore.save(db, projectId,
      ContentSyncBase(localHash: hash, cloudHash: hash),
    );
    return hash;
  }

  /// Otro dispositivo sube su versión.
  void otherDeviceUploads() {
    cloud.rows[cloudId] = {
      'project_id': cloudId,
      'content': {'version': 4, 'otro': true},
      'content_hash': 'version-de-otro-dispositivo',
    };
  }

  Future<List<CloudSyncQueueData>> pendingQueue() => (db.select(
    db.cloudSyncQueue,
  )..where((q) => q.processed.equals(false))).get();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    cloud = _FakeSnapshots();
    client = cloud.client();
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'lala', cloudId: const Value(cloudId)),
    );
    await addScene(1);
  });

  group('la cola de subidas', () {
    test('no pisa la nube si otro dispositivo ha subido', () async {
      await syncedState();
      await addScene(2);
      await db.touchProjectContent(projectId);
      otherDeviceUploads();
      cloud.writes = 0;

      await CloudSyncQueueService(db, client).processPending();

      expect(cloud.writes, 0);
      expect(
        cloud.rows[cloudId]!['content_hash'],
        'version-de-otro-dispositivo',
      );
      // Queda pendiente: la próxima sincronización lo enseña como conflicto.
      expect(await pendingQueue(), hasLength(1));
    });

    test('sube si la nube sigue como en la última sincronización', () async {
      await syncedState();
      await addScene(2);
      await db.touchProjectContent(projectId);

      await CloudSyncQueueService(db, client).processPending();

      final localHash = await ProjectContentBundle.computeLocalHash(
        db,
        projectId,
      );
      expect(cloud.rows[cloudId]!['content_hash'], localHash);
      expect(
        (await ContentSyncBaseStore.load(db, projectId))!.cloudHash,
        localHash,
      );
      expect(await pendingQueue(), isEmpty);
    });

    test('sin sincronización previa no sube nada', () async {
      otherDeviceUploads();
      await db.touchProjectContent(projectId);
      cloud.writes = 0;

      await CloudSyncQueueService(db, client).processPending();

      expect(cloud.writes, 0);
      expect(await pendingQueue(), hasLength(1));
    });
  });

  group('aplicar el plan', () {
    test('subir no pisa una versión más nueva que la del plan', () async {
      final seen = await syncedState();
      await addScene(2);
      // El plan se hizo viendo `seen`; antes de aplicarlo sube otro.
      otherDeviceUploads();
      cloud.writes = 0;

      final result = await SyncPlanApplier(db, client).apply(
        SyncPlan(
          items: [
            SyncPlanItem(
              action: SyncPlanAction.pushContentLocal,
              title: 'lala — contenido',
              description: '',
              localProjectId: projectId,
              cloudId: cloudId,
              cloudContentHash: seen,
            ),
          ],
        ),
        'workspace',
      );

      expect(result.pushed, 0);
      expect(cloud.writes, 0);
      expect(
        cloud.rows[cloudId]!['content_hash'],
        'version-de-otro-dispositivo',
      );
    });

    test(
      'elegir «lo de aquí» en un conflicto pisa la versión revisada',
      () async {
        await syncedState();
        await addScene(2);
        otherDeviceUploads();

        final result = await SyncPlanApplier(db, client).apply(
          SyncPlan(
            items: [
              SyncPlanItem(
                action: SyncPlanAction.contentConflict,
                title: 'lala — contenido',
                description: '',
                localProjectId: projectId,
                cloudId: cloudId,
                cloudContentHash: 'version-de-otro-dispositivo',
                choice: SyncResolutionChoice.useLocal,
              ),
            ],
          ),
          'workspace',
        );

        expect(result.pushed, 1);
        expect(
          cloud.rows[cloudId]!['content_hash'],
          await ProjectContentBundle.computeLocalHash(db, projectId),
        );
      },
    );

    test('actualizar el nombre del proyecto no sube el contenido', () async {
      await syncedState();
      await addScene(2);
      otherDeviceUploads();
      cloud.writes = 0;

      await SyncPlanApplier(db, client).apply(
        SyncPlan(
          items: [
            SyncPlanItem(
              action: SyncPlanAction.updateCloudFromLocal,
              title: 'lala',
              description: '',
              localProjectId: projectId,
              cloudId: cloudId,
              localProject: (await db.getProject(projectId))!,
            ),
          ],
        ),
        'workspace',
      );

      expect(cloud.writes, 0);
      expect(
        cloud.rows[cloudId]!['content_hash'],
        'version-de-otro-dispositivo',
      );
    });

    test('una copia antigua sin huella se reconoce por su contenido', () async {
      await syncedState();
      cloud.rows[cloudId]!['content_hash'] = null;
      final seen = ProjectContentBundle.hashBundle(
        Map<String, dynamic>.from(cloud.rows[cloudId]!['content'] as Map),
      );
      await addScene(2);

      await ProjectContentSyncService(
        db,
        client,
      ).upload(projectId, cloudId, expectedCloudHash: seen);

      expect(
        cloud.rows[cloudId]!['content_hash'],
        await ProjectContentBundle.computeLocalHash(db, projectId),
      );
    });

    test('sin copia en la nube, no pisa una creada entretanto', () async {
      otherDeviceUploads();

      expect(
        () => ProjectContentSyncService(
          db,
          client,
        ).upload(projectId, cloudId, expectedCloudHash: null),
        throwsA(isA<CloudContentChanged>()),
      );
    });
  });
}
