import '../../core/database/app_database.dart';
import '../../core/utils/scene_characters.dart';
import 'shoot_document_block_types.dart';

/// Datos resueltos para renderizar un bloque (maestro + overrides).
class ResolvedShootBlock {
  final ShootDocumentBlock block;
  final Scene? scene;
  final Shot? shot;
  final ShootBlockVisibility visibility;
  final Map<String, dynamic> overrides;

  const ResolvedShootBlock({
    required this.block,
    this.scene,
    this.shot,
    required this.visibility,
    required this.overrides,
  });

  String? get lens =>
      overrides['lens'] as String? ?? shot?.lens;
  String? get movement =>
      overrides['movement'] as String? ?? shot?.movement;
  String? get framing =>
      overrides['framing'] as String? ?? shot?.framing;
  String? get action =>
      overrides['action'] as String? ?? shot?.action;
  String? get imagePath =>
      block.imagePath ?? shot?.referenceImagePath;
  List<String> get characters {
    final fromBlock = decodeSceneCharacters(block.charactersJson);
    if (fromBlock.isNotEmpty) return fromBlock;
    final fromShot = decodeSceneCharacters(shot?.charactersJson);
    if (fromShot.isNotEmpty) return fromShot;
    return decodeSceneCharacters(scene?.charactersJson);
  }

  int? get durationSeconds =>
      block.durationSeconds ?? shot?.durationSeconds;

  String get title {
    return switch (block.blockType) {
      ShootBlockType.sectionHeader ||
      ShootBlockType.sceneHeader =>
        block.customLabel ?? scene?.locationCanonical ?? 'Sección',
      ShootBlockType.characterList => 'Personajes',
      ShootBlockType.scriptExcerpt => 'Guion',
      ShootBlockType.shot =>
        shot != null ? 'Plano ${shot!.number}' : 'Plano',
      ShootBlockType.note => 'Nota',
      ShootBlockType.image => 'Imagen',
      ShootBlockType.pageBreak => 'Salto de página',
      ShootBlockType.spacer => 'Espacio',
      _ => ShootBlockType.label(block.blockType),
    };
  }
}

ShootBlockVisibility mergeVisibility(
  ShootBlockVisibility docDefault,
  ShootDocumentBlock block,
) {
  final blockVis = decodeBlockVisibility(block.visibilityJson);
  return docDefault.copyWith(
    showThumbnail: blockVis.showThumbnail,
    showCharacters: blockVis.showCharacters,
    showDuration: blockVis.showDuration,
    showCamera: blockVis.showCamera,
    showAction: blockVis.showAction,
    showScript: blockVis.showScript,
  );
}

String formatDurationSeconds(int? seconds) {
  if (seconds == null || seconds <= 0) return '—';
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (s == 0) return '${m}m';
  return '${m}m ${s}s';
}
