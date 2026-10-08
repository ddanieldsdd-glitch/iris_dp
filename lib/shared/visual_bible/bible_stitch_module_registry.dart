import 'bible_section_fields.dart';
import 'bible_section_ids.dart';
import 'bible_subsection_kind_catalog.dart';

/// Metadatos de un módulo Stitch wireable desde el panel Widgets.
class StitchModule {
  final String key;
  final String label;
  final BibleSectionFieldType type;
  final String? hint;
  final int maxLines;
  final bool required;
  final bool legacyOnly;

  /// Tiene vista propia y se puede añadir, pero no viene por defecto.
  final bool optional;

  /// Widget del catálogo al que equivale este punto (`BibleWidgetCatalog`),
  /// para nombrarlo por lo que es: actos, pilares, paleta maestra…
  final String? widgetId;

  /// Kind del catálogo de sub-apartados (nombre + icono reutilizable).
  final BibleSubsectionKindId? subsectionKind;

  /// Ancho con el que nace el punto.
  final BiblePointWidth width;

  const StitchModule({
    required this.key,
    required this.label,
    this.type = BibleSectionFieldType.text,
    this.hint,
    this.maxLines = 3,
    this.required = false,
    this.legacyOnly = false,
    this.optional = false,
    this.widgetId,
    this.subsectionKind,
    this.width = BiblePointWidth.full,
  });

  BibleSubsectionKind get catalogKind {
    final annotated = BibleSubsectionKindCatalog.byId(subsectionKind);
    if (annotated != null) return annotated;
    return BibleSubsectionKindCatalog.fromFieldType(type);
  }

  BibleWidgetContentFamily get contentFamily => catalogKind.contentFamily;

