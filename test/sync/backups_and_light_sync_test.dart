import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/local_database_backup.dart';
import 'package:iris_dp/core/sync/content_sync_base_store.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/core/sync/server_clock.dart';
import 'package:iris_dp/core/sync/sync_merge_store.dart';
import 'package:iris_dp/core/sync/sync_plan_builder.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('copias locales', () {
    late Directory dir;
    late String path;
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = Directory.systemTemp.createTempSync('iris_copias');
      path = p.join(dir.path, 'iris.sqlite');
      db = AppDatabase.forTesting(NativeDatabase(File(path)));
      await db.insertProject(ProjectsCompanion.insert(name: 'Uno'));
    });

    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    test('la copia diaria se hace una sola vez al día', () async {
      final first = await LocalDatabaseBackup.createDailyIfDue(
        db,
        databaseFileOverride: path,
      );
      expect(first, isNotNull);
      final second = await LocalDatabaseBackup.createDailyIfDue(
        db,
        databaseFileOverride: path,
      );
      expect(second, isNull);
    });

    test('conserva las 7 últimas y copia en la segunda carpeta', () async {
      final other = Directory(p.join(dir.path, 'otra'))..createSync();
      for (var day = 1; day <= 9; day++) {
        final name = 'iris.sqlite.diaria-2020-01-0$day-000000';
        File(p.join(dir.path, name)).writeAsStringSync('x');
        File(p.join(other.path, name)).writeAsStringSync('x');
      }
      await LocalDatabaseBackup.createDailyIfDue(
        db,
        secondFolder: other.path,
        databaseFileOverride: path,
      );
      int count(Directory d) => d
          .listSync()
          .where((f) => p.basename(f.path).contains('.diaria-'))
          .length;
      expect(count(dir), 7);
      expect(count(other), 7);
    });

    test('la lista explica cada copia y omite los archivos auxiliares', () async {
      await LocalDatabaseBackup.create(
        db,
        label: 'antes-de-mezclar',
        databaseFileOverride: path,
      );
      File('$path.diaria-2020-01-01-000000-wal').writeAsStringSync('x');
      File('$path.antes-de-esquema-62-2020-01-01').writeAsStringSync('x');
      final titles = (await LocalDatabaseBackup.list(
        databaseFileOverride: path,
      )).map((c) => c.title).toSet();
      expect(titles, {
        'Antes de mezclar con la nube',
        'Antes de actualizar la app',
      });
    });

    test('restaurar guarda lo actual y pone la copia elegida', () {
      final loose = p.join(dir.path, 'suelta.sqlite');
      File(loose).writeAsStringSync('actual');
      File('$loose-wal').writeAsStringSync('wal viejo');
      final chosen = p.join(dir.path, 'suelta.sqlite.diaria-2020-01-01-000000');
      File(chosen).writeAsStringSync('copia');
      File('$loose.restaurar').writeAsStringSync(chosen);

      expect(
        LocalDatabaseBackup.applyPendingRestore(loose),
        isTrue,
      );
      expect(File(loose).readAsStringSync(), 'copia');
      expect(File('$loose-wal').existsSync(), isFalse);
      expect(File('$loose.restaurar').existsSync(), isFalse);
      final safe = dir.listSync().whereType<File>().where(
        (f) =>
            p.basename(f.path).contains('.antes-de-restaurar-') &&
            !f.path.endsWith('-wal'),
      );
      expect(safe.single.readAsStringSync(), 'actual');
      expect(LocalDatabaseBackup.applyPendingRestore(loose), isFalse);
    });

    test('una copia restaurada no se da por igual a la nube', () async {
      final id = await db.insertProject(ProjectsCompanion.insert(name: 'Dos'));
      await ContentSyncBaseStore.save(
        db,
        id,
        const ContentSyncBase(localHash: 'a', cloudHash: 'b'),
      );
      await ContentBaseBundleStore.save(db, id, local: {}, cloud: {});

      final statements = <String>[];
      LocalDatabaseBackup.forgetSyncBases(statements.add);
      for (final sql in statements) {
        await db.customStatement(sql);
      }
      final project = await db.getProject(id);
      expect(project!.contentSyncBaseLocal, isNull);
      expect(project.contentSyncBaseCloud, isNull);
      expect(await ContentBaseBundleStore.has(db, id), isFalse);
    });
  });

  test('el desfase con el servidor descuenta el viaje de la petición', () {
    final sent = DateTime.utc(2026, 11, 10, 12);
    final offset = ServerClock.offsetFrom(
      sent,
      sent.add(const Duration(seconds: 2)),
      sent.add(const Duration(minutes: 5, seconds: 1)),
    );
    expect(offset, const Duration(minutes: 5));
  });

  test('sin cambios, la segunda pasada no baja el contenido', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.insertProject(
      ProjectsCompanion.insert(
        name: 'Enlazado',
        cloudId: const Value('c1'),
      ),
    );
    final bundle = await ProjectContentBundle.export(db, id);
    final hash = ProjectContentBundle.hashBundle(bundle);
    var fullDownloads = 0;
    http.Response json(Object body, http.Request request) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
    final client = SupabaseClient(
      'http://127.0.0.1:9',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSJ9.test',
      httpClient: MockClient((request) async {
        if (!request.url.path.contains('cloud_project_snapshots')) {
          return json([
            if (request.url.path.contains('cloud_projects'))
              {
                'id': 'c1',
                'workspace_id': 'ws',
                'name': 'Enlazado',
                'status': 'preproduction',
                'sort_order': 0,
                'updated_at': '2026-08-08T10:00:00.000Z',
              },
          ], request);
        }
        final select = request.url.queryParameters['select'] ?? '';
        if (select.replaceAll(' ', '') == 'project_id,content_hash') {
          return json([
            {'project_id': 'c1', 'content_hash': hash},
          ], request);
        }
        final filter = request.url.queryParameters['project_id'] ?? '';
        if (!filter.contains('c1')) return json(<Object>[], request);
        fullDownloads++;
        return json([
          {
            'project_id': 'c1',
            'content': bundle,
            'content_hash': hash,
            'updated_at': '2026-08-08T10:00:00.000Z',
          },
        ], request);
      }),
    );

    final builder = SyncPlanBuilder(db, client);
    await builder.build('ws');
    expect(fullDownloads, 1);
    await builder.build('ws');
    expect(fullDownloads, 1);

    // Si cambia la nube, se vuelve a mirar el contenido.
    await db.insertProject(ProjectsCompanion.insert(name: 'Otro sin enlazar'));
    await db.customStatement(
      "UPDATE projects SET content_sync_base_cloud = 'otra' WHERE id = ?",
      [id],
    );
    await builder.build('ws');
    expect(fullDownloads, 2);
  });
}
