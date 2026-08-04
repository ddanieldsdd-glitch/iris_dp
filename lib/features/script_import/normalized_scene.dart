import 'script_parser.dart';

/// Escena normalizada a partir de sluglines del parser local.
class NormalizedScene {
  final int number;
  final String intExt;
  final String dayNight;
  final String location;
  final String shootSet;
  final String locationSite;
  final String? name;
  final String? description;
  final String? locationColor;
  final List<String> characters;

  const NormalizedScene({
    required this.number,
    required this.intExt,
    required this.dayNight,
    required this.location,
    required this.shootSet,
    required this.locationSite,
    this.name,
    this.description,
    this.locationColor,
    this.characters = const [],
  });

  factory NormalizedScene.fromRaw(RawSlugline raw) => NormalizedScene(
        number: raw.number,
        intExt: raw.intExt,
        dayNight: raw.dayNight,
        location: raw.location,
        shootSet: raw.location,
        locationSite: raw.location,
      );

  NormalizedScene copyWith({
    int? number,
    String? intExt,
    String? dayNight,
    String? location,
    String? shootSet,
    String? locationSite,
    String? name,
    String? description,
    String? locationColor,
    List<String>? characters,
  }) =>
      NormalizedScene(
        number: number ?? this.number,
        intExt: intExt ?? this.intExt,
        dayNight: dayNight ?? this.dayNight,
        location: location ?? this.location,
        shootSet: shootSet ?? this.shootSet,
        locationSite: locationSite ?? this.locationSite,
        name: name ?? this.name,
        description: description ?? this.description,
        locationColor: locationColor ?? this.locationColor,
        characters: characters ?? this.characters,
      );

  static List<NormalizedScene> mergeWithRaw(
    List<RawSlugline> raw,
    List<NormalizedScene> normalized,
  ) {
    if (normalized.isEmpty) return raw.map(NormalizedScene.fromRaw).toList();

    final byNumber = {for (final s in normalized) s.number: s};
    return raw.map((r) {
      final match = byNumber[r.number];
      if (match != null) return match;
      return NormalizedScene.fromRaw(r);
    }).toList();
  }
}
