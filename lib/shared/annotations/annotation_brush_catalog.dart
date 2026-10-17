import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'annotation_document.dart';
import 'annotation_textures.dart';

/// Qué hace el pincel con lo que ya hay pintado.
enum BrushMode { paint, erase, smudge }

/// Pinceles que pintan un área rodeada en vez de un trazo.
enum BrushArea { none, fill, hatch, crossHatch }

/// Estantes de la biblioteca de pinceles.
enum BrushCategory { pencil, ink, marker, custom }

/// Pincel por estampado, al estilo de Procreate: una punta [tip] que se
/// repite a lo largo del trazo cada [spacing] diámetros, recortada por el
/// grano del papel [grain].
class BrushSpec {
  final String id;
  final String name;
  final BrushCategory category;

  /// Familia antigua equivalente: la guarda el trazo para que una versión
  /// anterior de la app lo pinte parecido.
  final AnnotationToolType family;

  final BrushTip tip;
  final BrushMode mode;
  final BrushArea area;

  /// Grosor por defecto, en milésimas del lado corto del folio.
  final double defaultWidth;
  final int defaultColor;

  /// Opacidad por defecto del trazo.
  final double defaultOpacity;

  /// Diámetro de la punta respecto al grosor.
  final double sizeScale;

  /// Distancia entre huellas, en diámetros.
  final double spacing;

  /// Opacidad de cada huella: con poco flujo el trazo se carga al repasar.
  final double flow;

  /// Cuánto cambian tamaño y opacidad con la presión (0–1). Negativo:
  /// al revés, más fino u opaco cuanto menos se aprieta.
  final double pressureSize;
  final double pressureOpacity;

  /// Cuánto crece la huella y cuánto se aclara al inclinar el lápiz (0–1).
  final double tiltSize;
  final double tiltOpacity;

  /// Estabilización propia del pincel (0–1); manda la mayor entre esta y
  /// la de Ajustes.
  final double streamline;

  /// Afilado del principio y del final, en diámetros.
  final double taperStart;
  final double taperEnd;

  final double sizeJitter;
  final double opacityJitter;

  /// Desplazamiento lateral aleatorio, en diámetros.
  final double scatter;

  /// Giro aleatorio de cada huella (0–1 de vuelta completa).
  final double rotationJitter;

  /// Ángulo de la punta. Si [followDirection], respecto a la dirección del
  /// trazo; si no, fijo sobre el papel (como un bisel sostenido a 45°).
  final double angle;
  final bool followDirection;

  final BrushGrain? grain;

  /// Tamaño del grano respecto al folio.
  final double grainScale;

  /// Cuánto se nota el grano (0 = nada, 1 = solo las crestas).
  final double grainDepth;

  /// Cuánto rellena la presión los huecos del grano (0–1).
  final double grainPressure;

  /// Húmedo: el trazo no se oscurece sobre sí mismo, pero sí al repasar
  /// con otro trazo (rotulador, tinta, aguada).
  final bool wet;

  /// Mezcla del trazo con lo que tiene debajo.
  final BlendMode blend;

  /// El lápiz tumbado ensancha la huella (barra de carbón de lado).
  final bool tiltWidens;

  /// Ángulo y separación (en grosores) de la trama.
  final double hatchAngle;
  final double hatchGap;

  /// Punta y grano propios (pinceles importados de Procreate): imágenes
  /// blancas con alfa. Si están, mandan sobre [tip] y [grain].
  final ui.Image? tipImage;
  final ui.Image? grainImage;

