import '../camera_plan/arch/arch_solid.dart';
import '../camera_plan/arch/arch_stair.dart';
import '../camera_plan/camera_plan_constants.dart';
import '../camera_plan/camera_plan_element_model.dart';
import '../camera_plan/light/street_lamp.dart';
import '../camera_plan/plan_opening.dart';
import '../camera_plan/plan_segment.dart';
import '../camera_plan/rig/plan_hall.dart';
import '../camera_plan/rig/plan_rig.dart';
import 'unreal_asset_ref.dart';

/// Ayudas para vincular piezas de la planta con assets de Unreal (AM.U2):
/// qué buscar para cada pieza, cuáles se ajustan a sus medidas y cuáles
/// son iguales, para vincularlas todas de una vez.
abstract final class UnrealLinkHints {
  /// Las piezas de arquitectura cuyo asset se ajusta a sus medidas.
  static bool canFit(PlanElement el) =>
      PlanOpening.isOpening(el) ||
      (PlanSegment.isSegment(el) &&
          PlanSegment.kind(el) == PlanSegment.kindWall) ||
      PlanPillar.isPillar(el) ||
      ArchSolid.isSolid(el);

  /// Lo que se busca en Unreal para la pieza, en inglés, que es como se
  /// llaman los assets de Fab y Megascans. Vacío: todo.
  static String queryFor(PlanElement el) {
    if (PlanOpening.isDoor(el)) return 'door';
    if (PlanOpening.isWindow(el)) return 'window';
    if (PlanOpening.isOpening(el)) return '';
    if (StreetLamp.isOn(el)) return 'street lamp';
    if (PlanPillar.isPillar(el)) return 'column';
    if (ArchSolid.isSlab(el)) return 'floor';
    if (ArchStair.isStair(el)) return 'stairs';
    if (PlanSegment.isSegment(el)) {
      return switch (PlanSegment.kind(el)) {
        PlanSegment.kindWall => 'wall',
        _ => '',
      };
    }
    if (el.type == ElementType.prop) {
      return switch (el.propType) {
        PropType.chair => 'chair',
        PropType.table => 'table',
        PropType.sofa => 'sofa',
        PropType.bed => 'bed',
        PropType.tree => 'tree',
        PropType.rock => 'rock',
        PropType.vehicle => 'car',
        _ => '',
      };
    }
    return '';
  }

  /// Lo que hace iguales a dos piezas: la misma clase de pieza con las
  /// mismas medidas o el mismo nombre. `null`: no se agrupa.
  static String? signature(PlanElement el) {
    String m(double v) => v.toStringAsFixed(2);
    if (PlanOpening.isOpening(el)) {
      return 'opening:${el.architectureType?.name}:'
          '${m(PlanOpening.width(el))}:${m(PlanOpening.head(el))}:'
          '${m(PlanOpening.sill(el))}';
    }
    if (StreetLamp.isOn(el)) {
      return 'lamp:${StreetLamp.isPole(el) ? 'pole' : 'arm'}';
    }
    if (PlanPillar.isPillar(el)) {
      return 'pillar:${PlanPillar.isRound(el)}:${m(PlanPillar.sizeM(el))}';
    }
    if (ArchSolid.isSolid(el)) {
      final s = ArchSolid.sizeM(el);
      return 'solid:${RigTypeCodec.of(el)?.name}:${m(s.width)}:'
          '${m(s.height)}:${ArchSolid.material(el).id}';
    }
    if (el.type == ElementType.prop && el.propType != null) {
      return 'prop:${el.propType!.name}:${el.customName ?? ''}';
    }
    return null;
  }

  /// Las otras piezas iguales a [el] en [all]: si es de una receta (una
  /// nave), solo las de esa receta.
  static List<PlanElement> siblingsOf(
    PlanElement el,
    Iterable<PlanElement> all,
  ) {
    final sig = signature(el);
    if (sig == null) return const [];
    final hall = PlanHall.hallUidOf(el);
    return [
      for (final o in all)
        if (!identical(o, el) &&
            signature(o) == sig &&
            (hall == null || PlanHall.hallUidOf(o) == hall))
          o,
    ];
  }

  /// Pone a [others] el mismo asset que [el], con su ajuste a medidas.
  /// Devuelve a cuántas ha cambiado.
  static int copyTo(PlanElement el, Iterable<PlanElement> others) {
    final ref = UnrealAssetRef.of(el);
    var n = 0;
    for (final o in others) {
      if (UnrealAssetRef.of(o)?.path == ref?.path &&
          UnrealAssetRef.fits(o) == UnrealAssetRef.fits(el)) {
        continue;
      }
      UnrealAssetRef.set(o, ref);
      UnrealAssetRef.setFits(o, UnrealAssetRef.fits(el));
      n++;
    }
    return n;
  }
}
