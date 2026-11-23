import 'dart:math' as math;
import 'dart:ui';

import '../camera_plan_element_model.dart';
import '../plan_segment.dart';
import '../rig/plan_rig.dart';
import 'arch_material.dart';
import 'arch_solid.dart';
import 'arch_stair.dart';

/// Un nivel de la localización (AM.6): planta baja, entreplanta, planta
/// 1… Su cota es la de su suelo; `slab` es el forjado que lo hace (la
/// planta baja no tiene).
class PlanStorey {
  final String name;
  final double elevationM;
  final PlanElement? slab;

  const PlanStorey(this.name, this.elevationM, [this.slab]);

  bool get isGround => slab == null;
}

/// Los niveles de una planta, como en Revit o ArchiCAD, pero sin nada
/// aparte: un nivel es un forjado con nombre. Su cara de arriba es el
/// suelo del nivel y lo que está en él lleva esa cota en `levelM`. Así se
/// guarda, se copia y viaja con la planta, y sale en el 3D y en Unreal.
abstract final class PlanLevels {
  /// Nombre del nivel en su forjado.
  static const nameKey = 'levelName';

  static const groundName = 'Planta baja';

  /// Lo de partida entre un nivel y el siguiente, de suelo a suelo.
  static const double defaultStoreyM = 3.0;
  static const double defaultSlabThickM = 0.25;
  static const defaultSlabMat = 'concrete-smooth';

  /// Lo que puede faltar para darse por en un nivel.
  static const double tolerance = 0.05;

  static bool isLevelSlab(PlanElement el) =>
      ArchSolid.isSlab(el) && el.props[nameKey] is String;

  /// Cota del suelo de un forjado de nivel, sobre el cero.
  static double slabFloorM(PlanElement el) =>
      PlanLevel.of(el) + ArchSolid.slabTopM(el);

  /// Los niveles, de abajo arriba: la planta baja y un nivel por cada
  /// forjado con nombre (dos a la misma cota cuentan como uno).
  static List<PlanStorey> of(Iterable<PlanElement> elements) {
    final out = <PlanStorey>[const PlanStorey(groundName, 0)];
    final slabs = elements.where(isLevelSlab).toList()
      ..sort((a, b) => slabFloorM(a).compareTo(slabFloorM(b)));
    for (final s in slabs) {
      final z = slabFloorM(s);
      if ((z - out.last.elevationM).abs() <= tolerance) continue;
      out.add(PlanStorey(s.props[nameKey] as String, z, s));
    }
    return out;
  }

  /// Dónde está el suelo de una pieza: un forjado de nivel, en su cara
  /// de arriba; lo demás, en su `levelM`.
  static double floorOf(PlanElement el) =>
      isLevelSlab(el) ? slabFloorM(el) : PlanLevel.of(el);

  /// El nivel en el que está una pieza: el más alto que no pasa de su
  /// suelo.
  static PlanStorey storeyOf(PlanElement el, List<PlanStorey> storeys) {
    final z = floorOf(el);
    var found = storeys.first;
    for (final s in storeys) {
      if (s.elevationM <= z + tolerance) found = s;
    }
    return found;
  }

  /// Si una pieza se ve en el nivel que está a [elevationM]: la suya y,
  /// una escalera, también el nivel al que llega.
  static bool isOn(
    PlanElement el,
    double elevationM,
    List<PlanStorey> storeys,
  ) {
    if ((storeyOf(el, storeys).elevationM - elevationM).abs() <= tolerance) {
      return true;
    }
    if (ArchStair.isStair(el)) {
      final top = PlanLevel.of(el) + ArchStair.riseM(el);
      return (top - elevationM).abs() <= tolerance;
    }
    return false;
  }

  /// El nivel siguiente a [storey], si lo hay.
  static PlanStorey? above(PlanStorey storey, List<PlanStorey> storeys) {
    for (final s in storeys) {
      if (s.elevationM > storey.elevationM + tolerance) return s;
    }
    return null;
  }

  /// Un nivel nuevo encima del último: un forjado que cubre lo que hay
  /// construido (paredes, forjados y volúmenes), a [storeyM] del de abajo.
  /// Sin nada construido, 10 × 10 m alrededor de [around].
  static PlanElement newStorey(
    Iterable<PlanElement> elements,
    double metersPerUnit, {
    Offset around = Offset.zero,
    double storeyM = defaultStoreyM,
  }) {
    final storeys = of(elements);
    final top = storeys.last;
    Rect? box;
    void grow(Offset p) {
      final r = Rect.fromLTWH(p.dx, p.dy, 0, 0);
      box = box == null ? r : box!.expandToInclude(r);
    }

    for (final el in elements) {
      if (PlanSegment.isSegment(el) &&
          PlanSegment.kind(el) == PlanSegment.kindWall) {
        grow(PlanSegment.pointAt(el, 0));
        grow(PlanSegment.pointAt(el, 1));
      } else if (ArchSolid.isSolid(el)) {
        ArchSolid.outline(el, metersPerUnit).forEach(grow);
      }
    }
    final half = 5 / metersPerUnit;
    final rect = box == null || box!.width < 1 || box!.height < 1
        ? Rect.fromCenter(center: around, width: half * 2, height: half * 2)
        : box!;
    final slab = ArchSolid.rectangle(
      RigType.slab,
      rect.topLeft,
      rect.bottomRight,
      metersPerUnit,
    );
    final floor = top.elevationM + storeyM;
    slab.props
      ..[nameKey] = 'Planta ${storeys.length}'
      ..[ArchSolid.topKey] = _r(floor)
      ..[ArchSolid.thickKey] = defaultSlabThickM
      ..[ArchMaterials.key] = defaultSlabMat;
    return slab;
  }

  /// Lo que hay entre un nivel y el siguiente: la altura que salva una
  /// escalera que empieza en [storey], o `null` si es el último.
  static double? riseToNext(PlanStorey storey, List<PlanStorey> storeys) {
    final next = above(storey, storeys);
    if (next == null) return null;
    return math.max(0.05, next.elevationM - storey.elevationM);
  }

  /// «Planta 1 · +3,00».
  static String label(PlanStorey s) {
    final v = s.elevationM.abs().toStringAsFixed(2).replaceAll('.', ',');
    final sign = s.elevationM < -1e-6 ? '−' : '+';
    return '${s.name} · $sign$v';
  }

  static double _r(double v) => (v * 1000).round() / 1000;
}