  const BrushSpec({
    required this.id,
    required this.name,
    required this.category,
    required this.family,
    required this.tip,
    this.mode = BrushMode.paint,
    this.area = BrushArea.none,
    required this.defaultWidth,
    this.defaultColor = 0xFF1A1A1A,
    this.defaultOpacity = 1,
    this.sizeScale = 1,
    this.spacing = 0.1,
    this.flow = 1,
    this.pressureSize = 0.4,
    this.pressureOpacity = 0,
    this.tiltSize = 0,
    this.tiltOpacity = 0,
    this.streamline = 0,
    this.taperStart = 0,
    this.taperEnd = 0,
    this.sizeJitter = 0,
    this.opacityJitter = 0,
    this.scatter = 0,
    this.rotationJitter = 0,
    this.angle = 0,
    this.followDirection = false,
    this.grain,
    this.grainScale = 1.4,
    this.grainDepth = 0,
    this.grainPressure = 0,
    this.wet = false,
    this.blend = BlendMode.srcOver,
    this.tiltWidens = false,
    this.hatchAngle = math.pi / 3,
    this.hatchGap = 3.2,
    this.tipImage,
    this.grainImage,
  });

  bool get isArea => area != BrushArea.none;

  bool get hasGrain => (grain != null || grainImage != null) && grainDepth > 0;

  /// Ajustes que se pueden cambiar en el estudio de pincel o leer de un
  /// pincel de Procreate.
  static const tunable = [
    'defaultWidth',
    'defaultOpacity',
    'spacing',
    'flow',
    'pressureSize',
    'pressureOpacity',
    'tiltSize',
    'tiltOpacity',
    'streamline',
    'taperStart',
    'taperEnd',
    'sizeJitter',
    'scatter',
    'rotationJitter',
    'angle',
    'grainScale',
    'grainDepth',
  ];

  Map<String, double> get params => {
    'defaultWidth': defaultWidth,
    'defaultOpacity': defaultOpacity,
    'spacing': spacing,
    'flow': flow,
    'pressureSize': pressureSize,
    'pressureOpacity': pressureOpacity,
    'tiltSize': tiltSize,
    'tiltOpacity': tiltOpacity,
    'streamline': streamline,
    'taperStart': taperStart,
    'taperEnd': taperEnd,
    'sizeJitter': sizeJitter,
    'scatter': scatter,
    'rotationJitter': rotationJitter,
    'angle': angle,
    'grainScale': grainScale,
    'grainDepth': grainDepth,
  };

  /// Variante con otro id, nombre y ajustes.
  BrushSpec derive({
    required String id,
    String? name,
    BrushCategory? category,
    Map<String, double> params = const {},
    ui.Image? tipImage,
    ui.Image? grainImage,
    int? defaultColor,
    bool? wet,
    BlendMode? blend,
    bool? followDirection,
  }) {
    double p(String key, double current) => params[key] ?? current;
    return BrushSpec(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      family: family,
      tip: tip,
      mode: mode,
      area: area,
      defaultWidth: p('defaultWidth', defaultWidth),
      defaultColor: defaultColor ?? this.defaultColor,
      defaultOpacity: p('defaultOpacity', defaultOpacity),
      sizeScale: sizeScale,
      spacing: p('spacing', spacing),
      flow: p('flow', flow),
      pressureSize: p('pressureSize', pressureSize),
      pressureOpacity: p('pressureOpacity', pressureOpacity),
      tiltSize: p('tiltSize', tiltSize),
      tiltOpacity: p('tiltOpacity', tiltOpacity),
      streamline: p('streamline', streamline),
      taperStart: p('taperStart', taperStart),
      taperEnd: p('taperEnd', taperEnd),
      sizeJitter: p('sizeJitter', sizeJitter),
      opacityJitter: opacityJitter,
      scatter: p('scatter', scatter),
      rotationJitter: p('rotationJitter', rotationJitter),
      angle: p('angle', angle),
      followDirection: followDirection ?? this.followDirection,
      grain: grain,
      grainScale: p('grainScale', grainScale),
      grainDepth: p('grainDepth', grainDepth),
      grainPressure: grainPressure,
      wet: wet ?? this.wet,
      blend: blend ?? this.blend,
      tiltWidens: tiltWidens,
      hatchAngle: hatchAngle,
      hatchGap: hatchGap,
      tipImage: tipImage ?? this.tipImage,
      grainImage: grainImage ?? this.grainImage,
    );
  }
}

