import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import 'shoot_document_block_types.dart';
import 'shoot_document_composer.dart';

/// CRUD y utilidades de documentos de rodaje.
abstract final class ShootDocumentService {
  ShootDocumentService._();

  static Future<int> createDocument({
    required AppDatabase db,
    required int projectId,
    required String name,
    ShootDocumentTemplate template = ShootDocumentTemplate.empty,
  }) async {
    final docId = await db.insertShootDocument(
      ShootDocumentsCompanion.insert(
        projectId: projectId,
        name: name,
        layoutPreset: const Value(ShootLayoutPreset.freeform),
      ),
    );

    if (template != ShootDocumentTemplate.empty) {
      final companions = await ShootDocumentComposer.compose(
        db: db,
        projectId: projectId,
        template: template,
      );
      for (final c in companions) {
        await db.insertShootDocumentBlock(
          c.copyWith(documentId: Value(docId)),
        );
      }
    }

    return docId;
  }

  static Future<void> reorderBlocks(
    AppDatabase db,
    int documentId,
    List<int> blockIdsInOrder,
  ) =>
      db.reorderShootDocumentBlocks(documentId, blockIdsInOrder);

  static Future<ShootDocumentBlock> duplicateBlock(
    AppDatabase db,
    ShootDocumentBlock block,
    int documentId,
  ) async {
    final blocks = await db.getBlocksForShootDocument(documentId);
    final nextOrder =
        blocks.isEmpty ? 0 : blocks.map((b) => b.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final companion = ShootDocumentComposer.duplicateBlock(
      block,
      documentId,
      nextOrder,
    );
    final id = await db.insertShootDocumentBlock(companion);
    return (await db.getBlocksForShootDocument(documentId))
        .firstWhere((b) => b.id == id);
  }

  static Future<int> nextSortOrder(AppDatabase db, int documentId) async {
    final blocks = await db.getBlocksForShootDocument(documentId);
    if (blocks.isEmpty) return 0;
    return blocks.last.sortOrder + 1;
  }

  static Future<ShootDocument?> primaryDocument(
    AppDatabase db,
    int projectId,
  ) async {
    final docs = await db.watchShootDocumentsForProject(projectId).first;
    for (final d in docs) {
      if (d.isPrimaryOnSet) return d;
    }
    return docs.isEmpty ? null : docs.first;
  }
}
