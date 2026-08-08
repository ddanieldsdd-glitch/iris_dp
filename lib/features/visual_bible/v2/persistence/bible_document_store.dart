import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../bible_v2_policy.dart';
import '../model/bible_document.dart';

/// Persistencia Drift del documento v2 (añade; no toca filas legacy).
class BibleDocumentStore {
  final AppDatabase db;

  BibleDocumentStore(this.db);

  Future<BibleDocument?> loadForBible(int bibleId) async {
    final row =
        await (db.select(db.visualBibleDocuments)
              ..where((t) => t.bibleId.equals(bibleId))
              ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    try {
      final map = jsonDecode(row.documentJson) as Map<String, dynamic>;
      return BibleDocument.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(BibleDocument doc) async {
    if (doc.bibleId == null) {
      throw ArgumentError('bibleId required to persist BibleDocument');
    }
    final existing =
        await (db.select(db.visualBibleDocuments)
              ..where((t) => t.bibleId.equals(doc.bibleId!))
              ..limit(1))
            .getSingleOrNull();

    final companion = VisualBibleDocumentsCompanion(
      bibleId: Value(doc.bibleId!),
      projectId: Value(doc.projectId),
      documentJson: Value(jsonEncode(doc.toJson())),
      documentSchemaVersion: Value(doc.schemaVersion),
      updatedAt: Value(DateTime.now().toUtc()),
    );

    if (existing == null) {
      await db.into(db.visualBibleDocuments).insert(companion);
    } else {
      await (db.update(
        db.visualBibleDocuments,
      )..where((t) => t.id.equals(existing.id))).write(companion);
    }
  }

  /// Snapshot versionado reutilizando VisualBibleVersions (no destructivo).
  Future<void> snapshotVersion({
    required int bibleId,
    required BibleDocument doc,
    required String label,
    String? note,
  }) async {
    await db
        .into(db.visualBibleVersions)
        .insert(
          VisualBibleVersionsCompanion.insert(
            bibleId: bibleId,
            label: label,
            snapshotJson: jsonEncode({
              'kind': 'bible_document_v2',
              'schemaVersion': kBibleDocumentSchemaVersion,
              'document': doc.toJson(),
            }),
            changeNote: Value(note),
          ),
        );
  }
}
