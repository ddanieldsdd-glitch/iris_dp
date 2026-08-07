import '../../../core/database/app_database.dart';
import '../shoot_document_block_types.dart';
import '../shoot_document_composer.dart';
import '../shoot_document_service.dart';

/// Puerta de entrada de documentos de rodaje a persistencia local.
class ShootDocumentRepository {
  ShootDocumentRepository(this._db);

  final AppDatabase _db;

  Future<int> createDocument({
    required int projectId,
    required String name,
    ShootDocumentTemplate template = ShootDocumentTemplate.empty,
  }) =>
      ShootDocumentService.createDocument(
        db: _db,
        projectId: projectId,
        name: name,
        template: template,
      );

  Future<ShootDocument?> primaryDocument(int projectId) =>
      ShootDocumentService.primaryDocument(_db, projectId);

  Future<List<ShootDocument>> listForProject(int projectId) async {
    final docs = await _db.watchShootDocumentsForProject(projectId).first;
    return docs;
  }

  Future<List<ShootDocumentBlock>> blocksForDocument(int documentId) =>
      _db.getBlocksForShootDocument(documentId);

  Future<void> reorderBlocks(int documentId, List<int> blockIdsInOrder) =>
      ShootDocumentService.reorderBlocks(_db, documentId, blockIdsInOrder);
}
