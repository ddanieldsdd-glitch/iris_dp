import 'dart:convert';

import '../../core/templates/user_template_models.dart';
import 'bible_blueprint.dart';
import 'visual_bible_export_config.dart';
import 'visual_bible_model.dart';

/// Seed de contenido de ejemplo para plantillas built-in.
class BiblePresetSampleSeed {
  final Map<String, dynamic> visualBibleFields;
  final List<Map<String, dynamic>> colorBlocks;
  final List<Map<String, dynamic>> lightingSetups;
  final Map<String, dynamic> sectionValues;
  final Map<String, String> sectionNarratives;

  const BiblePresetSampleSeed({
    this.visualBibleFields = const {},
    this.colorBlocks = const [],
    this.lightingSetups = const [],
    this.sectionValues = const {},
    this.sectionNarratives = const {},
  });

  Map<String, dynamic> toJson() => {
    'visualBibleFields': visualBibleFields,
    'colorBlocks': colorBlocks,
    'lightingSetups': lightingSetups,
    'sectionValues': sectionValues,
    'sectionNarratives': sectionNarratives,
  };

  factory BiblePresetSampleSeed.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BiblePresetSampleSeed();
    return BiblePresetSampleSeed(
      visualBibleFields: Map<String, dynamic>.from(
        json['visualBibleFields'] as Map? ?? {},
      ),
      colorBlocks: (json['colorBlocks'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      lightingSetups: (json['lightingSetups'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      sectionValues: Map<String, dynamic>.from(
        json['sectionValues'] as Map? ?? {},
      ),
      sectionNarratives: (json['sectionNarratives'] as Map? ?? {}).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
    );
  }
}

/// Bundle unificado: layout + blueprint + estilos + export + seed.
class BiblePresetBundle {
  final String id;
  final String name;
  final String description;
  final BibleBlueprintType blueprint;
  final BibleLayoutTemplatePayload? layout;
  final Map<String, BibleSectionStyle> sectionStyles;
  final VisualBibleExportConfig? exportDefaults;
  final BiblePresetSampleSeed? sampleSeed;
  final List<String> includes;

  const BiblePresetBundle({
    required this.id,
    required this.name,
    required this.description,
    required this.blueprint,
    this.layout,
    this.sectionStyles = const {},
    this.exportDefaults,
    this.sampleSeed,
    this.includes = const [],
  });

  /// Solo plantillas de Ficción están operativas por ahora.
  bool get isAvailable => blueprint.isAvailable;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'name': name,
    'description': description,
    'blueprint': blueprint.storageKey,
    if (layout != null) 'layout': layout!.toJson(),
    'sectionStyles': sectionStyles.map((k, v) => MapEntry(k, v.storageKey)),
    if (exportDefaults != null) 'exportDefaults': exportDefaults!.toJson(),
    if (sampleSeed != null) 'sampleSeed': sampleSeed!.toJson(),
    'includes': includes,
  };

  String encode() => jsonEncode(toJson());

  factory BiblePresetBundle.fromJson(Map<String, dynamic> json) {
    final stylesRaw = json['sectionStyles'] as Map? ?? {};
    final styles = <String, BibleSectionStyle>{};
    for (final e in stylesRaw.entries) {
      styles[e.key.toString()] = BibleSectionStyle.values.firstWhere(
        (s) => s.name == e.value.toString(),
        orElse: () => BibleSectionStyle.cinematic,
      );
    }

    VisualBibleExportConfig? export;
    final exportRaw = json['exportDefaults'];
    if (exportRaw is Map) {
      export = VisualBibleExportConfig.fromJson(
        Map<String, dynamic>.from(exportRaw),
      );
    }

    BibleLayoutTemplatePayload? layout;
    final layoutRaw = json['layout'];
    if (layoutRaw is Map) {
      layout = BibleLayoutTemplatePayload.fromJson(
        Map<String, dynamic>.from(layoutRaw),
      );
    }

    return BiblePresetBundle(
      id: json['id'] as String? ?? 'unknown',
      name: json['name'] as String? ?? 'Preset',
      description: json['description'] as String? ?? '',
      blueprint: BibleBlueprintTypeX.fromStorageKey(
        json['blueprint'] as String?,
      ),
      layout: layout,
      sectionStyles: styles,
      exportDefaults: export,
      sampleSeed: BiblePresetSampleSeed.fromJson(
        json['sampleSeed'] is Map
            ? Map<String, dynamic>.from(json['sampleSeed'] as Map)
            : null,
      ),
      includes:
          (json['includes'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  static BiblePresetBundle? tryDecode(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      if (map['version'] == null && map['groups'] != null) {
        // Legacy layout-only payload.
        return null;
      }
      if (map['blueprint'] == null && map['version'] == null) return null;
      return BiblePresetBundle.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Detecta si el JSON de plantilla es un bundle v1 o layout legacy.
  static bool isBundlePayload(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return false;
      return decoded['version'] == 1 || decoded['blueprint'] != null;
    } catch (_) {
      return false;
    }
  }
}

/// Presets built-in. Solo Plantilla 1 (Ficción · Cinematic) está operativa.
abstract final class BibleBuiltinPresets {
  static const plantilla1Id = 'builtin_plantilla_1';
  /// Legacy id — resuelve a [plantilla1].
  static const fictionNoirId = 'builtin_fiction_noir';
  static const commercialCleanId = 'builtin_commercial_clean';
  static const documentaryObsId = 'builtin_documentary_obs';

  static List<BiblePresetBundle> get all => [
    plantilla1,
    commercialClean,
    documentaryObs,
  ];

  static List<BiblePresetBundle> get available =>
      all.where((p) => p.isAvailable).toList();

  static BiblePresetBundle? byId(String id) {
    if (id == fictionNoirId || id == plantilla1Id) return plantilla1;
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static Map<String, BibleSectionStyle> _stylesFor(BibleBlueprintType type) {
    final out = <String, BibleSectionStyle>{};
    for (final id in BibleSectionId.all) {
      out[id] = defaultStyleForSection(id, type);
    }
    return out;
  }

  static VisualBibleExportConfig _exportFor({
    required String id,
    required String name,
    required String mode,
  }) {
    return VisualBibleExportConfig(
      id: 'export_$id',
      name: name,
      audience: VisualBibleExportAudience.general,
      mode: mode,
      sections: VisualBibleExportConfig.defaultSectionsForMode(mode),
      destination: VisualBibleExportDestination.saveFile,
      updatedAt: DateTime.now(),
    );
  }

  static final plantilla1 = BiblePresetBundle(
    id: plantilla1Id,
    name: 'Plantilla 1',
    description:
        'Base de ficción en estilo cinematic. Incluye el deck de Iluminación '
        '(visión general, comportamiento de la luz, refs fílmicas y localizaciones).',
    blueprint: BibleBlueprintType.fiction,
    sectionStyles: _stylesFor(BibleBlueprintType.fiction),
    exportDefaults: _exportFor(
      id: plantilla1Id,
      name: 'Biblia — Plantilla 1',
      mode: VisualBibleExportMode.full,
    ),
    includes: const [
      'Estructura Ficción completa',
      'Estilo cinematic en todas las pantallas',
      'Iluminación: overview + comportamientos + film refs + localizaciones',
      'Contenedores de luz vinculados a tags del moodboard',
    ],
    sampleSeed: const BiblePresetSampleSeed(
      visualBibleFields: {
        'visualConcept':
            'Alto contraste, prácticos fríos contra una base de sombra profunda '
            'para enfatizar aislamiento. Cámara como observador objetivo.',
        'tone': 'Noir contemporáneo / cyberpunk emocional',
        'creativeIntention':
            'Que cada frame sienta la distancia entre personajes y la ciudad.',
        'lightingPhilosophy':
            'Motivar con prácticos. Key dura desde ventana; fill mínimo. '
            'Negros con detalle controlado (no crush total).',
        'lightQuality': 'Hard / motivated',
        'contrastStyle': 'High contrast 4:1',
        'keyFillRatioNight': '4:1',
        'keyFillRatioDay': '2:1',
        'lightSource': '3200K',
        'defaultTStop': 'T2.8',
        'nativeIso': 800,
        'highlightBehavior': 'Proteger highlights de prácticos',
        'shadowBehavior': 'Sombra profunda con detalle en rostros',
        'grainLevel': 'Kodak Vision3 500T',
        'imageTexture': 'Film grain orgánico',
        'diffusionNotes': '1/8 Black Pro-Mist en close-ups',
        'workingLutName': 'LogC4 → Rec.709',
        'creativeLutName': 'Noir Cyan Shadow',
        'aspectRatio': '2.39:1',
        'directionNarrativeIntent':
            'La cámara no juzga: observa. El contraste marca jerarquía emocional.',
        'conceptNarrativeIntent':
            'Referencias: Blade Runner 2049, Heat (nocturnos), Drive.',
        'lightingNarrativeIntent':
            'Pre-riguear techos; prácticos motivan key. Ratio 4:1 en rostros.',
        'exposureNarrativeIntent':
            'ISO 800 base; forzar 1280 solo en INT noche para grano ligero.',
        'colorNarrativeIntent':
            'Cian en sombras, ámbar en prácticos. Magenta prohibido en piel.',
        'textureNarrativeIntent':
            'Grain visible en noche; día más limpio. Halation suave en prácticos.',
      },
      colorBlocks: [
        {
          'blockName': 'INT. APARTAMENTO — NOCHE',
          'dominantColors': ['#0A0E14', '#1A3C40', '#C4A574', '#8B9DC3'],
          'accentColors': ['#E8A838', '#4A90D9'],
          'prohibitedColors': ['#FF00AA'],
          'colorTempKelvin': 3200,
        },
        {
          'blockName': 'EXT. CIUDAD — DÍA',
          'dominantColors': ['#2C3E50', '#7F8C8D', '#ECF0F1', '#3498DB'],
          'accentColors': ['#E74C3C'],
          'colorTempKelvin': 5600,
        },
      ],
      lightingSetups: [
        {
          'setupName': 'INT. Apartamento noche',
          'narrativeNote':
              'Key: M18 Chimera ventana izq. Fill: S60 bounce techo 20%. '
              'Back: Astera tras librero. Practical escritorio DMX 40%.',
          'gelNotes': 'CTO 1/2 en fill',
          'practicalMotivation': 'Lámpara de escritorio',
        },
      ],
      sectionValues: {
        BibleSectionId.lighting: {
          'colorTemp': 3200,
          'contrastRatio': '4:1',
          'visualIntent': 'Alto contraste motivado por prácticos',
          'temperatureNote':
              'Sensación fría en exteriores; dualismo cálido/frío en INT.',
        },
        BibleSectionId.exposure: {
          'baseIso': '800',
          'targetTStop': 'T2.8',
          'shutterAngle': '180°',
          'highlightStrategy': 'Proteger prácticos',
          'shadowStrategy': 'Detalle en rostros, crush selectivo en fondo',
        },
        BibleSectionId.texture: {
          'grainPreset': 'Kodak Vision3 500T',
          'halationRadius': 'suave',
        },
        BibleSectionId.colorImage: {
          'kelvin': 3200,
          'kelvinLabel': 'Temperatura base (INT)',
          'workingLutTags': ['LogC4', 'Rec.709'],
          'creativeLutTags': ['Contraste alto', 'Tint cyan'],
        },
      },
    ),
  );

  /// Alias legacy.
  static BiblePresetBundle get fictionNoir => plantilla1;

  static final commercialClean = BiblePresetBundle(
    id: commercialCleanId,
    name: 'Comercial — producto limpio',
    description:
        'Spot / promo: impacto visual, color de marca, exposición segura en highlights. '
        'Oculta pruebas de cámara y workflow.',
    blueprint: BibleBlueprintType.commercial,
    sectionStyles: _stylesFor(BibleBlueprintType.commercial),
    exportDefaults: _exportFor(
      id: commercialCleanId,
      name: 'Pitch deck — Comercial',
      mode: VisualBibleExportMode.pitch,
    ),
    includes: const [
      'Concepto + color de marca',
      'Exposición protectora de highlights',
      'LUT Rec.709 limpio',
      'Sin camera tests / workflow',
    ],
    sampleSeed: const BiblePresetSampleSeed(
      visualBibleFields: {
        'visualConcept':
            'Producto heroico, fondos limpios, contraste controlado. '
            'La luz vende textura y acabado.',
        'tone': 'Premium / limpio',
        'lightingPhilosophy':
            'Soft key grande, fill generoso, speculars controlados en producto.',
        'lightQuality': 'Soft / beauty',
        'contrastStyle': 'Medium 2:1',
        'keyFillRatioDay': '2:1',
        'lightSource': '5600K',
        'defaultTStop': 'T4',
        'nativeIso': 800,
        'highlightBehavior': 'Nunca clippear speculars del producto',
        'shadowBehavior': 'Sombras abiertas, detalle en packaging',
        'grainLevel': 'Clean / digital',
        'imageTexture': 'Limpio',
        'workingLutName': 'Log → Rec.709',
        'creativeLutName': 'Brand Look v1',
        'aspectRatio': '16:9',
        'conceptNarrativeIntent': 'Hero product + lifestyle inserts.',
        'colorNarrativeIntent': 'Paleta de marca; blancos neutrales.',
      },
      colorBlocks: [
        {
          'blockName': 'Brand / Hero',
          'dominantColors': ['#FFFFFF', '#F5F5F5', '#1A1A1A', '#0066FF'],
          'accentColors': ['#FF3B30'],
          'colorTempKelvin': 5600,
        },
      ],
      sectionValues: {
        BibleSectionId.exposure: {
          'baseIso': '800',
          'targetTStop': 'T4',
          'highlightStrategy': 'Protect product speculars',
          'shadowStrategy': 'Open fill',
        },
        BibleSectionId.colorImage: {
          'kelvin': 5600,
          'workingLutTags': ['Rec.709'],
          'creativeLutTags': ['Brand Look'],
        },
      },
    ),
  );

  static final documentaryObs = BiblePresetBundle(
    id: documentaryObsId,
    name: 'Documental — observación / available light',
    description:
        'Run & gun: luz disponible, bounce y prácticos. Énfasis en localización '
        'y exposición por set. Sin camera tests.',
    blueprint: BibleBlueprintType.documentary,
    sectionStyles: _stylesFor(BibleBlueprintType.documentary),
    exportDefaults: _exportFor(
      id: documentaryObsId,
      name: 'Tech scout — Documental',
      mode: VisualBibleExportMode.techScout,
    ),
    includes: const [
      'Filosofía available light',
      'Exposición adaptable por localización',
      'Color documental (skin-first)',
      'Sin camera tests',
    ],
    sampleSeed: const BiblePresetSampleSeed(
      visualBibleFields: {
        'visualConcept':
            'Observación respetuosa. La luz del lugar manda; intervenimos poco.',
        'tone': 'Observacional',
        'lightingPhilosophy':
            'Available light + bounce + prácticos existentes. Kit mínimo.',
        'lightQuality': 'Natural / soft bounce',
        'contrastStyle': 'Natural 3:1',
        'keyFillRatioDay': '3:1',
        'lightSource': '5600K',
        'defaultTStop': 'T2.8–T4',
        'nativeIso': 800,
        'highlightBehavior': 'Aceptar ventanas hot si motiva',
        'shadowBehavior': 'Dejar que el espacio respire',
        'grainLevel': 'Ligero ISO 1280',
        'imageTexture': 'Orgánico',
        'workingLutName': 'Log → Rec.709',
        'aspectRatio': '16:9',
        'lightingNarrativeIntent':
            'Priorizar movilidad. LED bi-color + bounce plegable.',
        'exposureNarrativeIntent':
            'Medir por cara; ventanas pueden clippear conscientemente.',
      },
      colorBlocks: [
        {
          'blockName': 'Skin / ambiente',
          'dominantColors': ['#C6866A', '#8B7355', '#4A5568', '#E2E8F0'],
          'colorTempKelvin': 4500,
        },
      ],
      lightingSetups: [
        {
          'setupName': 'Interview available',
          'narrativeNote':
              'Key: ventana + diffusion. Fill: bounce blanco. '
              'Practicals dimmeados si molestan.',
          'practicalMotivation': 'Luz existente del espacio',
        },
      ],
      sectionValues: {
        BibleSectionId.lighting: {
          'colorTemp': 5600,
          'contrastRatio': '3:1',
          'visualIntent': 'Available light first',
        },
        BibleSectionId.exposure: {
          'baseIso': '800–1280',
          'targetTStop': 'T2.8',
          'highlightStrategy': 'Aceptar hot windows',
          'shadowStrategy': 'Natural falloff',
        },
      },
    ),
  );
}
