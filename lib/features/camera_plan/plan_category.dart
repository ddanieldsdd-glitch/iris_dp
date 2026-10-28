import 'package:flutter/material.dart';

import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light_beam.dart';
import 'rig/plan_rig.dart';

/// Qué es un elemento de la planta, a grandes rasgos, para reconocerlo de un
/// vistazo con un color: el mismo en la planta 2D, en el 3D y en la lista de
/// elementos (F6.20 A3–A5).
enum PlanCategory {
  camera('Cámaras', Color(0xFFE8963F)),
  light('Luces', Color(0xFFF2C94C)),
  grip('Grip', Color(0xFF9B8AE0)),
  furniture('Mobiliario y atrezzo', Color(0xFF4FB3A9)),
  architecture('Arquitectura', Color(0xFF8FA3B5)),
  rig('Rigging', Color(0xFFE06C6C)),
  people('Personas', Color(0xFF5B9BE0)),
  scan('Escaneos', Color(0xFFB07CC6)),
  other('Otros', Color(0xFF9AA0A6));

  final String label;
  final Color color;
  const PlanCategory(this.label, this.color);

  /// `#rrggbb`, para el visor 3D.
  String get hex =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static PlanCategory of(PlanElement el) {
    switch (RigTypeCodec.of(el)) {
      case RigType.scan:
        return PlanCategory.scan;
      case RigType.hall ||
          RigType.truss ||
          RigType.motor ||
          RigType.groundSupport ||
          RigType.pillar:
        return PlanCategory.rig;
      case null:
        break;
    }
    return switch (el.type) {
      ElementType.camera => PlanCategory.camera,
      ElementType.actor => PlanCategory.people,
      ElementType.wall => PlanCategory.architecture,
      ElementType.light =>
        LightBeam.emits(el.lightType) ? PlanCategory.light : PlanCategory.grip,
      ElementType.prop => switch (el.propType) {
        PropType.table ||
        PropType.chair ||
        PropType.rectangle ||
        PropType.sofa ||
        PropType.bed ||
        PropType.tree ||
        PropType.rock ||
        PropType.vehicle => PlanCategory.furniture,
        _ => PlanCategory.other,
      },
    };
  }

  /// Si el elemento tiene un asset de Unreal asignado (distintivo «UE»).
  static bool hasUnrealAsset(PlanElement el) =>
      el.props['unrealAsset'] is String || el.props['unreal'] is Map;

  /// Colores de todas, para que el visor 3D use los mismos.
  static Map<String, String> get palette => {
    for (final c in values) c.name: c.hex,
  };
}
