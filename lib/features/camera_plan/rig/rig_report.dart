import 'dart:math' as math;

import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../light_overrides.dart';
import '../plan_gear_list.dart';
import 'plan_drape.dart';
import 'plan_hall.dart';
import 'plan_rig.dart';

/// Un aviso de rigging, con lo que lo provoca para poder seleccionarlo.
class RigWarning {
  final String text;
  final PlanElement element;

  /// `true` si hay que corregirlo; `false` si solo está al límite.
  final bool serious;

  const RigWarning(this.text, this.element, {this.serious = true});
}

/// Lo que el rigger necesita saber de la planta: el material (tramos,
/// esquinas, motores, torres, garras, eslingas, telas) y los avisos
/// (sobrecargas, truss que tocan la cubierta, cuerdas que tiran demasiado,
/// truss sin colgar).
class RigReport {
  RigReport._();

  /// Parte de la carga de trabajo a partir de la que se avisa.
  static const double nearLimit = 0.8;

  /// Tiro de una tela en un amarre a partir del que se avisa, en kg.
  static const double heavyPullKg = 150;

  /// Líneas de rigging para la lista de material.
  static List<GearLine> rigging(
    List<PlanElement> elements,
    double metersPerUnit,
  ) {
    final groups = <String, List<PlanElement>>{};
    final counts = <String, int>{};
    void add(String label, PlanElement el, [int n = 1]) {
      counts.update(label, (c) => c + n, ifAbsent: () => n);
      groups.putIfAbsent(label, () => []).add(el);
    }

    final trusses = elements.where(PlanTruss.isTruss).toList();
    for (final t in trusses) {
      final kind =
          '${_profileName(PlanTruss.profile(t))} ${PlanTruss.sizeCm(t)}';
      for (final piece in PlanTruss.pieces(t, metersPerUnit).pieces) {
        add('Truss $kind · ${_meters(piece)}', t);
      }
    }
    // Esquinas: extremos de truss que coinciden.
    final tolerance = 0.2 / metersPerUnit;
    final ends = [
      for (final t in trusses) ...[
        (PlanTruss.start(t), t),
        (PlanTruss.end(t), t),
      ],
    ];
    final used = <int>{};
    for (var i = 0; i < ends.length; i++) {
      if (used.contains(i)) continue;
      final joint = [i];
      for (var j = i + 1; j < ends.length; j++) {
        if (!used.contains(j) &&
            (ends[j].$1 - ends[i].$1).distance < tolerance) {
          joint.add(j);
        }
      }
      if (joint.length < 2) continue;
      used.addAll(joint);
      final ways = joint.length;
      add(
        ways == 2
            ? 'Esquina de 2 vías'
            : ways == 3
            ? 'Pieza en T de 3 vías'
            : 'Cruce de $ways vías',
        ends[i].$2,
      );
    }
    for (final el in elements) {
      switch (RigTypeCodec.of(el)) {
        case RigType.motor:
          add('Motor de cadena ${_kg(PlanRigPoint.wllKg(el))}', el);
          add('Eslinga y grillete', el);
        case RigType.groundSupport:
          add('Torre de ground support', el);
        default:
          break;
      }
      if (el.type == ElementType.light && TrussMagnet.rigOf(el) != null) {
        add('Garra y cable de seguridad', el);
      }
    }
    // Telas por material, en metros cuadrados.
    final cloth = <String, (double, List<PlanElement>)>{};
    for (final d in elements.where(PlanDrape.isDrape)) {
      final c = PlanDrape.catenary(d, metersPerUnit);
      final name = PlanDrape.material(d).name;
      final prev = cloth[name];
      cloth[name] = (
        (prev?.$1 ?? 0) + PlanDrape.areaM2(d, c),
        [...?prev?.$2, d],
      );
    }
    return [
      for (final e in counts.entries)
        GearLine(e.value, e.key, groups[e.key] ?? const []),
      for (final e in cloth.entries)
        GearLine(e.value.$1.ceil(), 'm² de ${e.key.toLowerCase()}', e.value.$2),
    ];
  }

