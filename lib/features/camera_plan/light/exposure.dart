import 'dart:math' as math;

/// Ajustes de cámara con los que se convierte la luz en diafragma.
class ExposureSettings {
  final double iso;

  /// Ángulo de obturación en grados.
  final double shutterDeg;
  final double fps;

  /// Filtro ND, en stops.
  final double ndStops;

  const ExposureSettings({
    this.iso = 800,
    this.shutterDeg = 180,
    this.fps = 24,
    this.ndStops = 0,
  });

  /// Tiempo de exposición en segundos.
  double get exposureTime => shutterDeg / (360 * fps);

  /// Constante de calibración de un fotómetro de luz incidente con
  /// semiesfera (la que usan los Sekonic): N² = E · ISO · t / C.
  static const double incidentConstant = 340;

  /// Diafragma que expone correctamente [lux] de luz incidente.
  double stopFor(double lux) {
    if (lux <= 0) return 0;
    final attenuation = math.pow(2, -ndStops).toDouble();
    return math.sqrt(lux * iso * exposureTime * attenuation / incidentConstant);
  }

  /// Lux que hacen falta para exponer a [stop].
  double luxFor(double stop) {
    final attenuation = math.pow(2, -ndStops).toDouble();
    return stop * stop * incidentConstant / (iso * exposureTime * attenuation);
  }

  ExposureSettings copyWith({
    double? iso,
    double? shutterDeg,
    double? fps,
    double? ndStops,
  }) => ExposureSettings(
    iso: iso ?? this.iso,
    shutterDeg: shutterDeg ?? this.shutterDeg,
    fps: fps ?? this.fps,
    ndStops: ndStops ?? this.ndStops,
  );
}

/// Diafragmas en tercios de stop.
const kThirdStops = <double>[
  1, 1.1, 1.2, 1.4, 1.6, 1.8, 2, 2.2, 2.5, 2.8, 3.2, 3.5, 4, 4.5, 5, 5.6, //
  6.3, 7.1, 8, 9, 10, 11, 13, 14, 16, 18, 20, 22, 25, 29, 32,
];

/// Stops de diferencia entre dos niveles de luz (positivo = [a] más luz).
double stopsBetweenLux(double a, double b) {
  if (a <= 0 || b <= 0) return 0;
  return math.log(a / b) / math.ln2;
}

/// Stops de diferencia entre dos diafragmas (positivo = [a] más cerrado, es
/// decir, hay más luz).
double stopsBetweenApertures(double a, double b) {
  if (a <= 0 || b <= 0) return 0;
  return 2 * math.log(a / b) / math.ln2;
}

/// «T2.8», redondeado al tercio de stop más cercano.
String formatStop(double stop, {String prefix = 'T'}) {
  if (stop <= 0.05) return '—';
  if (stop < 0.92) return '<${prefix}1';
  if (stop > 38) return '${prefix}32+';
  var best = kThirdStops.first;
  for (final candidate in kThirdStops) {
    if ((math.log(candidate / stop)).abs() < (math.log(best / stop)).abs()) {
      best = candidate;
    }
  }
  final text = best == best.roundToDouble()
      ? best.toStringAsFixed(0)
      : best.toString();
  return '$prefix$text';
}

/// «+1⅓», «−⅔», «0»: una diferencia en stops, en tercios.
String formatStopDifference(double stops) {
  final thirds = (stops * 3).round();
  if (thirds == 0) return '0';
  final sign = thirds > 0 ? '+' : '−';
  final whole = thirds.abs() ~/ 3;
  final rest = thirds.abs() % 3;
  final fraction = switch (rest) {
    1 => '⅓',
    2 => '⅔',
    _ => '',
  };
  return '$sign${whole > 0 ? whole : ''}$fraction';
}

/// «12,4k lx», «850 lx», «3,2 lx».
String formatLux(double lux) {
  if (lux >= 10000) return '${(lux / 1000).toStringAsFixed(1)}k lx';
  if (lux >= 100) return '${lux.round()} lx';
  if (lux >= 1) return '${lux.toStringAsFixed(1)} lx';
  if (lux > 0.05) return '${lux.toStringAsFixed(2)} lx';
  return '0 lx';
}
