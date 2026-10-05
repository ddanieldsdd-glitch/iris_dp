import 'dart:math' as math;

/// Qué hace un modificador delante de una luz.
enum ModifierKind {
  /// Tela o filtro de difusión: quita luz y la ablanda.
  diffusion,

  /// Red metálica: quita luz sin cambiar su calidad.
  scrim,

  /// Gelatina de corrección de color: quita luz y cambia la temperatura.
  correction,
}

/// Difusión, red o gelatina que se pone delante de un aparato.
///
/// Los valores de transmisión y de cambio de temperatura son los que
/// publican los fabricantes en sus muestrarios, redondeados. Son
/// orientativos: cambian con el lote y con la fuente, así que conviene
/// contrastarlos con el muestrario antes de fiarse de un tercio de stop.
class LightModifier {
  final String id;
  final String name;

  /// Referencia del fabricante, p. ej. «Rosco 3407».
  final String? reference;
  final ModifierKind kind;

  /// Parte de la luz que deja pasar, de 0 a 1.
  final double transmission;

  /// Cambio de temperatura de color, en mired (positivo = más cálido).
  final double miredShift;

  /// Ángulo de haz mínimo que deja la difusión. `null` = no abre el haz.
  final double? spreadDeg;

  /// La reducción de luz es la que publica el fabricante. Si no, es una
  /// cifra orientativa del oficio.
  final bool published;

  const LightModifier({
    required this.id,
    required this.name,
    required this.kind,
    required this.transmission,
    this.reference,
    this.miredShift = 0,
    this.spreadDeg,
    this.published = false,
  });

  /// Stops de luz que quita.
  double get stopsLost =>
      transmission <= 0 ? double.infinity : -math.log(transmission) / math.ln2;

  /// Temperatura de color que queda al ponerlo delante de [kelvin].
  double shiftCct(double kelvin) {
    if (miredShift == 0 || kelvin <= 0) return kelvin;
    final mired = 1e6 / kelvin + miredShift;
    return mired <= 0 ? kelvin : 1e6 / mired;
  }

  static LightModifier? byId(String? id) {
    if (id == null) return null;
    for (final m in kLightModifiers) {
      if (m.id == id) return m;
    }
    return null;
  }

  static List<LightModifier> ofKind(ModifierKind kind) =>
      kLightModifiers.where((m) => m.kind == kind).toList();
}

