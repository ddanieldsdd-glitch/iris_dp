import 'dart:convert';

/// Tarjeta de un punto estructurado de la biblia: una idea con título y
/// desarrollo. En una división por actos, [kicker] es la fase del acto e
/// [imageIds] las imágenes del moodboard que lo representan.
class BibleCard {
  /// Identidad del acto cuando es uno de los del proyecto; vacío en el resto.
  final String id;
  final String kicker;
  final String title;
  final String body;
  final List<int> imageIds;

  /// Punto de giro: un hito entre actos, que no se numera.
  final bool turn;

  /// Puntos que desarrollan la ficha (título y texto), p. ej. lo que se
  /// quiere explicar de un acto.
  final List<BibleCard> points;

  const BibleCard({
    this.id = '',
    this.kicker = '',
    this.title = '',
    this.body = '',
    this.imageIds = const [],
    this.turn = false,
    this.points = const [],
  });

  bool get isEmpty =>
      kicker.trim().isEmpty &&
      title.trim().isEmpty &&
      body.trim().isEmpty &&
      imageIds.isEmpty &&
      points.every((point) => point.isEmpty);

  BibleCard copyWith({
    String? id,
    String? kicker,
    String? title,
    String? body,
    List<int>? imageIds,
    bool? turn,
    List<BibleCard>? points,
  }) => BibleCard(
    id: id ?? this.id,
    kicker: kicker ?? this.kicker,
    title: title ?? this.title,
    body: body ?? this.body,
    imageIds: imageIds ?? this.imageIds,
    turn: turn ?? this.turn,
    points: points ?? this.points,
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
  );

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    if (kicker.isNotEmpty) 'kicker': kicker,
    'title': title,
    'body': body,
    if (imageIds.isNotEmpty) 'images': imageIds,
    if (turn) 'turn': true,
    if (points.isNotEmpty) 'points': [for (final p in points) p.toJson()],
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
