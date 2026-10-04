import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';

/// Cómo emite una luz en la planta: apertura, alcance, intensidad y color.
/// Los valores viven en `PlanElement.props`; lo que falte sale del tipo.
class LightBeam {
  /// Apertura del haz en grados. 360 = luz en todas direcciones.
  final double spread;

  /// Alcance del haz, en unidades del lienzo.
  final double reach;

  /// 0–100.
  final double intensity;

  /// Temperatura de color en kelvin.
  final double cct;
  final bool off;

  const LightBeam({
    required this.spread,
    required this.reach,
    required this.intensity,
    required this.cct,
    required this.off,
  });

  static const spreadKey = 'spread';
  static const reachKey = 'throw';
  static const intensityKey = 'intensity';
  static const cctKey = 'cct';
  static const offKey = 'off';

  /// Grip y accesorios: modifican la luz, no la emiten.
  static bool emits(LightType? type) => switch (type) {
    LightType.bounce ||
    LightType.flag ||
    LightType.cutter ||
    LightType.diffusionFrame ||
    LightType.net ||
    LightType.gel ||
    LightType.cStand ||
    LightType.generator => false,
    _ => true,
  };

  static ({double spread, double reach, double cct}) defaultsFor(
    LightType? type,
  ) => switch (type) {
    LightType.sun => (spread: 30, reach: 700, cct: 5600),
    LightType.fresnelSmall => (spread: 40, reach: 240, cct: 3200),
    LightType.fresnelMedium => (spread: 40, reach: 320, cct: 3200),
    LightType.fresnelLarge => (spread: 40, reach: 420, cct: 3200),
    LightType.hmi => (spread: 45, reach: 480, cct: 5600),
    LightType.ellipsoidal => (spread: 26, reach: 380, cct: 3200),
    LightType.par => (spread: 30, reach: 340, cct: 3200),
    LightType.openFace => (spread: 70, reach: 280, cct: 3200),
    LightType.flo4Tubes ||
    LightType.flo2Tubes ||
    LightType.floSingle => (spread: 110, reach: 180, cct: 5600),
    LightType.lightPanel ||
    LightType.led ||
    LightType.led1x1 => (spread: 100, reach: 220, cct: 5600),
    LightType.softbox ||
    LightType.chimera ||
    LightType.octagon => (spread: 100, reach: 240, cct: 5600),
    LightType.scoop || LightType.cyc => (spread: 120, reach: 220, cct: 3200),
    LightType.practical => (spread: 360, reach: 110, cct: 2800),
    _ => (spread: 60, reach: 260, cct: 5600),
  };

  /// El haz de una luz, o `null` si el elemento no emite.
  static LightBeam? of(PlanElement el) {
    if (el.type != ElementType.light || !emits(el.lightType)) return null;
    final d = defaultsFor(el.lightType);
    double read(String key, double fallback) =>
        (el.props[key] as num?)?.toDouble() ?? fallback;
    return LightBeam(
      spread: read(spreadKey, d.spread).clamp(5, 360),
      reach: read(reachKey, d.reach).clamp(20, 2000),
      intensity: read(intensityKey, 75).clamp(0, 100),
      cct: read(cctKey, d.cct).clamp(1800, 12000),
      off: el.props[offKey] == true,
    );
  }

  Color get color => colorForCct(cct);

  /// Color aproximado de una fuente a esa temperatura (Tanner Helland).
  static Color colorForCct(double kelvin) {
    final t = kelvin.clamp(1000, 40000) / 100;
    double r, g, b;
    if (t <= 66) {
      r = 255;
      g = 99.4708025861 * math.log(t) - 161.1195681661;
      b = t <= 19 ? 0 : 138.5177312231 * math.log(t - 10) - 305.0447927307;
    } else {
      r = 329.698727446 * math.pow(t - 60, -0.1332047592);
      g = 288.1221695283 * math.pow(t - 60, -0.0755148492);
      b = 255;
    }
    int c(double v) => v.clamp(0, 255).round();
    return Color.fromARGB(255, c(r), c(g), c(b));
  }
}

/// Ángulo de visión horizontal de una cámara, en grados, a partir de la
/// focal escrita («35mm», «50») y el ancho de sensor. Sin focal legible,
/// `null`.
double? cameraFovDegrees(String? lens, {double sensorWidthMm = 24.89}) {
  if (lens == null) return null;
  final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(lens);
  if (match == null) return null;
  final focal = double.tryParse(match.group(1)!.replaceAll(',', '.'));
  if (focal == null || focal <= 0) return null;
  return 2 * math.atan(sensorWidthMm / (2 * focal)) * 180 / math.pi;
}
