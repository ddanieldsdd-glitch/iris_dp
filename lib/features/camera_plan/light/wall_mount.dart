import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
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

  static bool isOn(PlanElement el) =>
      el.props[PlanLight.mountKey] == PlanLight.mountWall;

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
          }
        }
        from = to;
      }
    }
    if (bestWall == null || best > PlanOpening.snapDistance) return false;
    // El lado en que estaba la luz (a la izquierda de la pared si estaba
    // encima).
    var n = Offset(-dir!.dy, dir.dx);
    final side =
        (el.position - foot!).dx * n.dx + (el.position - foot).dy * n.dy;
    if (side < 0) n = -n;
    final offM = PlanSegment.thicknessM(bestWall) / 2 + gapM;
    el.position = foot + n * (offM / metersPerUnit);
    // Paneo: 0° mira hacia arriba en la planta (−y), y gira con el reloj.
    el.rotation = (math.atan2(n.dx, -n.dy) * 180 / math.pi + 360) % 360;
    el.props[PlanLight.heightKey] ??= defaultHeightM;
    return true;
  }

  /// Un tubo pegado a la pared alumbra en horizontal.
  static bool isTube(PlanElement el) => el.lightType == LightType.floSingle;
}
