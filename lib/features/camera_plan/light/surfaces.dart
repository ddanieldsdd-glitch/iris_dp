/// Cómo devuelve la luz una superficie: cuánta, de qué color y cómo de
/// abierta.
class SurfaceMaterial {
  final String id;
  final String name;

  /// Parte de la luz que devuelve, de 0 a 1.
  final double reflectance;

  /// Tinte que añade, en mired (positivo = más cálido).
  final double miredShift;

  /// Ángulo de haz de lo que devuelve. Un rebote mate lo reparte por todo
  /// el frente (120°); uno plateado lo concentra.
  final double beamDeg;

  const SurfaceMaterial({
    required this.id,
    required this.name,
    required this.reflectance,
    this.miredShift = 0,
    this.beamDeg = 120,
  });

  static SurfaceMaterial byId(String? id, List<SurfaceMaterial> from) {
    for (final m in from) {
      if (m.id == id) return m;
    }
    return from.first;
  }
}

/// Materiales de un rebote de grip, con los nombres de los palios de
/// Rosco. Lo que devuelve cada uno y su tinte son valores orientativos.
const kBounceMaterials = <SurfaceMaterial>[
  SurfaceMaterial(
    id: 'ultrabounce',
    name: 'Ultrabounce',
    reflectance: 0.85,
    miredShift: -5,
  ),
  SurfaceMaterial(
    id: 'cinebounce',
    name: 'Cinebounce (cara blanca)',
    reflectance: 0.8,
  ),
  SurfaceMaterial(
    id: 'griffolyn',
    name: 'Griffolyn blanco',
    reflectance: 0.8,
    miredShift: -5,
  ),
  SurfaceMaterial(id: 'poly', name: 'Poliespán', reflectance: 0.8),
  SurfaceMaterial(
    id: 'molton-white',
    name: 'Molton blanco',
    reflectance: 0.7,
    beamDeg: 130,
  ),
  SurfaceMaterial(
    id: 'muslin-bleached',
    name: 'Muslin blanca',
    reflectance: 0.7,
    beamDeg: 130,
  ),
  SurfaceMaterial(
    id: 'muslin',
    name: 'Muslin cruda',
    reflectance: 0.6,
    miredShift: 30,
    beamDeg: 130,
  ),
  SurfaceMaterial(
    id: 'silver',
    name: 'Reflector plata',
    reflectance: 0.9,
    miredShift: -8,
    beamDeg: 70,
  ),
  SurfaceMaterial(
    id: 'gold',
    name: 'Reflector oro',
    reflectance: 0.75,
    miredShift: 85,
    beamDeg: 80,
  ),
  SurfaceMaterial(
    id: 'checkerboard',
    name: 'Checkerboard oro/plata',
    reflectance: 0.82,
    miredShift: 40,
    beamDeg: 75,
  ),
];

/// Materiales de pared: lo que rebotan al ambiente de la sala y con qué
/// tinte. Una pared blanca devuelve mucho y algo frío; el ladrillo, poco,
/// más marrón y más repartido. Valores orientativos.
const kWallMaterials = <SurfaceMaterial>[
  SurfaceMaterial(
    id: 'white',
    name: 'Blanca',
    reflectance: 0.75,
    miredShift: -8,
  ),
  SurfaceMaterial(id: 'cream', name: 'Crema', reflectance: 0.6, miredShift: 25),
  SurfaceMaterial(id: 'grey', name: 'Gris', reflectance: 0.35),
  SurfaceMaterial(
    id: 'concrete',
    name: 'Hormigón',
    reflectance: 0.35,
    miredShift: 8,
    beamDeg: 130,
  ),
  SurfaceMaterial(
    id: 'brick',
    name: 'Ladrillo',
    reflectance: 0.25,
    miredShift: 60,
    beamDeg: 140,
  ),
  SurfaceMaterial(
    id: 'wood',
    name: 'Madera',
    reflectance: 0.3,
    miredShift: 75,
    beamDeg: 130,
  ),
  SurfaceMaterial(id: 'black', name: 'Negra', reflectance: 0.04),
];

/// Suelos de un recinto: lo que devuelve la mancha de sol que cae sobre
/// ellos. Valores orientativos.
const kFloorMaterials = <SurfaceMaterial>[
  SurfaceMaterial(id: 'wood', name: 'Madera', reflectance: 0.3, miredShift: 25),
  SurfaceMaterial(id: 'concrete', name: 'Hormigón', reflectance: 0.25),
  SurfaceMaterial(id: 'light', name: 'Suelo claro', reflectance: 0.6),
  SurfaceMaterial(id: 'dark', name: 'Moqueta oscura', reflectance: 0.08),
];