/// Un estilo de dibujo: papel, colores, estante de pinceles y capas iniciales.
class SketchStyle {
  final String id;
  final String name;
  final String description;
  final AnnotationPaper paper;
  final List<int> palette;
  final List<String> shelf;
  final List<AnnotationLayer> layers;

  /// Capa en la que se empieza a dibujar.
  final String startLayerId;

  const SketchStyle({
    required this.id,
    required this.name,
    required this.description,
    required this.paper,
    required this.palette,
    required this.shelf,
    required this.layers,
    required this.startLayerId,
  });
}

abstract final class BrushCatalog {
  static const _graphite = 0xFF34373C;
  static const _ink = 0xFF111111;

  /// Gris frío de rotulador (C1 … C9).
  static const coolGreys = [
    0xFFE1E5E7,
    0xFFD3D8DB,
    0xFFC1C7CB,
    0xFFADB4B9,
    0xFF969DA3,
    0xFF7F878D,
    0xFF686F75,
    0xFF52585D,
    0xFF3D4246,
  ];

  /// Pocos pinceles y buenos, pensados como los de Procreate: forma y
  /// grano, presión, inclinación del Pencil y estabilización.
  static const all = <BrushSpec>[
    // ─── Lápiz y carbón ──────────────────────────────────────────────────────
    BrushSpec(
      id: 'graphite.hb',
      name: 'Lápiz',
      category: BrushCategory.pencil,
      family: AnnotationToolType.pencil,
      tip: BrushTip.graphite,
      defaultWidth: 3,
      defaultColor: _graphite,
      spacing: 0.1,
      flow: 0.4,
      pressureSize: 0.35,
      pressureOpacity: 0.75,
      tiltSize: 0.8,
      tiltOpacity: 0.5,
      streamline: 0.1,
      taperStart: 1,
      taperEnd: 2,
      rotationJitter: 1,
      scatter: 0.05,
      grain: BrushGrain.fine,
      grainScale: 2.2,
      grainDepth: 0.75,
      grainPressure: 0.35,
    ),
    BrushSpec(
      id: 'graphite.8b',
      name: 'Lápiz blando',
      category: BrushCategory.pencil,
      family: AnnotationToolType.pencil,
      tip: BrushTip.graphite,
      defaultWidth: 6,
      defaultColor: 0xFF1E1F22,
      spacing: 0.09,
      flow: 0.55,
      pressureSize: 0.5,
      pressureOpacity: 0.6,
      tiltSize: 1,
      tiltOpacity: 0.55,
      taperStart: 0.8,
      taperEnd: 1.2,
      rotationJitter: 1,
      scatter: 0.08,
      grain: BrushGrain.rough,
      grainScale: 2.4,
      grainDepth: 0.55,
      grainPressure: 0.55,
    ),
    BrushSpec(
      id: 'charcoal.vine',
      name: 'Carboncillo',
      category: BrushCategory.pencil,
      family: AnnotationToolType.charcoal,
      tip: BrushTip.charcoal,
      defaultWidth: 9,
      defaultColor: 0xFF1E1E22,
      sizeScale: 1.7,
      spacing: 0.08,
      flow: 0.42,
      pressureSize: 0.4,
      pressureOpacity: 0.7,
      tiltSize: 1,
      tiltOpacity: 0.3,
      sizeJitter: 0.15,
      rotationJitter: 1,
      scatter: 0.06,
      taperEnd: 1,
      grain: BrushGrain.rough,
      grainScale: 2.4,
      grainDepth: 0.8,
      grainPressure: 0.35,
    ),
    BrushSpec(
      id: 'smudge.stump',
      name: 'Difumino',
      category: BrushCategory.pencil,
      family: AnnotationToolType.airbrush,
      tip: BrushTip.softRound,
      mode: BrushMode.smudge,
      defaultWidth: 18,
      sizeScale: 1.6,
      spacing: 0.15,
      flow: 0.5,
      pressureSize: 0.3,
    ),
    BrushSpec(
      id: 'eraser.kneaded',
      name: 'Goma moldeable',
      category: BrushCategory.pencil,
      family: AnnotationToolType.eraseArea,
      tip: BrushTip.softRound,
      mode: BrushMode.erase,
      defaultWidth: 16,
      sizeScale: 1.6,
      spacing: 0.12,
      flow: 0.4,
      pressureOpacity: 0.6,
      grain: BrushGrain.fine,
      grainDepth: 0.4,
    ),

    // ─── Tinta ───────────────────────────────────────────────────────────────
    BrushSpec(
      id: 'fineliner.03',
      name: 'Fineliner',
      category: BrushCategory.ink,
      family: AnnotationToolType.ink,
      tip: BrushTip.hardRound,
      defaultWidth: 2.4,
      defaultColor: _ink,
      spacing: 0.06,
      pressureSize: 0.15,
      streamline: 0.45,
      taperEnd: 0.5,
      wet: true,
    ),
    BrushSpec(
      id: 'ink.brushpen',
      name: 'Rotulador pincel',
      category: BrushCategory.ink,
      family: AnnotationToolType.ink,
      tip: BrushTip.hardRound,
      defaultWidth: 9,
      defaultColor: _ink,
      spacing: 0.05,
      pressureSize: 0.9,
      tiltSize: 0.4,
      streamline: 0.35,
      taperStart: 2.5,
      taperEnd: 4,
      wet: true,
    ),
    BrushSpec(
      id: 'ink.hatch',
      name: 'Trama',
      category: BrushCategory.ink,
      family: AnnotationToolType.hatch,
      tip: BrushTip.hardRound,
      area: BrushArea.hatch,
      defaultWidth: 1.6,
      defaultColor: _ink,
      wet: true,
      hatchAngle: math.pi / 3,
      hatchGap: 3.4,
    ),

    // ─── Rotulador y color ───────────────────────────────────────────────────
    BrushSpec(
      id: 'marker.chisel',
      name: 'Rotulador',
      category: BrushCategory.marker,
      family: AnnotationToolType.marker,
      tip: BrushTip.chisel,
      defaultWidth: 22,
      defaultColor: 0xFFADB4B9,
      defaultOpacity: 0.85,
      spacing: 0.03,
      pressureSize: 0.15,
      tiltSize: 0.5,
      streamline: 0.2,
      angle: -math.pi / 4,
      wet: true,
      blend: BlendMode.multiply,
    ),
    BrushSpec(
      id: 'wash.sepia',
      name: 'Acuarela',
      category: BrushCategory.marker,
      family: AnnotationToolType.wash,
      tip: BrushTip.wash,
      defaultWidth: 34,
      defaultColor: 0xFFB0573A,
      defaultOpacity: 0.55,
      spacing: 0.12,
      pressureSize: 0.5,
      tiltSize: 0.6,
      sizeJitter: 0.1,
      rotationJitter: 1,
      wet: true,
      blend: BlendMode.multiply,
      grain: BrushGrain.rough,
      grainScale: 2.4,
      grainDepth: 0.3,
    ),
    BrushSpec(
      id: 'marker.mist',
      name: 'Aerógrafo',
      category: BrushCategory.marker,
      family: AnnotationToolType.airbrush,
      tip: BrushTip.softRound,
      defaultWidth: 70,
      defaultColor: 0xFF969DA3,
      sizeScale: 1.4,
      spacing: 0.12,
      flow: 0.1,
      pressureOpacity: 0.7,
      pressureSize: 0.2,
    ),
    BrushSpec(
      id: 'marker.tone',
      name: 'Relleno',
      category: BrushCategory.marker,
      family: AnnotationToolType.fill,
      tip: BrushTip.hardRound,
      area: BrushArea.fill,
      defaultWidth: 2,
      defaultColor: 0xFFC1C7CB,
      defaultOpacity: 0.9,
      wet: true,
      blend: BlendMode.multiply,
    ),
    BrushSpec(
      id: 'marker.light',
      name: 'Luz',
      category: BrushCategory.marker,
      family: AnnotationToolType.airbrush,
      tip: BrushTip.softRound,
      defaultWidth: 50,
      defaultColor: 0xFFFFFFFF,
      sizeScale: 1.4,
      spacing: 0.12,
      flow: 0.12,
      pressureOpacity: 0.7,
      pressureSize: 0.2,
    ),
  ];

