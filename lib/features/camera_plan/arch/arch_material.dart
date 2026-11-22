import 'dart:math' as math;

import '../camera_plan_element_model.dart';
import '../light/surfaces.dart';

/// De qué está hecha una superficie (plan AM.1): agrupa la biblioteca en
/// el selector y dice a Unreal qué tipo de material es.
enum ArchFamily {
  plaster('Yeso y pintura'),
  concrete('Hormigón'),
  brick('Ladrillo'),
  stone('Piedra'),
  tile('Baldosa'),
  wood('Madera'),
  metal('Metal'),
  glass('Vidrio'),
  fabric('Tela y piel'),
  asphalt('Asfalto'),
  earth('Tierra'),
  sand('Arena'),
  grass('Hierba'),
  water('Agua');

  const ArchFamily(this.label);
  final String label;
}

/// Una textura CC0 de la biblioteca: lo que mide en la realidad un
/// recuadro de la imagen y su color medio, para que la luz y el 3D digan
/// lo mismo.
class ArchTexture {
  /// Nombre de los archivos en `assets/viewer3d/textures/`:
  /// `<file>_albedo.jpg`, `_normal.jpg`, `_rough.jpg` y, si es metal,
  /// `_metal.jpg`.
  final String file;

  /// De dónde sale. Todas son CC0 (dominio público).
  final String source;

  /// Ancho y alto de un recuadro de la textura, en metros.
  final double widthM;
  final double heightM;

  /// Color medio del albedo, lineal (0–1).
  final (double, double, double) mean;

  /// Trae mapa de metal.
  final bool metalMap;

  const ArchTexture(
    this.file, {
    required this.widthM,
    required this.heightM,
    required this.mean,
    this.source = 'ambientCG',
    this.metalMap = false,
  });

  static const folder = 'assets/viewer3d/textures';

  /// Ruta del albedo dentro de la app (miniaturas del selector).
  String get albedoAsset => '$folder/${file}_albedo.jpg';

  /// Ficha de la fuente, para el manifiesto de licencias.
  String get sourceUrl => 'https://ambientcg.com/a/$file';
}

/// Un material de arquitectura (plan AM.1): cómo devuelve la luz (para el
/// motor de luz) y cómo se ve (PBR, para el 3D y Unreal), con su textura
/// CC0 si la tiene.
///
/// Con textura, lo que devuelve y su tinte salen del color medio de la
/// imagen. Los materiales de siempre de pared y suelo guardan sus números
/// y la textura se tiñe para casar con ellos.
class ArchMaterial {
  final String id;
  final String name;
  final ArchFamily family;

  final double _reflectance;
  final double _miredShift;

  /// Ángulo de lo que devuelve, como en [SurfaceMaterial.beamDeg].
  final double beamDeg;

  /// PBR: 0 = espejo, 1 = mate.
  final double roughness;
  final double metalness;

  /// Parte de la luz que pasa (vidrio, agua, PVC).
  final double transmission;
  final double ior;

  final ArchTexture? texture;

  const ArchMaterial({
    required this.id,
    required this.name,
    required this.family,
    double? reflectance,
    double? miredShift,
    this.beamDeg = 120,
    this.roughness = 0.85,
    this.metalness = 0,
    this.transmission = 0,
    this.ior = 1.5,
    this.texture,
  }) : _reflectance = reflectance ?? -1,
       _miredShift = miredShift ?? 0;

  /// Parte de la luz que devuelve, de 0 a 1. Si no se puso a mano, la
  /// luminancia del color medio de su textura.
  double get reflectance {
    if (_reflectance >= 0) return _reflectance;
    final t = texture;
    if (t == null) return 0.5;
    final (r, g, b) = t.mean;
    return (0.2126 * r + 0.7152 * g + 0.0722 * b).clamp(0.02, 0.95);
  }

  /// Tinte en mired (positivo = más cálido). Si no se puso a mano, el de
  /// la textura: el reparto entre rojo y azul de su color medio.
  double get miredShift {
    if (_reflectance >= 0) return _miredShift;
    final t = texture;
    if (t == null) return _miredShift;
    final (r, _, b) = t.mean;
    if (r + b <= 0) return 0;
    return ((r - b) / (r + b) * 250).clamp(-87.5, 87.5);
  }

  /// Para el motor de luz.
  SurfaceMaterial get surface => surfaceAs(id);

  /// Con otro `id`: las listas de siempre ([kWallMaterials]…) conservan
  /// los suyos.
  SurfaceMaterial surfaceAs(String legacyId) => SurfaceMaterial(
    id: legacyId,
    name: name,
    reflectance: reflectance,
    miredShift: miredShift,
    beamDeg: beamDeg,
  );

