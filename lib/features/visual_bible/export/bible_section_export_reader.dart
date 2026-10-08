import '../../../shared/visual_bible/bible_table.dart';
import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../../shared/visual_bible/bible_lighting_data.dart';
import '../../../shared/visual_bible/bible_acts.dart';
import '../../../shared/visual_bible/bible_cards.dart';
import '../../../shared/visual_bible/direction_points.dart';
import '../../../shared/visual_bible/bible_palette.dart';
import '../../../shared/visual_bible/bible_point_extras.dart';
import '../../../shared/visual_bible/bible_reference.dart';
import '../../../shared/visual_bible/bible_section_fields.dart';
import '../../../shared/visual_bible/bible_section_ids.dart';
import '../../../shared/visual_bible/bible_stitch_module_registry.dart';

/// Sección de la biblia en el orden en que debe salir en el PDF.
class BibleExportSectionRef {
  final String id;
  final String label;

  /// Pantalla creada por el usuario (plantilla `freeform`).
  final bool isCustom;

  const BibleExportSectionRef({
    required this.id,
    required this.label,
    this.isCustom = false,
  });
}

/// Punto añadido por el usuario, con su valor crudo de `values[key]`.
typedef BibleUserPoint = ({BibleSectionField field, String value});

/// Entrada aplanada para el PDF.
class BibleSectionExportEntry {
  final String label;
  final String value;

  const BibleSectionExportEntry({required this.label, required this.value});
}

/// Lee `contentJson` de secciones VB y lo convierte en filas exportables.
///
/// Cobertura contentJson (blobs `*Data` en [BibleSectionDefinitions.contentJson]):
/// camera, location, lighting, exposure, direction, color_image, concept,
/// texture, format, workflow.
///
/// Rutas de export distintas (no usan este reader):
/// - moodboard → tabla [MoodboardImage]
/// - camera_tests → tabla [CameraTest]
/// - optics → [VisualBibleData.opticsConfigJson] (ver [rowsFromOpticsConfigJson])
/// - settings → no exportable
abstract final class BibleSectionExportReader {
  BibleSectionExportReader._();

  static const _blobKeys = {
    BibleSectionId.camera: 'cameraData',
    BibleSectionId.location: 'locationData',
    BibleSectionId.lighting: 'lightingData',
    BibleSectionId.exposure: 'exposureData',
    BibleSectionId.direction: 'directionData',
    BibleSectionId.colorImage: 'colorData',
    BibleSectionId.concept: 'conceptData',
    BibleSectionId.texture: 'textureData',
    BibleSectionId.format: 'formatData',
    BibleSectionId.workflow: 'workflowData',
  };

