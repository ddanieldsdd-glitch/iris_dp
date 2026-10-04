import 'dart:math' as math;
import 'dart:ui';

import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'plan_segment.dart';

/// Puertas, ventanas y aberturas: piezas que se enganchan a una pared y le
/// abren un hueco.
///
/// El elemento guarda su centro en `position` y la dirección de la pared en
/// `rotation`. El resto va en `props`: `width` (ancho del hueco, en
/// unidades del lienzo), y para las puertas `open` (grados de apertura),
/// `double` (dos hojas), `hingeFar` (bisagra en el otro extremo) y
/// `swingIn` (abre hacia el otro lado).
class PlanOpening {
  PlanOpening._();

  static const widthKey = 'width';
  static const openKey = 'open';
  static const doubleKey = 'double';
  static const hingeFarKey = 'hingeFar';
  static const swingInKey = 'swingIn';

  /// Ancho de partida: 0,9 m de puerta y 1,2 m de ventana a la escala por
  /// defecto.
  static const double defaultDoorWidth = 45;
  static const double defaultWindowWidth = 60;
  static const double maxOpen = 110;

  /// Distancia a la que una pieza se engancha a una pared al soltarla.
  static const double snapDistance = 40;

  static bool isDoor(PlanElement el) =>
      el.type == ElementType.wall &&
      !PlanSegment.isSegment(el) &&
      switch (el.architectureType) {
        ArchitectureType.doorOpen ||
        ArchitectureType.doorClosed ||
        ArchitectureType.doubleDoor => true,
        _ => false,
      };

  static bool isWindow(PlanElement el) =>
      el.type == ElementType.wall &&
      !PlanSegment.isSegment(el) &&
      el.architectureType == ArchitectureType.window;

  /// Hueco sin hoja ni cristal, o rejas.
  static bool isGap(PlanElement el) =>
      el.type == ElementType.wall &&
      !PlanSegment.isSegment(el) &&
      (el.architectureType == ArchitectureType.opening ||
          el.architectureType == ArchitectureType.prisonBars);

  /// Cualquier pieza que abre hueco en una pared.
  static bool isOpening(PlanElement el) =>
      isDoor(el) || isWindow(el) || isGap(el);

  static double width(PlanElement el) =>
      (el.props[widthKey] as num?)?.toDouble() ??
      (isDoor(el) && el.architectureType != ArchitectureType.doubleDoor
          ? defaultDoorWidth
          : defaultWindowWidth);

  /// Grados que está abierta una puerta. 0 = cerrada.
  static double openDeg(PlanElement el) {
    final stored = (el.props[openKey] as num?)?.toDouble();
    if (stored != null) return stored.clamp(0, maxOpen);
    return el.architectureType == ArchitectureType.doorClosed ? 0 : 90;
  }

  static bool isDouble(PlanElement el) =>
      el.props[doubleKey] as bool? ??
      el.architectureType == ArchitectureType.doubleDoor;

  static bool hingeFar(PlanElement el) => el.props[hingeFarKey] == true;
  static bool swingIn(PlanElement el) => el.props[swingInKey] == true;

  /// Dirección de la pared en la que está la pieza.
  static Offset direction(PlanElement el) {
    final rad = el.rotation * math.pi / 180;
    return Offset(math.cos(rad), math.sin(rad));
  }

  /// Los dos extremos del hueco.
  static (Offset, Offset) span(PlanElement el) {
    final half = direction(el) * (width(el) / 2);
    return (el.position - half, el.position + half);
  }

  static Offset _rotate(Offset v, double degrees) {
    final rad = degrees * math.pi / 180;
    final c = math.cos(rad);
    final s = math.sin(rad);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  /// Las hojas de una puerta, de la bisagra al canto, según lo abierta que
  /// esté. Una puerta cerrada tiene la hoja sobre el hueco.
  static List<(Offset, Offset)> leaves(PlanElement el) {
    if (!isDoor(el)) return const [];
    final (a, b) = span(el);
    final dir = direction(el);
    final open = openDeg(el) * (swingIn(el) ? -1 : 1);
    if (isDouble(el)) {
      final half = width(el) / 2;
      return [
        (a, a + _rotate(dir, -open) * half),
        (b, b + _rotate(dir * -1, open) * half),
      ];
    }
    final w = width(el);
    return hingeFar(el)
        ? [(b, b + _rotate(dir * -1, open) * w)]
        : [(a, a + _rotate(dir, -open) * w)];
  }

  /// ¿Deja pasar la luz por el hueco? Una puerta casi cerrada, no.
  static bool passesLight(PlanElement el) => !isDoor(el) || openDeg(el) > 3;

  /// Pared (tramo dibujado punto a punto) más cercana a un punto, con el
  /// punto de la pared y su ángulo. `null` si ninguna queda a menos de
  /// [within].
  static ({Offset point, double rotation})? nearestWall(
    Offset p,
    Iterable<PlanElement> elements, {
    double within = snapDistance,
  }) {
    ({Offset point, double rotation})? best;
    var bestDistance = within;
    for (final wall in elements) {
      if (!PlanSegment.isSegment(wall) ||
          PlanSegment.kind(wall) != PlanSegment.kindWall) {
        continue;
      }
      const steps = 24;
      final pieces = PlanSegment.curve(wall) == 0 ? 1 : steps;
      var from = PlanSegment.pointAt(wall, 0);
      for (var i = 1; i <= pieces; i++) {
        final to = PlanSegment.pointAt(wall, i / pieces);
        final ab = to - from;
        final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
        if (len2 > 0) {
          final t =
              (((p.dx - from.dx) * ab.dx + (p.dy - from.dy) * ab.dy) / len2)
                  .clamp(0.0, 1.0);
          final foot = from + ab * t;
          final distance = (p - foot).distance;
          if (distance < bestDistance) {
            bestDistance = distance;
            best = (
              point: foot,
              rotation: math.atan2(ab.dy, ab.dx) * 180 / math.pi,
            );
          }
        }
        from = to;
      }
    }
    return best;
  }

  /// Engancha la pieza a la pared más cercana: la coloca sobre ella y la
  /// alinea. Devuelve si se ha enganchado.
  static bool snapToWall(PlanElement el, Iterable<PlanElement> elements) {
    final wall = nearestWall(el.position, elements);
    if (wall == null) return false;
    el
      ..position = wall.point
      ..rotation = wall.rotation;
    return true;
  }
}
