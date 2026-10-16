import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'annotation_document.dart';
import 'annotation_textures.dart';

/// Qué hace el pincel con lo que ya hay pintado.
enum BrushMode { paint, erase, smudge }

/// Pinceles que pintan un área rodeada en vez de un trazo.
enum BrushArea { none, fill, hatch, crossHatch }

/// Estantes de la biblioteca de pinceles.
enum BrushCategory { pencil, ink, marker }

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

  /// Cuánto cambian tamaño y opacidad con la presión (0–1).
  final double pressureSize;
  final double pressureOpacity;

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
  });

  bool get isArea => area != BrushArea.none;
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

  static const all = <BrushSpec>[
    // ─── Lápiz y carbón ──────────────────────────────────────────────────────
    BrushSpec(
      id: 'graphite.2h',
      name: 'Grafito 2H',
      category: BrushCategory.pencil,
      family: AnnotationToolType.pencil,
      tip: BrushTip.graphite,
      defaultWidth: 2.2,
      defaultColor: 0xFF5A5F67,
      spacing: 0.12,
      flow: 0.28,
      pressureSize: 0.25,
      pressureOpacity: 0.75,
      taperStart: 1,
      taperEnd: 2,
      rotationJitter: 1,
      scatter: 0.04,
      grain: BrushGrain.fine,
      grainDepth: 0.85,
      grainPressure: 0.25,
      grainScale: 2.2,
    ),
    BrushSpec(
      id: 'graphite.hb',
      name: 'Grafito HB',
      category: BrushCategory.pencil,
      family: AnnotationToolType.pencil,
      tip: BrushTip.graphite,
      defaultWidth: 3,
      defaultColor: _graphite,
      spacing: 0.12,
      flow: 0.38,
      pressureSize: 0.35,
      pressureOpacity: 0.7,
      taperStart: 1,
      taperEnd: 2,
      rotationJitter: 1,
      scatter: 0.05,
      grain: BrushGrain.fine,
      grainDepth: 0.75,
      grainPressure: 0.35,
      grainScale: 2.2,
    ),
    BrushSpec(
      id: 'graphite.4b',
      name: 'Grafito 4B',
      category: BrushCategory.pencil,
      family: AnnotationToolType.pencil,
      tip: BrushTip.graphite,
      defaultWidth: 4.5,
      defaultColor: 0xFF2A2C30,
      spacing: 0.1,
      flow: 0.5,
      pressureSize: 0.45,
      pressureOpacity: 0.6,
      taperStart: 1,
      taperEnd: 1.5,
      rotationJitter: 1,
      scatter: 0.06,
      grain: BrushGrain.fine,
      grainDepth: 0.62,
      grainPressure: 0.45,
      grainScale: 2.2,
    ),
    BrushSpec(
      id: 'graphite.8b',
      name: 'Grafito 8B',
      category: BrushCategory.pencil,
      family: AnnotationToolType.pencil,
      tip: BrushTip.graphite,
      defaultWidth: 7,
      defaultColor: 0xFF1E1F22,
      spacing: 0.09,
      flow: 0.62,
      pressureSize: 0.55,
      pressureOpacity: 0.5,
      taperStart: 0.8,
      taperEnd: 1.2,
      rotationJitter: 1,
      scatter: 0.08,
      grain: BrushGrain.rough,
      grainDepth: 0.55,
      grainPressure: 0.55,
      grainScale: 2.2,
    ),
    BrushSpec(
      id: 'charcoal.vine',
      name: 'Carbón de vid',
      category: BrushCategory.pencil,
      family: AnnotationToolType.charcoal,
      tip: BrushTip.charcoal,
      defaultWidth: 8,
      defaultColor: 0xFF26262A,
      spacing: 0.1,
      flow: 0.32,
      pressureSize: 0.4,
      pressureOpacity: 0.7,
      sizeJitter: 0.2,
      rotationJitter: 1,
      scatter: 0.08,
      taperEnd: 1,
      grain: BrushGrain.rough,
      grainDepth: 0.8,
      grainPressure: 0.3,
      sizeScale: 1.7,
      grainScale: 2.4,
    ),
    BrushSpec(
      id: 'charcoal.compressed',
      name: 'Carbón comprimido',
      category: BrushCategory.pencil,
      family: AnnotationToolType.charcoal,
      tip: BrushTip.charcoal,
      defaultWidth: 9,
      defaultColor: 0xFF121212,
      spacing: 0.08,
      flow: 0.6,
      pressureSize: 0.45,
      pressureOpacity: 0.55,
      sizeJitter: 0.15,
      rotationJitter: 1,
      scatter: 0.05,
      grain: BrushGrain.rough,
      grainDepth: 0.55,
      grainPressure: 0.5,
      sizeScale: 1.6,
      grainScale: 2.4,
    ),
    BrushSpec(
      id: 'charcoal.side',
      name: 'Barra de lado',
      category: BrushCategory.pencil,
      family: AnnotationToolType.charcoal,
      tip: BrushTip.chalk,
      defaultWidth: 26,
      defaultColor: 0xFF202022,
      spacing: 0.05,
      flow: 0.22,
      pressureSize: 0.2,
      pressureOpacity: 0.8,
      followDirection: true,
      angle: math.pi / 2,
      rotationJitter: 0.03,
      grain: BrushGrain.rough,
      grainDepth: 0.9,
      grainPressure: 0.35,
      tiltWidens: true,
      sizeJitter: 0.1,
      grainScale: 2.4,
    ),
    BrushSpec(
      id: 'conte.sanguine',
      name: 'Sanguina',
      category: BrushCategory.pencil,
      family: AnnotationToolType.pencil,
      tip: BrushTip.graphite,
      defaultWidth: 4.5,
      defaultColor: 0xFFA0472F,
      spacing: 0.1,
      flow: 0.5,
      pressureSize: 0.4,
      pressureOpacity: 0.6,
      taperStart: 1,
      taperEnd: 1.5,
      rotationJitter: 1,
      scatter: 0.06,
      grain: BrushGrain.rough,
      grainDepth: 0.7,
      grainPressure: 0.4,
      grainScale: 2.2,
    ),
    BrushSpec(
      id: 'conte.sepia',
      name: 'Sepia',
      category: BrushCategory.pencil,
      family: AnnotationToolType.pencil,
      tip: BrushTip.graphite,
      defaultWidth: 4,
      defaultColor: 0xFF5E4029,
      spacing: 0.1,
      flow: 0.5,
      pressureSize: 0.4,
      pressureOpacity: 0.6,
      taperStart: 1,
      taperEnd: 1.5,
      rotationJitter: 1,
      scatter: 0.06,
      grain: BrushGrain.fine,
      grainDepth: 0.65,
      grainPressure: 0.4,
      grainScale: 2.2,
    ),
    BrushSpec(
      id: 'wash.sepia',
      name: 'Aguada',
      category: BrushCategory.pencil,
      family: AnnotationToolType.wash,
      tip: BrushTip.wash,
      defaultWidth: 34,
      defaultColor: 0xFFB0573A,
      defaultOpacity: 0.55,
      spacing: 0.12,
      pressureSize: 0.5,
      sizeJitter: 0.1,
      rotationJitter: 1,
      wet: true,
      blend: BlendMode.multiply,
      grain: BrushGrain.rough,
      grainDepth: 0.3,
      grainScale: 2.4,
    ),
    BrushSpec(
      id: 'smudge.stump',
      name: 'Difumino',
      category: BrushCategory.pencil,
      family: AnnotationToolType.airbrush,
      tip: BrushTip.softRound,
      mode: BrushMode.smudge,
      defaultWidth: 18,
      spacing: 0.15,
      flow: 0.5,
      pressureSize: 0.3,
      sizeScale: 1.6,
    ),
    BrushSpec(
      id: 'eraser.kneaded',
      name: 'Goma moldeable',
      category: BrushCategory.pencil,
      family: AnnotationToolType.eraseArea,
      tip: BrushTip.softRound,
      mode: BrushMode.erase,
      defaultWidth: 16,
      spacing: 0.12,
      flow: 0.4,
      pressureOpacity: 0.6,
      grain: BrushGrain.fine,
      grainDepth: 0.4,
      sizeScale: 1.6,
    ),

    // ─── Tinta ───────────────────────────────────────────────────────────────
    BrushSpec(
      id: 'fineliner.01',
      name: 'Fineliner 0.1',
      category: BrushCategory.ink,
      family: AnnotationToolType.ink,
      tip: BrushTip.hardRound,
      defaultWidth: 1.1,
      defaultColor: _ink,
      spacing: 0.08,
      pressureSize: 0.1,
      taperEnd: 0.5,
      wet: true,
    ),
    BrushSpec(
      id: 'fineliner.03',
      name: 'Fineliner 0.3',
      category: BrushCategory.ink,
      family: AnnotationToolType.ink,
      tip: BrushTip.hardRound,
      defaultWidth: 2,
      defaultColor: _ink,
      spacing: 0.08,
      pressureSize: 0.12,
      taperEnd: 0.5,
      wet: true,
    ),
    BrushSpec(
      id: 'fineliner.05',
      name: 'Fineliner 0.5',
      category: BrushCategory.ink,
      family: AnnotationToolType.ink,
      tip: BrushTip.hardRound,
      defaultWidth: 3.2,
      defaultColor: _ink,
      spacing: 0.08,
      pressureSize: 0.12,
      taperEnd: 0.4,
      wet: true,
    ),
    BrushSpec(
      id: 'fineliner.08',
      name: 'Fineliner 0.8',
      category: BrushCategory.ink,
      family: AnnotationToolType.ink,
      tip: BrushTip.hardRound,
      defaultWidth: 5,
      defaultColor: _ink,
      spacing: 0.08,
      pressureSize: 0.12,
      taperEnd: 0.3,
      wet: true,
    ),
    BrushSpec(
      id: 'ink.brushpen',
      name: 'Rotulador pincel',
      category: BrushCategory.ink,
      family: AnnotationToolType.ink,
      tip: BrushTip.hardRound,
      defaultWidth: 8,
      defaultColor: _ink,
      spacing: 0.06,
      pressureSize: 0.9,
      taperStart: 3,
      taperEnd: 5,
      wet: true,
    ),
    BrushSpec(
      id: 'ink.nib',
      name: 'Plumilla',
      category: BrushCategory.ink,
      family: AnnotationToolType.ink,
      tip: BrushTip.nib,
      defaultWidth: 6,
      defaultColor: _ink,
      spacing: 0.05,
      pressureSize: 0.7,
      taperStart: 1.5,
      taperEnd: 2.5,
      angle: math.pi / 4,
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
    BrushSpec(
      id: 'ink.crosshatch',
      name: 'Trama cruzada',
      category: BrushCategory.ink,
      family: AnnotationToolType.hatch,
      tip: BrushTip.hardRound,
      area: BrushArea.crossHatch,
      defaultWidth: 1.4,
      defaultColor: _ink,
      wet: true,
      hatchAngle: math.pi / 3,
      hatchGap: 3.8,
    ),
    BrushSpec(
      id: 'ink.fill',
      name: 'Negro macizo',
      category: BrushCategory.ink,
      family: AnnotationToolType.fill,
      tip: BrushTip.hardRound,
      area: BrushArea.fill,
      defaultWidth: 2,
      defaultColor: _ink,
      wet: true,
    ),
    BrushSpec(
      id: 'ink.gel',
      name: 'Gel blanco',
      category: BrushCategory.ink,
      family: AnnotationToolType.ink,
      tip: BrushTip.hardRound,
      defaultWidth: 2.6,
      defaultColor: 0xFFFFFFFF,
      spacing: 0.08,
      pressureSize: 0.2,
      taperEnd: 0.6,
      wet: true,
    ),

    // ─── Rotulador gris de storyboard ────────────────────────────────────────
    BrushSpec(
      id: 'marker.chisel',
      name: 'Rotulador biselado',
      category: BrushCategory.marker,
      family: AnnotationToolType.marker,
      tip: BrushTip.chisel,
      defaultWidth: 22,
      defaultColor: 0xFFADB4B9,
      defaultOpacity: 0.85,
      spacing: 0.03,
      pressureSize: 0.15,
      angle: -math.pi / 4,
      wet: true,
      blend: BlendMode.multiply,
    ),
    BrushSpec(
      id: 'marker.bullet',
      name: 'Rotulador punta fina',
      category: BrushCategory.marker,
      family: AnnotationToolType.marker,
      tip: BrushTip.hardRound,
      defaultWidth: 6,
      defaultColor: 0xFF969DA3,
      defaultOpacity: 0.85,
      spacing: 0.05,
      pressureSize: 0.2,
      wet: true,
      blend: BlendMode.multiply,
    ),
    BrushSpec(
      id: 'marker.dry',
      name: 'Rotulador gastado',
      category: BrushCategory.marker,
      family: AnnotationToolType.marker,
      tip: BrushTip.dryChisel,
      defaultWidth: 24,
      defaultColor: 0xFF7F878D,
      defaultOpacity: 0.8,
      spacing: 0.03,
      pressureSize: 0.15,
      followDirection: true,
      angle: math.pi / 2,
      wet: true,
      blend: BlendMode.multiply,
    ),
    BrushSpec(
      id: 'marker.tone',
      name: 'Tono plano',
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
      id: 'marker.mist',
      name: 'Niebla',
      category: BrushCategory.marker,
      family: AnnotationToolType.airbrush,
      tip: BrushTip.softRound,
      defaultWidth: 70,
      defaultColor: 0xFF969DA3,
      spacing: 0.12,
      flow: 0.1,
      pressureOpacity: 0.7,
      pressureSize: 0.2,
      sizeScale: 1.4,
    ),
    BrushSpec(
      id: 'marker.light',
      name: 'Luz',
      category: BrushCategory.marker,
      family: AnnotationToolType.airbrush,
      tip: BrushTip.softRound,
      defaultWidth: 50,
      defaultColor: 0xFFFFFFFF,
      spacing: 0.12,
      flow: 0.12,
      pressureOpacity: 0.7,
      pressureSize: 0.2,
      sizeScale: 1.4,
    ),
  ];

  static final Map<String, BrushSpec> _byId = {
    for (final brush in all) brush.id: brush,
  };

  static BrushSpec? byId(String? id) => id == null ? null : _byId[id];

  static List<BrushSpec> inCategory(BrushCategory category) =>
      all.where((brush) => brush.category == category).toList();

  static String categoryLabel(BrushCategory category) => switch (category) {
    BrushCategory.pencil => 'Lápiz y carbón',
    BrushCategory.ink => 'Tinta',
    BrushCategory.marker => 'Rotulador',
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
      'graphite.2h',
      'graphite.hb',
      'graphite.4b',
      'graphite.8b',
      'charcoal.vine',
      'charcoal.compressed',
      'charcoal.side',
      'conte.sanguine',
      'wash.sepia',
      'smudge.stump',
      'eraser.kneaded',
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
      'fineliner.01',
      'fineliner.03',
      'fineliner.05',
      'fineliner.08',
      'ink.brushpen',
      'ink.nib',
      'ink.hatch',
      'ink.crosshatch',
      'ink.fill',
      'marker.tone',
      'ink.gel',
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
      'marker.bullet',
      'marker.dry',
      'marker.tone',
      'marker.mist',
      'fineliner.03',
      'fineliner.05',
      'ink.brushpen',
      'ink.gel',
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
      'graphite.hb',
      'fineliner.03',
      'fineliner.05',
      'fineliner.08',
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
