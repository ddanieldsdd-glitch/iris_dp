import 'dart:math' as math;
import 'dart:ui';

import '../camera_plan_element_model.dart';
import '../light_overrides.dart';
import '../plan_elevation.dart';
import '../rig/plan_rig.dart';

/// Una línea de sección en la planta (AM.6), como en Revit o ArchiCAD: por
/// dónde se corta y hacia qué lado se mira. La sección sale en la pantalla
/// de alzados, en la hoja de luz y en DXF.
///
/// Se guarda como una pieza más: empieza en `position` y acaba en
/// `position + (dx, dy)`, así que moverla la mueve entera.
abstract final class PlanSection {
  static const nameKey = 'sectionName';

  /// Mira al otro lado de la línea.
  static const flipKey = 'sectionFlip';

  static bool isSection(PlanElement el) =>
      RigTypeCodec.of(el) == RigType.section;

  static PlanElement create(Offset from, Offset to, {String name = 'A'}) {
    final el = RigTypeCodec.create(
      RigType.section,
      from,
      props: {'dx': to.dx - from.dx, 'dy': to.dy - from.dy, nameKey: name},
    );
    LightOverrides.ensureUids([el]);
    return el;
  }

  static Offset start(PlanElement el) => el.position;

  static Offset end(PlanElement el) =>
      el.position +
      Offset(
        (el.props['dx'] as num?)?.toDouble() ?? 100,
        (el.props['dy'] as num?)?.toDouble() ?? 0,
      );

  static String name(PlanElement el) {
    final n = (el.props[nameKey] as String?)?.trim() ?? '';
    return n.isEmpty ? 'A' : n;
  }

  static bool flipped(PlanElement el) => el.props[flipKey] == true;

  static void flip(PlanElement el) {
    if (flipped(el)) {
      el.props.remove(flipKey);
    } else {
      el.props[flipKey] = true;
    }
  }

  /// El corte: de un extremo al otro, mirando a su izquierda en el lienzo
  /// (o a la derecha, si está dada la vuelta).
  static ElevationCut cutOf(PlanElement el) => flipped(el)
      ? ElevationCut(end(el), start(el), name: name(el))
      : ElevationCut(start(el), end(el), name: name(el));

  /// Hacia dónde se mira, de largo 1, en el lienzo.
  static Offset look(PlanElement el) => cutOf(el).look;

  /// Las secciones de la planta, por su letra.
  static List<PlanElement> of(Iterable<PlanElement> elements) =>
      elements.where(isSection).toList()
        ..sort((a, b) => name(a).compareTo(name(b)));

  /// La letra siguiente: A, B, C…
  static String nextName(Iterable<PlanElement> elements) {
    final used = {for (final s in elements.where(isSection)) name(s)};
    for (var i = 0; i < 26; i++) {
      final c = String.fromCharCode(65 + i);
      if (!used.contains(c)) return c;
    }
    return '${used.length + 1}';
  }

  /// Si [p] toca la línea, con [slop] de margen en el lienzo.
  static bool contains(PlanElement el, Offset p, {double slop = 14}) {
    final a = start(el), b = end(el);
    final d = b - a;
    final len2 = d.dx * d.dx + d.dy * d.dy;
    if (len2 < 1e-9) return (p - a).distance <= slop;
    final t = (((p - a).dx * d.dx + (p - a).dy * d.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + d * t)).distance <= slop;
  }

  /// La sección vista: [PlanElevation.of] cortado por esta línea.
  static PlanElevation elevationOf(
    PlanElement section,
    List<PlanElement> elements, {
    required double metersPerUnit,
  }) => PlanElevation.of(
    [for (final e in elements) if (!isSection(e)) e],
    metersPerUnit: metersPerUnit,
    side: ElevationSide.front,
    cut: cutOf(section),
  );

  /// Largo de la línea, en metros.
  static double lengthM(PlanElement el, double metersPerUnit) =>
      (end(el) - start(el)).distance * metersPerUnit;

  /// El giro de la línea en grados, para el DXF.
  static double angleDeg(PlanElement el) {
    final d = end(el) - start(el);
    return math.atan2(d.dy, d.dx) * 180 / math.pi;
  }
}
