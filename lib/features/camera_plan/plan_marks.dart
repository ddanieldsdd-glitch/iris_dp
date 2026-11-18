import 'dart:ui';

import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light_beam.dart';
import 'light_overrides.dart';

/// Posiciones (marcas) de un actor o de una cámara: por dónde pasa durante
/// el plano y hacia dónde mira en cada sitio.
///
/// La primera es el propio elemento. Las demás van en `pathPoints`, y el
/// giro de cada una en `props['pathRot']`, en el mismo orden.
class PlanMarks {
  PlanMarks._();

  static const rotKey = 'pathRot';

  /// En una viñeta de un tramo de documento, cuántas posiciones van antes
  /// de la primera que se ve: sus números siguen los del plano.
  static const fromKey = 'markFrom';
  static const poseKey = 'pose';
  static const poseStand = 'stand';
  static const poseSit = 'sit';
  static const poseLie = 'lie';

  static bool supports(PlanElement el) =>
      el.type == ElementType.camera || el.type == ElementType.actor;

  /// Lo que puede tener posiciones: cámaras, actores y, ajustados en un
  /// plano, los focos que se mueven o cambian en caliente (PL.3).
  static bool canMark(PlanElement el) =>
      supports(el) || el.type == ElementType.light;

  /// Cambios de un foco en cada posición: una lista alineada con
  /// `pathPoints`, con lo que cambia al llegar a ella (intensidad, color,
  /// temperatura, apertura, apagado). Lo que no cambia sigue como antes.
  static const lightKey = 'markLight';
  static const lightValueKeys = {
    LightBeam.intensityKey,
    LightBeam.cctKey,
    LightBeam.rgbKey,
    LightBeam.spreadKey,
    LightBeam.offKey,
  };

  static List<Map<String, dynamic>> _lightChanges(PlanElement el) => [
    for (final v in (el.props[lightKey] as List? ?? const []))
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{},
  ];

  static void _storeLight(PlanElement el, List<Map<String, dynamic>> list) {
    final trimmed = list.take(el.pathPoints.length).toList();
    while (trimmed.isNotEmpty && trimmed.last.isEmpty) {
      trimmed.removeLast();
    }
    if (trimmed.isEmpty) {
      el.props.remove(lightKey);
    } else {
      el.props[lightKey] = trimmed;
    }
  }

  /// Lo que cambia el foco al llegar a la marca [index] de `pathPoints`.
  static Map<String, dynamic> lightChangeAt(PlanElement el, int index) {
    final list = _lightChanges(el);
    return index >= 0 && index < list.length ? list[index] : const {};
  }

  /// Cambia [key] del foco desde la marca [index]; nulo lo quita (sigue
  /// como en la anterior).
  static void setLightAt(PlanElement el, int index, String key, Object? v) {
    if (index < 0 || index >= el.pathPoints.length) return;
    final list = _lightChanges(el);
    while (list.length <= index) {
      list.add({});
    }
    if (v == null) {
      list[index].remove(key);
    } else {
      list[index][key] = v;
    }
    _storeLight(el, list);
  }

  /// Cuántas posiciones tiene: la suya y las de `pathPoints`.
  static int positionsOf(PlanElement el) => 1 + el.pathPoints.length;

  /// Cómo está en la posición [position] (0 es la primera, la suya): una
  /// copia en esa marca, mirando hacia donde mira en ella y, si es un foco,
  /// con los cambios que lleva hasta ahí. Quien tiene menos posiciones se
  /// queda en su última.
  static PlanElement atPosition(PlanElement el, int position) {
    if (position <= 0 || el.pathPoints.isEmpty || !canMark(el)) return el;
    final at = position > el.pathPoints.length
        ? el.pathPoints.length
        : position;
    final copy = LightOverrides.clone(el)
      ..position = el.pathPoints[at - 1]
      ..rotation = rotationAt(el, at - 1)
      ..pathPoints = []
      ..shotOverride = el.shotOverride
      ..layer = el.layer;
    copy.props.remove(rotKey);
    copy.props.remove(lightKey);
    final changes = _lightChanges(el);
    for (var i = 0; i < at && i < changes.length; i++) {
      for (final entry in changes[i].entries) {
        if (!lightValueKeys.contains(entry.key)) continue;
        if (entry.value == null) {
          copy.props.remove(entry.key);
        } else {
          copy.props[entry.key] = entry.value;
        }
      }
    }
    return copy;
  }

  /// Los cambios de un foco al pasar de la posición [index] a la
  /// siguiente, para el PDF: «50 % → 100 %», «apagado».
  static List<String> lightChangeLabels(PlanElement el, int index) {
    final change = lightChangeAt(el, index);
    if (change.isEmpty) return const [];
    final before = atPosition(el, index);
    final after = atPosition(el, index + 1);
    final out = <String>[];
    final b = LightBeam.of(before);
    final a = LightBeam.of(after);
    if (a == null || b == null) return const [];
    if (a.off != b.off) {
      out.add(a.off ? 'se apaga' : 'se enciende');
    }
    if (!a.off && a.intensity.round() != b.intensity.round()) {
      out.add('${b.intensity.round()} % → ${a.intensity.round()} %');
    }
    if (!a.off && a.rgb == null && a.cct.round() != b.cct.round()) {
      out.add('${b.cct.round()} K → ${a.cct.round()} K');
    }
    if (!a.off && a.rgb != b.rgb && a.rgb != null) out.add('cambia de color');
    if (!a.off && a.spread.round() != b.spread.round()) {
      out.add('apertura ${a.spread.round()}°');
    }
    return out;
  }
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
    final lights = _lightChanges(el);
    el.pathPoints.removeAt(index);
    if (index < rotations.length) rotations.removeAt(index);
    if (index < lights.length) lights.removeAt(index);
    _store(el, rotations);
    _storeLight(el, lights);
  }

  static void clear(PlanElement el) {
    el.pathPoints.clear();
    el.props.remove(rotKey);
    el.props.remove(lightKey);
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
