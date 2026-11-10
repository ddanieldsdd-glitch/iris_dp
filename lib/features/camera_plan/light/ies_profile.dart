import 'dart:math' as math;

/// Lo que importa a la planta de un archivo fotométrico IES (LM-63) del
/// fabricante.
class IesProfile {
  /// Intensidad máxima, en candelas.
  final double peakCandela;

  /// Ángulo donde la intensidad cae a la mitad, en grados.
  final double beamDeg;

  /// Vatios de entrada; `null` si el archivo no los da.
  final double? inputWatts;

  const IesProfile({
    required this.peakCandela,
    required this.beamDeg,
    this.inputWatts,
  });

  /// Lee el texto de un `.ies`, o lanza [FormatException].
  static IesProfile parse(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final tilt = lines.indexWhere((l) => l.trimLeft().startsWith('TILT='));
    if (tilt < 0) throw const FormatException('No es un archivo IES.');
    final tiltValue = lines[tilt].trimLeft().substring(5).trim().toUpperCase();
    final numbers = <double>[
      for (final line in lines.skip(tilt + 1))
        for (final token in line.trim().split(RegExp(r'[\s,]+')))
          if (token.isNotEmpty) double.parse(token),
    ];
    var at = 0;
    if (tiltValue == 'INCLUDE') {
      // Geometría, número de ángulos, ángulos y factores.
      final count = numbers[1].toInt();
      at = 2 + count * 2;
    }
    double next() {
      if (at >= numbers.length) {
        throw const FormatException('El archivo IES está incompleto.');
      }
      return numbers[at++];
    }

    next(); // lámparas
    next(); // lúmenes por lámpara
    final multiplier = next();
    final nVertical = next().toInt();
    final nHorizontal = next().toInt();
    next(); // tipo fotométrico
    next(); // unidades
    next(); // ancho
    next(); // largo
    next(); // alto
    final ballast = next();
    next(); // reservado
    final watts = next();
    if (nVertical < 2 || nHorizontal < 1) {
      throw const FormatException('El archivo IES no trae ángulos.');
    }
    final vertical = [for (var i = 0; i < nVertical; i++) next()];
    for (var i = 0; i < nHorizontal; i++) {
      next();
    }
    final planes = [
      for (var h = 0; h < nHorizontal; h++)
        [for (var v = 0; v < nVertical; v++) next() * multiplier * ballast],
    ];
    final peak = planes.expand((p) => p).reduce(math.max);
    if (peak <= 0) {
      throw const FormatException('El archivo IES no da luz.');
    }
    final widths = [for (final p in planes) ?_beamOf(vertical, p)];
    if (widths.isEmpty) {
      throw const FormatException('El archivo IES no tiene haz medible.');
    }
    return IesProfile(
      peakCandela: peak,
      beamDeg: widths.reduce((a, b) => a + b) / widths.length,
      inputWatts: watts > 0 ? watts : null,
    );
  }

  /// Ancho a media intensidad de un plano. Si los ángulos empiezan en el
  /// máximo (el eje), lo medido es medio haz.
  static double? _beamOf(List<double> angles, List<double> values) {
    var top = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[top]) top = i;
    }
    if (values[top] <= 0) return null;
    final half = values[top] / 2;
    double? cross(int step) {
      for (var i = top; i + step >= 0 && i + step < values.length; i += step) {
        final a = values[i], b = values[i + step];
        if (b <= half) {
          final t = a == b ? 0.0 : (a - half) / (a - b);
          return angles[i] + (angles[i + step] - angles[i]) * t;
        }
      }
      return null;
    }

    final right = cross(1);
    final left = cross(-1);
    if (right == null && left == null) return 360;
    if (left == null) return (right! - angles[top]) * 2;
    if (right == null) return (angles[top] - left) * 2;
    return right - left;
  }
}
