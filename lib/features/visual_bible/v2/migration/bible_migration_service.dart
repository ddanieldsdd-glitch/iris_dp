import '../../../../core/database/app_database.dart';
import '../../visual_bible_model.dart';
import '../model/bible_document.dart';
import '../persistence/bible_document_store.dart';
import 'legacy_to_document_migrator.dart';

/// Migración segura legacy → V2 (no destructiva).
class BibleMigrationService {
  BibleMigrationService(this._db, this._store);

  final AppDatabase _db;
  final BibleDocumentStore _store;

  Future<BibleDocument> migrateLegacyToV2({
    required int projectId,
    required int bibleId,
    VisualBibleData? data,
  }) async {
    final groups = await (_db.select(
      _db.bibleSectionGroups,
    )..where((t) => t.bibleId.equals(bibleId))).get();
    final sections = await (_db.select(
      _db.bibleSectionDefinitions,
    )..where((t) => t.bibleId.equals(bibleId))).get();

    final doc = LegacyToDocumentMigrator.migrate(
      projectId: projectId,
      bibleId: bibleId,
      groups: groups
          .map(
            (g) => LegacyBibleGroupSnapshot(
              id: g.id,
              label: g.label,
              sortOrder: g.sortOrder,
            ),
          )
          .toList(),
      sections: sections
          .map(
            (s) => LegacyBibleSectionSnapshot(
              id: s.id,
              groupId: s.groupId,
              label: s.label,
              iconKey: s.iconKey,
              sortOrder: s.sortOrder,
              isHidden: s.isHidden,
              template: s.template,
              contentJson: s.contentJson,
            ),
          )
          .toList(),
      data: data,
    );

    await _store.save(doc);
    await _store.snapshotVersion(
      bibleId: bibleId,
      doc: doc,
      label: 'legacy_migration',
      note: 'Migración manual legacy → V2',
    );
    await _db.promoteEngineToV2(bibleId);
    return doc;
  }
}
