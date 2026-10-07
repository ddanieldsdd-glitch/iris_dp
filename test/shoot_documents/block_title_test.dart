import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/shoot_documents/shoot_document_block_resolver.dart';
import 'package:iris_dp/features/shoot_documents/shoot_document_block_types.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('el bloque de plano enseña el número del guion técnico, también tras '
      'reordenar el documento y el guion', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'P'),
    );
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 7,
        name: 'Escena',
        locationCanonical: 'EXT. CALLE RAVAL - NOCHE',
        locationPureName: 'CALLE RAVAL',
      ),
    );
    final shotIds = [
      for (var i = 0; i < 3; i++)
        await db.insertShot(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: i + 1,
            sortOrder: Value(i),
          ),
        ),
    ];
    final docId = await db.insertShootDocument(
      ShootDocumentsCompanion.insert(projectId: projectId, name: 'Jornada 1'),
    );
    final blockIds = [
      for (var i = 0; i < 3; i++)
        await db.insertShootDocumentBlock(
          ShootDocumentBlocksCompanion.insert(
            documentId: docId,
            sortOrder: Value(i),
            blockType: ShootBlockType.shot,
            sceneId: Value(sceneId),
            shotId: Value(shotIds[i]),
          ),
        ),
    ];

    Future<List<String>> titles() async {
      final scene = (await db.getSceneById(sceneId))!;
      final blocks = await db.getBlocksForShootDocument(docId);
      return [
        for (final b in blocks)
          ResolvedShootBlock(
            block: b,
            scene: scene,
            shot: await db.getShotById(b.shotId!),
            visibility: ShootBlockVisibility.defaults,
            overrides: const {},
          ).title,
      ];
    }

    // Orden de rodaje distinto del guion: los números no cambian.
    await db.reorderShootDocumentBlocks(docId, blockIds.reversed.toList());
    expect(await titles(), [
      'Esc. 7 · Plano 3',
      'Esc. 7 · Plano 2',
      'Esc. 7 · Plano 1',
    ]);

    // Reordenar en el guion técnico renumera, y el documento lo refleja sin
    // cambiar su propio orden.
    await db.reorderShotsInScene(sceneId, [
      shotIds[2],
      shotIds[0],
      shotIds[1],
    ]);
    expect(await titles(), [
      'Esc. 7 · Plano 1',
      'Esc. 7 · Plano 3',
      'Esc. 7 · Plano 2',
    ]);
  });
}