  static const _labels = {
    BibleSectionId.camera: {
      'editorialCaption': 'Caption editorial',
      'isoNote': 'Nota ISO',
      'colorSpace': 'Espacio de color',
      'shutterAngle': 'Obturador',
      'slowMoMax': 'Slow motion máx.',
      'pipeline': 'Pipeline',
      'gamut': 'Gamut',
      'bitDepth': 'Bit depth',
      'noiseFloor': 'Noise floor',
      'dualIso': 'Dual ISO',
      'showLut': 'Show LUT',
      'idt': 'IDT',
      'setPreview': 'Set preview',
      'ditFlow': 'Flujo DIT',
      'ditFlowNote': 'Nota flujo DIT',
      'transferProto': 'Protocolo de transferencia',
      'transferNote': 'Nota transferencia',
      'sensorLabel': 'Sensor',
      'mountLabel': 'Montura',
      'dynamicRange': 'Rango dinámico',
      'captureResolution': 'Resolución de captura',
    },
    BibleSectionId.location: {
      'coords': 'Coordenadas',
      'elevation': 'Elevación',
      'intExt': 'INT/EXT',
      'locLabel': 'Label LOC',
      'contrastRatio': 'Contrast ratio',
      'lightQuality': 'Calidad de luz',
      'bouncePotential': 'Bounce',
      'siteLightNote': 'Luz del sitio',
      'azimuth': 'Azimut solar',
      'weather': 'Clima',
      'humidity': 'Humedad',
      'skyQuality': 'Cielo',
      'wind': 'Viento',
      'spatialPsychology': 'Psicología espacial',
      'strategy': 'Estrategia',
      'narrativeGeography': 'Geografía narrativa',
      'textureMateriality': 'Textura',
      'soundscape': 'Paisaje sonoro',
      'extraGear': 'Equipo extra',
      'criticalPoints': 'Puntos críticos',
      'practicalsDetail': 'Practical light sources',
      'mapsUrl': 'Google Maps',
      'earthUrl': 'Google Earth',
      'palette': 'Paleta de color',
      'sunrise': 'Amanecer',
      'sunriseAz': 'Azimut amanecer',
      'sunset': 'Atardecer',
      'sunsetAz': 'Azimut atardecer',
      'daylightWindow': 'Ventana de luz diurna',
      'blueHour': 'Hora azul',
      'goldenHour': 'Golden hour',
      'maxElevation': 'Elevación máxima solar',
      'shadowRatio': 'Ratio de sombra',
    },
    BibleSectionId.lighting: {
      'heroBadge': 'Badge de escena',
      'heroTitle': 'Título hero',
      'heroSubtitle': 'Subtítulo hero',
      'narrativeStory': 'Qué nos cuenta la luz',
      'visualIntent': 'Intención visual',
      'colorLanguage': 'Color y luz',
      'gafferDirectives': 'Directivas de gaffer',
      'sourceKelvin': 'Kelvin origen',
      'targetKelvin': 'Kelvin destino',
      'colorTemp': 'Temperatura de color',
      'lightBehavior': 'Comportamiento de luz',
      'dayNightIntent': 'Intención día/noche',
      'tintValue': 'Tint',
      'tint': 'Tint (etiqueta)',
      'contrastNum': 'Contraste',
      'blackLevelIre': 'Black level (IRE)',
      'crushedBlacks': 'Crushed blacks',
      'activeFixtures': 'Fixtures activos',
      'fixtureTypes': 'Tipos de fixture',
    },
    BibleSectionId.exposure: {
      'sceneBadge': 'Badge de escena',
      'baseIso': 'ISO base',
      'targetTStop': 'T-stop objetivo',
      'shutterAngle': 'Ángulo obturador',
      'ndFilter': 'ND filter',
      'exposureIndex': 'Exposure index',
      'sourceIntensity': 'Source intensity',
      'sensorSensitivity': 'Sensor sensitivity',
      'opticsLimit': 'Optics limit',
      'lumaCrush': 'Luma crush',
      'lumaPeak': 'Luma peak',
      'narrativeIntent': 'Intención narrativa',
      'iso': 'ISO',
      'tStop': 'T-stop',
      'nd': 'ND',
      'shutter': 'Shutter',
      'approach': 'Approach',
      'highlightStrategy': 'Highlight strategy',
      'shadowStrategy': 'Shadow strategy',
      'keyFill': 'Key/fill ratio',
    },
    BibleSectionId.direction: {
      'sceneTag': 'Escena',
      'emotionTags': 'Tags emocionales',
      'tonePoints': 'Tono y estrategias',
      'extraStrategies': 'Estrategias extra',
      'act1Phase': 'Fase acto 1',
      'act2Phase': 'Fase acto 2',
      'act3Phase': 'Fase acto 3',
      'act1Title': 'Título acto 1',
      'act2Title': 'Título acto 2',
      'act3Title': 'Título acto 3',
      'act1Desc': 'Descripción acto 1',
      'act2Desc': 'Descripción acto 2',
      'act3Desc': 'Descripción acto 3',
      'keyFrameIntent': 'Intención key frame',
      'transitionLanguage': 'Lenguaje de transiciones',
    },
    BibleSectionId.colorImage: {
      'workingLutTags': 'Tags Working LUT',
      'creativeLutTags': 'Tags Creative LUT',
      'kelvin': 'Temperatura base (K)',
      'kelvinLabel': 'Temperatura base',
    },
    BibleSectionId.concept: {
      'shadowTreatment': 'Tratamiento de sombras',
      'actComposition': 'Composición por actos',
      'act1Intent': 'Intención acto 1',
      'act2Intent': 'Intención acto 2',
      'act3Intent': 'Intención acto 3',
    },
    BibleSectionId.texture: {
      'grainEnabled': 'Film grain',
      'grainSize': 'Tamaño grano',
      'grainIntensity': 'Intensidad grano',
      'grainColorVariation': 'Variación color grano',
      'grainPreset': 'Preset grano',
      'diffusionEnabled': 'Diffusion',
      'diffusionFilter': 'Filtro difusión',
      'diffusionDensity': 'Densidad difusión',
      'halationRadius': 'Halation radius',
      'highlightBehavior': 'Highlight behavior',
      'shadowBehavior': 'Shadow behavior',
      'digitalNoiseLabel': 'Digital noise',
      'noiseFloorDesc': 'Noise floor',
      'cameraLabel': 'Cámara',
      'shadowChromaNoise': 'Shadow chroma noise',
      'fixedPatternNoise': 'Fixed pattern noise',
      'pushPullProcessing': 'Push/pull processing',
      'savedPresetName': 'Preset guardado',
    },
    BibleSectionId.format: {
      'sensorMode': 'Modo sensor',
      'sensorModeName': 'Modo sensor (catálogo)',
      'sensorDetail': 'Detalle sensor',
      'squeezeFactor': 'Factor squeeze',
      'squeezeDetail': 'Detalle squeeze',
      'activeRatio': 'Aspect ratio activo',
      'ratioName': 'Nombre ratio',
      'cameraBody': 'Cuerpo cámara',
      'lensMount': 'Montura lente',
      'sensorDims': 'Dimensiones sensor',
      'resolution': 'Resolución',
      'imageCircle': 'Image circle',
      'cropFactor': 'Crop factor',
      'overlayCam': 'Overlay cámara',
      'intentNarrative': 'Narrativa (Director\'s Intent)',
      'intentComposition': 'Composición',
      'intentReinforce': 'Refuerzo de imagen',
    },
    BibleSectionId.workflow: {
      'ditName': 'Nombre DIT',
      'wranglerName': 'Nombre wrangler',
      'technicalNote': 'Nota técnica',
    },
  };

