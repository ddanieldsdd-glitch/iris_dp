import 'dart:ui';

import '../camera_plan_element_model.dart';
import '../light/surfaces.dart';
import 'arch_material.dart';

/// Las dos caras de una pared (AM.4): la A, a la izquierda del sentido en
/// que se dibujó (la de siempre, `mat`), y la B, al otro lado (`matB`).
/// Un tabique con azulejo en el baño y pintura en el pasillo, o una
/// fachada de ladrillo enlucida por dentro.
abstract final class WallFaces {
  static const backKey = 'matB';

  /// El material de la cara B, si tiene uno propio.
  static ArchMaterial? back(PlanElement el) =>
      ArchMaterials.byId(el.props[backKey] as String?);

  /// El de la cara A (o el de toda la pared).
  static ArchMaterial? front(PlanElement el) => ArchMaterials.ofWall(el);

  /// Tiene un material distinto en cada cara.
  static bool isTwoSided(PlanElement el) {
    final b = back(el);
    return b != null && b.id != front(el)?.id;
  }

  /// Lo que devuelve a la luz la cara que mira hacia [side] (> 0: la A,
  /// la de la normal `(−dy, dx)`; < 0: la B).
  static SurfaceMaterial surface(PlanElement el, double side) {
    final b = back(el);
    if (side < 0 && b != null) return b.surface;
    return ArchMaterials.wallSurface(
      el,
      el.props['material'] as String?,
    );
  }

  /// Los colores de las dos caras para la planta, o `null` si es la misma.
  static (Color, Color)? colors(PlanElement el) {
    if (!isTwoSided(el)) return null;
    Color of(ArchMaterial? m) =>
        m == null ? const Color(0xFFBDB8AE) : Color(0xFF000000 | m.albedoRgb);
    return (of(front(el)), of(back(el)));
  }
}
