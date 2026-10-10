import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../shared/visual_bible/bible_acts.dart';
import '../../../../shared/visual_bible/bible_cards.dart';
import '../../../../shared/visual_bible/bible_palette.dart';
import '../../../../shared/visual_bible/bible_reference.dart';
import '../../../../shared/visual_bible/bible_section_fields.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../../moodboard_helpers.dart';
import '../../../../core/database/app_database.dart';
import '../bible_acts_widget.dart';
import '../bible_card_editor.dart';
import '../bible_cards_widget.dart';
import '../bible_generic_point_views.dart';
import '../bible_navigation_scope.dart';
import '../bible_palette_widget.dart';
import '../bible_point_images.dart';
import '../bible_point_panel.dart';
import '../bible_equipment_widget.dart';
import '../bible_references_deck.dart';
import '../lighting/lighting_metrics_widget.dart';
import '../../../../shared/visual_bible/lighting_metrics.dart';
import '../../../../shared/visual_bible/bible_equipment.dart';
import '../bible_table_widget.dart';
import '../../../../shared/visual_bible/bible_table.dart';
import '../../../../shared/visual_bible/bible_text_specs.dart';

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

  /// Los actos del proyecto, para los puntos «División por actos».
  final List<BibleCard> sharedActs;

  /// Guarda los actos del proyecto; sin él, esos puntos solo llevan actos
  /// propios.
  final ValueChanged<List<BibleCard>>? onSharedActsChanged;

  const BibleWidgetContext({
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.field,
    required this.value,
    required this.onChanged,
    required this.db,
    this.sharedActs = const [],
    this.onSharedActsChanged,
  });
}

/// Familias del catálogo: agrupan los widgets al añadir un punto.
enum BibleWidgetCategory {
  writing('Texto'),
  structure('Narrativa y estructura'),
  color('Color'),
  image('Imagen'),
  references('Referencias'),
  data('Datos');

  const BibleWidgetCategory(this.label);

  final String label;
}

/// Un tipo de widget reutilizable en cualquier sección de la biblia.
class BibleWidgetEntry {
  /// Identificador estable, también para elegirlo al añadir un punto.
  final String id;
  final BibleSectionFieldType type;
  final BibleWidgetCategory category;
  final String label;
  final String description;
  final IconData icon;

  /// Pantallas en las que este widget se propone primero.
  final Set<String> screens;

  /// Valor con el que nace el punto (p. ej. el preajuste de referencias).
  final String? initialValue;
  final Widget Function(BuildContext context, BibleWidgetContext ctx) build;

