import 'dart:math' as math;

import '../../../shared/equipment/light_optics.dart';

import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../light_beam.dart';
import 'modifiers.dart';
import 'photometry.dart';

/// Una luz de la planta lista para calcular: su fuente con todo aplicado
/// (regulación, difusiones, redes y gelatinas) y de dónde sale el dato.
class PlanLight {
  final PlanElement element;

  /// La fuente tal como sale del aparato, a plena potencia y sin nada
  /// delante.
  final LightSource bare;

  /// La fuente que llega a la escena.
  final LightSource source;
  final List<LightModifier> modifiers;
  final double watts;
  final LightTech tech;

  const PlanLight({
    required this.element,
    required this.bare,
    required this.source,
    required this.modifiers,
    required this.watts,
    required this.tech,
  });

  // Claves en `PlanElement.props`.
  static const wattsKey = 'watts';
  static const techKey = 'tech';
  static const measuredLuxKey = 'measuredLux';
  static const measuredMetersKey = 'measuredMeters';
  static const modifiersKey = 'modifiers';

  /// «ceiling» si el aparato cuelga del techo y alumbra hacia abajo.
  static const mountKey = 'mount';
  static const mountCeiling = 'ceiling';

  /// Altura a la que cuelga, en metros.
  static const heightKey = 'height';
  static const double defaultCeilingHeight = 3;

  /// Altura a la que se mide la luz: la cara de una persona de pie.
  static const double subjectHeightM = 1.5;

  static bool isOverhead(PlanElement el) => el.props[mountKey] == mountCeiling;

  /// Grados que se inclina una luz colgada, desde la vertical.
  static const tiltKey = 'tilt';
  static double tiltOf(PlanElement el) => isOverhead(el)
      ? ((el.props[tiltKey] as num?)?.toDouble() ?? 0).clamp(0.0, 80.0)
      : 0;

  static double heightOf(PlanElement el) =>
      (el.props[heightKey] as num?)?.toDouble() ?? defaultCeilingHeight;

  /// Metros que hay del aparato al plano donde se mide, si cuelga del
  /// techo; `null` si va en trípode.
  static double? overheadDrop(PlanElement el) =>
      isOverhead(el) ? (heightOf(el) - subjectHeightM).clamp(0.3, 50.0) : null;

  /// «manufacturer» si el dato medido viene del catálogo y no del set.
  static const photometrySourceKey = 'photometrySource';

  /// Haz con el que se tomó el dato medido. Si luego se abre o se cierra el
  /// aparato, el mismo flujo se reparte en otro ángulo y el eje sube o baja
  /// con él.
  static const measuredBeamKey = 'measuredBeam';

  /// Tamaño de la superficie que emite, en metros, si no es el de su tipo.
  static const sizeKey = 'sizeM';

  /// Rango de foco del aparato: haz más cerrado y más abierto, en grados.
  static const spotKey = 'spotDeg';
  static const floodKey = 'floodDeg';

  /// `true` si el rango sale del formato y no de la ficha.
  static const focusEstimatedKey = 'focusEstimated';

  /// Fotometría del fabricante en varios haces: `[[haz, lux, metros], …]`.
  static const curveKey = 'photometryCurve';

  /// La óptica guardada en la planta para esta luz.
  static LightOptics opticsOf(PlanElement el) {
    double? read(String key) => (el.props[key] as num?)?.toDouble();
    return LightOptics(
      spotDeg: read(spotKey),
      floodDeg: read(floodKey),
      points: [
        for (final p in (el.props[curveKey] as List? ?? const []))
          ?LightPhotometryPoint.fromList(p),
      ],
      estimated: el.props[focusEstimatedKey] == true,
    );
  }

  /// Stops que quitan los modificadores y la regulación juntos.
  double get stopsLost {
    if (bare.candela <= 0 || source.candela <= 0) return 0;
    final ratio =
        source.illuminance(3) /
        bare.illuminance(3).clamp(1e-9, double.infinity);
    return ratio <= 0 ? 0 : -math.log(ratio) / math.ln2;
  }