  /// Pinceles retirados: sus trazos se pintan con el más parecido de hoy.
  static const retired = <String, String>{
    'graphite.2h': 'graphite.hb',
    'graphite.4b': 'graphite.8b',
    'conte.sanguine': 'graphite.8b',
    'conte.sepia': 'graphite.hb',
    'charcoal.compressed': 'charcoal.vine',
    'charcoal.side': 'charcoal.vine',
    'fineliner.01': 'fineliner.03',
    'fineliner.05': 'fineliner.03',
    'fineliner.08': 'fineliner.03',
    'ink.gel': 'fineliner.03',
    'ink.nib': 'ink.brushpen',
    'ink.crosshatch': 'ink.hatch',
    'ink.fill': 'marker.tone',
    'marker.bullet': 'marker.chisel',
    'marker.dry': 'marker.chisel',
  };

  static final Map<String, BrushSpec> _byId = {
    for (final brush in all) brush.id: brush,
  };

  /// Pinceles propios de este dispositivo: importados o variantes.
  static final Map<String, BrushSpec> _custom = {};

  static BrushSpec? byId(String? id) =>
      id == null ? null : (_byId[id] ?? _custom[id] ?? _byId[retired[id]]);

  static List<BrushSpec> get custom => _custom.values.toList();

  static void register(BrushSpec brush) => _custom[brush.id] = brush;