  /// Color de la superficie como 0xRRGGBB lineal. Con números puestos a
  /// mano, el que usa la luz; si sale de su textura, el color medio de la
  /// imagen tal cual (la luz solo toma de él el brillo y el tinte).
  int get albedoRgb {
    final t = texture;
    if (_reflectance >= 0 || t == null) return surface.albedoRgb;
    int byte(double v) => (v.clamp(0.0, 1.0) * 255).round();
    final (r, g, b) = t.mean;
    return byte(r) << 16 | byte(g) << 8 | byte(b);
  }

  /// Lo que multiplica la textura (lineal) para que su brillo sea el que
  /// usa la luz: el mismo en los tres canales, así la textura conserva su
  /// color (una tarima de roble sigue siendo marrón). 1 si el material sale
  /// de su textura.
  List<double> get tint {
    final t = texture;
    if (t == null) return const [1, 1, 1];
    final (r, g, b) = t.mean;
    final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    final k = ((reflectance / math.max(lum, 0.005)) * 1000).round() / 1000;
    return [k, k, k];
  }

  /// Para el visor 3D y el glTF que va a Unreal (`iris.scene3d`).
  Map<String, dynamic> toScene() => {
    'name': name,
    'family': family.name,
    'rgb': albedoRgb,
    'rough': roughness,
    if (metalness > 0) 'metal': metalness,
    if (transmission > 0) ...{'trans': transmission, 'ior': ior},
    if (texture case final t?)
      'tex': {
        'file': t.file,
        'w': t.widthM,
        'h': t.heightM,
        'tint': tint,
        if (t.metalMap) 'metalMap': true,
      },
  };
}

/// La biblioteca de materiales (plan AM.1) y cómo se lee el de cada pieza.
abstract final class ArchMaterials {
  /// Material de una cara de la pieza: un `id` de [all]. Manda sobre el
  /// `material` de siempre de las paredes.
  static const key = 'mat';

  static final Map<String, ArchMaterial> _byId = {
    for (final m in all) m.id: m,
  };

  static ArchMaterial? byId(String? id) => id == null ? null : _byId[id];

  /// Los `id` de pared de siempre (`props['material']`) en la biblioteca.
  static const wallLegacy = {
    'white': 'paint-white',
    'cream': 'paint-cream',
    'grey': 'paint-grey',
    'concrete': 'concrete-smooth',
    'brick': 'brick-old',
    'wood': 'wood-planks',
    'black': 'paint-black',
  };

  /// Los `id` de suelo de un recinto de siempre.
  static const floorLegacy = {
    'wood': 'wood-floor-oak',
    'concrete': 'concrete-floor',
    'light': 'tile-light',
    'dark': 'carpet-dark',
  };

  /// Material de una pared: el de la biblioteca (`mat`) o el de siempre
  /// (`material`). `null` si no se le ha elegido ninguno.
  static ArchMaterial? ofWall(PlanElement el) {
    if (byId(el.props[key] as String?) case final m?) return m;
    // Las fachadas de una calle, el de sus fachadas.
    if (byId(el.props[facadeKey] as String?) case final m?) return m;
    return byId(wallLegacy[el.props['material']]);
  }

  /// Lo que devuelve la pared para la luz: el de siempre si no hay
  /// material de la biblioteca.
  static SurfaceMaterial wallSurface(PlanElement el, String? legacyId) =>
      (byId(el.props[key] as String?) ??
              byId(el.props[facadeKey] as String?))
          ?.surface ??
      SurfaceMaterial.byId(legacyId, kWallMaterials);

  /// Lo que devuelve el suelo de un recinto: uno de la biblioteca o uno
  /// de los de siempre (`kFloorMaterials`).
  static SurfaceMaterial floorSurface(String? id) =>
      byId(id)?.surface ?? SurfaceMaterial.byId(id, kFloorMaterials);

  /// El material de la biblioteca de un suelo de recinto guardado.
  static ArchMaterial floorOf(String? id) =>
      byId(id) ??
      byId(floorLegacy[SurfaceMaterial.byId(id, kFloorMaterials).id])!;

  /// Lo que se guarda al elegir [m]: el `id` de siempre si es uno de
  /// ellos (una versión anterior de IRIS lo sigue leyendo) o el suyo.
  static String storedId(ArchMaterial m, Map<String, String> legacy) =>
      legacy.entries.where((e) => e.value == m.id).firstOrNull?.key ?? m.id;

