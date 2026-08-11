import 'package:flutter/material.dart';

import 'bible_section_fields.dart';

/// Identificador estable de un tipo de sub-apartado reutilizable en la biblia.
///
/// Catálogo paralelo a [BibleSectionFieldType]: no rompe pantallas existentes;
/// permite nombre UI + icono + mapeo al tipo de field persistido.
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
}

/// Entrada del catálogo de sub-apartados (nombre, logo, tipo wireable).
class BibleSubsectionKind {
  final BibleSubsectionKindId id;
  final String label;
  final String description;
  final IconData icon;
  final BibleSectionFieldType fieldType;

  const BibleSubsectionKind({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.fieldType,
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
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.narrativeIntent,
      label: 'Intención narrativa',
      description: 'Bloque narrativo largo (visión, intención, análisis).',
      icon: Icons.menu_book_outlined,
      fieldType: BibleSectionFieldType.narrative,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.moodboardRefs,
      label: 'Referencias moodboard',
      description: 'Galería de stills del moodboard asignados a la sección.',
      icon: Icons.dashboard_customize_outlined,
      fieldType: BibleSectionFieldType.references,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.referenceImages,
      label: 'Imágenes referencia',
      description: 'Slot de imagen / cover de referencia.',
      icon: Icons.image_outlined,
      fieldType: BibleSectionFieldType.image,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.dynamicBlocks,
      label: 'Bloques dinámicos',
      description: 'Grid o lista de cartas/contenedores editables.',
      icon: Icons.view_module_outlined,
      fieldType: BibleSectionFieldType.blocks,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.headerTags,
      label: 'Tags de cabecera',
      description: 'Chips de tags encima del título del contenedor.',
      icon: Icons.label_outline,
      fieldType: BibleSectionFieldType.text,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.heroWithCaption,
      label: 'Hero con pie de foto',
      description: 'Imagen representante con apuntes del plano.',
      icon: Icons.photo_size_select_actual_outlined,
      fieldType: BibleSectionFieldType.image,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.paletteTarget,
      label: 'Paleta del plano',
      description: 'Visor de paleta de color del still representante.',
      icon: Icons.palette_outlined,
      fieldType: BibleSectionFieldType.references,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.reinforcementText,
      label: 'Texto de refuerzo',
      description: 'Bloque narrativo adicional bajo la paleta.',
      icon: Icons.notes_outlined,
      fieldType: BibleSectionFieldType.narrative,
    ),
    BibleSubsectionKind(
      id: BibleSubsectionKindId.reinforcementImages,
      label: 'Imágenes de refuerzo',
      description: 'Grid de referencias extra con paleta opcional.',
      icon: Icons.collections_outlined,
      fieldType: BibleSectionFieldType.references,
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