  static void unregister(String id) => _custom.remove(id);

  static List<BrushSpec> inCategory(BrushCategory category) =>
      category == BrushCategory.custom
      ? custom
      : all.where((brush) => brush.category == category).toList();

  static String categoryLabel(BrushCategory category) => switch (category) {
    BrushCategory.pencil => 'Lápiz y carbón',
    BrushCategory.ink => 'Tinta',
    BrushCategory.marker => 'Rotulador y color',
    BrushCategory.custom => 'Míos',
  };

  // ─── Estilos ───────────────────────────────────────────────────────────────

  static const pencilStyle = SketchStyle(
    id: 'pencil',
    name: 'Lápiz y carboncillo',
    description: 'Grafito, carbón y aguada sobre papel tostado.',
    paper: AnnotationPaper.kraft,
    palette: [
      0xFF1E1F22,
      _graphite,
      0xFF5A5F67,
      0xFF8C9096,
      0xFF5E4029,
      0xFFA0472F,
      0xFFB0573A,
      0xFFF4EEDF,
    ],
    shelf: [
      'graphite.hb',
      'graphite.8b',
      'charcoal.vine',
      'wash.sepia',
      'marker.mist',
      'marker.tone',
    ],
    layers: [
      AnnotationLayer(id: 'encaje', name: 'Encaje', opacity: 0.6),
      AnnotationLayer(id: 'dibujo', name: 'Dibujo'),
      AnnotationLayer(
        id: 'sombra',
        name: 'Sombra',
        blend: AnnotationLayerBlend.multiply,
      ),
    ],
    startLayerId: 'encaje',
  );

