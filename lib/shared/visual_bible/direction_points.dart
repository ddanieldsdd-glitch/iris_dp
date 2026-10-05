import 'bible_acts.dart';
import 'bible_cards.dart';

/// Contenido de los puntos de Dirección, para la pantalla y el PDF.
///
/// Cada punto guarda su valor en `values[clave]`. Mientras no lo tenga, se
/// lee de donde estaba antes: el blob `directionData` y las columnas de la
/// biblia. Al editarlo por primera vez queda guardado en su sitio.
abstract final class DirectionPoints {
  static const tone = 'tone';
  static const strategies = 'strategies';
  static const acts = 'acts';
  static const transitions = 'transitions';

  /// Pilares con los que nace «Estrategia visual».
  static const pillarCamera = 'Cámara';
  static const pillarStaging = 'Blocking';
  static const pillarPov = 'POV';

  static String _text(Object? v) => v?.toString().trim() ?? '';

  static List<BibleCard> _pairs(Object? raw) => [
    if (raw is List)
      for (final entry in raw)
        if (entry is Map)
          BibleCard(
            title: _text(entry['title']),
            body: _text(entry['body'] ?? entry['desc']),
          )
        else
          BibleCard(title: _text(entry)),
  ].where((card) => !card.isEmpty).toList();

  static List<BibleCard> toneCards(
    Map<String, String> values,
    Map<String, dynamic> blob, {
    String? legacyTone,
  }) {
    if (values.containsKey(tone)) return BibleCard.listFrom(values[tone]);
    final points = _pairs(blob['tonePoints']);
    if (points.isNotEmpty) return points;
    final legacy = _text(legacyTone);
    return [if (legacy.isNotEmpty) BibleCard(body: legacy)];
  }

  static List<BibleCard> strategyCards(
    Map<String, String> values,
    Map<String, dynamic> blob, {
    String? camera,
    String? staging,
    String? pointOfView,
  }) {
    if (values.containsKey(strategies)) {
      return BibleCard.listFrom(values[strategies]);
    }
    return [
      BibleCard(title: pillarCamera, body: _text(camera)),
      BibleCard(title: pillarStaging, body: _text(staging)),
      BibleCard(title: pillarPov, body: _text(pointOfView)),
      ..._pairs(blob['extraStrategies']),
    ];
  }

  static List<BibleCard> transitionCards(
    Map<String, String> values,
    Map<String, dynamic> blob,
  ) {
    if (values.containsKey(transitions)) {
      return BibleCard.listFrom(values[transitions]);
    }
    return _pairs(blob['transitionLanguage']);
  }

  /// Lo que Dirección dice de cada acto del proyecto.
  static BibleActsValue actsValue(
    Map<String, String> values,
    Map<String, dynamic> blob,
  ) {
    if (values.containsKey(acts)) {
      return BibleActsValue.decode(values[acts], sharedByDefault: true);
    }
    return BibleActsValue(
      shared: true,
      layers: {
        for (var n = 1; n <= 3; n++)
          if (_text(blob['act${n}Desc']).isNotEmpty)
            BibleSharedActs.legacyId(n): BibleCard(
              body: _text(blob['act${n}Desc']),
            ),
      },
    );
  }

  /// Texto del pilar [title] en [cards], para las columnas de la biblia que
  /// leen otras pantallas (Cámara, resumen del proyecto).
  static String? pillarBody(List<BibleCard> cards, String title) {
    for (final card in cards) {
      if (card.title.trim().toLowerCase() == title.toLowerCase()) {
        return card.body.trim().isEmpty ? null : card.body.trim();
      }
    }
    return null;
  }
}
