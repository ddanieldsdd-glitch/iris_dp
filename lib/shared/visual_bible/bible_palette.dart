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

  /// Lee una paleta desde una lista ya decodificada o desde su JSON, sea el
  /// de una lista de colores o el de un [BiblePaletteValue].
  static List<BiblePaletteColor> listFrom(Object? raw) {
    var value = raw;
    if (value is String && value.trim().isNotEmpty) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return const [];
      }
    }
    // Un punto de paleta con imágenes o texto guarda los colores dentro.
    if (value is Map) value = value['colors'];
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

/// Partes de un punto de paleta que se pueden mostrar u ocultar.
enum BiblePalettePart { palette, images, text }

/// Valor de un punto de paleta: los colores y, si se quiere, imágenes que
/// los representan y un texto que los desarrolla. [show] dice qué partes se
/// ven; ocultar una no borra su contenido.
class BiblePaletteValue {
  final List<BiblePaletteColor> colors;
  final List<int> imageIds;
  final String text;
  final Set<BiblePalettePart> show;

  const BiblePaletteValue({
    this.colors = const [],
    this.imageIds = const [],
    this.text = '',
    this.show = const {BiblePalettePart.palette},
  });

  bool shows(BiblePalettePart part) => show.contains(part);

  /// Lo que se ve tiene contenido.
  bool get hasVisibleContent =>
      (shows(BiblePalettePart.palette) && colors.isNotEmpty) ||
      (shows(BiblePalettePart.images) && imageIds.isNotEmpty) ||
      (shows(BiblePalettePart.text) && text.trim().isNotEmpty);

  BiblePaletteValue copyWith({
    List<BiblePaletteColor>? colors,
    List<int>? imageIds,
    String? text,
    Set<BiblePalettePart>? show,
  }) => BiblePaletteValue(
    colors: colors ?? this.colors,
    imageIds: imageIds ?? this.imageIds,
    text: text ?? this.text,
    show: show ?? this.show,
  );

  /// Muestra u oculta [part]. Siempre queda al menos una parte visible.
  BiblePaletteValue toggled(BiblePalettePart part) {
    final next = {...show};
    if (!next.remove(part)) next.add(part);
    return next.isEmpty ? this : copyWith(show: next);
  }

  /// Lee el valor de `values[key]`. Acepta el formato anterior, una lista de
  /// colores, que equivale a mostrar solo la paleta.
  factory BiblePaletteValue.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const BiblePaletteValue();
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const BiblePaletteValue();
    }
    if (decoded is List) {
      return BiblePaletteValue(colors: BiblePaletteColor.listFrom(decoded));
    }
    if (decoded is! Map) return const BiblePaletteValue();
    final show = <BiblePalettePart>{
      if (decoded['show'] is List)
        for (final name in decoded['show'] as List)
          for (final part in BiblePalettePart.values)
            if (part.name == name) part,
    };
    return BiblePaletteValue(
      colors: BiblePaletteColor.listFrom(decoded['colors']),
      imageIds: [
        if (decoded['images'] is List)
          for (final id in decoded['images'] as List)
            if (id is num) id.toInt(),
      ],
      text: decoded['text']?.toString() ?? '',
      show: show.isEmpty ? const {BiblePalettePart.palette} : show,
    );
  }

  /// Valor para `values[key]`; null si no hay nada que guardar.
  String? encode() {
    final onlyPalette =
        show.length == 1 && show.contains(BiblePalettePart.palette);
    if (colors.isEmpty && imageIds.isEmpty && text.trim().isEmpty) {
      if (onlyPalette) return null;
    }
    return jsonEncode({
      'colors': BiblePaletteColor.toJsonList(colors),
      if (imageIds.isNotEmpty) 'images': imageIds,
      if (text.trim().isNotEmpty) 'text': text,
      'show': [
        for (final part in BiblePalettePart.values)
          if (show.contains(part)) part.name,
      ],
    });
  }
}