  static const finelinerStyle = SketchStyle(
    id: 'fineliner',
    name: 'Fineliner',
    description: 'Tinta, tramas y negros macizos sobre lápiz guía.',
    paper: AnnotationPaper.white,
    palette: [
      _ink,
      0xFF3A3A3A,
      0xFF6E6E6E,
      0xFF9A9A9A,
      0xFFC8C8C8,
      0xFFFFFFFF,
      0xFF6FA8DC,
    ],
    shelf: [
      'graphite.hb',
      'fineliner.03',
      'ink.brushpen',
      'ink.hatch',
      'marker.tone',
      'wash.sepia',
    ],
    layers: [
      AnnotationLayer(id: 'guia', name: 'Lápiz guía', opacity: 0.35),
      AnnotationLayer(
        id: 'tonos',
        name: 'Tonos',
        blend: AnnotationLayerBlend.multiply,
      ),
      AnnotationLayer(id: 'tinta', name: 'Tinta'),
    ],
    startLayerId: 'guia',
  );

  static const markerStyle = SketchStyle(
    id: 'marker',
    name: 'Rotulador gris',
    description: 'Grises fríos que se oscurecen al repasar, línea y luces.',
    paper: AnnotationPaper.white,
    palette: [...coolGreys, _ink, 0xFFFFFFFF],
    shelf: [
      'graphite.hb',
      'marker.chisel',
      'marker.tone',
      'fineliner.03',
      'ink.brushpen',
      'marker.mist',
      'marker.light',
    ],
    layers: [
      AnnotationLayer(id: 'guia', name: 'Lápiz guía', opacity: 0.35),
      AnnotationLayer(
        id: 'grises',
        name: 'Grises',
        blend: AnnotationLayerBlend.multiply,
      ),
      AnnotationLayer(id: 'linea', name: 'Línea'),
      AnnotationLayer(id: 'luces', name: 'Luces'),
    ],
    startLayerId: 'guia',
  );

  /// Planta de cámara y luz: capas por tipo de elemento.
  static const planStyle = SketchStyle(
    id: 'plan',
    name: 'Planta',
    description: 'Decorado, personajes, cámaras y luz, cada uno en su capa.',
    paper: AnnotationPaper.white,
    palette: [
      0xFF1A1A1A,
      0xFF1F3FBF,
      0xFFD32F2F,
      0xFF8A8A8A,
      0xFF2E7D32,
      0xFFFFB300,
      0xFF4FC3F7,
      0xFFFFFFFF,
    ],
    shelf: [
      'fineliner.03',
      'graphite.hb',
      'ink.brushpen',
      'marker.chisel',
      'marker.tone',
      'ink.hatch',
      'marker.mist',
    ],
    layers: [
      AnnotationLayer(id: 'decorado', name: 'Decorado'),
      AnnotationLayer(id: 'personajes', name: 'Personajes'),
      AnnotationLayer(id: 'camaras', name: 'Cámaras'),
      AnnotationLayer(id: 'luz', name: 'Luz'),
      AnnotationLayer(id: 'notas', name: 'Notas'),
    ],
    startLayerId: 'decorado',
  );

  /// Estilos para elegir en el storyboard.
  static const styles = [pencilStyle, finelinerStyle, markerStyle];

  static SketchStyle? styleById(String? id) {
    for (final style in [...styles, planStyle]) {
      if (style.id == id) return style;
    }
    return null;
  }

  /// Color de fondo de cada papel.
  static Color paperColor(AnnotationPaper paper) => switch (paper) {
    AnnotationPaper.white => const Color(0xFFFCFCFA),
    AnnotationPaper.ivory => const Color(0xFFF6F0E1),
    AnnotationPaper.kraft => const Color(0xFFE2CC9F),
    AnnotationPaper.grey => const Color(0xFFD9D9D6),
  };

  static String paperLabel(AnnotationPaper paper) => switch (paper) {
    AnnotationPaper.white => 'Blanco',
    AnnotationPaper.ivory => 'Marfil',
    AnnotationPaper.kraft => 'Kraft',
    AnnotationPaper.grey => 'Gris',
  };

  /// Grano que se ve en el propio papel.
  static BrushGrain paperGrain(AnnotationPaper paper) => switch (paper) {
    AnnotationPaper.kraft => BrushGrain.kraft,
    AnnotationPaper.grey => BrushGrain.rough,
    _ => BrushGrain.fine,
  };
}
