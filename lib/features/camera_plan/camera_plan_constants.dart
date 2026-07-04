import 'package:flutter/material.dart';

enum ElementType { camera, actor, light, prop, wall }

/// Catálogo de fixtures — orden y nomenclatura alineados con Shot Designer.
enum LightType {
  sun,
  fresnelSmall,
  fresnelMedium,
  fresnelLarge,
  flo4Tubes,
  flo2Tubes,
  floSingle,
  lightPanel,
  led,
  led1x1,
  openFace,
  ellipsoidal,
  par,
  scoop,
  cyc,
  softbox,
  practical,
  bounce,
  flag,
  octagon,
  cutter,
  gel,
  cStand,
  generator,
  chimera,
  hmi,
}

extension ElementTypeCodec on ElementType {
  String get dbValue => name;

  static ElementType fromDb(String value) => ElementType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => ElementType.prop,
      );
}

extension LightTypeLabel on LightType {
  String get label => switch (this) {
        LightType.sun => 'Sun',
        LightType.fresnelSmall => 'Small Fresnel',
        LightType.fresnelMedium => 'Medium Fresnel',
        LightType.fresnelLarge => 'Large Fresnel',
        LightType.flo4Tubes => 'FLO 4 Tubes',
        LightType.flo2Tubes => 'FLO 2 Tubes',
        LightType.floSingle => 'Single FLO Tube',
        LightType.lightPanel => 'Light Panel',
        LightType.led => 'LED',
        LightType.led1x1 => 'LED 1x1 Panel',
        LightType.openFace => 'Open Face',
        LightType.ellipsoidal => 'Ellipsoidal',
        LightType.par => 'PAR Light',
        LightType.scoop => 'Scoop',
        LightType.cyc => 'Cyc Light',
        LightType.softbox => 'Soft Box',
        LightType.practical => 'Practical',
        LightType.bounce => 'Bounce',
        LightType.flag => 'Flag/Solid',
        LightType.octagon => 'Octagon',
        LightType.cutter => 'Cutter',
        LightType.gel => 'Gel',
        LightType.cStand => 'C-Stand',
        LightType.generator => 'Generador',
        LightType.chimera => 'Chimera',
        LightType.hmi => 'HMI',
      };

  String get dbValue => switch (this) {
        LightType.fresnelSmall => 'fresnel_small',
        LightType.fresnelMedium => 'fresnel_medium',
        LightType.fresnelLarge => 'fresnel_large',
        LightType.flo4Tubes => 'flo_4_tubes',
        LightType.flo2Tubes => 'flo_2_tubes',
        LightType.floSingle => 'flo_single',
        LightType.lightPanel => 'light_panel',
        LightType.led1x1 => 'led_1x1',
        LightType.openFace => 'open_face',
        LightType.par => 'par',
        LightType.cyc => 'cyc',
        _ => name,
      };

  static LightType? fromDb(String? value) {
    if (value == null || value.isEmpty) return null;
    final key = value.trim().toLowerCase();
    for (final t in LightType.values) {
      if (t.dbValue == key || t.name.toLowerCase() == key) return t;
    }
    return switch (key) {
      'fresnel' => LightType.fresnelMedium,
      'led_panel' || 'ledpanel' => LightType.led1x1,
      _ => LightType.fresnelMedium,
    };
  }
}

enum PropType {
  table,
  chair,
  rectangle,
  sofa,
  bed,
}

enum ArchitectureType {
  wall,
  window,
  doorOpen,
  doorClosed,
  doubleDoor,
  opening,
  prisonBars,
}

extension PropTypeCodec on PropType {
  String get dbValue => name;

  String get label => switch (this) {
        PropType.table => 'Mesa',
        PropType.chair => 'Silla',
        PropType.rectangle => 'Rectángulo',
        PropType.sofa => 'Sofá',
        PropType.bed => 'Cama',
      };

  IconData get icon => switch (this) {
        PropType.table => Icons.table_restaurant,
        PropType.chair => Icons.chair_outlined,
        PropType.rectangle => Icons.crop_square,
        PropType.sofa => Icons.weekend_outlined,
        PropType.bed => Icons.bed_outlined,
      };

  static PropType? fromLabel(String? value) {
    if (value == null || value.isEmpty) return null;
    return PropType.values.firstWhere(
      (t) => t.dbValue == value || t.name == value,
      orElse: () => PropType.rectangle,
    );
  }
}

extension ArchitectureTypeCodec on ArchitectureType {
  String get dbValue => name;

  String get label => switch (this) {
        ArchitectureType.wall => 'Pared',
        ArchitectureType.window => 'Ventana',
        ArchitectureType.doorOpen => 'Puerta abierta',
        ArchitectureType.doorClosed => 'Puerta cerrada',
        ArchitectureType.doubleDoor => 'Puerta doble',
        ArchitectureType.opening => 'Abertura',
        ArchitectureType.prisonBars => 'Rejas',
      };

  IconData get icon => switch (this) {
        ArchitectureType.wall => Icons.horizontal_rule,
        ArchitectureType.window => Icons.window,
        ArchitectureType.doorOpen => Icons.sensor_door_outlined,
        ArchitectureType.doorClosed => Icons.door_front_door_outlined,
        ArchitectureType.doubleDoor => Icons.door_sliding,
        ArchitectureType.opening => Icons.crop_landscape,
        ArchitectureType.prisonBars => Icons.grid_on,
      };

  static ArchitectureType? fromLabel(String? value) {
    if (value == null || value.isEmpty) return null;
    return ArchitectureType.values.firstWhere(
      (t) => t.dbValue == value || t.name == value,
      orElse: () => ArchitectureType.wall,
    );
  }
}

const kActorColors = [
  Color(0xFF0A84FF),
  Color(0xFF30D158),
  Color(0xFFFF9F0A),
  Color(0xFFFF453A),
  Color(0xFFBF5AF2),
  Color(0xFF64D2FF),
  Color(0xFFFFD60A),
  Color(0xFFAC8E68),
];

/// Colores de cámara por letra (convención multicámara / Shot Designer).
const kCameraColors = [
  Color(0xFF30D158), // A — verde
  Color(0xFF0A84FF), // B — azul
  Color(0xFFFF9F0A), // C — naranja
  Color(0xFFFF453A), // D — rojo
  Color(0xFFBF5AF2), // E — morado
  Color(0xFF64D2FF), // F — cian
  Color(0xFFFFD60A), // G — amarillo
  Color(0xFFAC8E68), // H — marrón
];

Color cameraColorForLetter(String letter) {
  if (letter.isEmpty) return kCameraColors.first;
  final index = letter.toUpperCase().codeUnitAt(0) - 65;
  if (index < 0) return kCameraColors.first;
  return kCameraColors[index % kCameraColors.length];
}

/// Orden del grid «Add New» de Shot Designer (3 filas × 8 columnas).
const kShotDesignerLightGrid = [
  LightType.sun,
  LightType.fresnelSmall,
  LightType.fresnelMedium,
  LightType.fresnelLarge,
  LightType.flo4Tubes,
  LightType.flo2Tubes,
  LightType.floSingle,
  LightType.lightPanel,
  LightType.led,
  LightType.led1x1,
  LightType.openFace,
  LightType.ellipsoidal,
  LightType.par,
  LightType.scoop,
  LightType.cyc,
  LightType.softbox,
  LightType.practical,
  LightType.bounce,
  LightType.flag,
  LightType.octagon,
  LightType.cutter,
  LightType.gel,
  LightType.cStand,
  LightType.generator,
  LightType.chimera,
];
