import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late int projectId;
  late int sceneId;

  Future<int> addShot(int number, {bool auto = true, int? scene}) =>
      db.insertShot(
        ShotsCompanion.insert(
          sceneId: scene ?? sceneId,
          projectId: projectId,
          number: number,
          sortOrder: Value(number - 1),
          autoNumbering: Value(auto),
        ),
      );

  Future<List<Shot>> shots([int? scene]) =>
      db.watchShotsForScene(scene ?? sceneId).first;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena',
        locationCanonical: 'EXT. CALLE - NOCHE',
        locationPureName: 'CALLE',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('reordenar planos reajusta el número al orden', () async {
    final a = await addShot(1);
    final b = await addShot(2);
    final c = await addShot(3);

    await db.reorderShotsInScene(sceneId, [c, a, b]);

    final result = await shots();
    expect(result.map((s) => s.id), [c, a, b]);
    expect(result.map((s) => s.number), [1, 2, 3]);
  });

  test('un plano con numeración manual conserva su número', () async {
    final a = await addShot(1);
    final b = await addShot(7, auto: false);

    await db.reorderShotsInScene(sceneId, [b, a]);

    final result = await shots();
    expect(result.map((s) => s.id), [b, a]);
    expect(result.map((s) => s.number), [7, 2]);
  });

  test('eliminar un plano renumera y no deja restos', () async {
    final a = await addShot(1);
    final b = await addShot(2);
    final c = await addShot(3);
    await db.insertShotReference(
      ShotReferencesCompanion.insert(shotId: b, imagePath: '/tmp/ref.jpg'),
    );
    final docId = await db.insertShootDocument(
      ShootDocumentsCompanion.insert(projectId: projectId, name: 'Jornada'),
    );
    await db.insertShootDocumentBlock(
      ShootDocumentBlocksCompanion.insert(
        documentId: docId,
        blockType: 'shot',
        sceneId: Value(sceneId),
        shotId: Value(b),
      ),
    );

    await db.deleteShot(b);

    final result = await shots();
    expect(result.map((s) => s.id), [a, c]);
    expect(result.map((s) => s.number), [1, 2]);
    expect(await db.watchReferencesForShot(b).first, isEmpty);
    expect(await db.getBlocksForShootDocument(docId), isEmpty);
  });

  test('eliminar una escena borra sus planos y deja las demás como estaban',
      () async {
    final otherScene = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 15,
        name: 'Otra',
        locationCanonical: 'INT. KEBAB - NOCHE',
        locationPureName: 'KEBAB',
      ),
    );
    final a = await addShot(1);
    final kept = await addShot(1, scene: otherScene);
    await db.insertShotReference(
      ShotReferencesCompanion.insert(shotId: a, imagePath: '/tmp/ref.jpg'),
    );
    final docId = await db.insertShootDocument(
      ShootDocumentsCompanion.insert(projectId: projectId, name: 'Jornada'),
    );
    await db.insertShootDocumentBlock(
      ShootDocumentBlocksCompanion.insert(
        documentId: docId,
        blockType: 'scene_header',
        sceneId: Value(sceneId),
      ),
    );
    await db.insertShootDocumentBlock(
      ShootDocumentBlocksCompanion.insert(
        documentId: docId,
        blockType: 'shot',
        sceneId: Value(otherScene),
        shotId: Value(kept),
      ),
    );

    await db.deleteScene(sceneId);

    expect(await db.getShotById(a), isNull);
    expect(await db.watchReferencesForShot(a).first, isEmpty);
    final scenes = await db.watchScenesForProject(projectId).first;
    expect(scenes.map((s) => s.number), [15]);
    expect((await shots(otherScene)).map((s) => s.id), [kept]);
    final blocks = await db.getBlocksForShootDocument(docId);
    expect(blocks.map((b) => b.shotId), [kept]);
  });

  test('mover un plano a otra escena renumera las dos y se lleva sus '
      'bloques de documento', () async {
    final other = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 2,
        name: 'Otra',
        locationCanonical: 'INT. KEBAB - NOCHE',
        locationPureName: 'KEBAB',
      ),
    );
    final a = await addShot(1);
    final b = await addShot(2);
    final c = await addShot(3);
    final x = await addShot(1, scene: other);
    final y = await addShot(2, scene: other);
    final docId = await db.insertShootDocument(
      ShootDocumentsCompanion.insert(projectId: projectId, name: 'Jornada'),
    );
    await db.insertShootDocumentBlock(
      ShootDocumentBlocksCompanion.insert(
        documentId: docId,
        blockType: 'shot',
        sceneId: Value(sceneId),
        shotId: Value(b),
      ),
    );

    // Al medio de la otra escena.
    await db.moveShotToScene(b, other, beforeIndex: 1);

    expect((await shots()).map((s) => s.id), [a, c]);
    expect((await shots()).map((s) => s.number), [1, 2]);
    expect((await shots(other)).map((s) => s.id), [x, b, y]);
    expect((await shots(other)).map((s) => s.number), [1, 2, 3]);
    expect((await db.getBlocksForShootDocument(docId)).single.sceneId, other);

    // Sin posición, al final.
    await db.moveShotToScene(a, other);
    expect((await shots(other)).map((s) => s.id), [x, b, y, a]);
    expect((await shots()).map((s) => s.number), [1]);
  });
}
