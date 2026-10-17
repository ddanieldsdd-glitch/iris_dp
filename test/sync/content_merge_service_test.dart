import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/content_merge_service.dart';
import 'package:iris_dp/core/sync/content_sync_base_store.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/core/sync/project_content_sync_service.dart';
import 'package:iris_dp/core/sync/sync_merge_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `cloud_project_snapshots` en memoria: `eq`, `select`, insert y update.
class _Cloud {
  final rows = <String, Map<String, dynamic>>{};

  /// Antes de cada escritura (para simular que otro equipo sube entremedias).
  void Function()? beforeWrite;

  http.Response _json(Object body, http.Request r, [int status = 200]) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
        request: r,
      );

  bool _matches(Map<String, dynamic> row, Map<String, String> query) {
    for (final e in query.entries) {
      if (const {'select', 'limit', 'order'}.contains(e.key)) continue;
      if (e.value.startsWith('eq.') && '${row[e.key]}' != e.value.substring(3)) {
        return false;
      }
      if (e.value == 'is.null' && row[e.key] != null) return false;
    }
    return true;
  }

  SupabaseClient client() => SupabaseClient(
    'http://127.0.0.1:9',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSJ9.test',
    httpClient: MockClient((request) async {
      final q = request.url.queryParameters;
      final matching = rows.values.where((r) => _matches(r, q)).toList();
      switch (request.method) {
        case 'GET':
          final accept = request.headers['Accept'] ?? '';
          if (accept.contains('vnd.pgrst.object')) {
            return matching.isEmpty
                ? _json({'code': 'PGRST116', 'message': 'no rows'}, request, 406)
                : _json(matching.first, request);
          }
          return _json(matching, request);
        case 'POST':
          beforeWrite?.call();
          final row = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          if (rows.containsKey(row['project_id'])) {
            return _json({'code': '23505', 'message': 'duplicate'}, request, 409);
          }
          rows[row['project_id'] as String] = row;
          return _json([row], request, 201);
        case 'PATCH':
          beforeWrite?.call();
          final again = rows.values.where((r) => _matches(r, q)).toList();
          final patch = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          for (final row in again) {
            row.addAll(patch);
          }
          return _json(again, request);
      }
      return _json(<Object>[], request);
    }),
  );
}

class _Device {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  late int projectId;

  Future<void> init() async {
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'KEBAB', cloudId: const Value('c1')),
    );
  }

  Future<List<Shot>> shots() => (db.select(db.shots)
        ..where((s) => s.projectId.equals(projectId))
        ..orderBy([(s) => OrderingTerm.asc(s.number)]))
      .get();

  Future<void> edit(int number, ShotsCompanion change) async {
    final shot = (await shots()).firstWhere((s) => s.number == number);
    await (db.update(db.shots)..where((s) => s.id.equals(shot.id))).write(change);
    await db.touchProjectContent(projectId);
  }
}

void main() {
  late _Cloud cloud;
  late SupabaseClient client;
  late _Device mac;
  late _Device ipad;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cloud = _Cloud();
    client = cloud.client();

    mac = _Device();
    ipad = _Device();
    addTearDown(mac.db.close);
    addTearDown(ipad.db.close);
    await mac.init();
    await ipad.init();

    final sceneId = await mac.db.insertScene(
      ScenesCompanion.insert(
        projectId: mac.projectId,
        number: 1,
        name: 'INT. CASA - DÍA',
        locationCanonical: 'INT. CASA - DÍA',
        locationPureName: 'CASA',
      ),
    );
    for (final n in [1, 2, 3]) {
      await mac.db.insertShot(
        ShotsCompanion.insert(
          projectId: mac.projectId,
          sceneId: sceneId,
          number: n,
          sortOrder: Value(n),
        ),
      );
    }
    // El Mac sube y el iPad baja: los dos parten del mismo contenido.
    await ProjectContentSyncService(mac.db, client)
        .upload(mac.projectId, 'c1', expectedCloudHash: null);
    await ProjectContentSyncService(ipad.db, client)
        .download(ipad.projectId, 'c1');
  });

  Future<void> ipadUploads() async {
    final base = await ContentSyncBaseStore.load(ipad.db, ipad.projectId);
    await ProjectContentSyncService(ipad.db, client).upload(
      ipad.projectId,
      'c1',
      expectedCloudHash: base!.cloudHash,
    );
  }

  test('planos distintos editados en cada equipo: quedan los dos', () async {
    await mac.edit(1, const ShotsCompanion(lens: Value('35mm')));
    await ipad.edit(2, const ShotsCompanion(notes: Value('grúa')));
    await ipadUploads();

    final discarded = await ContentMergeService(mac.db, client)
        .mergeAndSync(mac.projectId, 'c1');

    expect(discarded, 0);
    final shots = await mac.shots();
    expect(shots.map((s) => s.lens), ['35mm', null, null]);
    expect(shots.map((s) => s.notes), [null, 'grúa', null]);
    // La nube tiene lo mismo y es la nueva base.
    final hash = await ProjectContentBundle.computeLocalHash(
      mac.db,
      mac.projectId,
    );
    expect(cloud.rows['c1']!['content_hash'], hash);
    expect(
      await ContentBaseBundleStore.load(
        mac.db,
        mac.projectId,
        localHash: hash,
        cloudHash: hash,
      ),
      isNotNull,
    );
  });

  test('el mismo campo en los dos: gana el último y queda en el historial',
      () async {
    await mac.edit(1, const ShotsCompanion(lens: Value('35mm')));
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await ipad.edit(1, const ShotsCompanion(lens: Value('85mm')));
    await ipadUploads();

    await ContentMergeService(mac.db, client).mergeAndSync(mac.projectId, 'c1');

    expect((await mac.shots()).first.lens, '85mm');
    final log = await SyncConflictLog.list(mac.db);
    expect(log, hasLength(1));
    expect(log.single.field, 'lens');
    expect(log.single.discardedValue, '35mm');
    expect(log.single.discardedSide, 'local');
  });

  test('si otro equipo sube mientras se mezcla, se vuelve a mezclar', () async {
    await mac.edit(1, const ShotsCompanion(lens: Value('35mm')));
    await ipad.edit(2, const ShotsCompanion(notes: Value('grúa')));
    await ipadUploads();

    // Justo antes de la primera subida del Mac, el iPad sube otra vez.
    var raced = false;
    cloud.beforeWrite = () {
      if (raced) return;
      raced = true;
      final row = cloud.rows['c1']!;
      final content = Map<String, dynamic>.from(row['content'] as Map);
      final shots = (content['shots'] as List).cast<Map<String, dynamic>>();
      shots[2] = {...shots[2], 'notes': 'añadido entremedias'};
      row['content'] = content;
      row['content_hash'] = ProjectContentBundle.hashBundle(content);
    };

    final discarded = await ContentMergeService(mac.db, client)
        .mergeAndSync(mac.projectId, 'c1');

    expect(discarded, 0);
    final shots = await mac.shots();
    expect(shots.map((s) => s.notes), [null, 'grúa', 'añadido entremedias']);
    expect(shots.first.lens, '35mm');
  });

  test('sin base guardada no mezcla: queda para revisar', () async {
    await mac.db.customStatement('DELETE FROM sync_content_bases');
    await mac.edit(1, const ShotsCompanion(lens: Value('35mm')));
    await ipad.edit(2, const ShotsCompanion(notes: Value('grúa')));
    await ipadUploads();

    expect(
      await ContentMergeService(mac.db, client).mergeAndSync(mac.projectId, 'c1'),
      isNull,
    );
    expect((await mac.shots())[1].notes, isNull);
  });
}
