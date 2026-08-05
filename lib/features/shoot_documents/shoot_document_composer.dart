import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../../core/database/app_database.dart';
import '../../core/utils/scene_characters.dart';
import 'shoot_document_block_types.dart';

/// Plantillas opcionales para generar bloques iniciales (no vinculantes).
abstract final class ShootDocumentComposer {
  ShootDocumentComposer._();

  static Future<List<ShootDocumentBlocksCompanion>> compose({
    required AppDatabase db,
    required int projectId,
    required ShootDocumentTemplate template,
    List<int>? selectedSceneIds,
  }) async {
    return switch (template) {
      ShootDocumentTemplate.empty => [],
      ShootDocumentTemplate.narrativeScenes =>
        _fromScenes(db, projectId, selectedSceneIds, narrative: true),
      ShootDocumentTemplate.shootingOrderScenes =>
        _fromScenes(db, projectId, selectedSceneIds, narrative: false),
      ShootDocumentTemplate.fullTechnical =>
        _fromFullTechnical(db, projectId),
    };
  }

  static Future<List<ShootDocumentBlocksCompanion>> _fromScenes(
    AppDatabase db,
    int projectId,
    List<int>? selectedSceneIds, {
    required bool narrative,
  }) async {
    var scenes = await (db.select(db.scenes)
          ..where((s) => s.projectId.equals(projectId)))
        .get();
    if (selectedSceneIds != null && selectedSceneIds.isNotEmpty) {
      final idSet = selectedSceneIds.toSet();
      scenes = scenes.where((s) => idSet.contains(s.id)).toList();
    }
    if (!narrative) {
      scenes.sort((a, b) {
        final site = a.locationPureName.compareTo(b.locationPureName);
        if (site != 0) return site;
        return a.dayNight.compareTo(b.dayNight);
      });
    } else {
      scenes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final blocks = <ShootDocumentBlocksCompanion>[];
    var order = 0;
    for (final scene in scenes) {
      blocks.add(_sceneHeaderBlock(scene, order++));
      final chars = decodeSceneCharacters(scene.charactersJson);
      if (chars.isNotEmpty) {
        blocks.add(
          ShootDocumentBlocksCompanion.insert(
            documentId: 0,
            sortOrder: Value(order++),
            blockType: ShootBlockType.characterList,
            sceneId: Value(scene.id),
            charactersJson: Value(encodeSceneCharacters(chars)),
          ),
        );
      }
      if (scene.actionText != null && scene.actionText!.trim().isNotEmpty) {
        blocks.add(
          ShootDocumentBlocksCompanion.insert(
            documentId: 0,
            sortOrder: Value(order++),
            blockType: ShootBlockType.scriptExcerpt,
            sceneId: Value(scene.id),
            scriptExcerpt: Value(scene.actionText),
          ),
        );
      }
      final shots = await (db.select(db.shots)
            ..where((s) => s.sceneId.equals(scene.id))
            ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
          .get();
      for (final shot in shots) {
        blocks.add(
          ShootDocumentBlocksCompanion.insert(
            documentId: 0,
            sortOrder: Value(order++),
            blockType: ShootBlockType.shot,
            sceneId: Value(scene.id),
            shotId: Value(shot.id),
            durationSeconds: Value(shot.durationSeconds),
            charactersJson: Value(shot.charactersJson),
          ),
        );
      }
    }
    return blocks;
  }

  static Future<List<ShootDocumentBlocksCompanion>> _fromFullTechnical(
    AppDatabase db,
    int projectId,
  ) =>
      _fromScenes(db, projectId, null, narrative: true);

  static ShootDocumentBlocksCompanion _sceneHeaderBlock(Scene scene, int order) {
    return ShootDocumentBlocksCompanion.insert(
      documentId: 0,
      sortOrder: Value(order),
      blockType: ShootBlockType.sceneHeader,
      sceneId: Value(scene.id),
      customLabel: Value(scene.locationCanonical),
    );
  }

  static ShootDocumentBlocksCompanion duplicateBlock(
    ShootDocumentBlock block,
    int documentId,
    int sortOrder,
  ) {
    return ShootDocumentBlocksCompanion.insert(
      documentId: documentId,
      sortOrder: Value(sortOrder),
      blockType: block.blockType,
      sceneId: Value(block.sceneId),
      shotId: Value(block.shotId),
      scriptExcerpt: Value(block.scriptExcerpt),
      customLabel: Value(block.customLabel),
      noteBody: Value(block.noteBody),
      imagePath: Value(block.imagePath),
      charactersJson: Value(block.charactersJson),
      durationSeconds: Value(block.durationSeconds),
      visibilityJson: Value(block.visibilityJson),
      contentOverridesJson: Value(block.contentOverridesJson),
    );
  }
}

enum ShootDocumentTemplate {
  empty,
  narrativeScenes,
  shootingOrderScenes,
  fullTechnical,
}

extension ShootDocumentTemplateX on ShootDocumentTemplate {
  String get label => switch (this) {
        ShootDocumentTemplate.empty => 'Documento vacío',
        ShootDocumentTemplate.narrativeScenes => 'Escenas (orden narrativo)',
        ShootDocumentTemplate.shootingOrderScenes =>
          'Escenas (orden de rodaje)',
        ShootDocumentTemplate.fullTechnical => 'Guion técnico completo',
      };

  String get description => switch (this) {
        ShootDocumentTemplate.empty =>
          'Empieza con bloques en blanco y compón libremente.',
        ShootDocumentTemplate.narrativeScenes =>
          'Genera cabeceras, personajes y planos por escena en orden del guion.',
        ShootDocumentTemplate.shootingOrderScenes =>
          'Agrupa por localización y día/noche; editable después.',
        ShootDocumentTemplate.fullTechnical =>
          'Todas las escenas y planos del proyecto como borrador.',
      };
}
