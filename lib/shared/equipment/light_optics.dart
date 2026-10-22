import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'light_kind.dart';

/// Un dato de fotometría: tantos lux en el eje a tantos metros, con el haz
/// abierto a tantos grados.
class LightPhotometryPoint {
  final double beamDeg;
  final double lux;
  final double distanceM;

  const LightPhotometryPoint({
    required this.beamDeg,
    required this.lux,
    required this.distanceM,
  });

  /// Intensidad en el eje, en candelas.
  double get candela => lux * distanceM * distanceM;

  factory LightPhotometryPoint.fromJson(Map<String, dynamic> json) =>
      LightPhotometryPoint(
        beamDeg: (json['beamDeg'] as num).toDouble(),
        lux: (json['lux'] as num).toDouble(),
        distanceM: (json['distanceM'] as num).toDouble(),
      );

  /// `[haz, lux, metros]`, como se guarda en la planta.
  List<double> toList() => [beamDeg, lux, distanceM];

  static LightPhotometryPoint? fromList(Object? raw) {
    if (raw is! List || raw.length < 3) return null;
    final v = [for (final x in raw.take(3)) (x as num?)?.toDouble()];
    if (v.any((x) => x == null || x <= 0)) return null;
    return LightPhotometryPoint(beamDeg: v[0]!, lux: v[1]!, distanceM: v[2]!);
  }

  Map<String, dynamic> toJson() => {
    'beamDeg': beamDeg,
    'lux': lux,
    'distanceM': distanceM,
  };
}

/// La óptica de un aparato: entre qué haces se puede enfocar (spot y
/// flood) y su fotometría en uno o varios de ellos.
class LightOptics {
  /// Haz más cerrado y más abierto. Iguales o `null` = haz fijo.
  final double? spotDeg;
  final double? floodDeg;
  final List<LightPhotometryPoint> points;

  /// El rango sale del formato, no de la ficha del aparato.
  final bool estimated;

  const LightOptics({
    this.spotDeg,
    this.floodDeg,
    this.points = const [],
    this.estimated = false,
  });

  static const none = LightOptics();

  bool get focusable =>
      spotDeg != null && floodDeg != null && floodDeg! - spotDeg! >= 2;

  /// Rango típico de un formato que enfoca: un fresnel, una abierta o un
  /// recorte con zoom. Los paneles, tubos, globos y COB con reflector
  /// tienen el haz fijo.
  static LightOptics forKind(LightKind kind) => switch (kind.format) {
    LightFormat.fresnel => LightOptics(
      spotDeg: kind.technology == LightTechnology.led ? 15 : 12,
      floodDeg: 55,
      estimated: true,
    ),
    LightFormat.open => const LightOptics(
      spotDeg: 20,
      floodDeg: 60,
      estimated: true,
    ),
    LightFormat.profile => const LightOptics(
      spotDeg: 19,
      floodDeg: 50,
      estimated: true,
    ),
    _ => none,
  };

  /// Pone [beamDeg] dentro del rango de foco.
  double clampBeam(double beamDeg) =>
      focusable ? beamDeg.clamp(spotDeg!, floodDeg!).toDouble() : beamDeg;

  /// Intensidad en el eje con el haz a [beamDeg], según la fotometría.
  /// Con dos datos o más se interpola entre ellos (en logaritmos: la luz
  /// cae deprisa al abrir); fuera de ellos, o con uno solo, el mismo flujo
  /// se reparte en el cono nuevo. Sin datos, `null`.
  double? candelaAt(double beamDeg) {
    if (points.isEmpty) return null;
    final sorted = [...points]..sort((a, b) => a.beamDeg.compareTo(b.beamDeg));
    LightPhotometryPoint? below, above;
    for (final p in sorted) {
      if (p.beamDeg <= beamDeg) below = p;
      if (p.beamDeg >= beamDeg && above == null) above = p;
    }
    if (below != null && above != null) {
      if (above.beamDeg - below.beamDeg < 0.01) return below.candela;
      final t =
          (math.log(beamDeg) - math.log(below.beamDeg)) /
          (math.log(above.beamDeg) - math.log(below.beamDeg));
      return math.exp(
        math.log(below.candela) +
            t * (math.log(above.candela) - math.log(below.candela)),
      );
    }
    final nearest = below ?? above!;
    return nearest.candela *
        _solidAngle(nearest.beamDeg) /
        _solidAngle(beamDeg);
  }

  static double _solidAngle(double beamDeg) {
    if (beamDeg >= 359) return 4 * math.pi;
    final half = beamDeg.clamp(1, 359) * math.pi / 360;
    return 2 * math.pi * (1 - math.cos(half));
  }

  factory LightOptics.fromJson(Map<String, dynamic> json) => LightOptics(
    spotDeg: (json['spotDeg'] as num?)?.toDouble(),
    floodDeg: (json['floodDeg'] as num?)?.toDouble(),
    points: [
      for (final p in (json['points'] as List? ?? const []))
        LightPhotometryPoint.fromJson(p as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toJson() => {
    if (spotDeg != null) 'spotDeg': spotDeg,
    if (floodDeg != null) 'floodDeg': floodDeg,
    if (points.isNotEmpty) 'points': [for (final p in points) p.toJson()],
  };
}

/// La óptica de cada aparato del catálogo, por su `externalId`. Viene del
/// mismo `assets/catalog/lights.json` que el resto de la ficha; no pasa
/// por la base.
class LightOpticsCatalog {
  LightOpticsCatalog._();

  static Map<String, LightOptics> _byId = const {};
  static bool _loaded = false;

  static Future<void> ensureLoaded([AssetBundle? bundle]) async {
    if (_loaded) return;
    try {
      // Bytes y no `loadString`: con un archivo grande, `loadString` lo
      // decodifica en otro isolate, y aquí no hace falta.
      final data = await (bundle ?? rootBundle).load(
        'assets/catalog/lights.json',
      );
      load(utf8.decode(data.buffer.asUint8List()));
    } catch (_) {
      _loaded = true;
    }
  }

  /// Lee las ópticas de un `lights.json`.
  static void load(String json) {
    final list = jsonDecode(json) as List;
    _byId = {
      for (final item in list.cast<Map<String, dynamic>>())
        if (item['optics'] is Map)
          item['externalId'] as String: LightOptics.fromJson(
            item['optics'] as Map<String, dynamic>,
          ),
    };
    _loaded = true;
  }

  static LightOptics? of(String? externalId) =>
      externalId == null ? null : _byId[externalId];
}
