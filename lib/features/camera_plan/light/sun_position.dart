import 'dart:math' as math;

/// Dónde está el sol: acimut en grados desde el norte hacia el este, y
/// altura sobre el horizonte.
class SunPosition {
  final double azimuth;
  final double elevation;

  const SunPosition(this.azimuth, this.elevation);

  bool get up => elevation > 0;

  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;

  /// Posición en un instante [utc] (fórmulas de la NOAA, de Meeus), con la
  /// refracción de la atmósfera.
  static SunPosition at(DateTime utc, double latitude, double longitude) {
    final moment = utc.toUtc();
    final jd = moment.millisecondsSinceEpoch / 86400000 + 2440587.5;
    final t = (jd - 2451545) / 36525;
    final l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360;
    final m = 357.52911 + t * (35999.05029 - 0.0001537 * t);
    final e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
    final mr = _rad(m);
    final center =
        math.sin(mr) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
        math.sin(2 * mr) * (0.019993 - 0.000101 * t) +
        math.sin(3 * mr) * 0.000289;
    final omega = _rad(125.04 - 1934.136 * t);
    final lambda = _rad(l0 + center - 0.00569 - 0.00478 * math.sin(omega));
    final mean =
        23 +
        (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
    final obliquity = _rad(mean + 0.00256 * math.cos(omega));
    final declination = math.asin(math.sin(obliquity) * math.sin(lambda));
    final y = math.pow(math.tan(obliquity / 2), 2).toDouble();
    final l = _rad(l0);
    final equation =
        4 *
        _deg(
          y * math.sin(2 * l) -
              2 * e * math.sin(mr) +
              4 * e * y * math.sin(mr) * math.cos(2 * l) -
              0.5 * y * y * math.sin(4 * l) -
              1.25 * e * e * math.sin(2 * mr),
        );
    final minutes =
        moment.hour * 60 +
        moment.minute +
        moment.second / 60 +
        moment.millisecond / 60000;
    final solar = (minutes + equation + 4 * longitude) % 1440;
    final hour = _rad(solar / 4 - 180);
    final phi = _rad(latitude);
    final cosZenith =
        (math.sin(phi) * math.sin(declination) +
                math.cos(phi) * math.cos(declination) * math.cos(hour))
            .clamp(-1.0, 1.0);
    final geometric = 90 - _deg(math.acos(cosZenith));
    // Saemundsson: el horizonte aparente levanta el sol unos 0,5°.
    final refraction = geometric < -1.5
        ? 0.0
        : 1.02 / math.tan(_rad(geometric + 10.3 / (geometric + 5.11))) / 60;
    final azimuth =
        (_deg(
              math.atan2(
                math.sin(hour),
                math.cos(hour) * math.sin(phi) -
                    math.tan(declination) * math.cos(phi),
              ),
            ) +
            180) %
        360;
    return SunPosition(azimuth, geometric + refraction);
  }

  /// Horas de salida y puesta del sol de un día, en minutos desde la
  /// medianoche del lugar (`utcOffsetMinutes`). `null` si ese día no sale o
  /// no se pone (zonas polares).
  static ({int rise, int set})? dayOf(
    DateTime day,
    double latitude,
    double longitude, {
    required int utcOffsetMinutes,
  }) {
    int? rise, set;
    final midnight = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).subtract(Duration(minutes: utcOffsetMinutes));
    var wasUp = at(midnight, latitude, longitude).elevation > _horizon;
    for (var minute = 1; minute < 1440; minute++) {
      final now = midnight.add(Duration(minutes: minute));
      final isUp = at(now, latitude, longitude).elevation > _horizon;
      if (isUp && !wasUp) rise ??= minute;
      if (!isUp && wasUp) set = minute;
      wasUp = isUp;
    }
    return rise == null || set == null ? null : (rise: rise, set: set);
  }

  /// Altura del centro del sol cuando asoma el borde (con refracción ya
  /// incluida en [elevation]): su radio.
  static const double _horizon = -0.27;

  /// Acimut para la planta (0 arriba, 90 a la derecha), cuando el norte
  /// está a [northDeg] de arriba del plano en el sentido de las agujas.
  double planAzimuth(double northDeg) => (azimuth + northDeg) % 360;

  /// «SE», «NO»…
  String get compass {
    const names = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
    return names[((azimuth + 22.5) ~/ 45) % 8];
  }
}
