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

/// Ambiente de un esquema de luz: la luz que no ponemos nosotros.
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

  const PlanAmbient({
    this.day = false,
    this.sunOn = true,
    this.sunAzimuth = 135,
    this.sunElevation = 35,
    this.condition = SkyCondition.clear,
    this.skyOn = true,
    this.wallBounce = true,
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
  }) => PlanAmbient(
    day: day ?? this.day,
    sunOn: sunOn ?? this.sunOn,
    sunAzimuth: sunAzimuth ?? this.sunAzimuth,
    sunElevation: sunElevation ?? this.sunElevation,
    condition: condition ?? this.condition,
    skyOn: skyOn ?? this.skyOn,
    wallBounce: wallBounce ?? this.wallBounce,
  );

  Map<String, dynamic> toJson() => {
    'day': day,
    'sunOn': sunOn,
    'sunAzimuth': sunAzimuth,
    'sunElevation': sunElevation,
    'condition': condition.name,
    'skyOn': skyOn,
    'wallBounce': wallBounce,
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
      other.wallBounce == wallBounce;

  @override
  int get hashCode => Object.hash(
    day,
    sunOn,
    sunAzimuth,
    sunElevation,
    condition,
    skyOn,
    wallBounce,
  );
}
