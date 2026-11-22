import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light_beam.dart';
import 'rig/plan_drape.dart';
import 'rig/plan_rig.dart';

/// Qué es cada cosa de la planta, para enseñarla u ocultarla por vista
/// (plan AR.1), como las clases de Vectorworks: lo que se oculta no se
/// borra ni deja de dar luz; solo no se dibuja.
enum PlanClass {
  architecture('Arquitectura'),
  decor('Decorado'),
  fixtures('Aparatos de luz'),
  grip('Grip: marcos, banderas, rebotes'),
  rigging('Rigging: truss, motores, telas'),
  people('Personas'),
  cameras('Cámaras');

  const PlanClass(this.label);
  final String label;

  static PlanClass of(PlanElement el) {
    switch (el.type) {
      case ElementType.camera:
        return PlanClass.cameras;
      case ElementType.actor:
        return PlanClass.people;
      case ElementType.wall:
        return PlanDrape.isDrape(el)
            ? PlanClass.rigging
            : PlanClass.architecture;
      case ElementType.light:
        return LightBeam.emits(el.lightType)
            ? PlanClass.fixtures
            : PlanClass.grip;
      case ElementType.prop:
        final rig = RigTypeCodec.of(el);
        if (rig == RigType.hall || rig == RigType.pillar) {
          return PlanClass.architecture;
        }
        if (rig != null) return PlanClass.rigging;
        return PlanClass.decor;
    }
  }

  /// Lo que se dibuja de [elements] con [hidden] oculto.
  static List<PlanElement> shown(
    List<PlanElement> elements,
    Set<PlanClass> hidden,
  ) => hidden.isEmpty
      ? elements
      : elements.where((e) => !hidden.contains(of(e))).toList();

  /// Para guardarlo: los nombres separados por comas.
  static Set<PlanClass> decode(String text) => {
    for (final n in text.split(',')) ?values.asNameMap()[n.trim()],
  };

  static String encode(Set<PlanClass> hidden) => [
    for (final c in values)
      if (hidden.contains(c)) c.name,
  ].join(',');
}
