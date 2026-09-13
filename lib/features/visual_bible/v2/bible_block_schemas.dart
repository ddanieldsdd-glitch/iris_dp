/// Schemas JSON de contenido por `subsectionKind` (Pasada 1: solo datos).
abstract final class BibleBlockSchemas {
  static const narrativeIntent = 'narrativeIntent';
  static const tonePoints = 'tonePoints';
  static const transitions = 'transitions';
  static const visualStrategy = 'visualStrategy';
  static const acts = 'acts';
  static const narrativeRefs = 'narrativeRefs';

  /// fieldKey legacy aprobados → subsectionKind destino.
  static const approvedDirectionLegacyFieldKeys = <String, String>{
    'toneStrategies': tonePoints,
    'transitionLanguage': transitions,
    'emotionTags': narrativeIntent,
  };

  static Map<String, dynamic> taggedText({
    String text = '',
    String label = 'Intención',
    List<String> tags = const [],
  }) {
    return {'text': text, 'label': label, 'tags': List<String>.from(tags)};
  }

  static Map<String, dynamic> pointList({
    String label = '',
    String text = '',
    List<Map<String, String>> points = const [],
  }) {
    return {
      'label': label,
      'text': text,
      'points': [
        for (final point in points)
          {'title': point['title'] ?? '', 'body': point['body'] ?? ''},
      ],
    };
  }

  static Map<String, dynamic> forSubsection(String subsectionKind) {
    return switch (subsectionKind) {
      narrativeIntent => taggedText(),
      tonePoints => pointList(label: 'Tono y atmósfera'),
      transitions => pointList(label: 'Lenguaje de transiciones'),
      visualStrategy => {
        'label': 'Estrategia visual',
        'pillars': [
          {'id': 'camera', 'title': 'Cámara', 'body': ''},
          {'id': 'blocking', 'title': 'Blocking', 'body': ''},
          {'id': 'pov', 'title': 'POV', 'body': ''},
        ],
        'extras': <Map<String, dynamic>>[],
      },
      acts => {
        'label': 'Intención visual por acto',
        'acts': [
          {'phase': 'ACTO I', 'title': '', 'body': ''},
          {'phase': 'ACTO II', 'title': '', 'body': ''},
          {'phase': 'ACTO III', 'title': '', 'body': ''},
        ],
      },
      narrativeRefs => {
        'label': 'Referencias',
        'images': <Map<String, dynamic>>[],
      },
      _ => const {},
    };
  }

  static List<Map<String, String>> parsePointList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          {
            'title': item['title']?.toString() ?? '',
            'body': item['body']?.toString() ?? item['desc']?.toString() ?? '',
          },
    ];
  }

  static List<String> parseTags(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item.toString().trim().isNotEmpty) item.toString(),
    ];
  }
}
