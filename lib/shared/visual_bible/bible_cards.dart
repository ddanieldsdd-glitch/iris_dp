import 'dart:convert';

/// Tarjeta de un punto estructurado de la biblia: una idea con título y
/// desarrollo. En una división por actos, [kicker] es la fase del acto e
/// [imageIds] las imágenes del moodboard que lo representan.
class BibleCard {
  final String kicker;
  final String title;
  final String body;
  final List<int> imageIds;

  const BibleCard({
    this.kicker = '',
    this.title = '',
    this.body = '',
    this.imageIds = const [],
  });

  bool get isEmpty =>
      kicker.trim().isEmpty &&
      title.trim().isEmpty &&
      body.trim().isEmpty &&
      imageIds.isEmpty;

  BibleCard copyWith({
    String? kicker,
    String? title,
    String? body,
    List<int>? imageIds,
  }) => BibleCard(
    kicker: kicker ?? this.kicker,
    title: title ?? this.title,
    body: body ?? this.body,
    imageIds: imageIds ?? this.imageIds,
  );

  factory BibleCard.fromJson(Map<dynamic, dynamic> json) => BibleCard(
    kicker: json['kicker']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    imageIds: [
      if (json['images'] is List)
        for (final id in json['images'] as List)
          if (id is num) id.toInt(),
    ],
  );

  Map<String, dynamic> toJson() => {
    if (kicker.isNotEmpty) 'kicker': kicker,
    'title': title,
    'body': body,
    if (imageIds.isNotEmpty) 'images': imageIds,
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
}
