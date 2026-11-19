import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/shoot_uids.dart';
import 'package:iris_dp/core/sync/bundle_merge.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plan R: jornadas y bloques con uid, iguales en todos los equipos, que se
/// bajan en su sitio y se mezclan elemento a elemento.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Map<String, dynamic> copy(Map<String, dynamic> b) =>
      jsonDecode(jsonEncode(b)) as Map<String, dynamic>;

  /// Un equipo con un proyecto, una escena con dos planos y dos jornadas.
  /// [extraProjects] desplaza los ids, como pasa entre el Mac y el iPad.
  Future<(AppDatabase, int)> device({int extraProjects = 0}) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    for (var i = 0; i < extraProjects; i++) {
      final other = await db.insertProject(
        ProjectsCompanion.insert(name: 'otro $i'),
      );
      await db.insertShootDocument(
        ShootDocumentsCompanion.insert(projectId: other, name: 'Jornada 1'),
      );
    }
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'KEBAB'),
    );
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        uid: const Value('scene-1'),
        projectId: projectId,
        number: 1,
        name: 'INT. BAR - NOCHE',
        locationCanonical: 'INT. BAR - NOCHE',
        locationPureName: 'BAR',
      ),
    );
    final shots = [
      for (final n in [1, 2])
        await db.insertShot(
          ShotsCompanion.insert(
            uid: Value('shot-$n'),
            projectId: projectId,
            sceneId: sceneId,
            number: n,
            sortOrder: Value(n),
          ),
        ),
    ];
    for (final (d, date) in const ['2026-11-13', '2026-11-14'].indexed) {
      final doc = await db.insertShootDocument(
        ShootDocumentsCompanion.insert(
          projectId: projectId,
          name: 'Jornada ${d + 1}',
          shootDate: Value(date),
          kind: const Value('technical_day'),
        ),
      );
      for (final (i, shot) in shots.indexed) {
        await db.insertShootDocumentBlock(
          ShootDocumentBlocksCompanion.insert(
            documentId: doc,
            blockType: 'shot',
            sceneId: Value(sceneId),
            shotId: Value(shot),
            sortOrder: Value(i),
          ),
        );
      }
    }
    // Como al venir de la versión 63: sin uid, y se rellenan.
    await db.customStatement('UPDATE shoot_documents SET uid = NULL');
    await db.customStatement('UPDATE shoot_document_blocks SET uid = NULL');
    await ShootUids.backfill(db);
    return (db, projectId);
  }

  Future<List<String?>> uids(AppDatabase db, int projectId) async {
    final docs =
        await (db.select(db.shootDocuments)
              ..where((d) => d.projectId.equals(projectId))
              ..orderBy([(d) => OrderingTerm.asc(d.id)]))
            .get();
    final blocks =
        await (db.select(db.shootDocumentBlocks)
              ..where((b) => b.documentId.isIn([for (final d in docs) d.id]))
              ..orderBy([(b) => OrderingTerm.asc(b.id)]))
            .get();
    return [for (final d in docs) d.uid, for (final b in blocks) b.uid];
  }

  test(
    'el relleno da los mismos uid en dos equipos con ids distintos',
    () async {
      final (mac, macProject) = await device();
      final (ipad, ipadProject) = await device(extraProjects: 3);
      final a = await uids(mac, macProject);
      final b = await uids(ipad, ipadProject);
      expect(a, everyElement(isNotNull));
      expect(a.toSet(), hasLength(a.length));
      expect(a, b);
      // Y es idempotente.
      await ShootUids.backfill(mac);
      expect(await uids(mac, macProject), a);
    },
  );

  test('una copia de un bloque no se queda con el uid del original', () async {
    final (db, projectId) = await device();
    final doc = (await db.getShootDocumentsForProject(projectId)).first;
    final block = (await db.getBlocksForShootDocument(doc.id)).first;
    final id = await db.insertShootDocumentBlock(
      block.toCompanion(false).copyWith(id: const Value.absent()),
    );
    final copied = await db.getShootDocumentBlock(id);
    expect(copied!.uid, isNot(block.uid));
  });

  test('al bajar, jornadas y bloques no cambian de id', () async {
    final (db, projectId) = await device();
    final docsBefore = {
      for (final d in await db.getShootDocumentsForProject(projectId))
        d.uid: d.id,
    };
    final bundle = copy(await ProjectContentBundle.export(db, projectId));
    expect(
      (bundle['shootDocuments'] as List).every((d) => d['uid'] != null),
      isTrue,
    );
    // En la nube se quitó el plano 2 de la Jornada 2 y se marcó el 1.
    final blocks = bundle['shootDocumentBlocks'] as List;
    final j2 = (bundle['shootDocuments'] as List).firstWhere(
      (d) => d['name'] == 'Jornada 2',
    )['documentKey'];
    blocks.removeWhere(
      (b) => b['documentKey'] == j2 && '${b['shotKey']}'.endsWith(':2'),
    );
    final marked = blocks.firstWhere((b) => b['documentKey'] == j2);
    marked['contentOverridesJson'] = jsonEncode({
      'onSet': {'status': 'done', 'at': '2026-11-14T10:00:00Z'},
    });
    final blockIdBefore = {
      for (final d in await db.getShootDocumentsForProject(projectId))
        for (final b in await db.getBlocksForShootDocument(d.id)) b.uid: b.id,
    };
    await ProjectContentBundle.importBundle(db, projectId, bundle);

    final docsAfter = {
      for (final d in await db.getShootDocumentsForProject(projectId))
        d.uid: d.id,
    };
    expect(docsAfter, docsBefore);
    final after = {
      for (final d in await db.getShootDocumentsForProject(projectId))
        for (final b in await db.getBlocksForShootDocument(d.id)) b.uid: b,
    };
    expect(after, hasLength(3));
    for (final b in after.values) {
      expect(b.id, blockIdBefore[b.uid]);
    }
    expect(after[marked['uid']]!.contentOverridesJson, contains('"done"'));
  });

  test('un paquete antiguo sin uid se baja y se rellena igual', () async {
    final (db, projectId) = await device();
    final before = await uids(db, projectId);
    final bundle = copy(await ProjectContentBundle.export(db, projectId));
    for (final k in ['shootDocuments', 'shootDocumentBlocks']) {
      for (final r in bundle[k] as List) {
        (r as Map).remove('uid');
      }
    }
    await ProjectContentBundle.importBundle(db, projectId, bundle);
    expect((await uids(db, projectId)).toSet(), before.toSet());
  });

  group('mezcla', () {
    Future<Map<String, dynamic>> exported() async {
      final (db, projectId) = await device();
      return copy(await ProjectContentBundle.export(db, projectId));
    }

    List<Map<String, dynamic>> blocksOf(Map<String, dynamic> b) =>
        (b['shootDocumentBlocks'] as List).cast<Map<String, dynamic>>();

    test('el iPhone marca En set y el Mac añade un plano a otra jornada: '
        'se quedan las dos cosas', () async {
      final base = await exported();
      final mac = copy(base);
      final iphone = copy(base);
      // Mac: añade a la Jornada 1 una franja nueva.
      final j1 = (mac['shootDocuments'] as List).first['documentKey'];
      blocksOf(mac).add({
        'uid': 'nuevo',
        'documentKey': j1,
        'blockType': 'schedule',
        'sortOrder': 5,
        'customLabel': 'COMIDA',
      });
      // iPhone: marca el primer bloque de la Jornada 2 y cambia la hora de
      // la jornada.
      final target = blocksOf(iphone).last;
      target['contentOverridesJson'] = jsonEncode({
        'onSet': {'status': 'done', 'at': '2026-11-14T10:00:00Z'},
      });
      (iphone['shootDocuments'] as List).last['shootFromTime'] = '08:00';
      for (final newer in MergeSide.values) {
        final out = BundleMerge.merge(
          baseLocal: base,
          baseCloud: base,
          local: mac,
          cloud: iphone,
          newer: newer,
        );
        final merged = out.merged;
        expect(blocksOf(merged).map((b) => b['uid']), contains('nuevo'));
        final kept = blocksOf(
          merged,
        ).firstWhere((b) => b['uid'] == target['uid']);
        expect(kept['contentOverridesJson'], contains('done'));
        expect(
          (merged['shootDocuments'] as List).last['shootFromTime'],
          '08:00',
        );
        expect(out.discards, isEmpty);
        // La franja nueva apunta a su jornada con la clave del resultado.
        final added = blocksOf(merged).firstWhere((b) => b['uid'] == 'nuevo');
        expect(
          (merged['shootDocuments'] as List).map((d) => d['documentKey']),
          contains(added['documentKey']),
        );
      }
    });

    test('una jornada borrada en un lado se va con sus bloques', () async {
      final base = await exported();
      final mac = copy(base);
      final gone = (mac['shootDocuments'] as List).removeAt(1);
      blocksOf(mac).removeWhere((b) => b['documentKey'] == gone['documentKey']);
      final merged = BundleMerge.merge(
        baseLocal: base,
        baseCloud: base,
        local: mac,
        cloud: copy(base),
        newer: MergeSide.cloud,
      ).merged;
      expect(merged['shootDocuments'], hasLength(1));
      expect(merged['shootDocumentBlocks'], hasLength(2));
    });

    test('la misma clave del JSON de un bloque: gana la marca más tardía, y '
        'lo demás se junta', () {
      final out = BundleMerge.mergeBlockOverrides(
        base: jsonEncode({'shotTime': '10:00'}),
        local: jsonEncode({
          'shotTime': '10:30',
          'onSet': {'status': 'done', 'at': '2026-11-14T12:00:00Z'},
        }),
        cloud: jsonEncode({
          'shotTime': '10:00',
          'stopMin': 90,
          'onSet': {'status': 'dropped', 'at': '2026-11-14T11:00:00Z'},
        }),
        newer: MergeSide.cloud,
      );
      final m = jsonDecode(out!) as Map;
      expect(m['shotTime'], '10:30');
      expect(m['stopMin'], 90);
      expect(m['onSet']['status'], 'done');
    });

    test('con bases sin uid (antes de actualizar) va en bloque y poner los '
        'uid no cuenta como cambio', () async {
      final base = await exported();
      final old = copy(base);
      for (final k in ['shootDocuments', 'shootDocumentBlocks']) {
        for (final r in old[k] as List) {
          (r as Map).remove('uid');
        }
      }
      final iphone = copy(base);
      blocksOf(iphone).last['contentOverridesJson'] = jsonEncode({
        'onSet': {'status': 'done', 'at': '2026-11-14T10:00:00Z'},
      });
      final out = BundleMerge.merge(
        baseLocal: old,
        baseCloud: old,
        local: copy(base),
        cloud: iphone,
        newer: MergeSide.local,
      );
      expect(out.discards.map((d) => '${d.collection} ${d.field}'), isEmpty);
      expect(
        blocksOf(out.merged).last['contentOverridesJson'],
        contains('done'),
      );
    });

    test('en bloque (bases sin uid) y los dos cambiaron: las marcas de En '
        'set del que pierde se quedan', () async {
      final base = await exported();
      final old = copy(base);
      for (final k in ['shootDocuments', 'shootDocumentBlocks']) {
        for (final r in old[k] as List) {
          (r as Map).remove('uid');
        }
      }
      final mac = copy(base);
      (mac['shootDocuments'] as List).first['shootFromTime'] = '07:00';
      final iphone = copy(base);
      blocksOf(iphone).last['contentOverridesJson'] = jsonEncode({
        'onSet': {'status': 'done', 'at': '2026-11-14T10:00:00Z'},
      });
      final out = BundleMerge.merge(
        baseLocal: old,
        baseCloud: old,
        local: mac,
        cloud: iphone,
        newer: MergeSide.local,
      ).merged;
      expect((out['shootDocuments'] as List).first['shootFromTime'], '07:00');
      expect(blocksOf(out).last['contentOverridesJson'], contains('done'));
    });
  });
}
