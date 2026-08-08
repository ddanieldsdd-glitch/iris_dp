import 'package:flutter/material.dart';

import '../../shared/visual_bible/bible_section_fields.dart';
import '../../shared/visual_bible/bible_section_ids.dart';
import 'bible_blueprint.dart';

/// Catálogo de bloques UI reutilizables para pantallas 100% modificables.
///
/// Estrategia: ir añadiendo tipos aquí y cablearlos en el renderer.
/// Las pantallas Stitch se construyen componiendo estos bloques.
enum BibleBlockKind {
  /// Texto multilínea editable.
  text,

  /// Intención narrativa (card con acento).
  narrative,

  /// Grid de referencias del moodboard filtrado por sección.
  moodboardRefs,

  /// Imagen / hero de referencia.
  heroImage,

  /// Selector de chips (emoción, tags…).
  chipSelect,

  /// Paleta de colores (swatches).
  colorPalette,

  /// Métricas técnicas (Kelvin, ratio, IRE…).
  telemetry,

  /// Lista de equipo / fixtures.
  equipmentList,

  /// Diagrama / planta de luz (puente a camera_plan).
  lightingDiagram,

  /// Tabla de specs (lentes, sensor…).
  specsTable,

  /// Pipeline / steps horizontales.
  workflowPipeline,

  /// Bloques dinámicos legacy (color/exposure setups).
  dynamicBlocks,
}

extension BibleBlockKindX on BibleBlockKind {
  String get label => switch (this) {
    BibleBlockKind.text => 'Campo de texto',
    BibleBlockKind.narrative => 'Intención narrativa',
    BibleBlockKind.moodboardRefs => 'Referencias moodboard',
    BibleBlockKind.heroImage => 'Imagen hero',
    BibleBlockKind.chipSelect => 'Chips / tags',
    BibleBlockKind.colorPalette => 'Paleta de color',
    BibleBlockKind.telemetry => 'Telemetría / métricas',
    BibleBlockKind.equipmentList => 'Lista de equipo',
    BibleBlockKind.lightingDiagram => 'Diagrama de iluminación',
    BibleBlockKind.specsTable => 'Tabla técnica',
    BibleBlockKind.workflowPipeline => 'Pipeline workflow',
    BibleBlockKind.dynamicBlocks => 'Bloques dinámicos',
  };

  IconData get icon => switch (this) {
    BibleBlockKind.text => Icons.notes_outlined,
    BibleBlockKind.narrative => Icons.auto_stories_outlined,
    BibleBlockKind.moodboardRefs => Icons.collections_outlined,
    BibleBlockKind.heroImage => Icons.image_outlined,
    BibleBlockKind.chipSelect => Icons.label_outlined,
    BibleBlockKind.colorPalette => Icons.palette_outlined,
    BibleBlockKind.telemetry => Icons.speed_outlined,
    BibleBlockKind.equipmentList => Icons.lightbulb_outline,
    BibleBlockKind.lightingDiagram => Icons.grid_on_outlined,
    BibleBlockKind.specsTable => Icons.table_chart_outlined,
    BibleBlockKind.workflowPipeline => Icons.account_tree_outlined,
    BibleBlockKind.dynamicBlocks => Icons.view_agenda_outlined,
  };

  /// Estado de implementación en el renderer.
  BibleBlockStatus get status => switch (this) {
    BibleBlockKind.text ||
    BibleBlockKind.narrative ||
    BibleBlockKind.heroImage ||
    BibleBlockKind.chipSelect ||
    BibleBlockKind.equipmentList ||
    BibleBlockKind.specsTable => BibleBlockStatus.live,
    BibleBlockKind.moodboardRefs ||
    BibleBlockKind.colorPalette ||
    BibleBlockKind.telemetry ||
    BibleBlockKind.lightingDiagram ||
    BibleBlockKind.workflowPipeline => BibleBlockStatus.partial,
    BibleBlockKind.dynamicBlocks => BibleBlockStatus.planned,
  };

  /// Mapeo al tipo legacy de campo (hasta migrar el editor).
  BibleSectionFieldType get fieldType => switch (this) {
    BibleBlockKind.text => BibleSectionFieldType.text,
    BibleBlockKind.narrative => BibleSectionFieldType.narrative,
    BibleBlockKind.moodboardRefs ||
    BibleBlockKind.heroImage => BibleSectionFieldType.references,
    BibleBlockKind.dynamicBlocks => BibleSectionFieldType.blocks,
    _ => BibleSectionFieldType.text,
  };
}

