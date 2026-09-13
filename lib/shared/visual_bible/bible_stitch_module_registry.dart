import 'bible_section_fields.dart';
import 'bible_section_ids.dart';
import 'bible_subsection_kind_catalog.dart';
import 'bible_subsection_kind_profiles.dart';
import 'bible_widget_size.dart';

/// Metadatos de un módulo Stitch wireable desde el panel Widgets.
class StitchModule {
  final String key;
  final String label;
  final BibleSectionFieldType type;
  final String? hint;
  final int maxLines;
  final bool required;
  final bool legacyOnly;
  /// Kind del catálogo de sub-apartados (nombre + icono reutilizable).
  final BibleSubsectionKindId? subsectionKind;

  const StitchModule({
    required this.key,
    required this.label,
    this.type = BibleSectionFieldType.text,
    this.hint,
    this.maxLines = 3,
    this.required = false,
    this.legacyOnly = false,
    this.subsectionKind,
  });

  BibleSubsectionKind get catalogKind {
    final annotated = BibleSubsectionKindCatalog.byId(subsectionKind);
    if (annotated != null) return annotated;
    return BibleSubsectionKindCatalog.fromFieldType(type);
  }

  BibleWidgetContentFamily get contentFamily => catalogKind.contentFamily;

  BibleSectionField toField({BibleWidgetSize? size}) {
    final kindId = subsectionKind ?? catalogKind.id;
    final resolvedSize = BibleSubsectionKindProfiles.clampSize(
      kindId,
      size ?? BibleSubsectionKindProfiles.defaultSize(kindId),
    );
    return BibleSectionField(
      key: key,
      label: label,
      hint: hint,
      maxLines: maxLines,
      type: type,
      kind: kindId,
      size: resolvedSize,
      binding: key,
    );
  }
}

