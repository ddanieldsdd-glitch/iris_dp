import 'dart:math' as math;
import 'dart:ui';

/// Tiempo que hace: decide cuánta luz da el sol directo y cuánta el cielo.
enum SkyCondition { clear, hazy, overcast }

extension SkyConditionInfo on SkyCondition {
  String get label => switch (this) {
    SkyCondition.clear => 'Despejado',
    SkyCondition.hazy => 'Bruma',
    SkyCondition.overcast => 'Nublado',
  };

  /// Lux del sol directo sobre un plano que lo mira. Valores típicos.
  double get sunLux => switch (this) {
    SkyCondition.clear => 60000,
    SkyCondition.hazy => 25000,
    SkyCondition.overcast => 0,
  };

  /// Lux de la luz del cielo, sin sol directo.
  double get skyLux => switch (this) {
    SkyCondition.clear => 12000,
    SkyCondition.hazy => 15000,
    SkyCondition.overcast => 8000,
  };

  /// Temperatura de color del sol directo y del cielo.
  double get sunCct => this == SkyCondition.hazy ? 5200 : 5400;
  double get skyCct => this == SkyCondition.overcast ? 6500 : 7500;
}

/// Lo que se ha decidido de un recinto cerrado: si tiene techo, a qué
/// altura y de qué es el suelo. El recinto es el que contiene el punto
/// ([x], [y]).
class RoomSetting {
  final double x;
  final double y;

  /// Sin techo: un patio.
  final bool openSky;
  final double? ceilingM;

  /// Material del suelo (ver `kFloorMaterials`).
  final String? floor;

  const RoomSetting({
    required this.x,
    required this.y,
    this.openSky = false,
    this.ceilingM,
    this.floor,
  });

