import 'dart:convert';

/// Color de una paleta de la biblia: código, nombre y, en una simbología,
/// lo que significa.
class BiblePaletteColor {
  final String hex;
  final String name;
  final String note;

  const BiblePaletteColor({
    required this.hex,
    this.name = '',
    this.note = '',
  });

  factory BiblePaletteColor.fromJson(Map<dynamic, dynamic> json) =>
      BiblePaletteColor(
        hex: json['hex']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        note: json['note']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
    'hex': hex,
    'name': name,
    if (note.isNotEmpty) 'note': note,
  };

  /// Lee una paleta desde una lista ya decodificada o desde su JSON.
  static List<BiblePaletteColor> listFrom(Object? raw) {
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
          if (entry is Map && (entry['hex']?.toString() ?? '').isNotEmpty)
            BiblePaletteColor.fromJson(entry),
    ];
  }

  static List<Map<String, dynamic>> toJsonList(
    List<BiblePaletteColor> colors,
  ) => [for (final color in colors) color.toJson()];

  /// Valor de un punto de paleta para `values[key]`; null si está vacía.
  static String? encode(List<BiblePaletteColor> colors) =>
      colors.isEmpty ? null : jsonEncode(toJsonList(colors));
}
