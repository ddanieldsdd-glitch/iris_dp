import 'dart:math' as math;

/// Horas de sol de un día en un lugar. Todas en UTC; quien las enseña las
/// pasa a la hora del lugar. Nulas donde ese día el sol no llega a esa
/// altura (verano o invierno polar).
class SunTimes {
  /// Empieza a clarear (sol a 6° bajo el horizonte): inicio de la hora azul.
  final DateTime? dawn;
  final DateTime? sunrise;
  final DateTime? solarNoon;
  final DateTime? sunset;

  /// Noche cerrada para rodar: fin de la hora azul de la tarde.
  final DateTime? dusk;

  /// La hora azul de la mañana acaba y empieza la dorada (sol a −4°).
  final DateTime? blueHourMorningEnd;

  /// Fin de la hora dorada de la mañana (sol a 6° sobre el horizonte).
  final DateTime? goldenHourMorningEnd;

  /// Empieza la hora dorada de la tarde (sol a 6°).
  final DateTime? goldenHourEveningStart;

  /// Empieza la hora azul de la tarde (sol a −4°).
  final DateTime? blueHourEveningStart;

  const SunTimes({
    this.dawn,
    this.sunrise,
    this.solarNoon,
    this.sunset,
    this.dusk,
    this.blueHourMorningEnd,
    this.goldenHourMorningEnd,
    this.goldenHourEveningStart,
    this.blueHourEveningStart,
  });
}

/// Posición del sol con las fórmulas de la NOAA. Sin conexión y para
/// cualquier fecha; el error es de un par de minutos.
abstract final class SunCalculator {
  static const _rad = math.pi / 180;
  static const _obliquity = 23.4397;

