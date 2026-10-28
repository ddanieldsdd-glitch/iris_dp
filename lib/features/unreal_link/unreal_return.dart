import 'dart:math' as math;

import '../camera_plan/camera_plan_constants.dart';
import '../camera_plan/camera_plan_element_model.dart';
import '../camera_plan/light/plan_light.dart';
import '../camera_plan/light_beam.dart';
import '../camera_plan/rig/plan_rig.dart';
import '../camera_plan/rig/plan_scene3d.dart';
import 'unreal_stage_payload.dart';

/// Un cambio hecho en Unreal a una pieza de IRIS: lo que está ahora en
/// Unreal y lo que IRIS había mandado. Solo lleva lo que ha cambiado.
class UnrealEdit {
  final String id;

  /// 'lights', 'cameras' o 'props'.
  final String kind;
  bool get camera => kind == 'cameras';

  /// Lo que IRIS mandó de esta pieza (unidades de Unreal).
  final Map sent;
  final List<double>? loc;
  final List<double>? rot;
  final double? cd;
  final double? cct;
  bool _claimed = false;

  /// Lo aplica quien lo pide primero: con el 3D abierto en el panel y a
  /// pantalla entera, el cambio no se aplica dos veces.
  bool claim() {
    if (_claimed) return false;
    return _claimed = true;
  }

  UnrealEdit({
    required this.id,
    required this.kind,
    required this.sent,
    this.loc,
    this.rot,
    this.cd,
    this.cct,
  });

  @override
  String toString() =>
      'UnrealEdit($id${loc != null ? ' loc' : ''}${rot != null ? ' rot' : ''}'
      '${cd != null ? ' cd' : ''}${cct != null ? ' cct' : ''})';
}

/// De Unreal a la planta (F6.16.10): qué ha cambiado allí y cómo se lleva
/// a los elementos de IRIS.
class UnrealReturn {
  UnrealReturn._();

  /// Márgenes por debajo de los cuales no es un cambio (redondeos).
  static const double locCm = 1, rotDeg = 0.5, cctK = 10;

  static List<double> _nums(Object? v) => [
    for (final n in (v as List? ?? const [])) (n as num).toDouble(),
  ];

  static double _angle(double a, double b) {
    final d = (a - b).abs() % 360;
    return d > 180 ? 360 - d : d;
  }

  /// Compara lo que hay en Unreal ([actors], de `Snapshot`) con lo último
  /// que mandó IRIS ([applied], de [UnrealStagePayload.build]).
  static List<UnrealEdit> detect(Map<String, dynamic> applied, Map actors) {
    final edits = <UnrealEdit>[];
    for (final kind in UnrealStagePayload.kinds) {
      for (final sent in (applied[kind] as List? ?? const []).cast<Map>()) {
        final now = actors['${sent['id']}'];
        if (now is! Map) continue;
        final loc = _nums(now['loc']), rot = _nums(now['rot']);
        final sLoc = _nums(sent['loc']), sRot = _nums(sent['rot']);
        // El atrezzo solo se mueve y gira en planta.
        final flat = kind == 'props';
        final moved =
            loc.length == 3 &&
            sLoc.length == 3 &&
            [
              for (var i = 0; i < (flat ? 2 : 3); i++) (loc[i] - sLoc[i]).abs(),
            ].any((d) => d > locCm);
        final turned =
            rot.length >= 2 &&
            sRot.length >= 2 &&
            ((!flat && _angle(rot[0], sRot[0]) > rotDeg) ||
                _angle(rot[1], sRot[1]) > rotDeg);
        double? cd, cct;
        if (kind == 'lights') {
          final expected = sent['on'] == true
              ? ((sent['cd'] ?? 0) as num).toDouble()
              : 0.0;
          final got = (now['intensity'] as num?)?.toDouble();
          if (got != null &&
              (got - expected).abs() > math.max(1, expected * 0.01)) {
            cd = got;
          }
          final gotCct = (now['cct'] as num?)?.toDouble();
          final sentCct = ((sent['cct'] ?? 0) as num).toDouble();
          if (gotCct != null && (gotCct - sentCct).abs() > cctK) cct = gotCct;
        }
        if (!moved && !turned && cd == null && cct == null) continue;
        edits.add(
          UnrealEdit(
            id: '${sent['id']}',
            kind: kind,
            sent: sent,
            loc: moved ? loc : null,
            rot: turned ? rot : null,
            cd: cd,
            cct: cct,
          ),
        );
      }
    }
    return edits;
  }

  /// Aplica [edit] a [el]. Devuelve si ha cambiado algo.
  static bool apply(
    PlanElement el,
    UnrealEdit edit,
    List<PlanElement> elements,
    double metersPerUnit,
  ) {
    var changed = false;
    final sLoc = _nums(edit.sent['loc']);
    final loc = edit.loc ?? sLoc;
    if (edit.loc case final now?) {
      final dx = (now[0] - sLoc[0]) / 100, dy = -(now[1] - sLoc[1]) / 100;
      if (dx.abs() > 0.005 || dy.abs() > 0.005) {
        changed |= PlanScene3d.moveBy(el, dx, dy, elements, metersPerUnit);
      }
      // En el atrezzo «height» es su alto, no a qué altura está: subir una
      // pieza en Unreal no cambia nada en la planta.
      if (edit.kind != 'props' && (now[2] - sLoc[2]).abs() > locCm) {
        final height = now[2] / 100 - PlanLevel.of(el);
        el.props[PlanLight.heightKey] = (height * 100).roundToDouble() / 100;
        changed = true;
      }
    }
    if (edit.rot case final rot?) {
      final d = UnrealStagePayload.dirOf(rot);
      if (edit.kind != 'lights') {
        // Cámara o pieza: hacia dónde mira en planta.
        final deg = math.atan2(d.x, d.y) * 180 / math.pi;
        el.rotation = ((deg % 360 + 360) % 360 * 2).roundToDouble() / 2;
      } else {
        // Apunta a un punto a 5 m en la dirección nueva.
        final x = loc[0] / 100, y = -loc[1] / 100, z = loc[2] / 100;
        PlanScene3d.aimAt(
          el,
          x + d.x * 5,
          y + d.y * 5,
          z + d.z * 5,
          metersPerUnit,
        );
      }
      changed = true;
    }
    if (el.type == ElementType.light) {
      if (edit.cd case final cd?) {
        final light = PlanLight.of(el);
        if (light != null) {
          final full = PlanLight.apply(
            light.bare,
            light.modifiers,
          ).candela;
          if (cd <= 0.5) {
            el.props[LightBeam.offKey] = true;
          } else {
            el.props.remove(LightBeam.offKey);
            el.props[LightBeam.intensityKey] = full <= 0
                ? 100.0
                : (cd / full * 100).clamp(1.0, 100.0).roundToDouble();
          }
          changed = true;
        }
      }
      if (edit.cct case final cct?) {
        final beam = LightBeam.of(el);
        if (beam != null) {
          // Lo que se ha movido en Unreal, sobre el color del aparato (las
          // gelatinas siguen delante).
          final sent = ((edit.sent['cct'] ?? beam.cct) as num).toDouble();
          el.props[LightBeam.cctKey] = ((beam.cct + cct - sent).clamp(
                    1800.0,
                    12000.0,
                  ) /
                  10)
              .roundToDouble() *
              10;
          changed = true;
        }
      }
    }
    return changed;
  }
}