  /// Avisos de rigging, los graves primero.
  static List<RigWarning> warnings(
    List<PlanElement> elements,
    double metersPerUnit,
  ) {
    final out = <RigWarning>[];
    final loads = RigLoads.of(elements, metersPerUnit);
    for (final el in elements.where(PlanRigPoint.isRigPoint)) {
      final load = loads[LightOverrides.uidOf(el)];
      if (load == null) continue;
      final wll = PlanRigPoint.wllKg(el);
      final what = RigTypeCodec.of(el)!.label;
      if (load > wll) {
        out.add(
          RigWarning(
            '$what con ${_kg(load)}: pasa de su carga (${_kg(wll)}).',
            el,
          ),
        );
      } else if (load > wll * nearLimit) {
        out.add(
          RigWarning(
            '$what con ${_kg(load)}: al límite de ${_kg(wll)}.',
            el,
            serious: false,
          ),
        );
      }
    }
    final halls = {
      for (final h in elements.where(PlanHall.isHall))
        if (LightOverrides.uidOf(h) != null) LightOverrides.uidOf(h)!: h,
    };
    final pointsOn = <Object?>{
      for (final el in elements.where(PlanRigPoint.isRigPoint))
        el.props[PlanRigPoint.trussKey],
    };
    final trusses = elements.where(PlanTruss.isTruss).toList();
    for (final t in trusses) {
      // Bajo la cubierta de su nave, con 10 cm de aire.
      final hall = halls[PlanHall.hallUidOf(t)];
      final recipe = hall == null ? null : PlanHall.recipeOf(hall);
      if (hall != null && recipe != null) {
        final top = PlanTruss.lowM(t) + PlanTruss.depthM(t);
        for (final end in [PlanTruss.start(t), PlanTruss.end(t)]) {
          final roof = recipe.roofAt((end - hall.position) * metersPerUnit);
          if (top > roof - 0.1) {
            out.add(
              RigWarning(
                'Truss a ${_meters(top)} arriba: toca la cubierta '
                '(${_meters(roof)} ahí).',
                t,
              ),
            );
            break;
          }
        }
      }
      // Un truss suelto, sin motores ni torres ni otro truss al que unirse.
      if (!pointsOn.contains(LightOverrides.uidOf(t)) &&
          !_touchesOther(t, trusses, 0.2 / metersPerUnit)) {
        out.add(RigWarning('Truss sin motores ni torres que lo sujeten.', t));
      }
    }
    for (final d in elements.where(PlanDrape.isDrape)) {
      final c = PlanDrape.catenary(d, metersPerUnit);
      final pull = c.anchorTension(PlanDrape.loadPerMeterKg(d, c));
      if (pull > heavyPullKg) {
        out.add(
          RigWarning(
            pull.isFinite
                ? 'Tela que tira ${_kg(pull)} en cada amarre: dale más caída.'
                : 'Tela sin caída: la cuerda no puede ir tensa del todo.',
            d,
          ),
        );
      }
    }
    out.sort((a, b) => (a.serious ? 0 : 1).compareTo(b.serious ? 0 : 1));
    return out;
  }

  static bool _touchesOther(
    PlanElement t,
    List<PlanElement> trusses,
    double tolerance,
  ) {
    for (final other in trusses) {
      if (identical(other, t)) continue;
      for (final p in [PlanTruss.start(t), PlanTruss.end(t)]) {
        if (PlanTruss.distanceTo(other, p) < tolerance) return true;
      }
      for (final p in [PlanTruss.start(other), PlanTruss.end(other)]) {
        if (PlanTruss.distanceTo(t, p) < tolerance) return true;
      }
    }
    return false;
  }

  /// Carga de cada punto respecto a su carga de trabajo (1 = al máximo),
  /// por `uid`.
  static Map<String, double> loadRatios(
    List<PlanElement> elements,
    double metersPerUnit,
  ) {
    final loads = RigLoads.of(elements, metersPerUnit);
    return {
      for (final el in elements.where(PlanRigPoint.isRigPoint))
        if (loads[LightOverrides.uidOf(el)] case final load?)
          LightOverrides.uidOf(el)!: load / math.max(PlanRigPoint.wllKg(el), 1),
    };
  }

  static String _profileName(TrussProfile p) => switch (p) {
    TrussProfile.square => 'cuadrado',
    TrussProfile.triangle => 'triangular',
    TrussProfile.ladder => 'escalera',
  };

  static String _meters(double v) =>
      '${(v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1)).replaceAll('.', ',')} m';

  static String _kg(double v) => v >= 1000
      ? '${(v / 1000).toStringAsFixed(1).replaceAll('.', ',')} t'
      : '${v.round()} kg';
}