  /// Día juliano entero de una fecha de calendario (a mediodía UTC).
  static int _julianDay(int year, int month, int day) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
  }

  static DateTime _fromJulian(double jd) => DateTime.fromMillisecondsSinceEpoch(
    ((jd - 2440587.5) * 86400000).round(),
    isUtc: true,
  );

  /// Horas de sol del día [year]-[month]-[day] (fecha del lugar) en
  /// [latitude], [longitude] (grados; este y norte positivos).
  static SunTimes forDate({
    required int year,
    required int month,
    required int day,
    required double latitude,
    required double longitude,
  }) {
    final n = _julianDay(year, month, day) - 2451545.0 + 0.0008;
    final jStar = n - longitude / 360;
    final m = (357.5291 + 0.98560028 * jStar) % 360;
    final c =
        1.9148 * math.sin(m * _rad) +
        0.02 * math.sin(2 * m * _rad) +
        0.0003 * math.sin(3 * m * _rad);
    final lambda = (m + c + 180 + 102.9372) % 360;
    final transit =
        2451545.0 +
        jStar +
        0.0053 * math.sin(m * _rad) -
        0.0069 * math.sin(2 * lambda * _rad);
    final sinDec = math.sin(lambda * _rad) * math.sin(_obliquity * _rad);
    final cosDec = math.cos(math.asin(sinDec));

    /// Momento en que el sol pasa por [altitude] grados, antes o después
    /// del mediodía.
    DateTime? at(double altitude, {required bool morning}) {
      final cosH =
          (math.sin(altitude * _rad) - math.sin(latitude * _rad) * sinDec) /
          (math.cos(latitude * _rad) * cosDec);
      if (cosH < -1 || cosH > 1) return null;
      final h = math.acos(cosH) / _rad;
      return _fromJulian(morning ? transit - h / 360 : transit + h / 360);
    }

    // −0,833°: el borde superior del sol en el horizonte, con refracción.
    return SunTimes(
      dawn: at(-6, morning: true),
      blueHourMorningEnd: at(-4, morning: true),
      sunrise: at(-0.833, morning: true),
      goldenHourMorningEnd: at(6, morning: true),
      solarNoon: _fromJulian(transit),
      goldenHourEveningStart: at(6, morning: false),
      sunset: at(-0.833, morning: false),
      blueHourEveningStart: at(-4, morning: false),
      dusk: at(-6, morning: false),
    );
  }

  /// Dónde está el sol en un instante: acimut (grados desde el norte, en
  /// el sentido del reloj) y altura sobre el horizonte (grados).
  static ({double azimuth, double altitude}) position(
    DateTime utc,
    double latitude,
    double longitude,
  ) {
    final jd = utc.toUtc().millisecondsSinceEpoch / 86400000 + 2440587.5;
    final n = jd - 2451545.0;
    final m = (357.5291 + 0.98560028 * n) % 360;
    final c =
        1.9148 * math.sin(m * _rad) +
        0.02 * math.sin(2 * m * _rad) +
        0.0003 * math.sin(3 * m * _rad);
    final lambda = (m + c + 180 + 102.9372) % 360;
    final e = _obliquity * _rad;
    final dec = math.asin(math.sin(lambda * _rad) * math.sin(e));
    final ra = math.atan2(
      math.sin(lambda * _rad) * math.cos(e),
      math.cos(lambda * _rad),
    );
    final sidereal = (280.16 + 360.9856235 * n + longitude) * _rad;
    final h = sidereal - ra;
    final phi = latitude * _rad;
    final altitude = math.asin(
      math.sin(phi) * math.sin(dec) +
          math.cos(phi) * math.cos(dec) * math.cos(h),
    );
    // Desde el sur hacia el oeste; se pasa a desde el norte.
    final fromSouth = math.atan2(
      math.sin(h),
      math.cos(h) * math.sin(phi) - math.tan(dec) * math.cos(phi),
    );
    return (azimuth: (fromSouth / _rad + 180) % 360, altitude: altitude / _rad);
  }

  /// El recorrido del sol en un día del lugar: por dónde sale y se pone,
  /// lo alto que llega y su camino, cada media hora con el sol fuera.
  static SunDayPath dayPath({
    required int year,
    required int month,
    required int day,
    required double latitude,
    required double longitude,
  }) {
    final times = forDate(
      year: year,
      month: month,
      day: day,
      latitude: latitude,
      longitude: longitude,
    );
    double? azAt(DateTime? t) =>
        t == null ? null : position(t, latitude, longitude).azimuth;
    final noon = times.solarNoon;
    final points = <({double azimuth, double altitude})>[];
    final start = times.sunrise ?? noon?.subtract(const Duration(hours: 12));
    final end = times.sunset ?? noon?.add(const Duration(hours: 12));
    if (start != null && end != null) {
      for (
        var t = start;
        !t.isAfter(end);
        t = t.add(const Duration(minutes: 30))
      ) {
        final p = position(t, latitude, longitude);
        if (p.altitude > -1) points.add(p);
      }
      points.add(position(end, latitude, longitude));
    }
    return SunDayPath(
      times: times,
      sunriseAzimuth: azAt(times.sunrise),
      sunsetAzimuth: azAt(times.sunset),
      noonAltitude: noon == null
          ? null
          : position(noon, latitude, longitude).altitude,
      path: points,
    );
  }
}

/// El sol de un día en un lugar, para dibujarlo.
class SunDayPath {
  final SunTimes times;
  final double? sunriseAzimuth;
  final double? sunsetAzimuth;
  final double? noonAltitude;
  final List<({double azimuth, double altitude})> path;

  const SunDayPath({
    required this.times,
    required this.sunriseAzimuth,
    required this.sunsetAzimuth,
    required this.noonAltitude,
    required this.path,
  });

  /// Largo de la sombra a mediodía por cada metro de altura.
  double? get noonShadow {
    final alt = noonAltitude;
    if (alt == null || alt <= 0) return null;
    return 1 / math.tan(alt * math.pi / 180);
  }
}

/// «NE», «SO»…: el rumbo de un acimut.
String compassPoint(double azimuth) {
  const names = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
  return names[((azimuth % 360) / 45).round() % 8];
}
