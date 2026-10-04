import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';

/// Tramo dibujado punto a punto: pared, calle o línea de relieve.
///
/// Es un elemento de tipo `wall` cuyo `position` es el inicio y cuyo final
/// se guarda relativo en `props` (`dx`, `dy`); así mover el elemento mueve
/// el tramo entero. `curve` es lo que se aparta el centro del tramo de la
/// recta que une sus extremos.
class PlanSegment {
  PlanSegment._();

  static const kindWall = 'wall';
  static const kindStreet = 'street';
  static const kindRelief = 'relief';

  static bool isSegment(PlanElement el) =>
      el.type == ElementType.wall &&
      el.props['dx'] is num &&
      el.props['dy'] is num;

  static PlanElement create({
    required Offset start,
    required Offset end,
    String kind = kindWall,
  }) => PlanElement(
    id: 0,
    type: ElementType.wall,
    position: start,
    label: ArchitectureType.wall.dbValue,
    props: {
      'dx': end.dx - start.dx,
      'dy': end.dy - start.dy,
      if (kind != kindWall) 'kind': kind,
    },
  );

  static String kind(PlanElement el) => el.props['kind'] as String? ?? kindWall;

  static String kindLabel(String kind) => switch (kind) {
    kindStreet => 'Calle',
    kindRelief => 'Relieve',
    _ => 'Pared',
  };

  static Offset delta(PlanElement el) => Offset(
    (el.props['dx'] as num).toDouble(),
    (el.props['dy'] as num).toDouble(),
  );

  static Offset start(PlanElement el) => el.position;

  static Offset end(PlanElement el) => el.position + delta(el);

  static double curve(PlanElement el) =>
      (el.props['curve'] as num?)?.toDouble() ?? 0;

  static void setEnd(PlanElement el, Offset end) {
    el.props['dx'] = end.dx - el.position.dx;
    el.props['dy'] = end.dy - el.position.dy;
  }

  /// Mueve el inicio dejando el final donde estaba.
  static void setStart(PlanElement el, Offset start) {
    final fixedEnd = end(el);
    el.position = start;
    setEnd(el, fixedEnd);
  }

  static Offset _normal(PlanElement el) {
    final d = delta(el);
    final len = d.distance;
    if (len == 0) return Offset.zero;
    return Offset(-d.dy / len, d.dx / len);
  }

  /// Punto por el que pasa el centro del tramo.
  static Offset midpoint(PlanElement el) =>
      el.position + delta(el) / 2 + _normal(el) * curve(el);

  /// Curva el tramo para que su centro pase por [through].
  static void bendThrough(PlanElement el, Offset through) {
    final chordMid = el.position + delta(el) / 2;
    final n = _normal(el);
    final offset = through - chordMid;
    final amount = offset.dx * n.dx + offset.dy * n.dy;
    if (amount.abs() < 4) {
      el.props.remove('curve');
    } else {
      el.props['curve'] = amount;
    }
  }

  /// Trazado del tramo en coordenadas del plano.
  static Path path(PlanElement el) {
    final a = start(el);
    final b = end(el);
    final c = curve(el);
    final path = Path()..moveTo(a.dx, a.dy);
    if (c == 0) {
      path.lineTo(b.dx, b.dy);
    } else {
      // Punto de control para que la curva pase por `midpoint`.
      final control = a + delta(el) / 2 + _normal(el) * (c * 2);
      path.quadraticBezierTo(control.dx, control.dy, b.dx, b.dy);
    }
    return path;
  }

  static Offset pointAt(PlanElement el, double t) {
    final a = start(el);
    final b = end(el);
    final c = curve(el);
    if (c == 0) return Offset.lerp(a, b, t)!;
    final control = a + delta(el) / 2 + _normal(el) * (c * 2);
    final u = 1 - t;
    return a * (u * u) + control * (2 * u * t) + b * (t * t);
  }

  static const _samples = 24;

  /// Longitud del tramo, en unidades del lienzo.
  static double length(PlanElement el) {
    if (curve(el) == 0) return delta(el).distance;
    var total = 0.0;
    var previous = start(el);
    for (var i = 1; i <= _samples; i++) {
      final p = pointAt(el, i / _samples);
      total += (p - previous).distance;
      previous = p;
    }
    return total;
  }

  /// Distancia de un punto al tramo.
  static double distanceTo(PlanElement el, Offset p) {
    var best = double.infinity;
    var previous = start(el);
    final steps = curve(el) == 0 ? 1 : _samples;
    for (var i = 1; i <= steps; i++) {
      final next = pointAt(el, i / steps);
      best = math.min(best, _distanceToLine(p, previous, next));
      previous = next;
    }
    return best;
  }

  static double _distanceToLine(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(
      0.0,
      1.0,
    );
    return (p - (a + ab * t)).distance;
  }
}

/// Escribe una distancia del lienzo en metros.
String formatMeters(double units, double metersPerUnit) {
  final m = units * metersPerUnit;
  return m >= 10 ? '${m.toStringAsFixed(1)} m' : '${m.toStringAsFixed(2)} m';
}
