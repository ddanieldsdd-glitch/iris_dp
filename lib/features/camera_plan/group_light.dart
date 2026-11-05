import 'camera_plan_element_model.dart';
import 'floor_plan_json.dart';
import 'light_overrides.dart';

/// La luz compartida de un grupo de sets tal como la ve cada set (SG.3).
///
/// Un set puede llevar su propia versión de una luz del grupo (un elemento
/// con el mismo identificador en su planta) o no llevarla
/// (`FloorPlanDocument.hiddenGroupLights`). Lo demás del grupo lo ve igual
/// que los otros sets.
abstract final class GroupLight {
  /// Las luces del grupo ([groupJson]) que se ven en el set ([setupJson]).
  static List<PlanElement> visible(String? groupJson, String? setupJson) {
    final group = FloorPlanJson.decode(groupJson);
    if (group.isEmpty) return group;
    final own = FloorPlanJson.decodeDocument(setupJson);
    final shadow = {
      ...own.hiddenGroupLights,
      for (final el in own.elements) ?LightOverrides.uidOf(el),
    };
    return [
      for (final el in group)
        if (!shadow.contains(LightOverrides.uidOf(el))) el,
    ];
  }
}