  const BibleWidgetEntry({
    required this.id,
    required this.type,
    required this.category,
    required this.label,
    required this.description,
    required this.icon,
    required this.build,
    this.screens = const {},
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
  static const _narrativeScreens = {
    BibleSectionId.direction,
    BibleSectionId.concept,
  };

  static final List<BibleWidgetEntry> entries = [
    // ── Texto ──────────────────────────────────────────────────────────────
    const BibleWidgetEntry(
      id: 'text',
      type: BibleSectionFieldType.text,
      category: BibleWidgetCategory.writing,
      label: 'Texto',
      description: 'Un párrafo libre.',
      icon: Icons.notes_outlined,
      build: _generic,
    ),
    const BibleWidgetEntry(
      id: 'list',
      type: BibleSectionFieldType.list,
      category: BibleWidgetCategory.writing,
      label: 'Lista',
      description: 'Puntos sueltos, uno por línea.',
      icon: Icons.format_list_bulleted,
      build: _generic,
    ),
    const BibleWidgetEntry(
      id: 'tags',
      type: BibleSectionFieldType.tags,
      category: BibleWidgetCategory.writing,
      label: 'Etiquetas',
      description: 'Palabras clave: emociones, conceptos, sensaciones.',
      icon: Icons.sell_outlined,
      screens: _narrativeScreens,
      build: _tags,
    ),
    // ── Narrativa y estructura ─────────────────────────────────────────────
    const BibleWidgetEntry(
      id: 'acts',
      type: BibleSectionFieldType.acts,
      category: BibleWidgetCategory.structure,
      label: 'División por actos',
      description:
          'Los actos del proyecto, o unos propios de la pantalla, con su '
          'imagen, su fase y su intención. Admite puntos de giro.',
      icon: Icons.movie_filter_outlined,
      screens: _narrativeScreens,
      build: _acts,
    ),
    const BibleWidgetEntry(
      id: 'cards_mosaic',
      type: BibleSectionFieldType.cards,
      category: BibleWidgetCategory.image,
      label: 'Mosaico de imágenes con nota',
      description:
          'Imágenes grandes con su título, sus datos cortos y su texto; '
          'cada una se abre en su ficha.',
      icon: Icons.auto_awesome_mosaic_outlined,
      build: _mosaic,
    ),
    const BibleWidgetEntry(
      id: 'cards_pillars',
      type: BibleSectionFieldType.cards,
      category: BibleWidgetCategory.structure,
      label: 'Pilares',
      description:
          'Ideas en columnas, una por pilar: cámara, puesta en escena, '
          'punto de vista…',
      icon: Icons.view_week_outlined,
      screens: {BibleSectionId.direction},
      build: _pillars,
    ),
    const BibleWidgetEntry(
      id: 'cards',
      type: BibleSectionFieldType.cards,
      category: BibleWidgetCategory.structure,
      label: 'Puntos con título',
      description: 'Ideas con título y desarrollo, una debajo de otra.',
      icon: Icons.segment_outlined,
      screens: _narrativeScreens,
      build: _cards,
    ),
    // ── Color ──────────────────────────────────────────────────────────────
    const BibleWidgetEntry(
      id: 'palette_master',
      type: BibleSectionFieldType.palette,
      category: BibleWidgetCategory.color,
      label: 'Paleta maestra',
      description:
          'Muestras grandes con nombre y código. Puede llevar imágenes y '
          'un texto que la desarrolle.',
      icon: Icons.palette_outlined,
      screens: {BibleSectionId.concept},
      build: _paletteMaster,
    ),
    const BibleWidgetEntry(
      id: 'palette',
      type: BibleSectionFieldType.palette,
      category: BibleWidgetCategory.color,
      label: 'Paleta compacta',
      description: 'Una tira de muestras pequeñas, para acompañar a un punto.',
      icon: Icons.gradient_outlined,
      build: _paletteCompact,
    ),
    const BibleWidgetEntry(
      id: 'palette_symbolism',
      type: BibleSectionFieldType.palette,
      category: BibleWidgetCategory.color,
      label: 'Simbología de color',
      description:
          'Cada color con lo que significa. Puede llevar imágenes y un '
          'texto que lo desarrolle.',
      icon: Icons.color_lens_outlined,
      screens: {BibleSectionId.concept},
      build: _paletteSymbolism,
    ),
    // ── Imagen ─────────────────────────────────────────────────────────────
    const BibleWidgetEntry(
      id: 'gallery',
      type: BibleSectionFieldType.gallery,
      category: BibleWidgetCategory.image,
      label: 'Imágenes',
      description: 'Una tira de imágenes del moodboard.',
      icon: Icons.photo_library_outlined,
      build: _gallery,
    ),
    // ── Referencias ────────────────────────────────────────────────────────
    BibleWidgetEntry(
      id: 'references_narrative',
      type: BibleSectionFieldType.referenceDeck,
      category: BibleWidgetCategory.references,
      label: 'Referencias narrativas',
      description: 'Obras que guían el relato: por qué y para qué.',
      icon: Icons.auto_stories_outlined,
      screens: const {BibleSectionId.direction},
      initialValue: BibleReferenceDeckValue.initial(
        BibleReferencePreset.narrative,
      ),
      build: _references,
    ),
    BibleWidgetEntry(
      id: 'references_visual',
      type: BibleSectionFieldType.referenceDeck,
      category: BibleWidgetCategory.references,
      label: 'Referencias visuales',
      description: 'Imágenes razonadas: qué nos atrae y qué nos llevamos.',
      icon: Icons.collections_outlined,
      screens: const {BibleSectionId.concept},
      initialValue: BibleReferenceDeckValue.initial(
        BibleReferencePreset.visual,
      ),
      build: _references,
    ),
    BibleWidgetEntry(
      id: 'references_technical',
      type: BibleSectionFieldType.referenceDeck,
      category: BibleWidgetCategory.references,
      label: 'Referencias técnicas',
      description: 'Cómo se hizo: equipo, montaje y ajustes a reproducir.',
      icon: Icons.construction_outlined,
      initialValue: BibleReferenceDeckValue.initial(
        BibleReferencePreset.technical,
      ),
      build: _references,
    ),
    // ── Datos ──────────────────────────────────────────────────────────────
    const BibleWidgetEntry(
      id: 'specs',
      type: BibleSectionFieldType.specs,
      category: BibleWidgetCategory.data,
      label: 'Datos técnicos',
      description: 'Pares de dato y valor.',
      icon: Icons.tune,
      build: _generic,
    ),
    const BibleWidgetEntry(
      id: 'light_metrics',
      type: BibleSectionFieldType.specs,
      category: BibleWidgetCategory.data,
      label: 'Luz: color y contraste',
      description:
          'Temperatura o colores, tinte, ratio de contraste y qué hace '
          'falta para conseguirlos.',
      icon: Icons.wb_incandescent_outlined,
      screens: {BibleSectionId.lighting},
      build: _lightMetrics,
    ),
    const BibleWidgetEntry(
      id: 'equipment',
      type: BibleSectionFieldType.equipment,
      category: BibleWidgetCategory.data,
      label: 'Cámaras del proyecto',
      description:
          'Cada cámara, tentativa o definitiva, con su alternativa.',
      icon: Icons.videocam_outlined,
      screens: {BibleSectionId.camera},
      build: _equipment,
    ),
    const BibleWidgetEntry(
      id: 'text_specs',
      type: BibleSectionFieldType.specs,
      category: BibleWidgetCategory.data,
      label: 'Texto con datos',
      description: 'Un desarrollo escrito y, debajo, datos sueltos.',
      icon: Icons.notes_outlined,
      build: _textSpecs,
    ),
    BibleWidgetEntry(
      id: 'table',
      type: BibleSectionFieldType.table,
      category: BibleWidgetCategory.data,
      label: 'Tabla',
      description: 'Columnas con nombre y filas que se añaden.',
      icon: Icons.table_rows_outlined,
      initialValue: BibleTableValue.initial(const ['Dato', 'Valor', 'Notas']),
      build: _table,
    ),
    const BibleWidgetEntry(
      id: 'meters',
      type: BibleSectionFieldType.meters,
      category: BibleWidgetCategory.data,
      label: 'Medidores',
      description: 'Datos con su valor, una barra de escala y una nota.',
      icon: Icons.speed_outlined,
      build: _meters,
    ),
  ];

  /// Widgets que se proponen primero en [sectionId].
  static List<BibleWidgetEntry> recommendedFor(String sectionId) => [
    for (final entry in entries)
      if (entry.screens.contains(sectionId)) entry,
  ];

  static List<BibleWidgetEntry> inCategory(BibleWidgetCategory category) => [
    for (final entry in entries)
      if (entry.category == category) entry,
  ];

  /// Entrada por defecto de un punto de [type], o `null` si no es del
  /// catálogo. Es la que lleva el nombre del tipo como identificador.
  static BibleWidgetEntry? forType(BibleSectionFieldType type) {
    BibleWidgetEntry? first;
    for (final entry in entries) {
      if (entry.type != type) continue;
      if (entry.id == type.name) return entry;
      first ??= entry;
    }
    return first;
  }

  static BibleWidgetEntry? byId(String? id) {
    if (id == null) return null;
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Entrada con la que se pinta [field]: la que eligió el usuario al
  /// crearlo y, si no consta, la de su tipo. Las referencias la guardan en
  /// su valor, así que [value] afina su nombre.
  static BibleWidgetEntry? forField(BibleSectionField field, {String? value}) {
    final chosen = byId(field.widget);
    if (chosen != null && chosen.type == field.type) return chosen;
    if (field.type == BibleSectionFieldType.referenceDeck && value != null) {
      final preset = BibleReferenceDeckValue.decode(value).preset;
      return byId('references_${preset.id}') ?? forType(field.type);
    }
    return forType(field.type);
  }

  /// Pinta [ctx.field] con su widget, o `null` si el tipo no es del catálogo.
  static Widget? build(BuildContext context, BibleWidgetContext ctx) =>
      forField(ctx.field)?.build(context, ctx);

  static Widget _generic(BuildContext context, BibleWidgetContext ctx) =>
      BibleGenericPointView(
        key: ValueKey('point_${ctx.sectionId}_${ctx.field.key}'),
        field: ctx.field,
        value: ctx.value,
        onChanged: ctx.onChanged,
      );

  static Widget _paletteMaster(BuildContext context, BibleWidgetContext ctx) =>
      _palettePoint(ctx, icon: Icons.palette_outlined);

  static Widget _paletteSymbolism(
    BuildContext context,
    BibleWidgetContext ctx,
  ) => _palettePoint(ctx, icon: Icons.color_lens_outlined, symbolism: true);

  static Widget _palettePoint(
    BibleWidgetContext ctx, {
    required IconData icon,
    bool symbolism = false,
  }) => BiblePalettePoint(
    projectId: ctx.projectId,
    bibleId: ctx.bibleId,
    sectionId: ctx.sectionId,
    label: ctx.field.label,
    icon: icon,
    symbolism: symbolism,
    value: BiblePaletteValue.decode(ctx.value),
    onChanged: (value) => ctx.onChanged(value.encode()),
  );

  static Widget _paletteCompact(
    BuildContext context,
    BibleWidgetContext ctx,
  ) => BiblePointPanel(
    label: ctx.field.label,
    icon: Icons.gradient_outlined,
    child: BiblePaletteWidget(
      projectId: ctx.projectId,
      bibleId: ctx.bibleId,
      sectionId: ctx.sectionId,
      swatchSize: 56,
      colors: BiblePaletteColor.listFrom(ctx.value),
      onChanged: (colors) => ctx.onChanged(BiblePaletteColor.encode(colors)),
    ),
  );

  static Widget _cardsPoint(
    BibleWidgetContext ctx, {
    required IconData icon,
    required BibleCardsLayout layout,
  }) => BiblePointPanel(
    label: ctx.field.label,
    icon: icon,
    child: BibleCardsWidget(
      cards: BibleCard.listFrom(ctx.value),
      layout: layout,
      imageSource: BibleCardImageSource(
        projectId: ctx.projectId,
        bibleId: ctx.bibleId,
        sectionId: ctx.sectionId,
      ),
      onChanged: (cards) => ctx.onChanged(BibleCard.encode(cards)),
    ),
  );

  static Widget _cards(BuildContext context, BibleWidgetContext ctx) =>
      _cardsPoint(
        ctx,
        icon: Icons.segment_outlined,
        layout: BibleCardsLayout.list,
      );

  static Widget _pillars(BuildContext context, BibleWidgetContext ctx) =>
      _cardsPoint(
        ctx,
        icon: Icons.view_week_outlined,
        layout: BibleCardsLayout.columns,
      );

  static Widget _acts(BuildContext context, BibleWidgetContext ctx) =>
      BiblePointPanel(
        label: ctx.field.label,
        icon: Icons.movie_filter_outlined,
        child: BibleActsPoint(
          projectId: ctx.projectId,
          bibleId: ctx.bibleId,
          sectionId: ctx.sectionId,
          value: BibleActsValue.decode(ctx.value),
          onChanged: (value) => ctx.onChanged(value.encode()),
          sharedActs: ctx.sharedActs,
          onSharedActsChanged: ctx.onSharedActsChanged,
        ),
      );

  static Widget _textSpecs(BuildContext context, BibleWidgetContext ctx) =>
      BiblePointPanel(
        label: ctx.field.label,
        icon: Icons.notes_outlined,
        child: BibleTextSpecsWidget(
          key: ValueKey('text_specs_${ctx.sectionId}_${ctx.field.key}'),
          value: BibleTextSpecsValue.decode(ctx.value),
          hint: ctx.field.hint ?? 'Escribe aquí…',
          onChanged: (value) => ctx.onChanged(value.encode()),
        ),
      );

  static Widget _lightMetrics(BuildContext context, BibleWidgetContext ctx) =>
      BiblePointPanel(
        label: ctx.field.label,
        icon: Icons.wb_incandescent_outlined,
        child: LightingMetricsWidget(
          value: LightingMetrics.fromJson(ctx.value),
          onChanged: (value) => ctx.onChanged(value.encode()),
        ),
      );

  static Widget _mosaic(BuildContext context, BibleWidgetContext ctx) =>
      _cardsPoint(
        ctx,
        icon: Icons.auto_awesome_mosaic_outlined,
        layout: BibleCardsLayout.mosaic,
      );

  static Widget _equipment(BuildContext context, BibleWidgetContext ctx) =>
      BiblePointPanel(
        label: ctx.field.label,
        icon: Icons.videocam_outlined,
        child: BibleCameraEquipmentPoint(
          key: ValueKey('equipment_${ctx.sectionId}_${ctx.field.key}'),
          projectId: ctx.projectId,
          items: BibleEquipmentItem.listFrom(ctx.value),
          onChanged: (items) =>
              ctx.onChanged(BibleEquipmentItem.encode(items)),
        ),
      );

  static Widget _table(BuildContext context, BibleWidgetContext ctx) =>
      BiblePointPanel(
        label: ctx.field.label,
        icon: Icons.table_rows_outlined,
        child: BibleTableWidget(
          key: ValueKey('table_${ctx.sectionId}_${ctx.field.key}'),
          value: BibleTableValue.decode(ctx.value),
          onChanged: (value) => ctx.onChanged(value.encode()),
        ),
      );

  static Widget _meters(BuildContext context, BibleWidgetContext ctx) =>
      BiblePointPanel(
        label: ctx.field.label,
        icon: Icons.speed_outlined,
        child: BibleMetersWidget(
          key: ValueKey('meters_${ctx.sectionId}_${ctx.field.key}'),
          meters: BibleMeter.listFrom(ctx.value),
          onChanged: (meters) => ctx.onChanged(BibleMeter.encode(meters)),
        ),
      );

  static Widget _tags(BuildContext context, BibleWidgetContext ctx) =>
      BiblePointPanel(
        label: ctx.field.label,
        icon: Icons.sell_outlined,
        child: BibleTagsWidget(
          tags: BibleSectionPointValue.decodeList(ctx.value),
          onChanged: (tags) =>
              ctx.onChanged(BibleSectionPointValue.encodeList(tags)),
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
