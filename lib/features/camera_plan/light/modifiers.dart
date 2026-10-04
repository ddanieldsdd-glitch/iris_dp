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

  const LightModifier({
    required this.id,
    required this.name,
    required this.kind,
    required this.transmission,
    this.reference,
    this.miredShift = 0,
    this.spreadDeg,
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

/// Catálogo de partida de difusiones, redes y gelatinas.
const kLightModifiers = <LightModifier>[
  // ── Difusión blanca (Rosco Tough White Diffusion y equivalentes) ──
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
    transmission: 0.60,
    spreadDeg: 75,
  ),
  LightModifier(
    id: 'white-quarter',
    name: '¼ difusión blanca',
    reference: 'Rosco 3028 · 251',
    kind: ModifierKind.diffusion,
    transmission: 0.80,
    spreadDeg: 55,
  ),
  LightModifier(
    id: 'opal',
    name: 'Opal',
    reference: 'Rosco 3010',
    kind: ModifierKind.diffusion,
    transmission: 0.80,
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
    transmission: 0.50,
    spreadDeg: 80,
  ),
  LightModifier(
    id: 'silk',
    name: 'Seda',
    reference: 'Rosco 3011',
    kind: ModifierKind.diffusion,
    transmission: 0.50,
    spreadDeg: 80,
  ),
  // ── Grid cloth ──
  LightModifier(
    id: 'grid-quarter',
    name: '¼ grid cloth',
    reference: 'Rosco 3034',
    kind: ModifierKind.diffusion,
    transmission: 0.71,
    spreadDeg: 70,
  ),
  LightModifier(
    id: 'grid-half',
    name: '½ grid cloth',
    reference: 'Rosco 3032',
    kind: ModifierKind.diffusion,
    transmission: 0.50,
    spreadDeg: 95,
  ),
  LightModifier(
    id: 'grid-full',
    name: 'Grid cloth',
    reference: 'Rosco 3030',
    kind: ModifierKind.diffusion,
    transmission: 0.25,
    spreadDeg: 120,
  ),
  LightModifier(
    id: 'muslin-bleached',
    name: 'Muselina blanqueada',
    kind: ModifierKind.diffusion,
    transmission: 0.35,
    spreadDeg: 130,
  ),
  LightModifier(
    id: 'muslin',
    name: 'Muselina cruda',
    kind: ModifierKind.diffusion,
    transmission: 0.25,
    miredShift: 20,
    spreadDeg: 130,
  ),
  // ── Redes ──
  LightModifier(
    id: 'scrim-single',
    name: 'Red simple',
    kind: ModifierKind.scrim,
    transmission: 0.71,
  ),
  LightModifier(
    id: 'scrim-double',
    name: 'Red doble',
    kind: ModifierKind.scrim,
    transmission: 0.50,
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
