import 'dart:convert';

/// Tarjeta de un punto estructurado de la biblia: una idea con título y
/// desarrollo. En una división por actos, [kicker] es la fase del acto.
class BibleCard {
  final String kicker;
  final String title;
  final String body;

  const BibleCard({this.kicker = '', this.title = '', this.body = ''});

  bool get isEmpty =>
      kicker.trim().isEmpty && title.trim().isEmpty && body.trim().isEmpty;

  factory BibleCard.fromJson(Map<dynamic, dynamic> json) => BibleCard(
    kicker: json['kicker']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {
    if (kicker.isNotEmpty) 'kicker': kicker,
    'title': title,
    'body': body,
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
