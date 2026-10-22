import 'dart:convert';

/// Herramientas del lienzo. El orden importa solo para la UI; en JSON se
/// guarda el nombre, así que añadir valores al final es compatible.
enum AnnotationToolType {
  pen,
  highlighter,
  arrow,
  eraser,
  select,

  /// Grafito con grano: boceto rápido.
  pencil,

  /// Tinta con presión: línea limpia de entintado.
  ink,

  /// Rotulador: plano y translúcido, no oscurece al repasar dentro del trazo.
  marker,

  /// Carboncillo: grano grueso para manchar sombras.
  charcoal,

  /// Aguada / acuarela: mancha ancha translúcida de borde suave.
  wash,

  /// Aerógrafo: niebla muy suave para luz, brillo o profundidad.
  airbrush,

  /// Relleno a lazo: se rodea un área y se pinta entera.
  fill,

  /// Trama a lazo: rayado diagonal dentro del área (sombras de boceto).
  hatch,

  /// Línea recta de punta a punta.
  line,

  /// Goma de pintura: borra píxeles, no trazos enteros.
  eraseArea,

  /// Coloca un sello (cámara, personaje, foco…).
  stamp,

  /// Coloca un texto libre.
  text,
}

/// Sellos de planta: símbolos cenitales que se colocan con un toque y se
/// orientan arrastrando.
///
/// Los valores nuevos van al final: en JSON se guarda el nombre y una versión
/// anterior lee uno desconocido como foco.
enum AnnotationStampKind {
  camera,
  actor,
  light,
  softbox,
  sun,
  frame,
  text,
  dolly,
  crane,
  fresnel,
  hmi,
  ledPanel,
  tube,
  bounce,
  diffusion,
  window,
  door,
  table,
  chair,
  sofa,
  car,
}

enum AnnotationInputKind { stylus, invertedStylus, touch, mouse, unknown }

class AnnotationPoint {
  final double x;
  final double y;
  final double pressure;

  /// Inclinación del lápiz en radianes (0 = vertical, π/2 = tumbado).
  final double tilt;

  /// Hacia dónde apunta el lápiz inclinado, en radianes.
  final double azimuth;

  const AnnotationPoint({
    required this.x,
    required this.y,
    this.pressure = 1,
    this.tilt = 0,
    this.azimuth = 0,
  });

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'pressure': pressure,
    if (tilt != 0) 'tilt': tilt,
    if (azimuth != 0) 'azimuth': azimuth,
  };

  factory AnnotationPoint.fromJson(Map<String, dynamic> json) =>
      AnnotationPoint(
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        pressure: (json['pressure'] as num?)?.toDouble() ?? 1,
        tilt: (json['tilt'] as num?)?.toDouble() ?? 0,
        azimuth: (json['azimuth'] as num?)?.toDouble() ?? 0,
      );
}

class AnnotationStroke {
  final String id;
  final AnnotationToolType tool;
  final int colorArgb;
  final double width;
  final AnnotationInputKind inputKind;
  final List<AnnotationPoint> points;

  /// Opacidad propia del trazo (0–1), además de la que impone el pincel.
  final double opacity;

  /// Forma cerrada (polígono o elipse reconocidos al enderezar).
  final bool closed;

  /// Pincel del catálogo (`graphite.hb`, `marker.chisel`…). [tool] sigue
  /// guardando la familia, para que una versión anterior de la app pinte
  /// algo parecido.
  final String? brushId;

  /// Capa a la que pertenece; sin capa va a la de abajo.
  final String? layerId;

  /// Semilla del azar del pincel; sin ella se deriva del [id].
  final int? seed;

  /// Pintado con la capa bloqueada: solo cubre lo que ya había en ella.
  final bool alphaLocked;

  const AnnotationStroke({
    required this.id,
    required this.tool,
    required this.colorArgb,
    required this.width,
    required this.points,
    this.inputKind = AnnotationInputKind.unknown,
    this.opacity = 1,
    this.closed = false,
    this.brushId,
    this.layerId,
    this.seed,
    this.alphaLocked = false,
  });

