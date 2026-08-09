import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('round-trip preserva contentJson de bibleSectionDefinitions', () async {
    final sourceProjectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Origen contentJson'),
    );
    final targetProjectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Destino contentJson'),
    );
    final sourceBible = await db.ensureVisualBibleForProject(sourceProjectId);
    await db.ensureBibleSectionLayout(sourceBible.id);

    const payload =
        '{"cameraData":{"isoNote":"FASE2-SMOKE-ISO","colorSpace":"LogC3"}}';
    await (db.update(db.bibleSectionDefinitions)
          ..where(
            (row) =>
                row.bibleId.equals(sourceBible.id) &
                row.id.equals(BibleSectionId.camera),
          ))
        .write(
      BibleSectionDefinitionsCompanion(contentJson: const Value(payload)),
    );

    final bundle = await ProjectContentBundle.export(db, sourceProjectId);
    final rows = bundle['bibleSectionDefinitions'] as List;
    final cameraRow = rows.cast<Map>().firstWhere(
      (row) => row['id'] == BibleSectionId.camera,
    );

    expect(cameraRow['contentJson'], payload);
    expect(cameraRow['bibleKey'], 'vb:${sourceBible.id}');

    await ProjectContentBundle.importBundle(db, targetProjectId, bundle);

    final importedBible = await db.getVisualBibleForProject(targetProjectId);
    final importedSections = await (db.select(db.bibleSectionDefinitions)
          ..where((row) => row.bibleId.equals(importedBible!.id)))
        .get();
    final importedCamera = importedSections.firstWhere(
      (row) => row.id == BibleSectionId.camera,
    );

    expect(importedCamera.contentJson, payload);
  });

  test('cambio en contentJson altera el hash local del bundle', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Hash contentJson'),
    );
    final bible = await db.ensureVisualBibleForProject(projectId);
    await db.ensureBibleSectionLayout(bible.id);

    final hashBefore = await ProjectContentBundle.computeLocalHash(db, projectId);

    await (db.update(db.bibleSectionDefinitions)
          ..where(
            (row) =>
                row.bibleId.equals(bible.id) &
                row.id.equals(BibleSectionId.camera),
          ))
        .write(
      BibleSectionDefinitionsCompanion(
        contentJson: const Value(
          '{"cameraData":{"isoNote":"hash-change-marker"}}',
        ),
      ),
    );

    final hashAfter = await ProjectContentBundle.computeLocalHash(db, projectId);

    expect(hashBefore, isNot(equals(hashAfter)));
    expect(
      ProjectContentBundle.contentMatchesSnapshot(
        hashAfter,
        {
          'content_hash': hashBefore,
          'content': {'summary': {}},
        },
      ),
      isFalse,
    );
  });
}
