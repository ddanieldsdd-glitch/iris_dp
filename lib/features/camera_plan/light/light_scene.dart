import 'dart:math' as math;
import 'dart:ui';

import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../plan_segment.dart';
import 'modifiers.dart';
import 'plan_light.dart';

/// Algo que se interpone entre una luz y un punto: una pared, una ventana,
/// una bandera. [transmission] es la parte de la luz que deja pasar.
class LightBlocker {
  final Offset a;
  final Offset b;
  final double transmission;

  const LightBlocker(this.a, this.b, {this.transmission = 0});

  bool get isOpaque => transmission <= 0;
}

/// Lo que aporta una luz a un punto.
class LightContribution {
  final PlanLight light;
  final double lux;

  const LightContribution(this.light, this.lux);
}

/// La planta vista por la luz: las fuentes, lo que las tapa y la escala.
/// Con ella se calcula cuánta luz llega a cualquier punto.
class LightScene {
  final List<PlanLight> lights;
  final List<LightBlocker> blockers;

  /// Metros por unidad del lienzo.
  final double metersPerUnit;

  const LightScene({
    required this.lights,
    required this.blockers,
    required this.metersPerUnit,
  });

  /// Ancho, en unidades del lienzo, de las piezas de arquitectura de tamaño
  /// fijo (pared suelta, ventana, puerta) y de una bandera.
  static const double pieceWidth = 60;

  /// Luz que deja pasar el cristal de una ventana.
  static const double glassTransmission = 0.9;

  /// A qué distancia de una pared se considera que una ventana o una puerta
  /// está puesta en ella.
  static const double _mountTolerance = 24;

  factory LightScene.from(
    Iterable<PlanElement> elements, {
    required double metersPerUnit,
  }) {
    final all = elements.toList();
    return LightScene(
      lights: [for (final el in all) ?PlanLight.of(el)],
      blockers: blockersOf(all),
      metersPerUnit: metersPerUnit,
    );
  }

  // ── Qué tapa la luz ───────────────────────────────────────────────────────

  static (Offset, Offset) _span(PlanElement el, [double width = pieceWidth]) {
    final rad = el.rotation * math.pi / 180;
    final half = Offset(math.cos(rad), math.sin(rad)) * (width / 2);
    return (el.position - half, el.position + half);
  }

  /// Paredes, ventanas, puertas y banderas convertidas en tramos que tapan
  /// o filtran. Una ventana o una puerta abre un hueco en la pared sobre la
  /// que está.
  static List<LightBlocker> blockersOf(List<PlanElement> elements) {
    // Huecos: tramo que ocupan y luz que dejan pasar.
    final openings = <(Offset, Offset, double)>[];
    final walls = <(Offset, Offset)>[];
    final blockers = <LightBlocker>[];

    for (final el in elements) {
      if (el.type == ElementType.light) {
        // Banderas y cortadores tapan; el resto del grip, de momento, no.
        if (el.lightType == LightType.flag ||
            el.lightType == LightType.cutter) {
          final (a, b) = _span(el);
          blockers.add(LightBlocker(a, b));
        }
        continue;
      }
      if (el.type != ElementType.wall) continue;

      if (PlanSegment.isSegment(el)) {
        if (PlanSegment.kind(el) != PlanSegment.kindWall) continue;
        // Una pared curva se trocea en tramos rectos.
        final pieces = PlanSegment.curve(el) == 0 ? 1 : 12;
        var from = PlanSegment.pointAt(el, 0);
        for (var i = 1; i <= pieces; i++) {
          final to = PlanSegment.pointAt(el, i / pieces);
          walls.add((from, to));
          from = to;
        }
        continue;
      }

      final (a, b) = _span(el);
      switch (el.architectureType) {
        case ArchitectureType.window:
          var transmission = glassTransmission;
          // Una ventana puede llevar su propia difusión o gelatina.
          for (final id in (el.props[PlanLight.modifiersKey] as List? ?? [])) {
            transmission *=
                LightModifier.byId(id?.toString())?.transmission ?? 1;
          }
          openings.add((a, b, transmission));
        case ArchitectureType.doorOpen ||
            ArchitectureType.doubleDoor ||
            ArchitectureType.opening:
          openings.add((a, b, 1));
        case ArchitectureType.prisonBars:
          openings.add((a, b, 0.7));
        case ArchitectureType.doorClosed:
          // Una puerta cerrada tapa, también el hueco que hubiera debajo.
          openings.add((a, b, 0));
        case ArchitectureType.wall || null:
          walls.add((a, b));
      }
    }

    for (final (a, b) in walls) {
      final length = (b - a).distance;
      if (length < 1) continue;
      final dir = (b - a) / length;

      // Tramos de esta pared ocupados por huecos, en distancia desde `a`.
      final cuts = <(double, double, double)>[];
      for (final (oa, ob, transmission) in openings) {
        final centre = (oa + ob) / 2;
        final along = (centre.dx - a.dx) * dir.dx + (centre.dy - a.dy) * dir.dy;
        final foot = a + dir * along.clamp(0, length);
        if ((centre - foot).distance > _mountTolerance) continue;
        final half = (ob - oa).distance / 2;
        final from = (along - half).clamp(0.0, length);
        final to = (along + half).clamp(0.0, length);
        if (to - from > 1) cuts.add((from, to, transmission));
      }
      cuts.sort((x, y) => x.$1.compareTo(y.$1));

      var cursor = 0.0;
      for (final (from, to, transmission) in cuts) {
        if (from > cursor + 0.5) {
          blockers.add(LightBlocker(a + dir * cursor, a + dir * from));
        }
        if (transmission < 1) {
          blockers.add(
            LightBlocker(
              a + dir * math.max(from, cursor),
              a + dir * to,
              transmission: transmission,
            ),
          );
        }
        cursor = math.max(cursor, to);
      }
      if (length > cursor + 0.5) {
        blockers.add(LightBlocker(a + dir * cursor, b));
      }
    }

    // Ventanas y puertas cerradas sueltas, sin pared: filtran o tapan igual.
    for (final (oa, ob, transmission) in openings) {
      if (transmission >= 1) continue;
      final centre = (oa + ob) / 2;
      final mounted = walls.any((w) {
        final length = (w.$2 - w.$1).distance;
        if (length < 1) return false;
        final dir = (w.$2 - w.$1) / length;
        final along =
            (centre.dx - w.$1.dx) * dir.dx + (centre.dy - w.$1.dy) * dir.dy;
        final foot = w.$1 + dir * along.clamp(0, length);
        return (centre - foot).distance <= _mountTolerance;
      });
      if (!mounted) {
        blockers.add(LightBlocker(oa, ob, transmission: transmission));
      }
    }
    return blockers;
  }