  static Future<Map<String, String?>> loadSectionContentJson(
    AppDatabase db,
    int bibleId,
  ) async {
    final rows = await (db.select(db.bibleSectionDefinitions)
          ..where((d) => d.bibleId.equals(bibleId)))
        .get();
    return {for (final row in rows) row.id: row.contentJson};
  }

  static Map<String, dynamic> parseCustomBlob(
    String? contentJson,
    String sectionId,
  ) {
    if (contentJson == null || contentJson.isEmpty) return {};
    try {
      final decoded = jsonDecode(contentJson);
      if (decoded is! Map<String, dynamic>) return {};
      final valuesRaw = decoded['values'] ?? decoded['_values'];
      if (valuesRaw is! Map) return {};

      final values = Map<String, dynamic>.from(valuesRaw);
      final blobKey = _blobKeys[sectionId];
      if (blobKey != null && values[blobKey] is String) {
        final raw = values[blobKey] as String;
        if (sectionId == BibleSectionId.lighting) {
          return BibleLightingData.decode(raw);
        }
        try {
          final parsed = jsonDecode(raw);
          if (parsed is Map<String, dynamic>) return parsed;
        } catch (_) {}
      }

      // Fallback: algunos blobs antiguos pueden estar en la raíz de values.
      if (blobKey != null && values.containsKey(blobKey)) {
        final direct = values[blobKey];
        if (direct is Map<String, dynamic>) return direct;
      }
      return values;
    } catch (_) {
      return {};
    }
  }

  /// Puntos que el usuario añadió a una sección estándar, en su orden y
  /// solo los que tienen contenido.
  static List<BibleUserPoint> userPoints(String? contentJson, String sectionId) {
    if (contentJson == null || contentJson.isEmpty) return const [];
    final values = BibleSectionFieldsConfig.parseValues(contentJson);
    return [
      for (final field in BibleSectionFieldsConfig.parse(contentJson, sectionId))
        if (_isUserPoint(sectionId, field) &&
            (values[field.key]?.trim().isNotEmpty ?? false))
          (field: field, value: values[field.key]!),
    ];
  }

