import 'bible_section_ids.dart';
import 'bible_stitch_module_registry.dart';
import 'bible_subsection_kind_catalog.dart';

/// Entrada del inventario de widgets de Iluminación.
class LightingWidgetCatalogEntry {
  final String id;
  final String? slotKey;
  final String? parentSlotKey;
  final String label;
  final BibleWidgetContentFamily contentFamily;
  final BibleSubsectionKindId subsectionKind;
  final String widgetName;
  final bool reusable;
  final String? notes;

  const LightingWidgetCatalogEntry({
    required this.id,
    this.slotKey,
    this.parentSlotKey,
    required this.label,
    required this.contentFamily,
    required this.subsectionKind,
    required this.widgetName,
    this.reusable = false,
    this.notes,
  });
}

/// Inventario de slots y piezas internas de la pantalla Iluminación.
abstract final class LightingWidgetCatalog {
  static const slotKeys = [
    'overview',
    'lightBehaviors',
    'filmRefs',
    'locationLights',
    'lightStyles',
    'lightingTagRefs',
    'diagrams',
    'references',
  ];

  static const List<LightingWidgetCatalogEntry> all = [
  // —— Slots de sección ——
    LightingWidgetCatalogEntry(
      id: 'slot_overview',
      slotKey: 'overview',
      label: 'Visión general',
      contentFamily: BibleWidgetContentFamily.cinematic,
      subsectionKind: BibleSubsectionKindId.narrativeIntent,
      widgetName: 'LightingOverviewBlock',
      reusable: false,
      notes: 'Compuesto: hero + narrativa + métricas globales.',
    ),
    LightingWidgetCatalogEntry(
      id: 'slot_lightBehaviors',
      slotKey: 'lightBehaviors',
      label: 'Comportamiento de la luz',
      contentFamily: BibleWidgetContentFamily.cinematic,
      subsectionKind: BibleSubsectionKindId.behaviorMosaic,
      widgetName: 'LightingBehaviorsBlock',
      reusable: true,
    ),
    LightingWidgetCatalogEntry(
      id: 'slot_filmRefs',
      slotKey: 'filmRefs',
      label: 'Referencias fílmicas',
      contentFamily: BibleWidgetContentFamily.cinematic,
      subsectionKind: BibleSubsectionKindId.cardDeck,
      widgetName: 'NarrativeDeckBlock',
      reusable: true,
      notes: 'kind: film_ref',
    ),
    LightingWidgetCatalogEntry(
      id: 'slot_locationLights',
      slotKey: 'locationLights',
      label: 'Localizaciones (luz)',
      contentFamily: BibleWidgetContentFamily.cinematic,
      subsectionKind: BibleSubsectionKindId.cardDeck,
      widgetName: 'NarrativeDeckBlock',
      reusable: true,
      notes: 'kind: location_light; incluye panel técnico expandible.',
    ),
    LightingWidgetCatalogEntry(
      id: 'slot_lightStyles',
      slotKey: 'lightStyles',
      label: 'Estilos de luz (legacy)',
      contentFamily: BibleWidgetContentFamily.cinematic,
      subsectionKind: BibleSubsectionKindId.cardDeck,
      widgetName: 'NarrativeDeckBlock',
      reusable: false,
      notes: 'Sustituido por lightBehaviors.',
    ),
    LightingWidgetCatalogEntry(
      id: 'slot_lightingTagRefs',
      slotKey: 'lightingTagRefs',
      label: 'Referencias por etiquetas',
      contentFamily: BibleWidgetContentFamily.cinematic,
      subsectionKind: BibleSubsectionKindId.moodboardRefs,
      widgetName: 'LightingTaggedRefsBlock',
      reusable: true,
    ),
    LightingWidgetCatalogEntry(
      id: 'slot_diagrams',
      slotKey: 'diagrams',
      label: 'Diagramas de iluminación',
      contentFamily: BibleWidgetContentFamily.technical,
      subsectionKind: BibleSubsectionKindId.setupList,
      widgetName: '_SetupsBlock',
      reusable: true,
    ),
    LightingWidgetCatalogEntry(
      id: 'slot_references',
      slotKey: 'references',
      label: 'Referencias visuales (legacy)',
      contentFamily: BibleWidgetContentFamily.cinematic,
      subsectionKind: BibleSubsectionKindId.moodboardRefs,
      widgetName: 'BibleReferencesPanel',
      reusable: true,
    ),
    // —— Nested dentro de overview ——
    LightingWidgetCatalogEntry(
      id: 'nested_hero',
      parentSlotKey: 'overview',
      label: 'Hero con still',
      contentFamily: BibleWidgetContentFamily.cinematic,
      subsectionKind: BibleSubsectionKindId.heroWithCaption,
      widgetName: '_HeroBanner',
      reusable: true,
    ),
    LightingWidgetCatalogEntry(
      id: 'nested_overview_narrative',
      parentSlotKey: 'overview',
      label: 'Intención narrativa global',
      contentFamily: BibleWidgetContentFamily.cinematic,
      subsectionKind: BibleSubsectionKindId.narrativeIntent,
      widgetName: '_OverviewNarrativePanel',
      reusable: true,
    ),
    LightingWidgetCatalogEntry(
      id: 'nested_global_metrics',
      parentSlotKey: 'overview',
      label: 'Métricas globales de luz',
      contentFamily: BibleWidgetContentFamily.technical,
      subsectionKind: BibleSubsectionKindId.telemetryPanel,
      widgetName: 'LightingGlobalMetricsPanel',
      reusable: true,
    ),
    // —— Nested mosaico / detalle de contenedor ——
    LightingWidgetCatalogEntry(
      id: 'nested_behavior_mosaic',
      parentSlotKey: 'lightBehaviors',
      label: 'Mosaico de contenedores',
      contentFamily: BibleWidgetContentFamily.cinematic,
      subsectionKind: BibleSubsectionKindId.behaviorMosaic,
      widgetName: 'LightingBehaviorMosaicBlock',
      reusable: true,
    ),
    LightingWidgetCatalogEntry(
      id: 'nested_container_header_tags',
      parentSlotKey: 'lightBehaviors',
      label: 'Tags de cabecera',
      contentFamily: BibleWidgetContentFamily.cinematic,
      subsectionKind: BibleSubsectionKindId.headerTags,
      widgetName: 'ContainerHeaderTags',
      reusable: true,
    ),
    LightingWidgetCatalogEntry(
      id: 'nested_container_hero',
      parentSlotKey: 'lightBehaviors',
      label: 'Hero de contenedor',
      contentFamily: BibleWidgetContentFamily.cinematic,
      subsectionKind: BibleSubsectionKindId.heroWithCaption,
      widgetName: 'ContainerHeroWithCaption',
      reusable: true,
    ),
    LightingWidgetCatalogEntry(
      id: 'nested_container_stills',
      parentSlotKey: 'lightBehaviors',
      label: 'Grid de stills',
      contentFamily: BibleWidgetContentFamily.cinematic,
      subsectionKind: BibleSubsectionKindId.moodboardRefs,
      widgetName: 'ContainerStillsGrid',
      reusable: true,
    ),
    LightingWidgetCatalogEntry(
      id: 'nested_container_palette',
      parentSlotKey: 'lightBehaviors',
      label: 'Paleta del plano',
      contentFamily: BibleWidgetContentFamily.cinematic,
      subsectionKind: BibleSubsectionKindId.paletteTarget,
      widgetName: 'ContainerPalettePanel',
      reusable: true,
    ),
    LightingWidgetCatalogEntry(
      id: 'nested_container_metrics',
      parentSlotKey: 'lightBehaviors',
      label: 'Métricas de contenedor',
      contentFamily: BibleWidgetContentFamily.technical,
      subsectionKind: BibleSubsectionKindId.telemetryPanel,
      widgetName: 'ContainerMetricsPanel',
      reusable: true,
    ),
  // —— Nested localización / setups ——
    LightingWidgetCatalogEntry(
      id: 'nested_location_technical',
      parentSlotKey: 'locationLights',
      label: 'Ficha técnica de set',
      contentFamily: BibleWidgetContentFamily.technical,
      subsectionKind: BibleSubsectionKindId.telemetryPanel,
      widgetName: '_LocationTechnicalPanel',
      reusable: true,
    ),
    LightingWidgetCatalogEntry(
      id: 'nested_setup_card',
      parentSlotKey: 'diagrams',
      label: 'Card de setup',
      contentFamily: BibleWidgetContentFamily.technical,
      subsectionKind: BibleSubsectionKindId.setupList,
      widgetName: '_SetupCard',
      reusable: true,
    ),
    LightingWidgetCatalogEntry(
      id: 'nested_lighting_diagram',
      parentSlotKey: 'diagrams',
      label: 'Editor de diagrama',
      contentFamily: BibleWidgetContentFamily.technical,
      subsectionKind: BibleSubsectionKindId.lightingDiagram,
      widgetName: 'LightingDiagramEditor',
      reusable: true,
    ),
  ];

  static LightingWidgetCatalogEntry? forSlot(String key) {
    for (final e in all) {
      if (e.slotKey == key) return e;
    }
    return null;
  }

  static List<LightingWidgetCatalogEntry> nestedForSlot(String parentKey) {
    return [
      for (final e in all)
        if (e.parentSlotKey == parentKey) e,
    ];
  }

  /// Keys de `fieldWidgets` en [LightingSection] cubiertas por el catálogo.
  static bool coversFieldWidgetKeys(Set<String> keys) {
    final covered = slotKeys.toSet();
    return keys.every(covered.contains);
  }

  /// Todos los módulos Stitch de lighting tienen subsectionKind con familia.
  static bool stitchModulesAnnotated() {
    for (final module in BibleStitchModuleRegistry.modulesFor(
      BibleSectionId.lighting,
    )) {
      if (module.subsectionKind == null) return false;
      final kind = BibleSubsectionKindCatalog.byId(module.subsectionKind);
      if (kind == null) return false;
    }
    return true;
  }
}