/// Catálogo de difusiones, redes y gelatinas.
///
/// Los nombres y referencias de las telas son los de los palios de Rosco
/// (Grid Cloth, Silent Grid Cloth, sedas, gasas, muselinas). Rosco publica
/// la reducción de luz de sedas y gasas, y esas van marcadas `published`;
/// la del resto es la cifra habitual del oficio, orientativa.
const kLightModifiers = <LightModifier>[
  // ── Grid cloth ──
  LightModifier(
    id: 'grid-quarter',
    name: '¼ Grid Cloth',
    reference: 'Rosco 3034',
    kind: ModifierKind.diffusion,
    transmission: 0.71,
    spreadDeg: 70,
  ),
  LightModifier(
    id: 'grid-half',
    name: 'Light Grid Cloth',
    reference: 'Rosco 3032',
    kind: ModifierKind.diffusion,
    transmission: 0.5,
    spreadDeg: 95,
  ),
  LightModifier(
    id: 'grid-full',
    name: 'Grid Cloth',
    reference: 'Rosco 3030',
    kind: ModifierKind.diffusion,
    transmission: 0.25,
    spreadDeg: 120,
  ),
  // ── Silent grid cloth: lo mismo, sin ruido con viento ──
  LightModifier(
    id: 'silent-grid-quarter',
    name: 'Silent ¼ Grid Cloth',
    reference: 'Rosco 3064',
    kind: ModifierKind.diffusion,
    transmission: 0.71,
    spreadDeg: 70,
  ),
  LightModifier(
    id: 'silent-grid-half',
    name: 'Silent Light Grid Cloth',
    reference: 'Rosco 3062',
    kind: ModifierKind.diffusion,
    transmission: 0.5,
    spreadDeg: 95,
  ),
  LightModifier(
    id: 'silent-grid-full',
    name: 'Silent Grid Cloth',
    reference: 'Rosco 3060',
    kind: ModifierKind.diffusion,
    transmission: 0.25,
    spreadDeg: 120,
  ),
  // ── Grid cloth teñido: difunde y corrige a la vez ──
  LightModifier(
    id: 'grid-straw-full',
    name: 'Full Straw Grid Cloth',
    reference: 'Rosco 3081',
    kind: ModifierKind.diffusion,
    transmission: 0.22,
    miredShift: 150,
    spreadDeg: 120,
  ),
  LightModifier(
    id: 'grid-straw-half',
    name: '½ Straw Grid Cloth',
    reference: 'Rosco 3082',
    kind: ModifierKind.diffusion,
    transmission: 0.24,
    miredShift: 80,
    spreadDeg: 120,
  ),
  LightModifier(
    id: 'grid-straw-quarter',
    name: '¼ Straw Grid Cloth',
    reference: 'Rosco 3083',
    kind: ModifierKind.diffusion,
    transmission: 0.25,
    miredShift: 40,
    spreadDeg: 120,
  ),
  LightModifier(
    id: 'grid-blue-full',
    name: 'Full Blue Grid Cloth',
    reference: 'Rosco 3071',
    kind: ModifierKind.diffusion,
    transmission: 0.15,
    miredShift: -130,
    spreadDeg: 120,
  ),
  LightModifier(
    id: 'grid-blue-half',
    name: '½ Blue Grid Cloth',
    reference: 'Rosco 3072',
    kind: ModifierKind.diffusion,
    transmission: 0.19,
    miredShift: -68,
    spreadDeg: 120,
  ),
  LightModifier(
    id: 'grid-blue-quarter',
    name: '¼ Blue Grid Cloth',
    reference: 'Rosco 3073',
    kind: ModifierKind.diffusion,
    transmission: 0.22,
    miredShift: -30,
    spreadDeg: 120,
  ),
  // ── Frost y difusores de palio ──
  LightModifier(
    id: 'soft-frost',
    name: 'Soft Frost',
    reference: 'Rosco 3002',
    kind: ModifierKind.diffusion,
    transmission: 0.36,
    spreadDeg: 110,
  ),
  LightModifier(
    id: 'silent-frost',
    name: 'Silent Frost',
    reference: 'Rosco 3029',
    kind: ModifierKind.diffusion,
    transmission: 0.36,
    spreadDeg: 110,
  ),
  LightModifier(
    id: 'hilite',
    name: 'Hilite',
    reference: 'Rosco 3014',
    kind: ModifierKind.diffusion,
    transmission: 0.71,
    spreadDeg: 65,
  ),
  LightModifier(
    id: 'cine-diffuser',
    name: 'Cine Diffuser',
    kind: ModifierKind.diffusion,
    transmission: 0.5,
    spreadDeg: 90,
  ),
  // ── Sedas: reducción publicada por Rosco ──
  LightModifier(
    id: 'silk-china',
    name: 'Seda China blanca',
    kind: ModifierKind.diffusion,
    transmission: 0.71,
    spreadDeg: 75,
    published: true,
  ),
  LightModifier(
    id: 'silk',
    name: 'Seda artificial blanca',
    kind: ModifierKind.diffusion,
    transmission: 0.5,
    spreadDeg: 90,
    published: true,
  ),
  LightModifier(
    id: 'silk-black',
    name: 'Seda artificial negra',
    kind: ModifierKind.diffusion,
    transmission: 0.5,
    spreadDeg: 80,
    published: true,
  ),
  LightModifier(
    id: 'silk-quarter',
    name: '¼ Seda artificial blanca',
    kind: ModifierKind.diffusion,
    transmission: 0.84,
    spreadDeg: 55,
    published: true,
  ),
  // ── Muselinas ──
  LightModifier(
    id: 'muslin-bleached',
    name: 'Muslin blanca',
    kind: ModifierKind.diffusion,
    transmission: 0.35,
    spreadDeg: 130,
  ),
  LightModifier(
    id: 'muslin',
    name: 'Muslin cruda',
    kind: ModifierKind.diffusion,
    transmission: 0.25,
    miredShift: 20,
    spreadDeg: 130,
  ),
  LightModifier(
    id: 'muslin-grey',
    name: 'Muslin gris',
    kind: ModifierKind.diffusion,
    transmission: 0.18,
    spreadDeg: 130,
  ),
  // ── Difusión blanca en gelatina (para el aparato) ──
  LightModifier(
    id: 'white-full',
    name: 'Difusión blanca',
    reference: 'Rosco 3026 · 216',
    kind: ModifierKind.diffusion,
    transmission: 0.36,
    spreadDeg: 100,
  ),
  LightModifier(
    id: 'white-half',
    name: '½ difusión blanca',
    reference: 'Rosco 3027 · 250',
    kind: ModifierKind.diffusion,
    transmission: 0.6,
    spreadDeg: 75,
  ),
  LightModifier(
    id: 'white-quarter',
    name: '¼ difusión blanca',
    reference: 'Rosco 3028 · 251',
    kind: ModifierKind.diffusion,
    transmission: 0.8,
    spreadDeg: 55,
  ),
  LightModifier(
    id: 'opal',
    name: 'Opal',
    reference: 'Rosco 3010',
    kind: ModifierKind.diffusion,
    transmission: 0.8,
    spreadDeg: 50,
  ),
  LightModifier(
    id: 'frost-light',
    name: 'Frost ligero',
    reference: 'Rosco 3009',
    kind: ModifierKind.diffusion,
    transmission: 0.71,
    spreadDeg: 60,
  ),
  LightModifier(
    id: 'frost',
    name: 'Frost',
    reference: 'Rosco 3008',
    kind: ModifierKind.diffusion,
    transmission: 0.5,
    spreadDeg: 80,
  ),
  // ── Gasas (redes): reducción publicada por Rosco ──
  LightModifier(
    id: 'scrim-single',
    name: 'Gasa simple',
    kind: ModifierKind.scrim,
    transmission: 0.71,
    published: true,
  ),
  LightModifier(
    id: 'scrim-double',
    name: 'Gasa doble',
    kind: ModifierKind.scrim,
    transmission: 0.5,
    published: true,
  ),
  LightModifier(
    id: 'scrim-triple',
    name: 'Gasa triple',
    kind: ModifierKind.scrim,
    transmission: 0.354,
    published: true,
  ),
  // ── CTO: enfría → calienta (luz día hacia tungsteno) ──
  LightModifier(
    id: 'cto-full',
    name: 'CTO',
    reference: 'Rosco 3407',
    kind: ModifierKind.correction,
    transmission: 0.47,
    miredShift: 167,
  ),
  LightModifier(
    id: 'cto-three-quarter',
    name: '¾ CTO',
    reference: 'Rosco 3411',
    kind: ModifierKind.correction,
    transmission: 0.58,
    miredShift: 131,
  ),
  LightModifier(
    id: 'cto-half',
    name: '½ CTO',
    reference: 'Rosco 3408',
    kind: ModifierKind.correction,
    transmission: 0.73,
    miredShift: 81,
  ),
  LightModifier(
    id: 'cto-quarter',
    name: '¼ CTO',
    reference: 'Rosco 3409',
    kind: ModifierKind.correction,
    transmission: 0.81,
    miredShift: 42,
  ),
  LightModifier(
    id: 'cto-eighth',
    name: '⅛ CTO',
    reference: 'Rosco 3410',
    kind: ModifierKind.correction,
    transmission: 0.92,
    miredShift: 20,
  ),
  // ── CTB: calienta → enfría (tungsteno hacia luz día) ──
  LightModifier(
    id: 'ctb-full',
    name: 'CTB',
    reference: 'Rosco 3202',
    kind: ModifierKind.correction,
    transmission: 0.36,
    miredShift: -131,
  ),
  LightModifier(
    id: 'ctb-three-quarter',
    name: '¾ CTB',
    reference: 'Rosco 3203',
    kind: ModifierKind.correction,
    transmission: 0.41,
    miredShift: -100,
  ),
  LightModifier(
    id: 'ctb-half',
    name: '½ CTB',
    reference: 'Rosco 3204',
    kind: ModifierKind.correction,
    transmission: 0.52,
    miredShift: -68,
  ),
  LightModifier(
    id: 'ctb-quarter',
    name: '¼ CTB',
    reference: 'Rosco 3208',
    kind: ModifierKind.correction,
    transmission: 0.74,
    miredShift: -30,
  ),
  LightModifier(
    id: 'ctb-eighth',
    name: '⅛ CTB',
    reference: 'Rosco 3216',
    kind: ModifierKind.correction,
    transmission: 0.81,
    miredShift: -12,
  ),
];