  BibleSectionField toField() => BibleSectionField(
        key: key,
        label: label,
        hint: hint,
        maxLines: maxLines,
        type: type,
        widget: type == BibleSectionFieldType.text ? null : widgetId,
        width: width,
      );
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
            ),
            StitchModule(
              key: 'lightPhilosophy',
              label: 'Filosofía de luz',
              width: BiblePointWidth.half,
            ),
            StitchModule(
              key: 'shadowTreatment',
              label: 'Tratamiento de sombras',
              width: BiblePointWidth.half,
            ),
            StitchModule(
              key: 'colorPalette',
              label: 'Paleta maestra',
              widgetId: 'palette_master',
              width: BiblePointWidth.half,
            ),
            StitchModule(
              key: 'colorSymbolism',
              label: 'Simbología de color',
              widgetId: 'palette_symbolism',
              width: BiblePointWidth.half,
            ),
            StitchModule(key: 'composition', label: 'Composición'),
            StitchModule(
              key: 'actNotes',
              label: 'Intención visual por acto',
              widgetId: 'acts',
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
            ),
            StitchModule(key: 'keyFrame', label: 'Key Frame', optional: true),
            StitchModule(
              key: 'actComposition',
              label: 'Composición por actos',
              optional: true,
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
            ),
            StitchModule(key: 'macroPreview', label: 'Vista macro grano / ruido'),
            StitchModule(key: 'filmGrain', label: 'Film Grain'),
            StitchModule(key: 'diffusion', label: 'Diffusion Optics'),
            StitchModule(key: 'sensorNoise', label: 'Sensor Noise Floor'),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
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
            ),
            StitchModule(
              key: 'lut',
              label: 'LUT y ciencia de color',
              width: BiblePointWidth.twoThirds,
            ),
            StitchModule(
              key: 'baseTemp',
              label: 'Temperatura base',
              width: BiblePointWidth.third,
            ),
            StitchModule(
              key: 'blocks',
              label: 'Paletas por bloque',
              type: BibleSectionFieldType.blocks,
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
            ),
          ],
        BibleSectionId.direction => const [
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
            ),
            StitchModule(
              key: 'tone',
              label: 'Tono y atmósfera',
              type: BibleSectionFieldType.cards,
              widgetId: 'cards',
            ),
            StitchModule(
              key: 'strategies',
              label: 'Estrategia visual',
              type: BibleSectionFieldType.cards,
              widgetId: 'cards_pillars',
            ),
            StitchModule(
              key: 'acts',
              label: 'Intención por acto',
              type: BibleSectionFieldType.acts,
              widgetId: 'acts',
            ),
            StitchModule(
              key: 'transitions',
              label: 'Lenguaje de transiciones',
              type: BibleSectionFieldType.cards,
              widgetId: 'cards',
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias de dirección',
              type: BibleSectionFieldType.references,
            ),
            // Puntos que ya no existen: la cabecera de escena y el Key Frame
            // (ahora es una referencia destacada).
            StitchModule(
              key: 'header',
              label: 'Cabecera de escena',
              legacyOnly: true,
            ),
            StitchModule(key: 'keyFrame', label: 'Key Frame', legacyOnly: true),
            StitchModule(
              key: 'toneStrategies',
              label: 'Tono y estrategias (legacy)',
              legacyOnly: true,
            ),
          ],
        BibleSectionId.camera => const [
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
            ),
            StitchModule(
              key: 'equipment',
              label: 'Cámaras',
              width: BiblePointWidth.twoThirds,
            ),
            StitchModule(
              key: 'cameraBody',
              label: 'Ficha del cuerpo',
              width: BiblePointWidth.third,
            ),
            StitchModule(
              key: 'recording',
              label: 'Formato y cadencia',
              width: BiblePointWidth.half,
            ),
            StitchModule(
              key: 'colorPipeline',
              label: 'Color en cámara',
              width: BiblePointWidth.half,
            ),
            StitchModule(key: 'recordingMatrix', label: 'Matriz de grabación'),
            StitchModule(key: 'philosophy', label: 'Filosofía de cámara'),
            StitchModule(key: 'movements', label: 'Movimientos de cámara'),
            StitchModule(
              key: 'accessories',
              label: 'Filtros, soportes y accesorios',
            ),
            StitchModule(key: 'dataManagement', label: 'Gestión de datos'),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
            ),
            StitchModule(
              key: 'specsReference',
              label: 'Referencias técnicas',
              optional: true,
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
            ),
            StitchModule(
              key: 'lensKit',
              label: 'Juegos de lentes',
              width: BiblePointWidth.twoThirds,
            ),
            StitchModule(
              key: 'filtration',
              label: 'Filtros',
              width: BiblePointWidth.third,
            ),
            StitchModule(key: 'opticSettings', label: 'Filosofía de lentes'),
            StitchModule(key: 'character', label: 'Carácter óptico'),
            StitchModule(
              key: 'focalTable',
              label: 'Tabla de focales',
              width: BiblePointWidth.twoThirds,
            ),
            StitchModule(
              key: 'maintenance',
              label: 'Revisión del juego',
              width: BiblePointWidth.third,
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
            ),
          ],
        BibleSectionId.exposure => const [
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
            ),
            StitchModule(
              key: 'globalExposure',
              label: 'Exposición de trabajo',
              width: BiblePointWidth.twoThirds,
            ),
            StitchModule(
              key: 'signalLevels',
              label: 'Niveles de señal',
              width: BiblePointWidth.third,
            ),
            StitchModule(key: 'exposureChain', label: 'Cadena de exposición'),
            StitchModule(key: 'blocks', label: 'Bloques de exposición'),
            StitchModule(
              key: 'byLocation',
              label: 'Exposición por localización',
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
            ),
          ],
        BibleSectionId.format => const [
            StitchModule(key: 'header', label: 'Cabecera'),
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
            ),
            StitchModule(key: 'formatSettings', label: 'Aspect ratio y entrega'),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
            ),
          ],
        BibleSectionId.workflow => const [
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
            ),
            StitchModule(key: 'workflowSettings', label: 'Pipeline de workflow'),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
            ),
          ],
        _ => const [
            StitchModule(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
            ),
            StitchModule(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
            ),
          ],
      };

  /// Fields por defecto para contentJson (sin legacy-only).
  static List<BibleSectionField> defaultFieldsFor(String sectionId) =>
      modulesFor(sectionId)
          .where((m) => !m.legacyOnly && !m.optional)
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
    List<BibleSectionField> fields, {
    int layoutVersion = 1,
  }) {
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

    // Concepto ganó «Composición» en la versión 2: se añade una sola vez, tras
    // las sombras, en biblias guardadas antes. Si el usuario la quita después,
    // no vuelve.
    if (layoutVersion < 2 &&
        sectionId == BibleSectionId.concept &&
        keys.contains('shadowTreatment') &&
        !keys.contains('composition')) {
      return [
        for (final field in fields) ...[
          field,
          if (field.key == 'shadowTreatment')
            module(sectionId, 'composition')!.toField(),
        ],
      ];
    }

    // Cámara se partió en la versión 4: lo que iba dentro de «Cámara y
    // formato» son ahora puntos propios. Se añaden una sola vez a las
    // biblias guardadas antes, para que nada de lo escrito quede sin
    // pantalla. Si el usuario quita alguno después, no vuelve.
    if (layoutVersion < 4 &&
        sectionId == BibleSectionId.camera &&
        keys.contains('cameraBody')) {
      BibleSectionField? add(String key) =>
          keys.contains(key) ? null : module(sectionId, key)?.toField();
      final tail = [
        ?add('accessories'),
        ?add('dataManagement'),
      ];
      final out = <BibleSectionField>[];
      for (final field in fields) {
        if (field.key == 'cameraBody') {
          out.addAll([
            ?add('equipment'),
            field.copyWith(label: 'Ficha del cuerpo'),
            ?add('recording'),
            ?add('colorPipeline'),
            ?add('recordingMatrix'),
          ]);
        } else if (field.key == 'references') {
          out
            ..addAll(tail)
            ..add(field);
          tail.clear();
        } else {
          out.add(field);
        }
      }
      return [...out, ...tail];
    }

    // Óptica se partió en la versión 5: lo que iba dentro de «Filosofía y
    // kit de lentes» son ahora puntos propios, añadidos una sola vez.
    if (layoutVersion < 5 &&
        sectionId == BibleSectionId.optics &&
        keys.contains('opticSettings')) {
      BibleSectionField? add(String key) =>
          keys.contains(key) ? null : module(sectionId, key)?.toField();
      return [
        for (final field in fields)
          if (field.key == 'opticSettings') ...[
            ?add('lensKit'),
            ?add('filtration'),
            field.copyWith(label: 'Filosofía de lentes'),
            ?add('character'),
            ?add('focalTable'),
            ?add('maintenance'),
          ] else
            field,
      ];
    }

    // Exposición se partió en la versión 6, igual que Cámara y Óptica.
    if (layoutVersion < 6 &&
        sectionId == BibleSectionId.exposure &&
        keys.contains('globalExposure')) {
      BibleSectionField? add(String key) =>
          keys.contains(key) ? null : module(sectionId, key)?.toField();
      return [
        for (final field in fields)
          if (field.key == 'globalExposure') ...[
            field.copyWith(label: 'Exposición de trabajo'),
            ?add('signalLevels'),
            ?add('exposureChain'),
          ] else if (field.key == 'blocks') ...[
            // Antes era un tipo propio; ahora es una tabla de la pantalla.
            module(sectionId, 'blocks')!.toField().copyWith(label: field.label),
            ?add('byLocation'),
          ] else
            field,
      ];
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
        'tone',
        'strategies',
        'acts',
        'keyFrame',
        'transitions',
      };
      final hasModular = keys.any(modularSlotKeys.contains);
      if (keys.contains('narrative') && !hasModular) {
        return defaultFieldsFor(sectionId);
      }
      final next = <BibleSectionField>[];
      for (final field in fields) {
        final m = module(sectionId, field.key);
        if (field.key == 'toneStrategies') {
          // «Tono y estrategias» era un solo punto; ahora son dos.
          if (!keys.contains('tone')) {
            next.add(module(sectionId, 'tone')!.toField());
          }
          if (!keys.contains('strategies')) {
            next.add(module(sectionId, 'strategies')!.toField());
          }
        } else if (m == null) {
          next.add(field);
        } else if (!m.legacyOnly) {
          // Los puntos de la pantalla se pintan con su widget del catálogo;
          // los que ya no existen (cabecera, Key Frame) se quitan.
          next.add(
            BibleSectionField(
              key: field.key,
              label: field.label,
              hint: field.hint,
              maxLines: field.maxLines,
              type: m.type,
              widget: m.widgetId,
            ),
          );
        }
      }
      // En la versión 3 las transiciones pasan delante de las referencias.
      if (layoutVersion < 3) {
        final refs = next.indexWhere((f) => f.key == 'references');
        final transitions = next.indexWhere((f) => f.key == 'transitions');
        if (refs >= 0 && transitions > refs) {
          next.insert(refs, next.removeAt(transitions));
        }
      }
      return next;
    }

    if (sectionId == BibleSectionId.lighting) {
      const deckKeys = {
        'overview',
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
        return fields.where((f) => f.key != 'philosophy').toList();
      }
    }

    return fields;
  }
}