/// Utilidades del catálogo de bloques V2.
abstract final class BibleBlockCatalog {
  /// Kinds visibles en el picker de usuario (sin placeholders).
  static Iterable<BibleBlockKind> get pickerKinds =>
      BibleBlockKind.values.where((k) => k.status == BibleBlockStatus.live);
}

enum BibleBlockStatus { live, partial, planned }

extension BibleBlockStatusX on BibleBlockStatus {
  String get label => switch (this) {
    BibleBlockStatus.live => 'Activo',
    BibleBlockStatus.partial => 'Parcial',
    BibleBlockStatus.planned => 'Próximo',
  };
}

/// Pack de bloques recomendados por sección + blueprint.
abstract final class BibleBlueprintPacks {
  /// Qué bloques deberían componer cada sección en una plantilla elaborada.
  static List<BibleBlockKind> blocksFor(
    String sectionId,
    BibleBlueprintType blueprint,
  ) {
    final base = _baseBlocks(sectionId);
    return switch (blueprint) {
      BibleBlueprintType.fiction => base,
      BibleBlueprintType.commercial => _commercialVariant(sectionId, base),
      BibleBlueprintType.documentary => _documentaryVariant(sectionId, base),
    };
  }

  static List<BibleBlockKind> _baseBlocks(String sectionId) =>
      switch (sectionId) {
        BibleSectionId.direction => const [
          BibleBlockKind.narrative,
          BibleBlockKind.chipSelect,
          BibleBlockKind.text,
          BibleBlockKind.moodboardRefs,
        ],
        BibleSectionId.concept => const [
          BibleBlockKind.narrative,
          BibleBlockKind.text,
          BibleBlockKind.moodboardRefs,
        ],
        BibleSectionId.lighting => const [
          BibleBlockKind.narrative,
          BibleBlockKind.telemetry,
          BibleBlockKind.equipmentList,
          BibleBlockKind.lightingDiagram,
          BibleBlockKind.moodboardRefs,
        ],
        BibleSectionId.colorImage => const [
          BibleBlockKind.narrative,
          BibleBlockKind.colorPalette,
          BibleBlockKind.dynamicBlocks,
          BibleBlockKind.moodboardRefs,
        ],
        BibleSectionId.moodboard => const [
          BibleBlockKind.moodboardRefs,
          BibleBlockKind.colorPalette,
        ],
        BibleSectionId.camera || BibleSectionId.optics => const [
          BibleBlockKind.narrative,
          BibleBlockKind.specsTable,
          BibleBlockKind.moodboardRefs,
        ],
        BibleSectionId.workflow => const [
          BibleBlockKind.workflowPipeline,
          BibleBlockKind.text,
        ],
        BibleSectionId.location => const [
          BibleBlockKind.heroImage,
          BibleBlockKind.telemetry,
          BibleBlockKind.moodboardRefs,
          BibleBlockKind.text,
        ],
        _ => const [
          BibleBlockKind.narrative,
          BibleBlockKind.text,
          BibleBlockKind.moodboardRefs,
        ],
      };

  static List<BibleBlockKind> _commercialVariant(
    String sectionId,
    List<BibleBlockKind> base,
  ) {
    if (sectionId == BibleSectionId.colorImage ||
        sectionId == BibleSectionId.moodboard) {
      return [
        BibleBlockKind.colorPalette,
        BibleBlockKind.heroImage,
        ...base.where((b) => b != BibleBlockKind.colorPalette),
      ];
    }
    return base;
  }

  static List<BibleBlockKind> _documentaryVariant(
    String sectionId,
    List<BibleBlockKind> base,
  ) {
    if (sectionId == BibleSectionId.lighting ||
        sectionId == BibleSectionId.location) {
      return [
        BibleBlockKind.narrative,
        BibleBlockKind.telemetry,
        BibleBlockKind.moodboardRefs,
        BibleBlockKind.text,
      ];
    }
    return base
        .where((b) => b != BibleBlockKind.specsTable)
        .toList(growable: false);
  }
}
