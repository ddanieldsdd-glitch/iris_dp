import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../shared/visual_bible/bible_palette.dart';
import '../../../../shared/visual_bible/bible_reference.dart';
import '../../../../shared/visual_bible/bible_section_fields.dart';
import '../../moodboard_helpers.dart';
import '../../../../core/database/app_database.dart';
import '../bible_generic_point_views.dart';
import '../bible_navigation_scope.dart';
import '../bible_palette_widget.dart';
import '../bible_point_images.dart';
import '../bible_point_panel.dart';
import '../bible_references_deck.dart';

/// Lo que un widget del catálogo necesita para pintarse y guardar su valor.
class BibleWidgetContext {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final BibleSectionField field;

  /// Valor crudo de `values[field.key]`.
  final String? value;

  /// Guarda el valor; `null` deja el punto vacío.
  final ValueChanged<String?> onChanged;
  final AppDatabase db;

  const BibleWidgetContext({
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.field,
    required this.value,
    required this.onChanged,
    required this.db,
  });
}

/// Un tipo de widget reutilizable en cualquier sección de la biblia.
class BibleWidgetEntry {
  /// Identificador estable, también para elegirlo al añadir un punto.
  final String id;
  final BibleSectionFieldType type;
  final String label;
  final String description;
  final IconData icon;

  /// Valor con el que nace el punto (p. ej. el preajuste de referencias).
  final String? initialValue;
  final Widget Function(BuildContext context, BibleWidgetContext ctx) build;

  const BibleWidgetEntry({
    required this.id,
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
    required this.build,
    this.initialValue,
  });
}

/// Preajustes del mazo de referencias: textos y tipos según el uso.
enum BibleReferencePreset {
  narrative(
    'narrative',
    BibleReferencesCopy.direction,
    kDirectionReferenceKinds,
  ),
  visual('visual', BibleReferencesCopy.concept, kConceptReferenceKinds),
  technical(
    'technical',
    BibleReferencesCopy.technical,
    kTechnicalReferenceKinds,
  );

  const BibleReferencePreset(this.id, this.copy, this.kinds);

  final String id;
  final BibleReferencesCopy copy;
  final List<String> kinds;

  static BibleReferencePreset parse(Object? id) => values.firstWhere(
    (p) => p.id == id,
    orElse: () => BibleReferencePreset.visual,
  );
}

/// Valor de un punto de referencias: preajuste y fichas.
class BibleReferenceDeckValue {
  final BibleReferencePreset preset;
  final List<BibleReference> items;

  const BibleReferenceDeckValue({required this.preset, this.items = const []});

  factory BibleReferenceDeckValue.decode(String? raw) {
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return BibleReferenceDeckValue(
            preset: BibleReferencePreset.parse(decoded['preset']),
            items: BibleReference.listFrom(decoded['items']),
          );
        }
      } catch (_) {}
    }
    return const BibleReferenceDeckValue(preset: BibleReferencePreset.visual);
  }

  String encode() => jsonEncode({
    'preset': preset.id,
    'items': [for (final item in items) item.toJson()],
  });

  static String initial(BibleReferencePreset preset) =>
      BibleReferenceDeckValue(preset: preset).encode();
}

