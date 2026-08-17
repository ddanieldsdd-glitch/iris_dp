import 'package:flutter/material.dart';

import 'bible_section_fields.dart';

/// Familia de **contenido** del widget (no el look visual de la sección).
///
/// - [cinematic]: narrativa + stills del moodboard.
/// - [technical]: números, specs, diagramas.
enum BibleWidgetContentFamily {
  cinematic,
  technical,
}

extension BibleWidgetContentFamilyX on BibleWidgetContentFamily {
  String get label => switch (this) {
        BibleWidgetContentFamily.cinematic => 'Cinematic',
        BibleWidgetContentFamily.technical => 'Technical',
      };
}

/// Identificador estable de un tipo de sub-apartado reutilizable en la biblia.
enum BibleSubsectionKindId {
  textField,
  narrativeIntent,
  moodboardRefs,
  referenceImages,
  dynamicBlocks,
  headerTags,
  heroWithCaption,
  paletteTarget,
  reinforcementText,
  reinforcementImages,
  behaviorMosaic,
  cardDeck,
  telemetryPanel,
  setupList,
  lightingDiagram,
}

/// Entrada del catálogo de sub-apartados (nombre, logo, tipo wireable).
class BibleSubsectionKind {
  final BibleSubsectionKindId id;
  final String label;
  final String description;
  final IconData icon;
  final BibleSectionFieldType fieldType;
  final BibleWidgetContentFamily contentFamily;

  const BibleSubsectionKind({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.fieldType,
    required this.contentFamily,
  });

  String get storageKey => id.name;
}

/// Catálogo de tipos de sub-apartado para composición futura y panel Widgets.
abstract final class BibleSubsectionKindCatalog {
  static const List<BibleSubsectionKind> all = [
    BibleSubsectionKind(
      id: BibleSubsectionKindId.textField,
      label: 'Campo de texto',
      description: 'Texto corto o técnico editable.',
      icon: Icons.short_text,
      fieldType: BibleSectionFieldType.text,
      contentFamily: BibleWidgetContentFamily.technical,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.narrativeIntent,
      label: 'Intención narrativa',
      description: 'Bloque narrativo largo (visión, intención, análisis).',
      icon: Icons.menu_book_outlined,
      fieldType: BibleSectionFieldType.narrative,
      contentFamily: BibleWidgetContentFamily.cinematic,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.moodboardRefs,
      label: 'Referencias moodboard',
      description: 'Galería de stills del moodboard asignados a la sección.',
      icon: Icons.dashboard_customize_outlined,
      fieldType: BibleSectionFieldType.references,
      contentFamily: BibleWidgetContentFamily.cinematic,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.referenceImages,
      label: 'Imágenes referencia',
      description: 'Slot de imagen / cover de referencia.',
      icon: Icons.image_outlined,
      fieldType: BibleSectionFieldType.image,
      contentFamily: BibleWidgetContentFamily.cinematic,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.dynamicBlocks,
      label: 'Bloques dinámicos',
      description: 'Grid o lista de cartas/contenedores editables.',
      icon: Icons.view_module_outlined,
      fieldType: BibleSectionFieldType.blocks,
      contentFamily: BibleWidgetContentFamily.cinematic,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.behaviorMosaic,
      label: 'Mosaico de contenedores',
      description: 'Grid de contenedores de comportamiento de luz.',
      icon: Icons.grid_view_outlined,
      fieldType: BibleSectionFieldType.blocks,
      contentFamily: BibleWidgetContentFamily.cinematic,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.cardDeck,
      label: 'Deck de cartas',
      description: 'Grid de cartas narrativas (refs fílmicas, sets…).',
      icon: Icons.view_agenda_outlined,
      fieldType: BibleSectionFieldType.blocks,
      contentFamily: BibleWidgetContentFamily.cinematic,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.telemetryPanel,
      label: 'Panel de telemetría',
      description: 'Kelvin, tint, contraste, fixtures y métricas.',
      icon: Icons.speed_outlined,
      fieldType: BibleSectionFieldType.blocks,
      contentFamily: BibleWidgetContentFamily.technical,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.setupList,
      label: 'Lista de setups',
      description: 'Setups de iluminación por set con notas.',
      icon: Icons.list_alt_outlined,
      fieldType: BibleSectionFieldType.blocks,
      contentFamily: BibleWidgetContentFamily.technical,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.lightingDiagram,
      label: 'Diagrama de planta',
      description: 'Plano de luces con nodos de fixture y cámara.',
      icon: Icons.map_outlined,
      fieldType: BibleSectionFieldType.blocks,
      contentFamily: BibleWidgetContentFamily.technical,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.headerTags,
      label: 'Tags de cabecera',
      description: 'Chips de tags encima del título del contenedor.',
      icon: Icons.label_outline,
      fieldType: BibleSectionFieldType.text,
      contentFamily: BibleWidgetContentFamily.cinematic,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.heroWithCaption,
      label: 'Hero con pie de foto',
      description: 'Imagen representante con apuntes del plano.',
      icon: Icons.photo_size_select_actual_outlined,
      fieldType: BibleSectionFieldType.image,
      contentFamily: BibleWidgetContentFamily.cinematic,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.paletteTarget,
      label: 'Paleta del plano',
      description: 'Visor de paleta de color del still representante.',
      icon: Icons.palette_outlined,
      fieldType: BibleSectionFieldType.references,
      contentFamily: BibleWidgetContentFamily.cinematic,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.reinforcementText,
      label: 'Texto de refuerzo',
      description: 'Bloque narrativo adicional bajo la paleta.',
      icon: Icons.notes_outlined,
      fieldType: BibleSectionFieldType.narrative,
      contentFamily: BibleWidgetContentFamily.cinematic,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.reinforcementImages,
      label: 'Imágenes de refuerzo',
      description: 'Grid de referencias extra con paleta opcional.',
      icon: Icons.collections_outlined,
      fieldType: BibleSectionFieldType.references,
      contentFamily: BibleWidgetContentFamily.cinematic,
    ),
  ];

  static BibleSubsectionKind? byId(BibleSubsectionKindId? id) {
    if (id == null) return null;
    for (final k in all) {
      if (k.id == id) return k;
    }
    return null;
  }

  static BibleSubsectionKind? byStorageKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final k in all) {
      if (k.storageKey == key) return k;
    }
    return null;
  }

  static BibleSubsectionKind fromFieldType(BibleSectionFieldType type) {
    for (final k in all) {
      if (k.fieldType == type) return k;
    }
    return all.first;
  }

  static bool isAvailable(BibleSubsectionKindId id) => true;
}