  AnnotationStroke copyWith({
    AnnotationToolType? tool,
    int? colorArgb,
    double? width,
    AnnotationInputKind? inputKind,
    List<AnnotationPoint>? points,
    double? opacity,
    bool? closed,
    String? brushId,
    String? layerId,
    int? seed,
    bool? alphaLocked,
  }) => AnnotationStroke(
    id: id,
    tool: tool ?? this.tool,
    colorArgb: colorArgb ?? this.colorArgb,
    width: width ?? this.width,
    inputKind: inputKind ?? this.inputKind,
    points: points ?? this.points,
    opacity: opacity ?? this.opacity,
    closed: closed ?? this.closed,
    brushId: brushId ?? this.brushId,
    layerId: layerId ?? this.layerId,
    seed: seed ?? this.seed,
    alphaLocked: alphaLocked ?? this.alphaLocked,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tool': tool.name,
    'colorArgb': colorArgb,
    'width': width,
    'inputKind': inputKind.name,
    'points': points.map((point) => point.toJson()).toList(),
    if (opacity != 1) 'opacity': opacity,
    if (closed) 'closed': true,
    if (brushId != null) 'brushId': brushId,
    if (layerId != null) 'layerId': layerId,
    if (seed != null) 'seed': seed,
    if (alphaLocked) 'alphaLocked': true,
  };

  factory AnnotationStroke.fromJson(Map<String, dynamic> json) =>
      AnnotationStroke(
        id:
            json['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        tool: AnnotationToolType.values.firstWhere(
          (value) => value.name == json['tool'],
          orElse: () => AnnotationToolType.pen,
        ),
        colorArgb: (json['colorArgb'] as num?)?.toInt() ?? 0xFF2997FF,
        width: (json['width'] as num?)?.toDouble() ?? 3,
        inputKind: AnnotationInputKind.values.firstWhere(
          (value) => value.name == json['inputKind'],
          orElse: () => AnnotationInputKind.unknown,
        ),
        points: (json['points'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (point) =>
                  AnnotationPoint.fromJson(Map<String, dynamic>.from(point)),
            )
            .toList(),
        opacity: ((json['opacity'] as num?)?.toDouble() ?? 1).clamp(0.0, 1.0),
        closed: json['closed'] == true,
        brushId: json['brushId']?.toString(),
        layerId: json['layerId']?.toString(),
        seed: (json['seed'] as num?)?.toInt(),
        alphaLocked: json['alphaLocked'] == true,
      );
}

/// Símbolo colocado sobre el lienzo. Posición normalizada 0–1; [size] es
/// fracción del lado corto del lienzo y [rotation] va en radianes (0 = mira a
/// la derecha).
class AnnotationStamp {
  final String id;
  final AnnotationStampKind kind;
  final double x;
  final double y;
  final double rotation;
  final double size;
  final int colorArgb;
  final String? label;

  /// Capa a la que pertenece; sin capa va a la de arriba.
  final String? layerId;

  /// Apertura del haz o del ángulo de visión, en radianes (`null` = la de
  /// siempre del sello).
  final double? spread;

  /// Alcance del haz o del ángulo de visión, en radios del sello.
  final double? reach;

  /// Óptica de la cámara en mm, si se eligió.
  final double? lensMm;

  const AnnotationStamp({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    this.rotation = 0,
    this.size = 0.07,
    required this.colorArgb,
    this.label,
    this.layerId,
    this.spread,
    this.reach,
    this.lensMm,
  });

  AnnotationStamp copyWith({
    double? x,
    double? y,
    double? rotation,
    double? size,
    int? colorArgb,
    String? label,
    String? layerId,
    double? spread,
    double? reach,
    double? lensMm,
  }) => AnnotationStamp(
    id: id,
    kind: kind,
    x: x ?? this.x,
    y: y ?? this.y,
    rotation: rotation ?? this.rotation,
    size: size ?? this.size,
    colorArgb: colorArgb ?? this.colorArgb,
    label: label ?? this.label,
    layerId: layerId ?? this.layerId,
    spread: spread ?? this.spread,
    reach: reach ?? this.reach,
    lensMm: lensMm ?? this.lensMm,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'x': x,
    'y': y,
    'rotation': rotation,
    'size': size,
    'colorArgb': colorArgb,
    if (label != null) 'label': label,
    if (layerId != null) 'layerId': layerId,
    if (spread != null) 'spread': spread,
    if (reach != null) 'reach': reach,
    if (lensMm != null) 'lensMm': lensMm,
  };

