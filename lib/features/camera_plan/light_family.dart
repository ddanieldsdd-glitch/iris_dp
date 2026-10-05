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

/// Grupo de un aparato del catálogo, según cómo venga escrito su tipo
/// («led_panel», «LED Panel», «LED point-source»…).
LightGroup lightGroupForCatalogType(String? type) {
  final t = (type ?? '').toLowerCase().replaceAll(RegExp('[_-]'), ' ');
  final String id;
  if (t.contains('hmi')) {
    id = 'hmi';
  } else if (t.contains('balloon') || t.contains('globo')) {
    id = 'balloon';
  } else if (t.contains('practical')) {
    id = 'practical';
  } else if (t.contains('led')) {
    id = t.contains('pixel')
        ? 'led-pixel'
        : t.contains('tube')
        ? 'led-tube'
        : t.contains('flex')
        ? 'led-flex'
        : t.contains('panel')
        ? 'led-panel'
        : t.contains('fresnel')
        ? 'led-fresnel'
        : 'led-point';
  } else if (t.contains('tube') || t.contains('flo') || t.contains('kino')) {
    id = 'fluorescent';
  } else if (t.contains('par') || t.contains('open')) {
    id = 'tungsten-open';
  } else if (t.contains('ellipsoidal') || t.contains('profile')) {
    id = 'tungsten-stage';
  } else {
    id = 'tungsten-fresnel';
  }
  return lightGroupById(id);
}
