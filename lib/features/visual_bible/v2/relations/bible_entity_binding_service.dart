import '../model/bible_block.dart';
import '../model/project_entity_reference.dart';

/// Resuelve bindings entre bloques de Biblia y entidades del proyecto.
abstract final class BibleEntityBindingService {
  static ProjectEntityReference? referenceFromBlock(BibleBlock block) =>
      block.binding;

  static BibleBlock bindConnected({
    required BibleBlock block,
    required String entity,
    required String entityId,
  }) {
    return block.copyWith(
      binding: ProjectEntityReference(
        entity: entity,
        id: entityId,
        mode: 'connected',
      ),
    );
  }

  static BibleBlock bindSnapshot({
    required BibleBlock block,
    required String entity,
    required String entityId,
    required Map<String, dynamic> snapshot,
  }) {
    return block.copyWith(
      binding: ProjectEntityReference(
        entity: entity,
        id: entityId,
        mode: 'snapshot',
        snapshot: snapshot,
      ),
    );
  }

  /// Entidades soportadas para interconexión Moodboard ↔ secciones ↔ equipo.
  static const supportedEntities = {
    'moodboardImage',
    'camera',
    'lens',
    'light',
    'location',
    'lightingSetup',
    'colorBlock',
    'cameraTest',
  };
}