  factory AnnotationStamp.fromJson(Map<String, dynamic> json) =>
      AnnotationStamp(
        id:
            json['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        kind: AnnotationStampKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => AnnotationStampKind.light,
        ),
        x: (json['x'] as num?)?.toDouble() ?? 0.5,
        y: (json['y'] as num?)?.toDouble() ?? 0.5,
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
        size: (json['size'] as num?)?.toDouble() ?? 0.07,
        colorArgb: (json['colorArgb'] as num?)?.toInt() ?? 0xFF111111,
        label: json['label']?.toString(),
        layerId: json['layerId']?.toString(),
        spread: (json['spread'] as num?)?.toDouble(),
        reach: (json['reach'] as num?)?.toDouble(),
        lensMm: (json['lensMm'] as num?)?.toDouble(),
      );
}

/// Cómo se mezcla una capa con lo que tiene debajo.
enum AnnotationLayerBlend { normal, multiply, screen, add }

/// Papel del folio. Sin papel, el dibujo es transparente (anotar encima de
/// un plano o una foto).
enum AnnotationPaper { white, ivory, kraft, grey }

/// Capa de dibujo. El orden de [AnnotationDocument.layers] es de abajo
/// arriba.
class AnnotationLayer {
  final String id;
  final String name;
  final bool visible;
  final bool locked;
  final double opacity;
  final AnnotationLayerBlend blend;

  /// Solo se pinta donde ya hay pintura en la capa (sombrear dentro).
  final bool alphaLock;

  /// Máscara de recorte: solo se ve donde hay pintura en la capa de abajo.
  final bool clip;

  const AnnotationLayer({
    required this.id,
    required this.name,
    this.visible = true,
    this.locked = false,
    this.opacity = 1,
    this.blend = AnnotationLayerBlend.normal,
    this.alphaLock = false,
    this.clip = false,
  });

  /// Capa de los documentos anteriores a las capas.
  static const base = AnnotationLayer(id: 'base', name: 'Capa 1');

  AnnotationLayer copyWith({
    String? name,
    bool? visible,
    bool? locked,
    double? opacity,
    AnnotationLayerBlend? blend,
    bool? alphaLock,
    bool? clip,
  }) => AnnotationLayer(
    id: id,
    name: name ?? this.name,
    visible: visible ?? this.visible,
    locked: locked ?? this.locked,
    opacity: opacity ?? this.opacity,
    blend: blend ?? this.blend,
    alphaLock: alphaLock ?? this.alphaLock,
    clip: clip ?? this.clip,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (!visible) 'visible': false,
    if (locked) 'locked': true,
    if (opacity != 1) 'opacity': opacity,
    if (blend != AnnotationLayerBlend.normal) 'blend': blend.name,
    if (alphaLock) 'alphaLock': true,
    if (clip) 'clip': true,
  };

  factory AnnotationLayer.fromJson(Map<String, dynamic> json) =>
      AnnotationLayer(
        id: json['id']?.toString() ?? 'base',
        name: json['name']?.toString() ?? 'Capa',
        visible: json['visible'] != false,
        locked: json['locked'] == true,
        opacity: ((json['opacity'] as num?)?.toDouble() ?? 1).clamp(0.0, 1.0),
        blend: AnnotationLayerBlend.values.firstWhere(
          (value) => value.name == json['blend'],
          orElse: () => AnnotationLayerBlend.normal,
        ),
        alphaLock: json['alphaLock'] == true,
        clip: json['clip'] == true,
      );
}

class AnnotationNote {
  final String id;
  final String text;
  final double x;
  final double y;
  final double width;
  final double height;
  final int colorArgb;

  const AnnotationNote({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.colorArgb,
  });

  AnnotationNote copyWith({
    String? text,
    double? x,
    double? y,
    double? width,
    double? height,
    int? colorArgb,
  }) => AnnotationNote(
    id: id,
    text: text ?? this.text,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    colorArgb: colorArgb ?? this.colorArgb,
  );

  bool containsNormalized(double nx, double ny) =>
      nx >= x && nx <= x + width && ny >= y && ny <= y + height;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'colorArgb': colorArgb,
  };

  factory AnnotationNote.fromJson(Map<String, dynamic> json) => AnnotationNote(
    id:
        json['id']?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString(),
    text: json['text']?.toString() ?? '',
    x: (json['x'] as num?)?.toDouble() ?? 0.1,
    y: (json['y'] as num?)?.toDouble() ?? 0.1,
    width: (json['width'] as num?)?.toDouble() ?? 0.25,
    height: (json['height'] as num?)?.toDouble() ?? 0.2,
    colorArgb: (json['colorArgb'] as num?)?.toInt() ?? 0xFFFFE082,
  );
}

