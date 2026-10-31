import 'dart:math' as math;
import 'dart:ui';

import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/plan_light.dart';

/// Hacia dónde mira la cámara de rodaje y a qué enfoca (F6.22.4): altura del
/// objetivo, paneo (el giro en planta), inclinación, giro sobre su eje y
/// distancia de foco. Viven en sus `props` y los usan el 3D y Unreal.
abstract final class CameraAim {
  static const tiltKey = 'camTilt';
  static const rollKey = 'camRoll';
  static const focusKey = 'focusM';

  /// Altura del objetivo sin altura propia: cámara al hombro.
  static const double defaultHeightM = 1.5;

  static double heightM(PlanElement el) =>
      (el.props[PlanLight.heightKey] as num?)?.toDouble() ?? defaultHeightM;

  /// Inclinación, en grados: positiva hacia arriba (contrapicado), negativa
  /// hacia abajo (picado).
  static double tiltDeg(PlanElement el) =>
      ((el.props[tiltKey] as num?)?.toDouble() ?? 0).clamp(-90.0, 90.0);

  /// Giro sobre su eje (plano holandés), en grados.
  static double rollDeg(PlanElement el) =>
      ((el.props[rollKey] as num?)?.toDouble() ?? 0).clamp(-90.0, 90.0);

  /// Distancia de foco propia, en metros, o `null` si se calcula.
  static double? ownFocusM(PlanElement el) =>
      (el.props[focusKey] as num?)?.toDouble();

  /// A qué distancia enfoca: la propia o, si no, la del actor más cercano
  /// que tiene delante (dentro de 30°), o 3 m si no hay ninguno.
  static double focusM(
    PlanElement camera,
    Iterable<PlanElement> elements,
    double metersPerUnit,
  ) {
    final own = ownFocusM(camera);
    if (own != null) return own;
    final rad = camera.rotation * math.pi / 180;
    // En el lienzo la cámara mira a (sin r, −cos r).
    final ahead = Offset(math.sin(rad), -math.cos(rad));
    double? best;
    for (final el in elements) {
      if (el.type != ElementType.actor) continue;
      final to = el.position - camera.position;
      final d = to.distance;
      if (d < 1e-6) continue;
      final cos = (to.dx * ahead.dx + to.dy * ahead.dy) / d;
      if (cos < math.cos(30 * math.pi / 180)) continue;
      final m = d * metersPerUnit;
      if (best == null || m < best) best = m;
    }
    return best ?? 3;
  }
}
