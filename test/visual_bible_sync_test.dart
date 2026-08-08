import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('round-trip remapea el contenido técnico de Biblia', () async {
    final sourceProjectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Biblia origen'),
    );
    final targetProjectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Biblia destino'),
    );
    final sourceBible = await db.ensureVisualBibleForProject(sourceProjectId);
    final previousTargetBible = await db.ensureVisualBibleForProject(
      targetProjectId,
    );
    final testedAt = DateTime.utc(2026, 8, 8, 10, 30);
    final documentUpdatedAt = DateTime.utc(2026, 8, 8, 11, 45);

    await db
        .into(db.exposureBlocks)
        .insert(
          ExposureBlocksCompanion.insert(
            bibleId: sourceBible.id,
            blockName: 'Noche exterior',
            highlightStrategy: const Value('Proteger neón'),
            shadowStrategy: const Value('Negros con detalle'),
            keyFillRatio: const Value('8:1'),
            narrativeIntent: const Value('Aislamiento'),
            referenceImages: const Value('["exposure.jpg"]'),
            sortOrder: const Value(2),
          ),
        );
    await db
        .into(db.lightingSetups)
        .insert(
          LightingSetupsCompanion.insert(
            bibleId: sourceBible.id,
            setupName: 'Ventana motivada',
            narrativeNote: const Value('Luz lateral'),
            diagramJson: '{"fixtures":["M40"]}',
            gelNotes: const Value('1/4 CTO'),
            practicalMotivation: const Value('Farola'),
            referenceImagePath: const Value('setup.jpg'),
            sortOrder: const Value(3),
          ),
        );
    await db
        .into(db.cameraTests)
        .insert(
          CameraTestsCompanion.insert(
            bibleId: sourceBible.id,
            testName: 'Altas luces',
            lutName: const Value('Show LUT'),
            lightCondition: const Value('Contraluz'),
            notes: const Value('Mantener piel a +1'),
            imagePaths: '["test-a.jpg","test-b.jpg"]',
            testedAt: Value(testedAt),
            sortOrder: const Value(4),
          ),
        );
    await db
        .into(db.visualBibleDocuments)
        .insert(
          VisualBibleDocumentsCompanion.insert(
            bibleId: sourceBible.id,
            projectId: sourceProjectId,
            documentJson: '{"pages":[{"id":"page-1"}]}',
            documentSchemaVersion: const Value(2),
            updatedAt: Value(documentUpdatedAt),
          ),
        );
    await db
        .into(db.visualBibleDocuments)
        .insert(
          VisualBibleDocumentsCompanion.insert(
            bibleId: previousTargetBible.id,
            projectId: targetProjectId,
            documentJson: '{"stale":true}',
          ),
        );

    final bundle = await ProjectContentBundle.export(db, sourceProjectId);

    for (final key in const [
      'exposureBlocks',
      'lightingSetups',
      'cameraTests',
      'visualBibleDocuments',
    ]) {
      final rows = bundle[key] as List;
      expect(rows, hasLength(1));
      expect(rows.single['bibleKey'], 'vb:${sourceBible.id}');
      expect(rows.single, isNot(contains('bibleId')));
    }

    await ProjectContentBundle.importBundle(db, targetProjectId, bundle);

    final importedBible = await db.getVisualBibleForProject(targetProjectId);
    final exposures = await (db.select(
      db.exposureBlocks,
    )..where((row) => row.bibleId.equals(importedBible!.id))).get();
    final setups = await (db.select(
      db.lightingSetups,
    )..where((row) => row.bibleId.equals(importedBible!.id))).get();
    final tests = await (db.select(
      db.cameraTests,
    )..where((row) => row.bibleId.equals(importedBible!.id))).get();
    final documents = await (db.select(
      db.visualBibleDocuments,
    )..where((row) => row.projectId.equals(targetProjectId))).get();

    expect(importedBible, isNotNull);
    expect(importedBible!.id, isNot(sourceBible.id));
    expect(importedBible.id, isNot(previousTargetBible.id));

    expect(exposures, hasLength(1));
    expect(exposures.single.bibleId, importedBible.id);
    expect(exposures.single.blockName, 'Noche exterior');
    expect(exposures.single.highlightStrategy, 'Proteger neón');
    expect(exposures.single.sortOrder, 2);

    expect(setups, hasLength(1));
    expect(setups.single.bibleId, importedBible.id);
    expect(setups.single.diagramJson, '{"fixtures":["M40"]}');
    expect(setups.single.practicalMotivation, 'Farola');
    expect(setups.single.sortOrder, 3);

    expect(tests, hasLength(1));
    expect(tests.single.bibleId, importedBible.id);
    expect(tests.single.imagePaths, '["test-a.jpg","test-b.jpg"]');
    expect(tests.single.testedAt?.toUtc(), testedAt);
    expect(tests.single.sortOrder, 4);

    expect(documents, hasLength(1));
    expect(documents.single.bibleId, importedBible.id);
    expect(documents.single.projectId, targetProjectId);
    expect(documents.single.documentJson, '{"pages":[{"id":"page-1"}]}');
    expect(documents.single.documentSchemaVersion, 2);
    expect(documents.single.updatedAt.toUtc(), documentUpdatedAt);
  });
}