  /// Ids de las imágenes del moodboard que usan los puntos del usuario de
  /// una pantalla (actos, paletas con imágenes y tiras de imágenes).
  static Set<int> userPointImageIds(String? contentJson, String sectionId) => {
    for (final point in userPoints(contentJson, sectionId))
      ...switch (point.field.type) {
        BibleSectionFieldType.acts => BibleActsValue.decode(
          point.value,
        ).imageIds,
        BibleSectionFieldType.cards => [
          for (final card in BibleCard.listFrom(point.value)) ...card.imageIds,
        ],
        BibleSectionFieldType.palette => BiblePaletteValue.decode(
          point.value,
        ).imageIds,
        BibleSectionFieldType.gallery => [
          for (final id in BibleSectionPointValue.decodeList(point.value))
            if (int.tryParse(id) != null) int.parse(id),
        ],
        _ => const <int>[],
      },
    // Complementos (menú «⋯») de cualquier punto.
    ...BiblePointExtras.allImageIds(
      BibleSectionFieldsConfig.parseValues(contentJson),
    ),
    // Actos y tarjetas de Dirección son puntos de la pantalla, con sus
    // imágenes.
    if (sectionId == BibleSectionId.direction) ...[
      ...DirectionPoints.actsValue(
        BibleSectionFieldsConfig.parseValues(contentJson),
        parseCustomBlob(contentJson, sectionId),
      ).imageIds,
      for (final key in const [
        DirectionPoints.tone,
        DirectionPoints.strategies,
        DirectionPoints.transitions,
      ])
        for (final card in BibleCard.listFrom(
          BibleSectionFieldsConfig.parseValues(contentJson)[key],
        ))
          ...card.imageIds,
    ],
  };

  static bool _isUserPoint(String sectionId, BibleSectionField field) =>
      BibleStitchModuleRegistry.module(sectionId, field.key) == null &&
      (field.type == BibleSectionFieldType.text ||
          field.type == BibleSectionFieldType.list ||
          field.type == BibleSectionFieldType.specs ||
          field.type == BibleSectionFieldType.palette ||
          field.type == BibleSectionFieldType.referenceDeck ||
          field.type == BibleSectionFieldType.gallery ||
          field.type == BibleSectionFieldType.cards ||
          field.type == BibleSectionFieldType.acts ||
          field.type == BibleSectionFieldType.tags ||
          field.type == BibleSectionFieldType.table ||
          field.type == BibleSectionFieldType.meters);

  /// Valor de un punto del usuario como texto plano, para listados de filas.
  static String userPointText(BibleUserPoint point) => switch (point.field.type) {
        BibleSectionFieldType.list => BibleSectionPointValue.decodeList(
            point.value,
          ).where((e) => e.trim().isNotEmpty).map((e) => '• $e').join('\n'),
        BibleSectionFieldType.specs => BibleSectionPointValue.decodeSpecs(
            point.value,
          ).map((r) => '${r.$1}: ${r.$2}').join('\n'),
        BibleSectionFieldType.palette => _paletteText(point.value),
        BibleSectionFieldType.referenceDeck => _referenceItems(point.value)
            .map((r) => [r.title, r.work].where((e) => e.isNotEmpty).join(' — '))
            .join('\n'),
        BibleSectionFieldType.gallery => '',
        BibleSectionFieldType.cards || BibleSectionFieldType.acts =>
          (point.field.type == BibleSectionFieldType.acts
                  ? _actsForText(point.value)
                  : BibleCard.listFrom(point.value))
              .where((c) => !c.isEmpty)
              .map(
                (c) => [c.kicker, c.title, c.body]
                    .where((e) => e.trim().isNotEmpty)
                    .join(' — '),
              )
              .join('\n'),
        BibleSectionFieldType.tags => BibleSectionPointValue.decodeList(
            point.value,
          ).join(' · '),
        BibleSectionFieldType.table => [
            for (final row in BibleTableValue.decode(point.value).filledRows)
              row.where((c) => c.trim().isNotEmpty).join(' · '),
          ].join('\n'),
        BibleSectionFieldType.meters => [
            for (final m in BibleMeter.listFrom(point.value))
              if (!m.isEmpty) '${m.label}: ${m.value}',
          ].join('\n'),
        _ => point.value.trim(),
      };

