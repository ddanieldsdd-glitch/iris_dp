import 'dart:convert';

/// Lo que se cuenta de una imagen dentro de una tarjeta: su título, el
/// texto y su luz (`LightingMetrics` en JSON).
class BibleImageNote {
  final String title;
  final String text;
  final String? light;

  const BibleImageNote({this.title = '', this.text = '', this.light});

  bool get isEmpty =>
      title.trim().isEmpty &&
      text.trim().isEmpty &&
      (light == null || light!.trim().isEmpty || light == '{}');

  BibleImageNote copyWith({String? title, String? text, String? light}) =>
      BibleImageNote(
        title: title ?? this.title,
        text: text ?? this.text,
        light: light ?? this.light,
      );

  Map<String, dynamic> toJson() => {
    if (title.isNotEmpty) 'title': title,
    if (text.isNotEmpty) 'text': text,
    if (light != null && light!.isNotEmpty && light != '{}') 'light': light,
  };

  static BibleImageNote fromJson(Object? raw) => raw is Map
      ? BibleImageNote(
          title: raw['title']?.toString() ?? '',
          text: raw['text']?.toString() ?? '',
          light: raw['light']?.toString(),
        )
      : const BibleImageNote();
}

/// Tarjeta de un punto estructurado de la biblia: una idea con título y
/// desarrollo. En una división por actos, [kicker] es la fase del acto e
/// [imageIds] las imágenes del moodboard que lo representan.
class BibleCard {
  /// Identidad del acto cuando es uno de los del proyecto; vacío en el resto.
  final String id;
  final String kicker;
  final String title;
  final String body;

  /// Las imágenes de la ficha y las de sus bloques, sin repetir.
  List<int> get allImageIds =>
      {...imageIds, for (final point in points) ...point.allImageIds}.toList();

  final List<int> imageIds;

  /// Punto de giro: un hito entre actos, que no se numera.
  final bool turn;

  /// Puntos que desarrollan la ficha (título y texto), p. ej. lo que se
  /// quiere explicar de un acto.
  final List<BibleCard> points;

  /// Lo que se cuenta de cada imagen (por su id del moodboard).
  final Map<int, BibleImageNote> imageNotes;

  const BibleCard({
    this.id = '',
    this.kicker = '',
    this.title = '',
    this.body = '',
    this.imageIds = const [],
    this.turn = false,
    this.points = const [],
    this.imageNotes = const {},
  });

  bool get isEmpty =>
      kicker.trim().isEmpty &&
      title.trim().isEmpty &&
      body.trim().isEmpty &&
      imageIds.isEmpty &&
      imageNotes.values.every((note) => note.isEmpty) &&
      points.every((point) => point.isEmpty);

  BibleCard copyWith({
    String? id,
    String? kicker,
    String? title,
    String? body,
    List<int>? imageIds,
    bool? turn,
    List<BibleCard>? points,
    Map<int, BibleImageNote>? imageNotes,
  }) => BibleCard(
    id: id ?? this.id,
    kicker: kicker ?? this.kicker,
    title: title ?? this.title,
    body: body ?? this.body,
    imageIds: imageIds ?? this.imageIds,
    turn: turn ?? this.turn,
    points: points ?? this.points,
    imageNotes: imageNotes ?? this.imageNotes,
  );

  factory BibleCard.fromJson(Map<dynamic, dynamic> json) => BibleCard(
    id: json['id']?.toString() ?? '',
    kicker: json['kicker']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    imageIds: [
      if (json['images'] is List)
        for (final id in json['images'] as List)
          if (id is num) id.toInt(),
    ],
    turn: json['turn'] == true,
    points: listFrom(json['points']),
    imageNotes: {
      if (json['imageNotes'] is Map)
        for (final e in (json['imageNotes'] as Map).entries)
          if (int.tryParse('${e.key}') case final id?)
            id: BibleImageNote.fromJson(e.value),
    },
  );

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    if (kicker.isNotEmpty) 'kicker': kicker,
    'title': title,
    'body': body,
    if (imageIds.isNotEmpty) 'images': imageIds,
    if (turn) 'turn': true,
    if (points.isNotEmpty) 'points': [for (final p in points) p.toJson()],
    if (imageNotes.values.any((n) => !n.isEmpty))
      'imageNotes': {
        for (final e in imageNotes.entries)
          if (!e.value.isEmpty) '${e.key}': e.value.toJson(),
      },
  };

  /// Lee las tarjetas desde una lista ya decodificada o desde su JSON.
  static List<BibleCard> listFrom(Object? raw) {
    var value = raw;
    if (value is String && value.trim().isNotEmpty) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return const [];
      }
    }
    return [
      if (value is List)
        for (final entry in value)
          if (entry is Map) BibleCard.fromJson(entry),
    ];
  }

  /// Valor del punto para `values[key]`; null si no hay tarjetas.
  static String? encode(List<BibleCard> cards) => cards.isEmpty
      ? null
      : jsonEncode([for (final card in cards) card.toJson()]);

  /// Número de cada acto de [acts]; `null` en los puntos de giro.
  static List<int?> actNumbers(List<BibleCard> acts) {
    var n = 0;
    return [for (final act in acts) act.turn ? null : ++n];
  }
}