/// Catálogo de widgets de la biblia. Añadir un widget nuevo es añadir una
/// entrada aquí (y su componente de PDF en `BiblePdfKit.point`).
abstract final class BibleWidgetCatalog {
  static final List<BibleWidgetEntry> entries = [
    const BibleWidgetEntry(
      id: 'text',
      type: BibleSectionFieldType.text,
      label: 'Texto',
      description: 'Un párrafo libre.',
      icon: Icons.notes_outlined,
      build: _generic,
    ),
    const BibleWidgetEntry(
      id: 'list',
      type: BibleSectionFieldType.list,
      label: 'Lista',
      description: 'Puntos sueltos, uno por línea.',
      icon: Icons.format_list_bulleted,
      build: _generic,
    ),
    const BibleWidgetEntry(
      id: 'specs',
      type: BibleSectionFieldType.specs,
      label: 'Datos técnicos',
      description: 'Pares de dato y valor.',
      icon: Icons.tune,
      build: _generic,
    ),
    const BibleWidgetEntry(
      id: 'palette',
      type: BibleSectionFieldType.palette,
      label: 'Paleta de color',
      description: 'Muestras con código y nombre; se extrae de una imagen.',
      icon: Icons.palette_outlined,
      build: _palette,
    ),
    const BibleWidgetEntry(
      id: 'gallery',
      type: BibleSectionFieldType.gallery,
      label: 'Imágenes',
      description: 'Una tira de imágenes del moodboard.',
      icon: Icons.photo_library_outlined,
      build: _gallery,
    ),
    BibleWidgetEntry(
      id: 'references_narrative',
      type: BibleSectionFieldType.referenceDeck,
      label: 'Referencias narrativas',
      description: 'Obras que guían el relato: por qué y para qué.',
      icon: Icons.auto_stories_outlined,
      initialValue: BibleReferenceDeckValue.initial(
        BibleReferencePreset.narrative,
      ),
      build: _references,
    ),
    BibleWidgetEntry(
      id: 'references_visual',
      type: BibleSectionFieldType.referenceDeck,
      label: 'Referencias visuales',
      description: 'Imágenes razonadas: qué nos atrae y qué nos llevamos.',
      icon: Icons.collections_outlined,
      initialValue: BibleReferenceDeckValue.initial(
        BibleReferencePreset.visual,
      ),
      build: _references,
    ),
    BibleWidgetEntry(
      id: 'references_technical',
      type: BibleSectionFieldType.referenceDeck,
      label: 'Referencias técnicas',
      description: 'Cómo se hizo: equipo, montaje y ajustes a reproducir.',
      icon: Icons.construction_outlined,
      initialValue: BibleReferenceDeckValue.initial(
        BibleReferencePreset.technical,
      ),
      build: _references,
    ),
  ];

  /// Entrada que pinta un punto de [type], o `null` si no es del catálogo.
  static BibleWidgetEntry? forType(BibleSectionFieldType type) {
    for (final entry in entries) {
      if (entry.type == type) return entry;
    }
    return null;
  }

  static BibleWidgetEntry? byId(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Pinta [ctx.field] con su widget, o `null` si el tipo no es del catálogo.
  static Widget? build(BuildContext context, BibleWidgetContext ctx) =>
      forType(ctx.field.type)?.build(context, ctx);

  static Widget _generic(BuildContext context, BibleWidgetContext ctx) =>
      BibleGenericPointView(
        key: ValueKey('point_${ctx.sectionId}_${ctx.field.key}'),
        field: ctx.field,
        value: ctx.value,
        onChanged: ctx.onChanged,
      );

  static Widget _palette(BuildContext context, BibleWidgetContext ctx) =>
      BiblePointPanel(
        label: ctx.field.label,
        icon: Icons.palette_outlined,
        child: BiblePaletteWidget(
          projectId: ctx.projectId,
          bibleId: ctx.bibleId,
          sectionId: ctx.sectionId,
          colors: BiblePaletteColor.listFrom(ctx.value),
          onChanged: (colors) =>
              ctx.onChanged(BiblePaletteColor.encode(colors)),
        ),
      );

  static Widget _gallery(BuildContext context, BibleWidgetContext ctx) {
    final ids = [
      for (final id in BibleSectionPointValue.decodeList(ctx.value))
        if (int.tryParse(id) != null) int.parse(id),
    ];
    return BiblePointPanel(
      label: ctx.field.label,
      icon: Icons.photo_library_outlined,
      child: BiblePointImages(
        projectId: ctx.projectId,
        bibleId: ctx.bibleId,
        sectionId: ctx.sectionId,
        imageIds: ids,
        height: 132,
        onChanged: (next) => ctx.onChanged(
          BibleSectionPointValue.encodeList([for (final id in next) '$id']),
        ),
      ),
    );
  }

  static Widget _references(BuildContext context, BibleWidgetContext ctx) {
    final deck = BibleReferenceDeckValue.decode(ctx.value);
    return BiblePointPanel(
      label: ctx.field.label,
      icon: Icons.collections_outlined,
      child: BibleReferencesDeck(
        projectId: ctx.projectId,
        bibleId: ctx.bibleId,
        sectionId: ctx.sectionId,
        kinds: deck.preset.kinds,
        copy: deck.preset.copy,
        references: deck.items,
        onChanged: (items) => ctx.onChanged(
          BibleReferenceDeckValue(preset: deck.preset, items: items).encode(),
        ),
        onAddImage: () => MoodboardHelpers.addManualImages(
          db: ctx.db,
          projectId: ctx.projectId,
          bibleId: ctx.bibleId,
          assignedSections: [ctx.sectionId],
        ),
        onOpenMoodboard: () => BibleNavigationScope.openMoodboardForSection(
          context,
          ctx.sectionId,
        ),
      ),
    );
  }
}