  // ── Geometría ─────────────────────────────────────────────────────────────

  /// Punto del rayo `origin + dir·t` donde corta el tramo, como distancia
  /// `t` desde el origen; `null` si no lo corta.
  static double? _rayHit(Offset origin, Offset dir, Offset a, Offset b) {
    final s = b - a;
    final denom = dir.dx * s.dy - dir.dy * s.dx;
    if (denom.abs() < 1e-9) return null;
    final diff = a - origin;
    final t = (diff.dx * s.dy - diff.dy * s.dx) / denom;
    final u = (diff.dx * dir.dy - diff.dy * dir.dx) / denom;
    if (t <= 1e-6 || u < 0 || u > 1) return null;
    return t;
  }

  /// Parte de la luz que llega de [from] a [to], según lo que hay en medio.
  /// 1 = nada en medio; 0 = tapado.
  double transmissionBetween(Offset from, Offset to) {
    final span = to - from;
    final distance = span.distance;
    if (distance < 1e-6) return 1;
    final dir = span / distance;
    var result = 1.0;
    for (final blocker in blockers) {
      final hit = _rayHit(from, dir, blocker.a, blocker.b);
      // Un tope a ras del punto medido (a menos de media unidad) no cuenta:
      // el punto está «en» la pared, no detrás.
      if (hit == null || hit >= distance - 0.5) continue;
      result *= blocker.transmission;
      if (result <= 0) return 0;
    }
    return result;
  }

  /// Distancia hasta la primera pared opaca en una dirección, con [max] de
  /// tope.
  double reachAlong(Offset origin, Offset dir, double max) {
    var best = max;
    for (final blocker in blockers) {
      if (!blocker.isOpaque) continue;
      final hit = _rayHit(origin, dir, blocker.a, blocker.b);
      if (hit != null && hit < best) best = hit;
    }
    return best;
  }

  /// Zona que alcanza una luz desde [origin] hasta [reach], recortada por
  /// las paredes: lo que queda a su sombra no entra.
  Path visibleArea(Offset origin, double reach) {
    // Un rayo por grado y medio, más uno a cada lado de cada esquina para
    // que el corte de la sombra salga limpio.
    final angles = <double>[
      for (var i = 0; i < 240; i++) i * 2 * math.pi / 240,
    ];
    for (final blocker in blockers) {
      if (!blocker.isOpaque) continue;
      for (final corner in [blocker.a, blocker.b]) {
        final d = corner - origin;
        if (d.distance > reach + 1) continue;
        final angle = math.atan2(d.dy, d.dx);
        angles
          ..add(angle - 0.0007)
          ..add(angle + 0.0007);
      }
    }
    angles.sort();

    final path = Path();
    var first = true;
    for (final angle in angles) {
      final dir = Offset(math.cos(angle), math.sin(angle));
      final point = origin + dir * reachAlong(origin, dir, reach);
      if (first) {
        path.moveTo(point.dx, point.dy);
        first = false;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  // ── Cuánta luz llega ──────────────────────────────────────────────────────

  /// Hacia dónde apunta una luz: el eje de su haz.
  static Offset aimOf(PlanElement el) {
    final rad = el.rotation * math.pi / 180;
    return Offset(math.sin(rad), -math.cos(rad));
  }

  /// Lo que aporta cada luz a un punto de la planta.
  List<LightContribution> contributionsAt(Offset point) {
    final result = <LightContribution>[];
    for (final light in lights) {
      if (light.source.candela <= 0) continue;
      final origin = light.element.position;
      final span = point - origin;
      final units = span.distance;
      final meters = math.max(units * metersPerUnit, 0.05);

      var offAxis = 0.0;
      if (!light.source.isOmni && units > 1e-6) {
        final aim = aimOf(light.element);
        final cos = ((span.dx * aim.dx + span.dy * aim.dy) / units).clamp(
          -1.0,
          1.0,
        );
        offAxis = math.acos(cos) * 180 / math.pi;
      }
      final open = transmissionBetween(origin, point);
      if (open <= 0) continue;
      final lux = light.source.illuminance(meters, offAxisDeg: offAxis) * open;
      if (lux > 0.01) result.add(LightContribution(light, lux));
    }
    result.sort((a, b) => b.lux.compareTo(a.lux));
    return result;
  }

  /// Lux totales en un punto.
  double luxAt(Offset point) =>
      contributionsAt(point).fold(0, (sum, c) => sum + c.lux);
}