  /// Materiales de una calle con perfil: calzada, aceras y fachadas.
  static const roadKey = 'roadMat';
  static const walkKey = 'walkMat';
  static const facadeKey = 'facadeMat';
  static const defaultRoad = 'asphalt';
  static const defaultWalk = 'stone-paving';

  static String streetMat(PlanElement street, String key) =>
      (byId(street.props[key] as String?)?.id) ??
      (key == roadKey ? defaultRoad : defaultWalk);

  /// Suelo de una nave.
  static const hallFloorKey = 'floorMat';
  static const defaultHallFloor = 'concrete-floor';

  /// Cubierta de una nave (salvo la de lona, que es su tela).
  static const hallRoofKey = 'roofMat';

  /// Los que sirven para paredes, suelos, cubiertas y volúmenes: todos
  /// menos las telas de colgar.
  static Iterable<ArchMaterial> get building =>
      all.where((m) => !m.id.startsWith('drape-'));

  /// Manifiesto de licencias de las texturas que van con la app.
  static List<Map<String, String>> get licenses => [
    for (final m in all)
      if (m.texture case final t?)
        {
          'material': m.id,
          'file': t.file,
          'source': t.source,
          'url': t.sourceUrl,
          'license': 'CC0 1.0',
        },
  ];

  static const all = <ArchMaterial>[
    // Yeso y pintura. Los de siempre de pared, con sus números.
    ArchMaterial(
      id: 'paint-white',
      name: 'Pintura blanca',
      family: ArchFamily.plaster,
      reflectance: 0.75,
      miredShift: -8,
      roughness: 0.9,
      texture: _paintedPlaster,
    ),
    ArchMaterial(
      id: 'paint-cream',
      name: 'Pintura crema',
      family: ArchFamily.plaster,
      reflectance: 0.6,
      miredShift: 25,
      roughness: 0.9,
      texture: _paintedPlaster,
    ),
    ArchMaterial(
      id: 'paint-grey',
      name: 'Pintura gris',
      family: ArchFamily.plaster,
      reflectance: 0.35,
      roughness: 0.9,
      texture: _paintedPlaster,
    ),
    ArchMaterial(
      id: 'paint-black',
      name: 'Pintura negra',
      family: ArchFamily.plaster,
      reflectance: 0.04,
      roughness: 0.95,
    ),
    ArchMaterial(
      id: 'plaster-raw',
      name: 'Yeso sin pintar',
      family: ArchFamily.plaster,
      roughness: 0.95,
      beamDeg: 130,
      texture: ArchTexture(
        'Plaster001',
        widthM: 2,
        heightM: 2,
        mean: (0.6792, 0.6528, 0.6294),
      ),
    ),
    // Hormigón.
    ArchMaterial(
      id: 'concrete-smooth',
      name: 'Hormigón liso',
      family: ArchFamily.concrete,
      reflectance: 0.35,
      miredShift: 8,
      beamDeg: 130,
      roughness: 0.9,
      texture: ArchTexture(
        'Concrete034',
        widthM: 1.1,
        heightM: 0.55,
        mean: (0.4817, 0.4817, 0.4817),
      ),
    ),
    ArchMaterial(
      id: 'concrete-floor',
      name: 'Solera de hormigón',
      family: ArchFamily.concrete,
      reflectance: 0.25,
      roughness: 0.9,
      texture: ArchTexture(
        'Concrete047A',
        widthM: 2.5,
        heightM: 2.5,
        mean: (0.2861, 0.2478, 0.1747),
      ),
    ),
    // Ladrillo.
    ArchMaterial(
      id: 'brick-old',
      name: 'Ladrillo viejo',
      family: ArchFamily.brick,
      reflectance: 0.25,
      miredShift: 60,
      beamDeg: 140,
      roughness: 0.9,
      texture: ArchTexture(
        'Bricks097',
        widthM: 2,
        heightM: 1,
        mean: (0.2537, 0.1683, 0.1054),
      ),
    ),
    ArchMaterial(
      id: 'brick-tan',
      name: 'Ladrillo caravista claro',
      family: ArchFamily.brick,
      beamDeg: 140,
      roughness: 0.9,
      texture: ArchTexture(
        'Bricks105',
        widthM: 2.4,
        heightM: 1.2,
        mean: (0.4875, 0.2991, 0.1492),
      ),
    ),
    // Piedra.
    ArchMaterial(
      id: 'stone-paving',
      name: 'Adoquín',
      family: ArchFamily.stone,
      roughness: 0.9,
      texture: ArchTexture(
        'PavingStones150',
        widthM: 0.9,
        heightM: 0.9,
        mean: (0.2070, 0.1702, 0.1148),
      ),
    ),
    ArchMaterial(
      id: 'stone-rock',
      name: 'Roca con musgo',
      family: ArchFamily.stone,
      beamDeg: 140,
      roughness: 0.95,
      texture: ArchTexture(
        'Rock063',
        widthM: 2,
        heightM: 1,
        mean: (0.2396, 0.2059, 0.0503),
      ),
    ),
    ArchMaterial(
      id: 'stone-marble',
      name: 'Mármol',
      family: ArchFamily.stone,
      roughness: 0.25,
      texture: ArchTexture(
        'Marble012',
        widthM: 1,
        heightM: 1,
        mean: (0.4202, 0.4253, 0.4734),
      ),
    ),
    ArchMaterial(
      id: 'stone-slate-roof',
      name: 'Teja de pizarra',
      family: ArchFamily.stone,
      roughness: 0.7,
      texture: ArchTexture(
        'RoofingTiles013A',
        widthM: 2.9,
        heightM: 2.9,
        mean: (0.0315, 0.0303, 0.0364),
      ),
    ),
    // Baldosa.
    ArchMaterial(
      id: 'tile-light',
      name: 'Baldosa clara',
      family: ArchFamily.tile,
      reflectance: 0.6,
      roughness: 0.5,
      texture: ArchTexture(
        'Tiles139',
        widthM: 2,
        heightM: 2,
        mean: (0.4578, 0.3506, 0.2546),
      ),
    ),
    // Madera.
    ArchMaterial(
      id: 'wood-floor-oak',
      name: 'Tarima de roble',
      family: ArchFamily.wood,
      reflectance: 0.3,
      miredShift: 25,
      roughness: 0.6,
      texture: ArchTexture(
        'WoodFloor051',
        widthM: 1.8,
        heightM: 1.8,
        mean: (0.3293, 0.1993, 0.1135),
      ),
    ),
    ArchMaterial(
      id: 'wood-floor-dark',
      name: 'Tarima oscura',
      family: ArchFamily.wood,
      roughness: 0.6,
      texture: ArchTexture(
        'WoodFloor043',
        widthM: 1.3,
        heightM: 0.65,
        mean: (0.1381, 0.0641, 0.0194),
      ),
    ),
    ArchMaterial(
      id: 'wood-planks',
      name: 'Tablas de madera',
      family: ArchFamily.wood,
      reflectance: 0.3,
      miredShift: 75,
      beamDeg: 130,
      roughness: 0.75,
      texture: ArchTexture(
        'Planks037A',
        widthM: 2,
        heightM: 2,
        mean: (0.0825, 0.0489, 0.0280),
      ),
    ),
    ArchMaterial(
      id: 'wood-painted',
      name: 'Madera pintada vieja',
      family: ArchFamily.wood,
      roughness: 0.8,
      texture: ArchTexture(
        'PaintedWood008C',
        widthM: 1,
        heightM: 1,
        mean: (0.1145, 0.0693, 0.0294),
      ),
    ),
    // Metal.
    ArchMaterial(
      id: 'metal-corrugated',
      name: 'Chapa ondulada',
      family: ArchFamily.metal,
      roughness: 0.5,
      metalness: 0.9,
      beamDeg: 90,
      texture: ArchTexture(
        'CorrugatedSteel005',
        widthM: 1,
        heightM: 1,
        mean: (0.3223, 0.3296, 0.3425),
        metalMap: true,
      ),
    ),
    ArchMaterial(
      id: 'metal-brushed',
      name: 'Metal claro',
      family: ArchFamily.metal,
      reflectance: 0.6,
      roughness: 0.35,
      metalness: 1,
      beamDeg: 70,
      texture: ArchTexture(
        'Metal049A',
        widthM: 1,
        heightM: 1,
        mean: (0.9717, 0.9629, 0.9224),
        metalMap: true,
      ),
    ),
    // Vidrio y agua: sin textura.
    ArchMaterial(
      id: 'glass-clear',
      name: 'Vidrio',
      family: ArchFamily.glass,
      reflectance: 0.08,
      roughness: 0.05,
      transmission: 0.9,
      ior: 1.5,
      beamDeg: 30,
    ),
    ArchMaterial(
      id: 'glass-frosted',
      name: 'Vidrio esmerilado',
      family: ArchFamily.glass,
      reflectance: 0.15,
      roughness: 0.6,
      transmission: 0.7,
      ior: 1.5,
    ),
    ArchMaterial(
      id: 'water',
      name: 'Agua',
      family: ArchFamily.water,
      reflectance: 0.06,
      miredShift: -20,
      roughness: 0.05,
      transmission: 0.85,
      ior: 1.33,
      beamDeg: 30,
    ),
    // Tela y piel de decorado (las de colgar van aparte).
    ArchMaterial(
      id: 'fabric-corduroy',
      name: 'Pana roja',
      family: ArchFamily.fabric,
      roughness: 0.95,
      beamDeg: 140,
      texture: ArchTexture(
        'Fabric026',
        widthM: 0.5,
        heightM: 0.5,
        mean: (0.1917, 0.0352, 0.0428),
      ),
    ),
    ArchMaterial(
      id: 'carpet-beige',
      name: 'Moqueta beige',
      family: ArchFamily.fabric,
      roughness: 1,
      beamDeg: 140,
      texture: ArchTexture(
        'Carpet016',
        widthM: 1.7,
        heightM: 1.7,
        mean: (0.5010, 0.4353, 0.2947),
      ),
    ),
    ArchMaterial(
      id: 'carpet-dark',
      name: 'Moqueta oscura',
      family: ArchFamily.fabric,
      reflectance: 0.08,
      roughness: 1,
      beamDeg: 140,
    ),
    ArchMaterial(
      id: 'leather',
      name: 'Cuero',
      family: ArchFamily.fabric,
      roughness: 0.55,
      texture: ArchTexture(
        'Leather037',
        widthM: 0.5,
        heightM: 0.5,
        mean: (0.1265, 0.0390, 0.0219),
      ),
    ),
    // Exterior.
    ArchMaterial(
      id: 'asphalt',
      name: 'Asfalto',
      family: ArchFamily.asphalt,
      roughness: 0.95,
      texture: ArchTexture(
        'Asphalt031',
        widthM: 2,
        heightM: 2,
        mean: (0.1951, 0.1951, 0.1949),
      ),
    ),
    ArchMaterial(
      id: 'earth',
      name: 'Tierra',
      family: ArchFamily.earth,
      roughness: 1,
      beamDeg: 140,
      texture: ArchTexture(
        'Ground054',
        widthM: 3.5,
        heightM: 3.5,
        mean: (0.3330, 0.2585, 0.1561),
      ),
    ),
    ArchMaterial(
      id: 'sand',
      name: 'Arena de playa',
      family: ArchFamily.sand,
      roughness: 1,
      beamDeg: 140,
      texture: ArchTexture(
        'Ground080',
        widthM: 2,
        heightM: 2,
        mean: (0.4614, 0.3428, 0.1648),
      ),
    ),
    ArchMaterial(
      id: 'grass',
      name: 'Césped',
      family: ArchFamily.grass,
      roughness: 1,
      beamDeg: 140,
      texture: ArchTexture(
        'Grass004',
        widthM: 1.4,
        heightM: 1.4,
        mean: (0.1268, 0.1610, 0.0342),
      ),
    ),
    // Telas de colgar (paredes de tela): su PBR. Lo que pesan y dejan
    // pasar sigue en `kDrapeMaterials`.
    ArchMaterial(
      id: 'drape-molleton',
      name: 'Molletón',
      family: ArchFamily.fabric,
      reflectance: 0.03,
      roughness: 0.98,
    ),
    ArchMaterial(
      id: 'drape-raso',
      name: 'Raso / terciopelo',
      family: ArchFamily.fabric,
      reflectance: 0.08,
      roughness: 0.7,
    ),
    ArchMaterial(
      id: 'drape-lona',
      name: 'Lona',
      family: ArchFamily.fabric,
      reflectance: 0.6,
      roughness: 0.9,
      transmission: 0.05,
    ),
    ArchMaterial(
      id: 'drape-pvc',
      name: 'PVC transparente',
      family: ArchFamily.fabric,
      reflectance: 0.08,
      roughness: 0.15,
      transmission: 0.85,
      ior: 1.4,
    ),
    ArchMaterial(
      id: 'drape-tul',
      name: 'Tul / gasa',
      family: ArchFamily.fabric,
      reflectance: 0.4,
      roughness: 0.95,
      transmission: 0.7,
      ior: 1.0,
    ),
  ];

  static const _paintedPlaster = ArchTexture(
    'PaintedPlaster017',
    widthM: 2,
    heightM: 1,
    mean: (0.5142, 0.5186, 0.4956),
  );
}
