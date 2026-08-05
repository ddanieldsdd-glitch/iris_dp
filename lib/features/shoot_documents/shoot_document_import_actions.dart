import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_snackbar.dart';
import 'shoot_document_block_types.dart';
import 'shoot_document_composer.dart';
import 'shoot_document_editor_screen.dart';
import 'shoot_document_service.dart';

/// Atajos para añadir bloques al documento de rodaje desde otros módulos.
abstract final class ShootDocumentImportActions {
  ShootDocumentImportActions._();

  static Future<ShootDocument?> pickDocument(
    BuildContext context,
    AppDatabase db,
    int projectId, {
    String title = 'Añadir al documento de rodaje',
  }) async {
    final docs = await db.watchShootDocumentsForProject(projectId).first;
    if (!context.mounted) return null;

    if (docs.isEmpty) {
      final create = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final palette = context.palette;
          return AlertDialog(
            backgroundColor: palette.surfaceElevated,
            title: Text(title, style: AppTypography.titleMedium(palette)),
            content: Text(
              'No hay documentos de rodaje. ¿Crear uno nuevo?',
              style: AppTypography.bodyMedium(palette),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Crear', style: AppTypography.bodyMedium(palette)
                    .copyWith(color: palette.accent)),
              ),
            ],
          );
        },
      );
      if (create != true || !context.mounted) return null;
      final id = await ShootDocumentService.createDocument(
        db: db,
        projectId: projectId,
        name: 'Plani',
      );
      return db.getShootDocument(id);
    }

    if (docs.length == 1) return docs.first;

    return showDialog<ShootDocument>(
      context: context,
      builder: (ctx) {
        final palette = context.palette;
        return SimpleDialog(
          backgroundColor: palette.surfaceElevated,
          title: Text(title, style: AppTypography.titleMedium(palette)),
          children: [
            for (final doc in docs)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, doc),
                child: Text(doc.name, style: AppTypography.bodyMedium(palette)),
              ),
          ],
        );
      },
    );
  }

  static Future<bool> addSceneBlocks({
    required BuildContext context,
    required AppDatabase db,
    required int projectId,
    required Scene scene,
  }) async {
    final doc = await pickDocument(context, db, projectId);
    if (doc == null || !context.mounted) return false;

    final companions = await ShootDocumentComposer.compose(
      db: db,
      projectId: projectId,
      template: ShootDocumentTemplate.narrativeScenes,
      selectedSceneIds: [scene.id],
    );
    var order = await ShootDocumentService.nextSortOrder(db, doc.id);
    for (final c in companions) {
      await db.insertShootDocumentBlock(
        c.copyWith(
          documentId: Value(doc.id),
          sortOrder: Value(order++),
        ),
      );
    }

    if (!context.mounted) return false;
    AppSnackBar.show(context, 'Escena añadida a «${doc.name}»');
    return true;
  }

  static Future<bool> addShotBlock({
    required BuildContext context,
    required AppDatabase db,
    required int projectId,
    required Shot shot,
    required Scene scene,
  }) async {
    final doc = await pickDocument(context, db, projectId);
    if (doc == null || !context.mounted) return false;

    final order = await ShootDocumentService.nextSortOrder(db, doc.id);
    await db.insertShootDocumentBlock(
      ShootDocumentBlocksCompanion.insert(
        documentId: doc.id,
        sortOrder: Value(order),
        blockType: ShootBlockType.shot,
        sceneId: Value(scene.id),
        shotId: Value(shot.id),
        durationSeconds: Value(shot.durationSeconds),
        charactersJson: Value(shot.charactersJson),
      ),
    );

    if (!context.mounted) return false;
    AppSnackBar.show(context, 'Plano ${shot.number} añadido a «${doc.name}»');
    return true;
  }

  static Future<bool> addImageBlock({
    required BuildContext context,
    required AppDatabase db,
    required int projectId,
    required String imagePath,
    int? shotId,
    int? sceneId,
  }) async {
    final doc = await pickDocument(context, db, projectId);
    if (doc == null || !context.mounted) return false;

    final order = await ShootDocumentService.nextSortOrder(db, doc.id);
    await db.insertShootDocumentBlock(
      ShootDocumentBlocksCompanion.insert(
        documentId: doc.id,
        sortOrder: Value(order),
        blockType: shotId != null ? ShootBlockType.shot : ShootBlockType.image,
        sceneId: Value(sceneId),
        shotId: Value(shotId),
        imagePath: Value(imagePath),
      ),
    );

    if (!context.mounted) return false;
    AppSnackBar.show(context, 'Referencia añadida a «${doc.name}»');
    return true;
  }

  static void openEditor(
    BuildContext context, {
    required int projectId,
    required int documentId,
  }) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ShootDocumentEditorScreen(
          projectId: projectId,
          documentId: documentId,
        ),
      ),
    );
  }
}
