import 'dart:math' as math;

import '../../../shared/equipment/light_kind.dart';

/// De dónde sale la intensidad de una fuente. Mismo criterio que los
/// estados de dato del master de material: lo que no está medido se dice.
enum PhotometryStatus {
  /// Medido en el set o escrito a mano por el usuario.
  measured,

  /// Dato publicado por el fabricante.
  manufacturer,

  /// Calculado a partir de vatios, tecnología y ángulo de haz.
  estimated,
}

extension PhotometryStatusLabel on PhotometryStatus {
  String get label => switch (this) {
    PhotometryStatus.measured => 'medido',
    PhotometryStatus.manufacturer => 'fabricante',
    PhotometryStatus.estimated => 'estimado',
  };
}

/// Tecnología de la lámpara: decide cuánta luz da cada vatio.
enum LightTech { tungsten, hmi, led, fluorescent }

extension LightTechInfo on LightTech {
  /// Eficacia luminosa típica, en lúmenes por vatio eléctrico.
  double get lumensPerWatt => switch (this) {
    LightTech.tungsten => 26,
    LightTech.hmi => 90,
    LightTech.led => 95,
    LightTech.fluorescent => 75,
  };

  String get label => switch (this) {
    LightTech.tungsten => 'Tungsteno',
    LightTech.hmi => 'HMI',
    LightTech.led => 'LED',
    LightTech.fluorescent => 'Fluorescente',
  };

  /// Tecnología según el tipo de luz del catálogo («led_fresnel»,
  /// «tungsten_fresnel» o, de antes, «LED Panel»…).
  static LightTech fromCatalogType(String? type) =>
      LightTech.values.byName(LightKind.parse(type).technology.code);
}

/// Una fuente de luz para el cálculo: cuánto emite, hacia dónde y cómo de
/// grande es.
class LightSource {
  /// Intensidad en el eje, en candelas.
  final double candela;

  /// Ángulo de haz en grados (donde la intensidad cae a la mitad).
  /// 360 = emite igual en todas direcciones.
  final double beamDeg;

  /// Tamaño de la superficie que emite, en metros. Una fuente grande cae
  /// más despacio de cerca.
  final double sizeM;

  /// Temperatura de color en kelvin.
  final double cct;
  final PhotometryStatus status;

  const LightSource({
    required this.candela,
    required this.beamDeg,
    this.sizeM = 0.1,
    this.cct = 5600,
    this.status = PhotometryStatus.estimated,
  });

  bool get isOmni => beamDeg >= 359;

  /// Parte del flujo que sale realmente del aparato (óptica, reflector).
  static const double opticalEfficiency = 0.65;

  /// Parte de ese flujo que cae dentro del ángulo de haz, y relación entre
  /// la intensidad media del haz y la del eje.
  static const double _fluxInBeam = 0.6;
  static const double _meanToPeak = 0.75;

  /// Ángulo sólido de un cono, en estereorradianes.
  static double solidAngle(double beamDeg) {
    if (beamDeg >= 359) return 4 * math.pi;
    final half = beamDeg.clamp(1, 359) * math.pi / 360;
    return 2 * math.pi * (1 - math.cos(half));
  }

  /// Estima la intensidad en el eje a partir de vatios, tecnología y haz.
  /// Sirve para planificar y comparar; no sustituye a un dato medido.
  static double estimateCandela({
    required double watts,
    required LightTech tech,
    required double beamDeg,
  }) {
    final flux = watts * tech.lumensPerWatt * opticalEfficiency;
    if (beamDeg >= 359) return flux / (4 * math.pi);
    return flux * _fluxInBeam / (_meanToPeak * solidAngle(beamDeg));
  }

  /// Intensidad a partir de una medida: tantos lux a tantos metros, en el
  /// eje.
  static double candelaFromMeasurement({
    required double lux,
    required double meters,
  }) => lux * meters * meters;

  factory LightSource.estimated({
    required double watts,
    required LightTech tech,
    required double beamDeg,
    double sizeM = 0.1,
    double cct = 5600,
  }) => LightSource(
    candela: estimateCandela(watts: watts, tech: tech, beamDeg: beamDeg),
    beamDeg: beamDeg,
    sizeM: sizeM,
    cct: cct,
  );

  factory LightSource.measured({
    required double lux,
    required double meters,
    required double beamDeg,
    double sizeM = 0.1,
    double cct = 5600,
    PhotometryStatus status = PhotometryStatus.measured,
  }) => LightSource(
    candela: candelaFromMeasurement(lux: lux, meters: meters),
    beamDeg: beamDeg,
    sizeM: sizeM,
    cct: cct,
    status: status,
  );

  LightSource copyWith({
    double? candela,
    double? beamDeg,
    double? sizeM,
    double? cct,
    PhotometryStatus? status,
  }) => LightSource(
    candela: candela ?? this.candela,
    beamDeg: beamDeg ?? this.beamDeg,
    sizeM: sizeM ?? this.sizeM,
    cct: cct ?? this.cct,
    status: status ?? this.status,
  );

  /// Cuánto queda de la intensidad del eje a [offAxisDeg] grados de él.
  /// Vale 1 en el eje y 0,5 en el borde del haz; más allá sigue cayendo
  /// (el derrame) hasta desaparecer.
  double profile(double offAxisDeg) {
    if (isOmni) return 1;
    final half = beamDeg / 2;
    final x = offAxisDeg.abs() / half;
    final value = math.pow(0.5, x * x).toDouble();
    return value < 0.01 ? 0 : value;
  }

  /// Lux que llegan a un punto a [meters] de la fuente y [offAxisDeg]
  /// grados del eje, sin nada en medio.
  ///
  /// Ley del cuadrado de la distancia, corregida de cerca por el tamaño de
  /// la fuente: una pantalla de un metro no se comporta como un punto a
  /// medio metro.
  double illuminance(double meters, {double offAxisDeg = 0}) {
    final d2 = meters * meters + (sizeM / 2) * (sizeM / 2);
    if (d2 <= 0) return 0;
    return candela * profile(offAxisDeg) / d2;
  }

  /// Distancia a la que el eje baja a [lux].
  double distanceFor(double lux) {
    if (lux <= 0) return double.infinity;
    final d2 = candela / lux - (sizeM / 2) * (sizeM / 2);
    return d2 <= 0 ? 0 : math.sqrt(d2);
  }
}
