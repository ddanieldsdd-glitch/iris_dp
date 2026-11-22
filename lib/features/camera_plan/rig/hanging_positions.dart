import '../camera_plan_element_model.dart';
import '../light/plan_light.dart';
import '../light/wall_mount.dart';
import '../light_overrides.dart';
import 'plan_rig.dart';

/// Las posiciones de cuelgue de la planta (AR.4), como en Spotlight: cada
/// truss o vara es una posición con nombre y altura, y cada foco dice de
/// cuál cuelga.
abstract final class HangingPositions {
  /// Nombre de cada truss por su `uid`: el que le hayan puesto o, si no
  /// tiene, «Truss 1», «Truss 2»… de arriba abajo y de izquierda a
  /// derecha en la planta.
  static Map<String, String> names(Iterable<PlanElement> elements) {
    final trusses = [
      for (final el in elements)
        if (PlanTruss.isTruss(el) && LightOverrides.uidOf(el) != null) el,
    ];
    (double, double) mid(PlanElement t) {
      final a = PlanTruss.start(t), b = PlanTruss.end(t);
      return ((a.dy + b.dy) / 2, (a.dx + b.dx) / 2);
    }

    final unnamed = trusses.where((t) => t.customName == null).toList()
      ..sort((a, b) {
        final (ay, ax) = mid(a);
        final (by, bx) = mid(b);
        // En la misma fila si están a menos de 20 unidades.
        if ((ay - by).abs() > 20) return ay.compareTo(by);
        return ax.compareTo(bx);
      });
    return {
      for (final t in trusses)
        if (t.customName case final name?) LightOverrides.uidOf(t)!: name,
      for (final (i, t) in unnamed.indexed)
        LightOverrides.uidOf(t)!: 'Truss ${i + 1}',
    };
  }

  /// Dónde va montado un foco: el nombre de su truss, o pared, techo o pie.
  static String mountOf(PlanElement light, Map<String, String> names) {
    final truss = TrussMagnet.trussUidOf(light);
    if (truss != null) return names[truss] ?? 'Truss';
    if (PlanLight.isOverhead(light)) return 'Techo';
    if (LightWallMount.isOn(light)) return 'Pared';
    return 'Pie';
  }
}
