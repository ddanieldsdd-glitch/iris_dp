import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../light_overrides.dart';
import '../plan_opening.dart';
import '../plan_segment.dart';
import 'plan_light.dart';

/// Luces pegadas a la pared (CA.3): tubos, apliques, farolas de brazo.
///
/// Como una puerta, la luz se engancha a la pared más cercana; además se
/// queda por el lado en que estaba, a ras de la cara de la pared, y mira
/// hacia fuera de ella.
class LightWallMount {
  LightWallMount._();

  /// Separación de la cara de la pared al centro del aparato.
  static const double gapM = 0.05;

  /// Altura por defecto de un aplique.
  static const double defaultHeightM = 2.2;

  /// Eje del tubo: a lo largo de la pared o de pie.
  static const tubeAxisKey = 'tubeAxis';
  static const axisHorizontal = 'horizontal';
  static const axisVertical = 'vertical';

  /// De qué pared cuelga y dónde (AR.4): `uid` de la pared, `t` a lo
  /// largo de ella (0–1) y `side` (1 o −1). Así la luz sigue a su pared
  /// si la pared se mueve.
  static const wallKey = 'onWall';

  static bool isOn(PlanElement el) =>
      el.props[PlanLight.mountKey] == PlanLight.mountWall;

  /// La pared de la que cuelga [el], si se sabe.
  static String? wallUidOf(PlanElement el) => switch (el.props[wallKey]) {
    final Map m => m['uid'] as String?,
    _ => null,
  };

  /// El tubo va tumbado a lo largo de la pared salvo que se diga otra cosa;
  /// en trípode, de pie.
  static bool tubeHorizontal(PlanElement el) => switch (el.props[tubeAxisKey]) {
    axisHorizontal => true,
    axisVertical => false,
    _ => isOn(el) || PlanLight.isOverhead(el),
  };

  /// Pega [el] a la pared más cercana. `false` si no hay ninguna a mano.
  static bool snap(
    PlanElement el,
    Iterable<PlanElement> elements,
    double metersPerUnit,
  ) {
    PlanElement? bestWall;
    var best = double.infinity;
    Offset? foot;
    Offset? dir;
    var bestT = 0.0;
    for (final w in elements) {
      if (identical(w, el) ||
          !PlanSegment.isSegment(w) ||
          PlanSegment.kind(w) != PlanSegment.kindWall) {
        continue;
      }
      final pieces = PlanSegment.curve(w) == 0 ? 1 : 24;
      var from = PlanSegment.pointAt(w, 0);
      for (var i = 1; i <= pieces; i++) {
        final to = PlanSegment.pointAt(w, i / pieces);
        final ab = to - from;
        final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
        if (len2 > 0) {
          final t =
              (((el.position.dx - from.dx) * ab.dx +
                          (el.position.dy - from.dy) * ab.dy) /
                      len2)
                  .clamp(0.0, 1.0);
          final f = from + ab * t;
          final d = (el.position - f).distance;
          if (d < best) {
            best = d;
            bestWall = w;
            foot = f;
            dir = ab / math.sqrt(len2);
            bestT = (i - 1 + t) / pieces;
          }
        }
        from = to;
      }
    }
    if (bestWall == null || best > PlanOpening.snapDistance) {
      el.props.remove(wallKey);
      return false;
    }
    // El lado en que estaba la luz (a la izquierda de la pared si estaba
    // encima).
    var n = Offset(-dir!.dy, dir.dx);
    final side =
        (el.position - foot!).dx * n.dx + (el.position - foot).dy * n.dy;
    if (side < 0) n = -n;
    _place(el, bestWall, foot, n, metersPerUnit);
    LightOverrides.ensureUids([bestWall]);
    el.props[wallKey] = {
      'uid': LightOverrides.uidOf(bestWall),
      't': bestT,
      'side': side < 0 ? -1 : 1,
    };
    el.props[PlanLight.heightKey] ??= defaultHeightM;
    return true;
  }

  /// A ras de la cara de [wall] en [foot], mirando hacia [n].
  static void _place(
    PlanElement el,
    PlanElement wall,
    Offset foot,
    Offset n,
    double metersPerUnit,
  ) {
    final offM = PlanSegment.thicknessM(wall) / 2 + gapM;
    el.position = foot + n * (offM / metersPerUnit);
    // Paneo: 0° mira hacia arriba en la planta (−y), y gira con el reloj.
    el.rotation = (math.atan2(n.dx, -n.dy) * 180 / math.pi + 360) % 360;
  }

  /// Vuelve a pegar a su pared las luces de las paredes [walls] (sus
  /// `uid`) después de moverlas o cambiarlas. Devuelve las luces movidas.
  static List<PlanElement> follow(
    List<PlanElement> elements,
    Set<String> walls,
    double metersPerUnit,
  ) {
    if (walls.isEmpty) return const [];
    final byUid = <String, PlanElement>{
      for (final el in elements)
        if (PlanSegment.isSegment(el))
          if (LightOverrides.uidOf(el) case final uid? when walls.contains(uid))
            uid: el,
    };
    final moved = <PlanElement>[];
    for (final el in elements) {
      if (el.type != ElementType.light || !isOn(el)) continue;
      final on = el.props[wallKey];
      if (on is! Map) continue;
      final wall = byUid[on['uid']];
      if (wall == null) continue;
      final t = ((on['t'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0);
      final foot = PlanSegment.pointAt(wall, t);
      final a = PlanSegment.pointAt(wall, math.max(0, t - 0.01));
      final b = PlanSegment.pointAt(wall, math.min(1, t + 0.01));
      final ab = b - a;
      if (ab.distance == 0) continue;
      final dir = ab / ab.distance;
      final side = (on['side'] as num?)?.toDouble() ?? 1;
      _place(el, wall, foot, Offset(-dir.dy, dir.dx) * side, metersPerUnit);
      moved.add(el);
    }
    return moved;
  }

  /// Un tubo pegado a la pared alumbra en horizontal.
  static bool isTube(PlanElement el) => el.lightType == LightType.floSingle;
}