  /// Potencia, tecnología y tamaño de partida según el tipo de luz, para
  /// los aparatos que aún no vienen de Equipo.
  static ({double watts, LightTech tech, double sizeM}) defaultsFor(
    LightType? type,
  ) => switch (type) {
    LightType.fresnelSmall => (
      watts: 650,
      tech: LightTech.tungsten,
      sizeM: 0.11,
    ),
    LightType.fresnelMedium => (
      watts: 1000,
      tech: LightTech.tungsten,
      sizeM: 0.15,
    ),
    LightType.fresnelLarge => (
      watts: 2000,
      tech: LightTech.tungsten,
      sizeM: 0.25,
    ),
    LightType.hmi => (watts: 1800, tech: LightTech.hmi, sizeM: 0.25),
    LightType.openFace => (watts: 800, tech: LightTech.tungsten, sizeM: 0.18),
    LightType.par => (watts: 1000, tech: LightTech.tungsten, sizeM: 0.2),
    LightType.ellipsoidal => (
      watts: 750,
      tech: LightTech.tungsten,
      sizeM: 0.15,
    ),
    LightType.scoop => (watts: 1000, tech: LightTech.tungsten, sizeM: 0.4),
    LightType.cyc => (watts: 1000, tech: LightTech.tungsten, sizeM: 0.3),
    LightType.flo4Tubes => (
      watts: 220,
      tech: LightTech.fluorescent,
      sizeM: 1.2,
    ),
    LightType.flo2Tubes => (
      watts: 110,
      tech: LightTech.fluorescent,
      sizeM: 1.2,
    ),
    LightType.floSingle => (watts: 55, tech: LightTech.fluorescent, sizeM: 1.2),
    LightType.lightPanel => (watts: 400, tech: LightTech.led, sizeM: 0.6),
    LightType.led => (watts: 300, tech: LightTech.led, sizeM: 0.15),
    LightType.led1x1 => (watts: 60, tech: LightTech.led, sizeM: 0.3),
    LightType.softbox ||
    LightType.chimera ||
    LightType.octagon => (watts: 300, tech: LightTech.led, sizeM: 0.9),
    LightType.practical => (watts: 60, tech: LightTech.tungsten, sizeM: 0.1),
    _ => (watts: 300, tech: LightTech.led, sizeM: 0.2),
  };

  /// La luz de un elemento, o `null` si no emite (grip, apagada no: una luz
  /// apagada existe, con intensidad cero).
  static PlanLight? of(PlanElement el) {
    final beam = LightBeam.of(el);
    if (beam == null) return null;
    final d = defaultsFor(el.lightType);
    double? read(String key) => (el.props[key] as num?)?.toDouble();

    final watts = read(wattsKey) ?? d.watts;
    final tech = LightTech.values.firstWhere(
      (t) => t.name == el.props[techKey],
      orElse: () => d.tech,
    );
    final measuredLux = read(measuredLuxKey);
    final measuredMeters = read(measuredMetersKey);
    final measuredBeam = read(measuredBeamKey);
    final sizeM = read(sizeKey) ?? d.sizeM;

    final fromSet = el.props[photometrySourceKey] !=
        PhotometryStatus.manufacturer.name;
    final curve = opticsOf(el).candelaAt(beam.spread);
    final bare = curve != null && !(fromSet && measuredLux != null)
        ? LightSource(
            candela: curve,
            beamDeg: beam.spread,
            sizeM: sizeM,
            cct: beam.cct,
            status: PhotometryStatus.manufacturer,
          )
        : measuredLux != null &&
            measuredLux > 0 &&
            measuredMeters != null &&
            measuredMeters > 0
        ? LightSource.measured(
            lux: measuredLux * _beamScale(measuredBeam, beam.spread),
            meters: measuredMeters,
            beamDeg: beam.spread,
            sizeM: sizeM,
            cct: beam.cct,
            status:
                el.props[photometrySourceKey] ==
                    PhotometryStatus.manufacturer.name
                ? PhotometryStatus.manufacturer
                : PhotometryStatus.measured,
          )
        : LightSource.estimated(
            watts: watts,
            tech: tech,
            beamDeg: beam.spread,
            sizeM: sizeM,
            cct: beam.cct,
          );

    final modifiers = [
      for (final id in (el.props[modifiersKey] as List? ?? const []))
        ?LightModifier.byId(id?.toString()),
    ];

    return PlanLight(
      element: el,
      bare: bare,
      source: apply(
        bare,
        modifiers,
        dimmer: beam.off ? 0 : beam.intensity / 100,
      ),
      modifiers: modifiers,
      watts: watts,
      tech: tech,
    );
  }

  /// Cuánto cambia el eje de un dato medido con [measuredDeg] de haz al
  /// llevarlo a [beamDeg]: el flujo es el mismo, repartido en otro cono.
  static double _beamScale(double? measuredDeg, double beamDeg) {
    if (measuredDeg == null || measuredDeg <= 0 || beamDeg <= 0) return 1;
    if ((measuredDeg - beamDeg).abs() < 0.5) return 1;
    return LightSource.solidAngle(measuredDeg) /
        LightSource.solidAngle(beamDeg);
  }

  /// Pone los modificadores delante de la fuente y la regula.
  ///
  /// Cada uno quita su parte de luz. Una difusión, además, reparte lo que
  /// queda en un haz más ancho, así que el eje baja más de lo que dice su
  /// transmisión; y la tela pasa a ser la superficie que emite.
  static LightSource apply(
    LightSource bare,
    List<LightModifier> modifiers, {
    double dimmer = 1,
  }) {
    var candela = bare.candela * dimmer.clamp(0, 1);
    var beam = bare.beamDeg;
    var cct = bare.cct;
    for (final m in modifiers) {
      candela *= m.transmission;
      cct = m.shiftCct(cct);
      final spread = m.spreadDeg;
      if (spread != null && spread > beam) {
        candela *=
            LightSource.solidAngle(beam) / LightSource.solidAngle(spread);
        beam = spread;
      }
    }
    return bare.copyWith(candela: candela, beamDeg: beam, cct: cct);
  }
}