/// Documento vectorial portable. Sus coordenadas son normalizadas 0–1 para
/// poder renderizarse igual en iPad, escritorio, imagen y PDF.
class AnnotationDocument {
  /// v2: pinceles con textura, opacidad, formas cerradas y sellos.
  /// v3: pinceles del catálogo, capas, papel e inclinación del lápiz.
  static const currentSchemaVersion = 3;

  final int schemaVersion;
  final List<AnnotationStroke> strokes;
  final List<AnnotationNote> notes;
  final List<AnnotationStamp> stamps;

  /// Capas de abajo arriba. Vacío = una sola capa [AnnotationLayer.base].
  final List<AnnotationLayer> layers;

  final AnnotationPaper? paper;

  /// Papel con imagen importado en el dispositivo (clave estable). Manda
  /// sobre [paper]; si este dispositivo no lo tiene, se ve [paper].
  final String? paperImage;

  const AnnotationDocument({
    this.schemaVersion = currentSchemaVersion,
    this.strokes = const [],
    this.notes = const [],
    this.stamps = const [],
    this.layers = const [],
    this.paper,
    this.paperImage,
  });

  bool get isEmpty => strokes.isEmpty && notes.isEmpty && stamps.isEmpty;

  /// Capas que se pintan; nunca vacío.
  List<AnnotationLayer> get effectiveLayers =>
      layers.isEmpty ? const [AnnotationLayer.base] : layers;

  /// Capa en la que cae un trazo: la suya, o la de abajo si no existe.
  String strokeLayerId(AnnotationStroke stroke) {
    final all = effectiveLayers;
    final id = stroke.layerId;
    if (id != null && all.any((layer) => layer.id == id)) return id;
    return all.first.id;
  }

  /// Capa en la que cae un sello: la suya, o la de arriba si no existe.
  String stampLayerId(AnnotationStamp stamp) {
    final all = effectiveLayers;
    final id = stamp.layerId;
    if (id != null && all.any((layer) => layer.id == id)) return id;
    return all.last.id;
  }

  AnnotationDocument copyWith({
    List<AnnotationStroke>? strokes,
    List<AnnotationNote>? notes,
    List<AnnotationStamp>? stamps,
    List<AnnotationLayer>? layers,
    AnnotationPaper? paper,
    bool clearPaper = false,
    String? paperImage,
    bool clearPaperImage = false,
  }) => AnnotationDocument(
    schemaVersion: currentSchemaVersion,
    strokes: strokes ?? this.strokes,
    notes: notes ?? this.notes,
    stamps: stamps ?? this.stamps,
    layers: layers ?? this.layers,
    paper: clearPaper ? null : (paper ?? this.paper),
    paperImage: clearPaperImage ? null : (paperImage ?? this.paperImage),
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
    'notes': notes.map((note) => note.toJson()).toList(),
    if (stamps.isNotEmpty)
      'stamps': stamps.map((stamp) => stamp.toJson()).toList(),
    if (layers.isNotEmpty)
      'layers': layers.map((layer) => layer.toJson()).toList(),
    if (paper != null) 'paper': paper!.name,
    if (paperImage != null) 'paperImage': paperImage,
  };

  String encode() => jsonEncode(toJson());

  factory AnnotationDocument.fromJson(Map<String, dynamic> json) =>
      AnnotationDocument(
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
        strokes: (json['strokes'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (stroke) =>
                  AnnotationStroke.fromJson(Map<String, dynamic>.from(stroke)),
            )
            .toList(),
        notes: (json['notes'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (note) =>
                  AnnotationNote.fromJson(Map<String, dynamic>.from(note)),
            )
            .toList(),
        stamps: (json['stamps'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (stamp) =>
                  AnnotationStamp.fromJson(Map<String, dynamic>.from(stamp)),
            )
            .toList(),
        layers: (json['layers'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (layer) =>
                  AnnotationLayer.fromJson(Map<String, dynamic>.from(layer)),
            )
            .toList(),
        paper: AnnotationPaper.values
            .where((value) => value.name == json['paper'])
            .firstOrNull,
        paperImage: json['paperImage']?.toString(),
      );

  factory AnnotationDocument.decode(String? raw) {
    if (raw == null || raw.isEmpty) return const AnnotationDocument();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const AnnotationDocument();
      return AnnotationDocument.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const AnnotationDocument();
    }
  }
}
