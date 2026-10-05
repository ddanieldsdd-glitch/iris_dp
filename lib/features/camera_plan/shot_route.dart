import 'dart:convert';

/// Un tramo del recorrido de un plano secuencia: por qué set pasa y con
/// qué esquema de luz.
class ShotLeg {
  final int? siteId;
  final int? setId;
  final int? lightSetupId;

  const ShotLeg({this.siteId, this.setId, this.lightSetupId});

  ShotLeg copyWith({int? lightSetupId, bool clearSetup = false}) => ShotLeg(
    siteId: siteId,
    setId: setId,
    lightSetupId: clearSetup ? null : lightSetupId ?? this.lightSetupId,
  );

  Map<String, dynamic> toJson() => {
    'siteId': ?siteId,
    'setId': ?setId,
    'lightSetupId': ?lightSetupId,
  };

  static ShotLeg fromJson(Map raw) => ShotLeg(
    siteId: (raw['siteId'] as num?)?.toInt(),
    setId: (raw['setId'] as num?)?.toInt(),
    lightSetupId: (raw['lightSetupId'] as num?)?.toInt(),
  );

  @override
  bool operator ==(Object other) =>
      other is ShotLeg &&
      other.siteId == siteId &&
      other.setId == setId &&
      other.lightSetupId == lightSetupId;

  @override
  int get hashCode => Object.hash(siteId, setId, lightSetupId);
}

/// Recorrido de un plano secuencia, guardado en `Shots.routeJson`.
class ShotRoute {
  ShotRoute._();

  /// `null` o vacío = no es un plano secuencia.
  static List<ShotLeg> decode(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      return [
        for (final leg in jsonDecode(json) as List)
          if (leg is Map) ShotLeg.fromJson(leg),
      ];
    } catch (_) {
      return const [];
    }
  }

  static String? encode(List<ShotLeg> legs) =>
      legs.isEmpty ? null : jsonEncode([for (final l in legs) l.toJson()]);
}
