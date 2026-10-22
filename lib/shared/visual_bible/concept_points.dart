import 'bible_acts.dart';
import 'bible_cards.dart';
import 'bible_palette.dart';
import 'bible_text_specs.dart';

/// Datos con los que nace «Filosofía de luz» en Concepto: clave antigua en
/// `lightingMetrics` y rótulo.
const kConceptLightMetrics = [
  ('contrast', 'Contraste'),
  ('motivation', 'Motivación'),
  ('fill', 'Relleno'),
  ('eyeLight', 'Luz de ojos'),
];

/// Datos con los que nace «Composición» en Concepto.
const kConceptCompositionMetrics = [
  ('framing', 'Encuadre'),
  ('balance', 'Equilibrio'),
  ('depth', 'Profundidad'),
  ('height', 'Altura de cámara'),
];

/// Contenido de los puntos de Concepto, para la pantalla y el PDF.
///
/// Cada punto guarda su valor en `values[clave]`. Mientras no lo tenga, se
/// lee de donde estaba antes: el blob `conceptData` y las columnas de la
/// biblia. Al editarlo por primera vez queda guardado en su sitio. Nada de
/// lo que devuelve es un ejemplo: si el usuario no lo escribió, sale vacío.
abstract final class ConceptPoints {
  static const palette = 'colorPalette';
  static const symbolism = 'colorSymbolism';
  static const light = 'lightPhilosophy';
  static const shadows = 'shadowTreatment';
  static const composition = 'composition';
  static const acts = 'actNotes';
  static const actComposition = 'actComposition';
  static const keyFrame = 'keyFrame';

  static String _text(Object? v) => v?.toString().trim() ?? '';

  static Map<String, String> _strings(Object? raw) => {
    if (raw is Map)
      for (final e in raw.entries) _text(e.key): _text(e.value),
  };

  static List<String> atmosphereTags(Map<String, dynamic> blob) => [
    if (blob['atmosphereTags'] is List)
      for (final tag in blob['atmosphereTags'] as List)
        if (_text(tag).isNotEmpty) _text(tag),
  ];

  static BiblePaletteValue paletteValue(
    Map<String, String> values,
    Map<String, dynamic> blob,
  ) {
    if (values.containsKey(palette)) {
      return BiblePaletteValue.decode(values[palette]);
    }
    return BiblePaletteValue(
      colors: BiblePaletteColor.listFrom(blob['masterPalette']),
    );
  }

  static BiblePaletteValue symbolismValue(
    Map<String, String> values,
    Map<String, dynamic> blob,
  ) {
    if (values.containsKey(symbolism)) {
      return BiblePaletteValue.decode(values[symbolism]);
    }
    return BiblePaletteValue(
      colors: [
        if (blob['colorSymbols'] is List)
          for (final e in blob['colorSymbols'] as List)
            if (e is Map && _text(e['hex']).isNotEmpty)
              BiblePaletteColor(
                hex: _text(e['hex']),
                name: _text(e['poeticName']),
                note: _text(e['narrativeMeaning']),
              ),
      ],
    );
  }

  static BibleTextSpecsValue _textSpecs(
    Map<String, String> values,
    String key, {
    required String legacyText,
    required List<(String, String)> labels,
    required Map<String, String> legacyMetrics,
  }) {
    if (values.containsKey(key)) {
      return BibleTextSpecsValue.decode(values[key]);
    }
    return BibleTextSpecsValue(
      text: legacyText,
      rows: [
        for (final (metric, label) in labels)
          (label, legacyMetrics[metric] ?? ''),
      ],
    );
  }

  static BibleTextSpecsValue lightValue(
    Map<String, String> values,
    Map<String, dynamic> blob, {
    String? philosophy,
    String? contrast,
  }) => _textSpecs(
    values,
    light,
    legacyText: _text(philosophy),
    labels: kConceptLightMetrics,
    legacyMetrics: {
      if (_text(contrast).isNotEmpty) 'contrast': _text(contrast),
      ..._strings(blob['lightingMetrics']),
    },
  );

  static String shadowsText(
    Map<String, String> values,
    Map<String, dynamic> blob,
  ) => values.containsKey(shadows)
      ? _text(values[shadows])
      : _text(blob['shadowTreatment']);

  static BibleTextSpecsValue compositionValue(
    Map<String, String> values,
    Map<String, dynamic> blob,
  ) => _textSpecs(
    values,
    composition,
    legacyText: _text(blob['composition']),
    labels: kConceptCompositionMetrics,
    legacyMetrics: _strings(blob['compositionMetrics']),
  );

  /// Lo que Concepto dice de cada acto del proyecto. La composición por
  /// acto que hubiera escrita pasa a ser un punto dentro de su acto.
  static BibleActsValue actsValue(
    Map<String, String> values,
    Map<String, dynamic> blob,
  ) {
    if (values.containsKey(acts)) {
      return BibleActsValue.decode(values[acts], sharedByDefault: true);
    }
    final perAct = _strings(blob['actComposition']);
    return BibleActsValue(
      shared: true,
      layers: {
        for (var n = 1; n <= 3; n++)
          if (_text(blob['act${n}Intent']).isNotEmpty ||
              (perAct['$n'] ?? '').isNotEmpty)
            BibleSharedActs.legacyId(n): BibleCard(
              body: _text(blob['act${n}Intent']),
              points: [
                if ((perAct['$n'] ?? '').isNotEmpty)
                  BibleCard(title: 'Composición', body: perAct['$n']!),
              ],
            ),
      },
    );
  }

  /// «Composición por actos», punto opcional de biblias anteriores.
  static List<(String, String)> actCompositionRows(Map<String, dynamic> blob) {
    const numerals = ['I', 'II', 'III'];
    final perAct = _strings(blob['actComposition']);
    return [
      for (var n = 1; n <= 3; n++)
        if ((perAct['$n'] ?? '').isNotEmpty)
          ('Acto ${numerals[n - 1]}', perAct['$n']!),
    ];
  }

  /// Key Frame de biblias anteriores: título y datos, si se escribieron.
  static (String, String) keyFrameOf(Map<String, dynamic> blob) =>
      (_text(blob['keyFrameTitle']), _text(blob['keyFrameTech']));
}