  /// Actos de un punto para un listado de texto: los propios, o lo que la
  /// pantalla dice de los del proyecto.
  static Iterable<BibleCard> _actsForText(String raw) {
    final value = BibleActsValue.decode(raw);
    return value.shared ? value.layers.values : value.own;
  }

  static String _paletteText(String raw) {
    final value = BiblePaletteValue.decode(raw);
    return [
      if (value.shows(BiblePalettePart.palette))
        for (final c in value.colors)
          [
            c.hex,
            if (c.name.isNotEmpty) c.name,
            if (c.note.isNotEmpty) '— ${c.note}',
          ].join(' '),
      if (value.shows(BiblePalettePart.text) && value.text.trim().isNotEmpty)
        value.text.trim(),
    ].join('\n');
  }

  /// Fichas de un punto de referencias (`{preset, items}`).
  static List<BibleReference> referenceItems(String? raw) =>
      _referenceItems(raw);

  static List<BibleReference> _referenceItems(String? raw) {
    try {
      final decoded = jsonDecode(raw ?? '');
      if (decoded is Map) return BibleReference.listFrom(decoded['items']);
    } catch (_) {}
    return const [];
  }

  /// Rótulos de «por qué» y «para qué» según el preajuste del punto.
  static (String, String) referenceLabels(String? raw) {
    var preset = 'visual';
    try {
      final decoded = jsonDecode(raw ?? '');
      if (decoded is Map) preset = decoded['preset']?.toString() ?? preset;
    } catch (_) {}
    return switch (preset) {
      'narrative' => ('Por qué esta referencia', 'Para qué en la película'),
      'technical' => ('Cómo se hizo', 'Qué necesitamos'),
      _ => ('Por qué nos gusta', 'Qué llevamos a la película'),
    };
  }

  /// `contentJson` sin los valores de los puntos del usuario, para los
  /// lectores de blob que caen a `values` cuando no hay blob propio.
  static String? withoutUserPoints(String? contentJson, String sectionId) {
    if (contentJson == null || contentJson.isEmpty) return contentJson;
    final fields = BibleSectionFieldsConfig.parse(contentJson, sectionId);
    final userKeys = {
      for (final field in fields)
        if (_isUserPoint(sectionId, field)) field.key,
    };
    if (userKeys.isEmpty) return contentJson;
    final values = BibleSectionFieldsConfig.parseValues(contentJson)
      ..removeWhere((key, _) => userKeys.contains(key));
    return BibleSectionFieldsConfig.encode(fields, values: values);
  }

  /// Filas del blob de la sección, sin los valores de los puntos del usuario
  /// (que se pintan aparte, con su tipo).
  static List<BibleSectionExportEntry> blobRows(
    String? contentJson,
    String sectionId,
  ) {
    final custom = Map<String, dynamic>.from(
      parseCustomBlob(contentJson, sectionId),
    );
    if (custom.isEmpty) return const [];
    final userKeys = {
      for (final field in BibleSectionFieldsConfig.parse(contentJson, sectionId))
        if (_isUserPoint(sectionId, field)) field.key,
    };
    custom.removeWhere(
      (key, _) =>
          userKeys.contains(key) ||
          key.endsWith('__images') ||
          key.endsWith('__extra') ||
          key.startsWith('__'),
    );
    return rowsForSection(sectionId, custom);
  }

  static bool hasExportableContent(
    String sectionId,
    Map<String, dynamic> custom,
  ) =>
      rowsForSection(sectionId, custom).isNotEmpty;

  static List<BibleSectionExportEntry> rowsForSection(
    String sectionId,
    Map<String, dynamic> custom,
  ) {
    if (custom.isEmpty) return const [];
    final rows = <BibleSectionExportEntry>[];
    _flatten(sectionId, custom, '', rows);
    return rows;
  }

