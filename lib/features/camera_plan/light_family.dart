import '../../shared/equipment/light_kind.dart';
import 'camera_plan_constants.dart';

/// Familias de luz por tecnología, para ordenar la paleta.
enum LightFamily { led, hmi, tungsten, fluorescent, practical }

extension LightFamilyInfo on LightFamily {
  String get label => switch (this) {
    LightFamily.led => 'LED',
    LightFamily.hmi => 'HMI',
    LightFamily.tungsten => 'Tungsteno',
    LightFamily.fluorescent => 'Fluorescente',
    LightFamily.practical => 'Prácticas y globos',
  };
}

/// Un tipo de aparato dentro de una familia: «Panel», «Tubo», «Fresnel»…
class LightGroup {
  final String id;
  final LightFamily family;
  final String name;

  /// Símbolos genéricos de la planta que caen en este grupo, con el nombre
  /// con el que se ofrecen.
  final List<(LightType, String)> generics;

  const LightGroup(this.id, this.family, this.name, this.generics);

  /// Símbolo con el que se dibuja un aparato del catálogo de este grupo.
  LightType get symbol => generics.first.$1;
}

const kLightGroups = <LightGroup>[
  LightGroup('led-panel', LightFamily.led, 'Panel', [
    (LightType.lightPanel, 'Panel LED'),
    (LightType.led1x1, 'Panel 1×1'),
  ]),
  LightGroup('led-flex', LightFamily.led, 'Flexible', [
    (LightType.lightPanel, 'Panel flexible'),
  ]),
  LightGroup('led-tube', LightFamily.led, 'Tubo', [
    (LightType.floSingle, 'Tubo LED'),
  ]),
  LightGroup('led-point', LightFamily.led, 'Puntual (COB)', [
    (LightType.led, 'LED puntual'),
  ]),
  LightGroup('led-fresnel', LightFamily.led, 'Fresnel LED', [
    (LightType.fresnelMedium, 'Fresnel LED'),
  ]),
  LightGroup('led-pixel', LightFamily.led, 'Barra de píxeles', [
    (LightType.floSingle, 'Barra de píxeles'),
  ]),
  LightGroup('hmi', LightFamily.hmi, 'HMI', [(LightType.hmi, 'HMI')]),
  LightGroup('tungsten-fresnel', LightFamily.tungsten, 'Fresnel', [
    (LightType.fresnelSmall, 'Fresnel pequeño'),
    (LightType.fresnelMedium, 'Fresnel mediano'),
    (LightType.fresnelLarge, 'Fresnel grande'),
  ]),
  LightGroup('tungsten-open', LightFamily.tungsten, 'Abierta y PAR', [
    (LightType.openFace, 'Cuarzo abierto'),
    (LightType.par, 'PAR'),
  ]),
  LightGroup('tungsten-stage', LightFamily.tungsten, 'Recorte y ciclorama', [
    (LightType.ellipsoidal, 'Recorte'),
    (LightType.scoop, 'Scoop'),
    (LightType.cyc, 'Ciclorama'),
  ]),
  LightGroup('fluorescent', LightFamily.fluorescent, 'Tubos', [
    (LightType.flo4Tubes, 'Pantalla de 4 tubos'),
    (LightType.flo2Tubes, 'Pantalla de 2 tubos'),
    (LightType.floSingle, 'Tubo suelto'),
  ]),
  LightGroup('practical', LightFamily.practical, 'Prácticas', [
    (LightType.practical, 'Práctica'),
  ]),
  LightGroup('balloon', LightFamily.practical, 'Globos', [
    (LightType.practical, 'Globo'),
  ]),
];

LightGroup lightGroupById(String id) =>
    kLightGroups.firstWhere((g) => g.id == id);

/// Grupo de un aparato del catálogo, por su formato y su tecnología
/// (`led_fresnel`, `hmi_open`… o, de antes, «LED Panel», «LED point-source»).
LightGroup lightGroupForCatalogType(String? type) {
  final kind = LightKind.parse(type);
  final id = switch ((kind.technology, kind.format)) {
    (_, LightFormat.balloon) => 'balloon',
    (_, LightFormat.practical) => 'practical',
    (LightTechnology.hmi, _) => 'hmi',
    (LightTechnology.led, LightFormat.panel) => 'led-panel',
    (LightTechnology.led, LightFormat.flex) => 'led-flex',
    (LightTechnology.led, LightFormat.tube) => 'led-tube',
    (LightTechnology.led, LightFormat.fresnel) => 'led-fresnel',
    (LightTechnology.led, _) => 'led-point',
    (LightTechnology.fluorescent, _) => 'fluorescent',
    (_, LightFormat.open) => 'tungsten-open',
    (_, LightFormat.profile) => 'tungsten-stage',
    _ => 'tungsten-fresnel',
  };
  // Las barras de píxeles de antes conservan su grupo.
  if (id == 'led-tube' && (type ?? '').toLowerCase().contains('pixel')) {
    return lightGroupById('led-pixel');
  }
  return lightGroupById(id);
}