/// Catálogo de módulos Stitch por pantalla — fuente única para defaults y panel Widgets.
abstract final class BibleStitchModuleRegistry {
  static List<StitchModule> modulesFor(String sectionId) => switch (sectionId) {
        BibleSectionId.concept => const [
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
              subsectionKind: BibleSubsectionKindId.narrativeIntent,
            ),
            StitchModule(
              key: 'colorPalette',
              label: 'Paleta de color',
              subsectionKind: BibleSubsectionKindId.paletteTarget,
            ),
            StitchModule(
              key: 'colorSymbolism',
              label: 'Simbología de color',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'lightPhilosophy',
              label: 'Filosofía de luz',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'keyFrame',
              label: 'Key Frame Analysis',
              subsectionKind: BibleSubsectionKindId.heroWithCaption,
            ),
            StitchModule(
              key: 'shadowTreatment',
              label: 'Tratamiento de sombras',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'actComposition',
              label: 'Composición por actos',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'actNotes',
              label: 'Intención visual por acto',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
              subsectionKind: BibleSubsectionKindId.moodboardRefs,
            ),
            StitchModule(
              key: 'visualConcept',
              label: 'Concepto (legacy)',
              legacyOnly: true,
            ),
          ],
        BibleSectionId.texture => const [
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
              subsectionKind: BibleSubsectionKindId.narrativeIntent,
            ),
            StitchModule(
              key: 'macroPreview',
              label: 'Vista macro grano / ruido',
              subsectionKind: BibleSubsectionKindId.heroWithCaption,
            ),
            StitchModule(
              key: 'filmGrain',
              label: 'Film Grain',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'diffusion',
              label: 'Diffusion Optics',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'sensorNoise',
              label: 'Sensor Noise Floor',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
              subsectionKind: BibleSubsectionKindId.moodboardRefs,
            ),
            StitchModule(
              key: 'textureSettings',
              label: 'Textura (legacy)',
              legacyOnly: true,
            ),
          ],
        BibleSectionId.colorImage => const [
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
              subsectionKind: BibleSubsectionKindId.narrativeIntent,
            ),
            StitchModule(
              key: 'lut',
              label: 'LUT y color science',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'blocks',
              label: 'Paletas por bloque',
              type: BibleSectionFieldType.blocks,
              subsectionKind: BibleSubsectionKindId.paletteTarget,
            ),
            StitchModule(
              key: 'baseTemp',
              label: 'Temperatura base (K)',
              subsectionKind: BibleSubsectionKindId.telemetryPanel,
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
              subsectionKind: BibleSubsectionKindId.moodboardRefs,
            ),
          ],
        BibleSectionId.direction => const [
            StitchModule(
              key: 'header',
              label: 'Cabecera de escena',
              subsectionKind: BibleSubsectionKindId.headerTags,
            ),
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
              subsectionKind: BibleSubsectionKindId.narrativeIntent,
            ),
            StitchModule(
              key: 'toneStrategies',
              label: 'Tono y estrategias',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'acts',
              label: 'Arco por actos',
              subsectionKind: BibleSubsectionKindId.cardDeck,
            ),
            StitchModule(
              key: 'keyFrame',
              label: 'Key Frame',
              subsectionKind: BibleSubsectionKindId.heroWithCaption,
            ),
            StitchModule(
              key: 'transitions',
              label: 'Lenguaje de transiciones',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias de dirección',
              type: BibleSectionFieldType.references,
              subsectionKind: BibleSubsectionKindId.moodboardRefs,
            ),
          ],
        BibleSectionId.camera => const [
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
              subsectionKind: BibleSubsectionKindId.narrativeIntent,
            ),
            StitchModule(
              key: 'cameraBody',
              label: 'Cámara y formato',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'philosophy',
              label: 'Filosofía de cámara',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'movements',
              label: 'Movimientos de cámara',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'specsReference',
              label: 'Fichas técnicas',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
              subsectionKind: BibleSubsectionKindId.moodboardRefs,
            ),
          ],
        BibleSectionId.lighting => const [
            StitchModule(
              key: 'overview',
              label: 'Visión general',
              type: BibleSectionFieldType.narrative,
              maxLines: 6,
              subsectionKind: BibleSubsectionKindId.narrativeIntent,
            ),
            StitchModule(
              key: 'globalMetrics',
              label: 'Sensación de temperatura',
              type: BibleSectionFieldType.blocks,
              subsectionKind: BibleSubsectionKindId.telemetryPanel,
            ),
            StitchModule(
              key: 'lightBehaviors',
              label: 'Comportamiento de la luz',
              type: BibleSectionFieldType.blocks,
              subsectionKind: BibleSubsectionKindId.behaviorMosaic,
            ),
            StitchModule(
              key: 'filmRefs',
              label: 'Referencias fílmicas',
              type: BibleSectionFieldType.blocks,
              subsectionKind: BibleSubsectionKindId.cardDeck,
            ),
            StitchModule(
              key: 'locationLights',
              label: 'Localizaciones (luz)',
              type: BibleSectionFieldType.blocks,
              subsectionKind: BibleSubsectionKindId.cardDeck,
            ),
            StitchModule(
              key: 'lightStyles',
              label: 'Estilos de luz',
              type: BibleSectionFieldType.blocks,
              legacyOnly: true,
              subsectionKind: BibleSubsectionKindId.cardDeck,
            ),
            StitchModule(
              key: 'lightingTagRefs',
              label: 'Referencias por etiquetas',
              type: BibleSectionFieldType.blocks,
              legacyOnly: true,
              subsectionKind: BibleSubsectionKindId.moodboardRefs,
            ),
            StitchModule(
              key: 'diagrams',
              label: 'Diagramas de iluminación',
              type: BibleSectionFieldType.blocks,
              legacyOnly: true,
              subsectionKind: BibleSubsectionKindId.setupList,
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
              legacyOnly: true,
              subsectionKind: BibleSubsectionKindId.moodboardRefs,
            ),
          ],
        BibleSectionId.optics => const [
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
              subsectionKind: BibleSubsectionKindId.narrativeIntent,
            ),
            StitchModule(
              key: 'opticSettings',
              label: 'Filosofía y kit de lentes',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
              subsectionKind: BibleSubsectionKindId.moodboardRefs,
            ),
          ],
        BibleSectionId.exposure => const [
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
              subsectionKind: BibleSubsectionKindId.narrativeIntent,
            ),
            StitchModule(
              key: 'globalExposure',
              label: 'Exposición global',
              subsectionKind: BibleSubsectionKindId.telemetryPanel,
            ),
            StitchModule(
              key: 'blocks',
              label: 'Bloques de exposición',
              type: BibleSectionFieldType.blocks,
              subsectionKind: BibleSubsectionKindId.dynamicBlocks,
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
              subsectionKind: BibleSubsectionKindId.moodboardRefs,
            ),
          ],
        BibleSectionId.format => const [
            StitchModule(
              key: 'header',
              label: 'Cabecera',
              subsectionKind: BibleSubsectionKindId.headerTags,
            ),
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
              subsectionKind: BibleSubsectionKindId.narrativeIntent,
            ),
            StitchModule(
              key: 'formatSettings',
              label: 'Aspect ratio y entrega',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
              subsectionKind: BibleSubsectionKindId.moodboardRefs,
            ),
          ],
        BibleSectionId.workflow => const [
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
              subsectionKind: BibleSubsectionKindId.narrativeIntent,
            ),
            StitchModule(
              key: 'workflowSettings',
              label: 'Pipeline de workflow',
              subsectionKind: BibleSubsectionKindId.textField,
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
              subsectionKind: BibleSubsectionKindId.moodboardRefs,
            ),
          ],
        _ => const [
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
              subsectionKind: BibleSubsectionKindId.narrativeIntent,
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
              subsectionKind: BibleSubsectionKindId.moodboardRefs,
            ),
          ],
      };

  /// Fields por defecto para contentJson (sin legacy-only).
  static List<BibleSectionField> defaultFieldsFor(String sectionId) =>
      modulesFor(sectionId)
          .where((m) => !m.legacyOnly)
          .map((m) => m.toField())
          .toList();

  /// Restaura plantilla estándar para una sección (opcionalmente ajustada por estilo).
  static List<BibleSectionField> packForStyle(
    String styleKey, {
    required String sectionId,
    String sectionLabel = 'Sección',
  }) {
    final base = defaultFieldsFor(sectionId);
    if (base.isNotEmpty) return base;

    return BibleSectionFieldsConfig.packForStyleGeneric(
      styleKey,
      sectionLabel: sectionLabel,
    );
  }

  static bool hasRenderer(String sectionId, String key) {
    final modules = modulesFor(sectionId);
    return modules.any((m) => m.key == key && !m.legacyOnly);
  }

  static StitchModule? module(String sectionId, String key) {
    for (final m in modulesFor(sectionId)) {
      if (m.key == key) return m;
    }
    return null;
  }

  /// Módulos Stitch que aún no están en la lista de fields del usuario.
  static List<StitchModule> missingModules(
    String sectionId,
    List<BibleSectionField> fields,
  ) {
    final present = fields.map((f) => f.key).toSet();
    return modulesFor(sectionId)
        .where((m) => !m.legacyOnly && !present.contains(m.key))
        .toList();
  }

  /// Normaliza fields legacy (monolitos) a slots actuales cuando aplica.
  static List<BibleSectionField> normalizeFields(
    String sectionId,
    List<BibleSectionField> fields,
  ) {
    final keys = fields.map((f) => f.key).toSet();
    final modularKeys = modulesFor(sectionId)
        .where((m) => !m.legacyOnly)
        .map((m) => m.key)
        .toSet();

    if (sectionId == BibleSectionId.concept) {
      final hasModular = keys.any((k) => modularKeys.contains(k) && k != 'narrative');
      if (keys.contains('visualConcept') &&
          (hasModular || !keys.contains('colorPalette'))) {
        return defaultFieldsFor(sectionId);
      }
      if (hasModular && keys.contains('visualConcept')) {
        return fields.where((f) => f.key != 'visualConcept').toList();
      }
    }

    if (sectionId == BibleSectionId.texture) {
      final hasModular = keys.any((k) =>
          k == 'filmGrain' || k == 'diffusion' || k == 'sensorNoise' || k == 'macroPreview');
      if (keys.contains('textureSettings') &&
          (hasModular || !keys.contains('filmGrain'))) {
        return defaultFieldsFor(sectionId);
      }
      if (hasModular && keys.contains('textureSettings')) {
        return fields.where((f) => f.key != 'textureSettings').toList();
      }
    }

    if (sectionId == BibleSectionId.direction) {
      const modularSlotKeys = {
        'header',
        'toneStrategies',
        'acts',
        'keyFrame',
        'transitions',
      };
      final hasModular = keys.any(modularSlotKeys.contains);
      if (keys.contains('narrative') && !hasModular && !keys.contains('header')) {
        return defaultFieldsFor(sectionId);
      }
    }

    if (sectionId == BibleSectionId.lighting) {
      const deckKeys = {
        'overview',
        'globalMetrics',
        'lightBehaviors',
        'lightStyles',
        'lightingTagRefs',
        'filmRefs',
        'locationLights',
      };
      final hasDeck = keys.any(deckKeys.contains);
      if (!hasDeck) {
        return defaultFieldsFor(sectionId);
      }
      if ((keys.contains('lightStyles') || keys.contains('lightingTagRefs')) &&
          !keys.contains('lightBehaviors')) {
        return defaultFieldsFor(sectionId);
      }
      // Evitar doble UI: mosaico + deck legacy de estilos/tags.
      if (keys.contains('lightBehaviors')) {
        fields = [
          for (final f in fields)
            if (f.key != 'lightStyles' && f.key != 'lightingTagRefs') f,
        ];
      }
      const act1Keys = {
        'narrativeStory',
        'colorLanguage',
        'textureLanguage',
        'lightSources',
      };
      const act2Keys = {'locationContext', 'lightBehavior', 'setTelemetry'};
      final hasNewSlots =
          keys.any(act1Keys.contains) || keys.any(act2Keys.contains);
      if (keys.contains('philosophy') &&
          (hasNewSlots || !keys.contains('narrativeStory'))) {
        return defaultFieldsFor(sectionId);
      }
      if (hasNewSlots && keys.contains('philosophy')) {
        fields = fields.where((f) => f.key != 'philosophy').toList();
      }
      return _ensureLightingGlobalMetrics(_dedupeFieldKeys(fields));
    }

    return fields;
  }

  static List<BibleSectionField> _dedupeFieldKeys(
    List<BibleSectionField> fields,
  ) {
    final seen = <String>{};
    return [
      for (final field in fields)
        if (seen.add(field.key)) field,
    ];
  }

  /// Inserta el slot técnico de métricas si el layout tiene overview y aún no lo incluye.
  static List<BibleSectionField> _ensureLightingGlobalMetrics(
    List<BibleSectionField> fields,
  ) {
    if (fields.any((f) => f.key == 'globalMetrics')) return fields;
    final slot = module(BibleSectionId.lighting, 'globalMetrics')?.toField();
    if (slot == null) return fields;
    final overviewIdx = fields.indexWhere((f) => f.key == 'overview');
    if (overviewIdx < 0) return [slot, ...fields];
    return [
      ...fields.sublist(0, overviewIdx + 1),
      slot,
      ...fields.sublist(overviewIdx + 1),
    ];
  }
}