  static void _flatten(
    String sectionId,
    Map<String, dynamic> data,
    String prefix,
    List<BibleSectionExportEntry> out,
  ) {
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value == null || key == 'selectedPlanId') continue;

      if (key == 'byPlan' || key == 'byLocation') {
        if (value is Map) {
          for (final nested in value.entries) {
            final nestedMap = nested.value;
            if (nestedMap is Map<String, dynamic>) {
              _flatten(
                sectionId,
                nestedMap,
                prefix.isEmpty ? 'Set ${nested.key}' : '$prefix · Set ${nested.key}',
                out,
              );
            } else if (nestedMap is Map) {
              _flatten(
                sectionId,
                Map<String, dynamic>.from(nestedMap),
                prefix.isEmpty ? 'Set ${nested.key}' : '$prefix · Set ${nested.key}',
                out,
              );
            }
          }
        }
        continue;
      }

      if (value is Map) {
        _flatten(
          sectionId,
          Map<String, dynamic>.from(value),
          _composeLabel(prefix, _labelFor(sectionId, key, key)),
          out,
        );
        continue;
      }

      if (value is List) {
        final text = _formatList(value);
        if (text.isEmpty) continue;
        out.add(
          BibleSectionExportEntry(
            label: _composeLabel(prefix, _labelFor(sectionId, key, key)),
            value: text,
          ),
        );
        continue;
      }

      if (value is bool) {
        out.add(
          BibleSectionExportEntry(
            label: _composeLabel(prefix, _labelFor(sectionId, key, key)),
            value: value ? 'Sí' : 'No',
          ),
        );
        continue;
      }

