import 'dart:math' as math;
import 'dart:ui';

import '../camera_plan_element_model.dart';
import 'exposure.dart';
import 'light_scene.dart';
import 'photometry.dart';

/// Ajustes de exposición de una cámara de la planta. Viven en sus `props`.
class CameraExposure {
  CameraExposure._();

  static const isoKey = 'iso';
  static const shutterKey = 'shutterDeg';
  static const fpsKey = 'fps';
  static const ndKey = 'nd';
  static const stopKey = 'tStop';

  /// Diafragma de trabajo si la cámara no dice otro.
  static const double defaultStop = 2.8;

  static ExposureSettings settingsOf(PlanElement? camera) {
    double read(String key, double fallback) =>
        (camera?.props[key] as num?)?.toDouble() ?? fallback;
    return ExposureSettings(
      iso: read(isoKey, 800),
      shutterDeg: read(shutterKey, 180),
      fps: read(fpsKey, 24),
      ndStops: read(ndKey, 0),
    );
  }

  /// Diafragma al que se quiere rodar.
  static double stopOf(PlanElement? camera) =>
      (camera?.props[stopKey] as num?)?.toDouble() ?? defaultStop;

  /// «2.8», «T4», «f/5,6» → 2.8, 4, 5.6.
  static double? parseStop(String? text) {
    if (text == null) return null;
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(text);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    return value == null || value <= 0 ? null : value;
  }
}

/// Luz que llega a un punto por un lado.
class MeterSide {
  final double lux;

  /// Parte de esa luz que sale de un dato estimado.
  final bool estimated;

  const MeterSide(this.lux, {this.estimated = false});
}

/// Lo que lee un fotómetro en un punto de la planta.
class MeterReading {
  final Offset point;
  final double lux;

  /// Diafragma que expone esa luz con los ajustes de la cámara.
  final double stop;

  /// Stops respecto al diafragma de trabajo: positivo = sobra luz.
  final double stopsOverTarget;
  final double targetStop;

  /// Temperatura de color de la mezcla; `null` si no llega luz.
  final double? cct;
  final List<LightContribution> parts;

  /// Luz por la izquierda y la derecha de cámara, y por detrás del sujeto.
  final MeterSide left;
  final MeterSide right;
  final MeterSide back;

  /// Si hay cámara para saber cuál es la izquierda y cuál la derecha.
  final bool hasCamera;

  /// Algún dato de los que suman sale de una estimación.
  final bool estimated;

  const MeterReading({
    required this.point,
    required this.lux,
    required this.stop,
    required this.stopsOverTarget,
    required this.targetStop,
    required this.cct,
    required this.parts,
    required this.left,
    required this.right,
    required this.back,
    required this.hasCamera,
    required this.estimated,
  });

  bool get keyIsLeft => left.lux >= right.lux;
  MeterSide get key => keyIsLeft ? left : right;
  MeterSide get fill => keyIsLeft ? right : left;

  /// Stops entre la clave y el relleno.
  double get contrastStops => stopsBetweenLux(key.lux, fill.lux);

  /// «2:1», «4:1»… o «sin relleno».
  String get ratioLabel {
    if (key.lux <= 0.5) return '—';
    if (fill.lux <= 0.5) return 'sin relleno';
    final ratio = key.lux / fill.lux;
    if (ratio <= 1.15) return '1:1';
    if (ratio > 32) return 'más de 32:1';
    final rounded = ratio < 8 ? (ratio * 2).round() / 2 : ratio.roundToDouble();
    final text = rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
    return '$text:1';
  }

  /// «T2.8 · 850 lx».
  String get shortLabel => '${formatStop(stop)} · ${formatLux(lux)}';

  /// Mide en un punto. Con [camera], separa la luz en izquierda, derecha y
  /// contra respecto a ella: lo que llega a más de 110° de la cámara, visto
  /// desde el sujeto, es contra.
  factory MeterReading.at(
    LightScene scene,
    Offset point, {
    PlanElement? camera,
    ExposureSettings? exposure,
    double? targetStop,
  }) {
    final settings = exposure ?? CameraExposure.settingsOf(camera);
    final target = targetStop ?? CameraExposure.stopOf(camera);
    final parts = scene.contributionsAt(point);

    var total = 0.0;
    var mired = 0.0;
    var left = 0.0, right = 0.0, back = 0.0;
    var leftEst = false, rightEst = false, backEst = false;
    var estimated = false;

    final toCamera = camera == null ? null : camera.position - point;
    final hasCamera = toCamera != null && toCamera.distance > 1e-6;
    final cameraAngle = hasCamera ? math.atan2(toCamera.dy, toCamera.dx) : 0.0;

    for (final part in parts) {
      total += part.lux;
      mired += part.lux * 1e6 / part.cct;
      final est = part.light.source.status == PhotometryStatus.estimated;
      estimated = estimated || est;
      final toSource = part.light.position - point;
      if (!hasCamera || toSource.distance < 1e-6) {
        // Sin cámara no hay lados: se reparte.
        left += part.lux / 2;
        right += part.lux / 2;
        leftEst = leftEst || est;
        rightEst = rightEst || est;
        continue;
      }
      var delta = math.atan2(toSource.dy, toSource.dx) - cameraAngle;
      while (delta > math.pi) {
        delta -= 2 * math.pi;
      }
      while (delta < -math.pi) {
        delta += 2 * math.pi;
      }
      final degrees = delta * 180 / math.pi;
      if (degrees.abs() > 110) {
        back += part.lux;
        backEst = backEst || est;
      } else if (degrees > 0) {
        // Con la y hacia abajo, un giro positivo desde la cámara cae a su
        // izquierda (la cámara mira al sujeto).
        left += part.lux;
        leftEst = leftEst || est;
      } else {
        right += part.lux;
        rightEst = rightEst || est;
      }
    }

    final stop = settings.stopFor(total);
    return MeterReading(
      point: point,
      lux: total,
      stop: stop,
      stopsOverTarget: total <= 0 ? 0 : stopsBetweenApertures(stop, target),
      targetStop: target,
      cct: total <= 0 ? null : 1e6 / (mired / total),
      parts: parts,
      left: MeterSide(left, estimated: leftEst),
      right: MeterSide(right, estimated: rightEst),
      back: MeterSide(back, estimated: backEst),
      hasCamera: hasCamera,
      estimated: estimated,
    );
  }
}

/// Color del mapa de exposición para una diferencia en stops respecto al
/// diafragma de trabajo: azul si falta luz, verde en su punto, rojo si
/// sobra.
Color exposureColor(double stopsOverTarget) {
  const scale = <(double, Color)>[
    (-5, Color(0xFF1B1464)),
    (-3, Color(0xFF2456C7)),
    (-1.5, Color(0xFF1FA7A0)),
    (0, Color(0xFF3FBF4A)),
    (1.5, Color(0xFFE8D33F)),
    (3, Color(0xFFF08A24)),
    (5, Color(0xFFD9342B)),
  ];
  if (stopsOverTarget <= scale.first.$1) return scale.first.$2;
  for (var i = 1; i < scale.length; i++) {
    if (stopsOverTarget <= scale[i].$1) {
      final (a, ca) = scale[i - 1];
      final (b, cb) = scale[i];
      return Color.lerp(ca, cb, (stopsOverTarget - a) / (b - a))!;
    }
  }
  return scale.last.$2;
}