  Offset get point => Offset(x, y);

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'openSky': openSky,
    'ceilingM': ?ceilingM,
    'floor': ?floor,
  };

  static RoomSetting? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final x = (raw['x'] as num?)?.toDouble();
    final y = (raw['y'] as num?)?.toDouble();
    if (x == null || y == null) return null;
    return RoomSetting(
      x: x,
      y: y,
      openSky: raw['openSky'] as bool? ?? false,
      ceilingM: (raw['ceilingM'] as num?)?.toDouble(),
      floor: raw['floor'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RoomSetting &&
      other.x == x &&
      other.y == y &&
      other.openSky == openSky &&
      other.ceilingM == ceilingM &&
      other.floor == floor;

  @override
  int get hashCode => Object.hash(x, y, openSky, ceilingM, floor);
}

/// Ambiente de un esquema de luz: la luz que no ponemos nosotros.
/// Qué niebla hay en el esquema de luz (F6.21.2).
enum FogKind {
  haze('Bruma', 'Ambiente parejo: los haces se ven'),
  smoke('Humo', 'Más densa y cerca del suelo'),
  exterior('Niebla exterior', 'Se nota con la distancia');

  final String label;
  final String hint;
  const FogKind(this.label, this.hint);
}

class PlanAmbient {
  /// De día hay sol y cielo; de noche, solo un resto de luna.
  final bool day;
  final bool sunOn;

  /// De dónde viene el sol, en grados: 0 = desde arriba del plano, 90 =
  /// desde la derecha.
  final double sunAzimuth;

  /// Altura del sol sobre el horizonte, en grados. Bajo alarga las sombras.
  final double sunElevation;
  final SkyCondition condition;
  final bool skyOn;

  /// Si las paredes devuelven luz a la sala.
  final bool wallBounce;

  /// Recintos con ajustes propios. Los demás tienen techo a la altura de
  /// partida.
  final List<RoomSetting> rooms;

  /// Niebla o humo del esquema, de 0 (nada) a 100 % (F6.21.2).
  final double fogPct;
  final FogKind fogKind;

  bool get hasFog => fogPct > 0;

  const PlanAmbient({
    this.day = false,
    this.sunOn = true,
    this.sunAzimuth = 135,
    this.sunElevation = 35,
    this.condition = SkyCondition.clear,
    this.skyOn = true,
    this.wallBounce = true,
    this.rooms = const [],
    this.fogPct = 0,
    this.fogKind = FogKind.haze,
  });

  /// Luz de luna llena sobre el suelo, en lux.
  static const double moonLux = 0.25;

  bool get hasSun => day && sunOn && condition.sunLux > 0;
  bool get hasSky => skyOn;

  double get skyLux => day ? condition.skyLux : moonLux;
  double get skyCct => day ? condition.skyCct : 4100;

  /// Dirección desde la que llega el sol, sobre el plano.
  Offset get towardSun {
    final rad = sunAzimuth * math.pi / 180;
    return Offset(math.sin(rad), -math.cos(rad));
  }

  /// Largo de la sombra de algo de [height] metros de alto.
  double shadowLength(double height) {
    final elevation = sunElevation.clamp(3.0, 89.0) * math.pi / 180;
    return height / math.tan(elevation);
  }

  PlanAmbient copyWith({
    bool? day,
    bool? sunOn,
    double? sunAzimuth,
    double? sunElevation,
    SkyCondition? condition,
    bool? skyOn,
    bool? wallBounce,
    List<RoomSetting>? rooms,
    double? fogPct,
    FogKind? fogKind,
  }) => PlanAmbient(
    day: day ?? this.day,
    sunOn: sunOn ?? this.sunOn,
    sunAzimuth: sunAzimuth ?? this.sunAzimuth,
    sunElevation: sunElevation ?? this.sunElevation,
    condition: condition ?? this.condition,
    skyOn: skyOn ?? this.skyOn,
    wallBounce: wallBounce ?? this.wallBounce,
    rooms: rooms ?? this.rooms,
    fogPct: fogPct ?? this.fogPct,
    fogKind: fogKind ?? this.fogKind,
  );

  Map<String, dynamic> toJson() => {
    'day': day,
    'sunOn': sunOn,
    'sunAzimuth': sunAzimuth,
    'sunElevation': sunElevation,
    'condition': condition.name,
    'skyOn': skyOn,
    'wallBounce': wallBounce,
    if (rooms.isNotEmpty) 'rooms': [for (final r in rooms) r.toJson()],
    if (fogPct > 0) ...{'fogPct': fogPct, 'fogKind': fogKind.name},
  };

  static PlanAmbient fromJson(Object? raw) {
    if (raw is! Map) return const PlanAmbient();
    return PlanAmbient(
      day: raw['day'] as bool? ?? false,
      sunOn: raw['sunOn'] as bool? ?? true,
      sunAzimuth: (raw['sunAzimuth'] as num?)?.toDouble() ?? 135,
      sunElevation: (raw['sunElevation'] as num?)?.toDouble() ?? 35,
      condition: SkyCondition.values.firstWhere(
        (c) => c.name == raw['condition'],
        orElse: () => SkyCondition.clear,
      ),
      skyOn: raw['skyOn'] as bool? ?? true,
      wallBounce: raw['wallBounce'] as bool? ?? true,
      rooms: [
        for (final r in (raw['rooms'] as List? ?? const []))
          ?RoomSetting.fromJson(r),
      ],
      fogPct: ((raw['fogPct'] as num?)?.toDouble() ?? 0).clamp(0.0, 100.0),
      fogKind: FogKind.values.firstWhere(
        (k) => k.name == raw['fogKind'],
        orElse: () => FogKind.haze,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlanAmbient &&
      other.day == day &&
      other.sunOn == sunOn &&
      other.sunAzimuth == sunAzimuth &&
      other.sunElevation == sunElevation &&
      other.condition == condition &&
      other.skyOn == skyOn &&
      other.wallBounce == wallBounce &&
      other.fogPct == fogPct &&
      other.fogKind == fogKind &&
      other.rooms.length == rooms.length &&
      [
        for (var i = 0; i < rooms.length; i++) rooms[i] == other.rooms[i],
      ].every((same) => same);

  @override
  int get hashCode => Object.hash(
    day,
    sunOn,
    sunAzimuth,
    sunElevation,
    condition,
    skyOn,
    wallBounce,
    Object.hashAll(rooms),
    fogPct,
    fogKind,
  );
}