      final text = value.toString().trim();
      if (text.isEmpty) continue;
      out.add(
        BibleSectionExportEntry(
          label: _composeLabel(prefix, _labelFor(sectionId, key, key)),
          value: text,
        ),
      );
    }
  }

  static String _composeLabel(String prefix, String label) =>
      prefix.isEmpty ? label : '$prefix · $label';

  static String _labelFor(String sectionId, String key, String fallback) {
    final sectionLabels = _labels[sectionId];
    if (sectionLabels != null && sectionLabels.containsKey(key)) {
      return sectionLabels[key]!;
    }
    return _humanizeKey(fallback);
  }

  static String _humanizeKey(String key) {
    if (key.isEmpty) return key;
    final spaced = key
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  static String _formatList(List<dynamic> values) {
    final parts = <String>[];
    for (final item in values) {
      if (item is Map) {
        final map = item.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
        final label = map['label'] ?? map['title'] ?? map['name'] ?? map['key'];
        final value = map['value'] ?? map['meta'] ?? map['note'] ?? map['tag'];
        if (label != null && label.isNotEmpty) {
          parts.add(
            value != null && value.isNotEmpty ? '$label: $value' : label,
          );
        } else if (value != null && value.isNotEmpty) {
          parts.add(value);
        } else {
          final joined = map.values.where((v) => v.isNotEmpty).join(' · ');
          if (joined.isNotEmpty) parts.add(joined);
        }
      } else {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) parts.add(text);
      }
    }
    return parts.join('\n');
  }

  /// Export estructurado de óptica desde [VisualBibleData.opticsConfigJson].
  static bool hasOpticsExportContent(
    String? opticsConfigJson, {
    String? narrativeIntent,
    String? lensPhilosophy,
  }) =>
      rowsFromOpticsConfigJson(
        opticsConfigJson,
        narrativeIntent: narrativeIntent,
        lensPhilosophy: lensPhilosophy,
      ).isNotEmpty;

  static List<BibleSectionExportEntry> rowsFromOpticsConfigJson(
    String? jsonStr, {
    String? narrativeIntent,
    String? lensPhilosophy,
  }) {
    final rows = <BibleSectionExportEntry>[];
    final narrative = narrativeIntent?.trim();
    if (narrative != null && narrative.isNotEmpty) {
      rows.add(
        BibleSectionExportEntry(label: 'Intención narrativa', value: narrative),
      );
    } else {
      final philosophy = lensPhilosophy?.trim();
      if (philosophy != null && philosophy.isNotEmpty) {
        rows.add(
          BibleSectionExportEntry(
            label: 'Filosofía de lente',
            value: philosophy,
          ),
        );
      }
    }

    final config = _parseOpticsConfig(jsonStr);
    if (config.isEmpty) return rows;

    void addScalar(String key, String label) {
      final value = config[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        rows.add(BibleSectionExportEntry(label: label, value: value));
      }
    }

    addScalar('styleSubtitle', 'Estilo / subtítulo');
    addScalar('primarySetName', 'Set principal');
    addScalar('tStop', 'T-stop');
    addScalar('squeeze', 'Squeeze');
    addScalar('bokehCharacteristic', 'Característica bokeh');
    addScalar('flareBehavior', 'Comportamiento flare');

    _appendOpticsListRows(
      rows,
      config['filtrationStack'],
      sectionLabel: 'Filtración',
      formatItem: (item) {
        final name = item['name']?.toString().trim() ?? '';
        final parts = <String>[];
        final density = item['density']?.toString().trim();
        final justification = item['justification']?.toString().trim();
        if (density != null && density.isNotEmpty) {
          parts.add('Densidad: $density');
        }
        if (justification != null && justification.isNotEmpty) {
          parts.add(justification);
        }
        return (
          label: name.isEmpty ? 'Filtro' : name,
          value: parts.join('\n'),
        );
      },
    );

    _appendOpticsListRows(
      rows,
      config['anamorphicSpecs'],
      sectionLabel: 'Especificación',
      formatItem: (item) {
        final focal = item['focalLength']?.toString().trim() ?? '';
        final parts = <String>[];
        for (final entry in [
          ('T-stop', item['tStop']),
          ('CFD', item['cfd']),
          ('Distorsión', item['distortion']),
        ]) {
          final value = entry.$2?.toString().trim();
          if (value != null && value.isNotEmpty) {
            parts.add('${entry.$1}: $value');
          }
        }
        return (
          label: focal.isEmpty ? 'Lente' : focal,
          value: parts.join(' · '),
        );
      },
    );

    _appendOpticsListRows(
      rows,
      config['maintenanceLog'],
      sectionLabel: 'Mantenimiento',
      formatItem: (item) {
        final title = item['title']?.toString().trim() ?? 'Entrada';
        final parts = <String>[];
        final date = item['date']?.toString().trim();
        final body =
            item['description']?.toString().trim() ??
            item['body']?.toString().trim();
        if (date != null && date.isNotEmpty) parts.add('Fecha: $date');
        if (body != null && body.isNotEmpty) parts.add(body);
        return (label: title, value: parts.join('\n'));
      },
    );

    _appendOpticsListRows(
      rows,
      config['lensSets'],
      sectionLabel: 'Set de lentes',
      formatItem: (item) {
        final name = item['name']?.toString().trim() ?? 'Set';
        final parts = <String>[];
        if (item['isAnamorphic'] == true) parts.add('Anamórfico');
        final squeeze = item['squeezeRatio']?.toString().trim();
        final ratio = item['aspectRatio']?.toString().trim();
        if (squeeze != null && squeeze.isNotEmpty) {
          parts.add('Squeeze: ${squeeze}x');
        }
        if (ratio != null && ratio.isNotEmpty) parts.add('Ratio: $ratio');
        return (label: name, value: parts.join(' · '));
      },
    );

    return rows;
  }

  static Map<String, dynamic> _parseOpticsConfig(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  static void _appendOpticsListRows(
    List<BibleSectionExportEntry> rows,
    dynamic raw, {
    required String sectionLabel,
    required ({String label, String value}) Function(Map<String, dynamic> item)
    formatItem,
  }) {
    if (raw is! List) return;
    for (final item in raw) {
      if (item is! Map) continue;
      final formatted = formatItem(Map<String, dynamic>.from(item));
      if (formatted.value.trim().isEmpty) continue;
      rows.add(
        BibleSectionExportEntry(
          label: '$sectionLabel · ${formatted.label}',
          value: formatted.value,
        ),
      );
    }
  }
}
