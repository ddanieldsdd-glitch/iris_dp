import 'dart:ui';

import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';

/// Posiciones (marcas) de un actor o de una cámara: por dónde pasa durante
/// el plano y hacia dónde mira en cada sitio.
///
/// La primera es el propio elemento. Las demás van en `pathPoints`, y el
/// giro de cada una en `props['pathRot']`, en el mismo orden.
class PlanMarks {
  PlanMarks._();

  static const rotKey = 'pathRot';
  static const poseKey = 'pose';
  static const poseStand = 'stand';
  static const poseSit = 'sit';
  static const poseLie = 'lie';

  static bool supports(PlanElement el) =>
      el.type == ElementType.camera || el.type == ElementType.actor;

  static List<double?> _rotations(PlanElement el) => [
    for (final v in (el.props[rotKey] as List? ?? const []))
      (v as num?)?.toDouble(),
  ];

  static void _store(PlanElement el, List<double?> rotations) {
    final trimmed = rotations.take(el.pathPoints.length).toList();
    if (trimmed.every((r) => r == null)) {
      el.props.remove(rotKey);
    } else {
      el.props[rotKey] = trimmed;
    }
  }

  /// Hacia dónde mira en la marca [index] de `pathPoints`. Sin giro
  /// propio, como en la posición anterior.
  static double rotationAt(PlanElement el, int index) {
    final rotations = _rotations(el);
    for (var i = index; i >= 0; i--) {
      if (i < rotations.length && rotations[i] != null) return rotations[i]!;
    }
    return el.rotation;
  }

  static void setRotation(PlanElement el, int index, double degrees) {
    if (index < 0 || index >= el.pathPoints.length) return;
    final rotations = _rotations(el);
    while (rotations.length <= index) {
      rotations.add(null);
    }
    rotations[index] = (degrees % 360 + 360) % 360;
    _store(el, rotations);
  }

  /// Añade una marca; mira hacia donde miraba en la anterior.
  static void add(PlanElement el, Offset at) {
    el.pathPoints.add(at);
  }

  static void removeAt(PlanElement el, int index) {
    if (index < 0 || index >= el.pathPoints.length) return;
    final rotations = _rotations(el);
    el.pathPoints.removeAt(index);
    if (index < rotations.length) rotations.removeAt(index);
    _store(el, rotations);
  }

  static void clear(PlanElement el) {
    el.pathPoints.clear();
    el.props.remove(rotKey);
  }

  /// Postura de un actor: de pie, sentado o tumbado.
  static String pose(PlanElement el) => switch (el.props[poseKey]) {
    poseSit => poseSit,
    poseLie => poseLie,
    _ => poseStand,
  };

  /// Altura hasta la que hace sombra un actor según su postura.
  static double heightM(PlanElement el) => switch (pose(el)) {
    poseSit => 1.3,
    poseLie => 0.35,
    _ => 1.75,
  };
}
