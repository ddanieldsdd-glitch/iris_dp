import 'dart:math' as math;

import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../light/plan_light.dart';
import '../plan_segment.dart';
import 'plan_rig.dart';
import 'plan_scene3d.dart';

/// Posición, giro y alturas de un elemento en metros y grados, con los
/// mismos ejes que el 3D: x a la derecha e y hacia el fondo de la planta.
/// Es lo que edita el panel «Transformar» y lo que mandan el aro y la
/// flecha del visor.
class PlanTransform {
  PlanTransform._();

  /// Las paredes y demás tramos se editan por sus puntos, no por aquí.
  static bool applies(PlanElement el) => !PlanSegment.isSegment(el);

  static bool canRotate(PlanElement el) =>
      applies(el) && !PlanRigPoint.isRigPoint(el) && !PlanTruss.isTruss(el);

  /// Focos y cámaras tienen altura propia sobre su suelo.
  static bool hasHeight(PlanElement el) =>
      el.type == ElementType.light || el.type == ElementType.camera;

  static ({double x, double y}) xyM(PlanElement el, double metersPerUnit) =>
      (x: el.position.dx * metersPerUnit, y: -el.position.dy * metersPerUnit);

  /// Lleva el elemento a (x, y) en metros. Un motor o una torre se quedan
  /// en su truss. Devuelve si se ha movido.
  static bool setXY(
    PlanElement el,
    double x,
    double y,
    List<PlanElement> elements,
    double metersPerUnit,
  ) {
    final now = xyM(el, metersPerUnit);
    final dx = x - now.x, dy = y - now.y;
    if (dx.abs() < 1e-6 && dy.abs() < 1e-6) return false;
    return PlanScene3d.moveBy(el, dx, dy, elements, metersPerUnit);
  }

  /// Giro en planta, de 0 a 360°.
  static double rotationDeg(PlanElement el) => _wrap(el.rotation);

  static void setRotation(PlanElement el, double deg) =>
      el.rotation = _round(_wrap(deg), 10);

  static double _wrap(double deg) => ((deg % 360) + 360) % 360;

  /// Altura del foco o la cámara sobre su suelo.
  static double heightM(PlanElement el) => PlanLight.heightOf(el);

  static void setHeight(PlanElement el, double meters) =>
      el.props[PlanLight.heightKey] = _round(math.max(0, meters), 100);

  /// Cota del suelo sobre el que está (una tarima, un primer piso).
  static double levelM(PlanElement el) => PlanLevel.of(el);

  static void setLevel(PlanElement el, double meters) =>
      PlanLevel.set(el, _round(meters.clamp(-20.0, 200.0), 100));

  /// Lo que manda la flecha vertical del visor: sube el foco o la cámara;
  /// lo demás sube con su suelo.
  static void liftBy(PlanElement el, double dz) {
    if (hasHeight(el)) {
      setHeight(el, heightM(el) + dz);
    } else {
      setLevel(el, levelM(el) + dz);
    }
  }

  static double _round(double v, int per) => (v * per).round() / per;

}
