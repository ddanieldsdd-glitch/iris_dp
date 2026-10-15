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
enum AnnotationStampKind { camera, actor, light, softbox, sun, frame, text }

enum AnnotationInputKind { stylus, invertedStylus, touch, mouse, unknown }

class AnnotationPoint {
  final double x;
  final double y;
  final double pressure;

  const AnnotationPoint({required this.x, required this.y, this.pressure = 1});

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'pressure': pressure};

  factory AnnotationPoint.fromJson(Map<String, dynamic> json) =>
      AnnotationPoint(
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        pressure: (json['pressure'] as num?)?.toDouble() ?? 1,
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

  const AnnotationStroke({
    required this.id,
    required this.tool,
    required this.colorArgb,
    required this.width,
    required this.points,
    this.inputKind = AnnotationInputKind.unknown,
    this.opacity = 1,
    this.closed = false,
  });

  AnnotationStroke copyWith({
    AnnotationToolType? tool,
    int? colorArgb,
    double? width,
    AnnotationInputKind? inputKind,
    List<AnnotationPoint>? points,
    double? opacity,
    bool? closed,
  }) => AnnotationStroke(
    id: id,
    tool: tool ?? this.tool,
    colorArgb: colorArgb ?? this.colorArgb,
    width: width ?? this.width,
    inputKind: inputKind ?? this.inputKind,
    points: points ?? this.points,
    opacity: opacity ?? this.opacity,
    closed: closed ?? this.closed,
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

  const AnnotationStamp({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    this.rotation = 0,
    this.size = 0.07,
    required this.colorArgb,
    this.label,
  });

  AnnotationStamp copyWith({
    double? x,
    double? y,
    double? rotation,
    double? size,
    int? colorArgb,
    String? label,
  }) => AnnotationStamp(
    id: id,
    kind: kind,
    x: x ?? this.x,
    y: y ?? this.y,
    rotation: rotation ?? this.rotation,
    size: size ?? this.size,
    colorArgb: colorArgb ?? this.colorArgb,
    label: label ?? this.label,
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
  static const currentSchemaVersion = 2;

  final int schemaVersion;
  final List<AnnotationStroke> strokes;
  final List<AnnotationNote> notes;
  final List<AnnotationStamp> stamps;

  const AnnotationDocument({
    this.schemaVersion = currentSchemaVersion,
    this.strokes = const [],
    this.notes = const [],
    this.stamps = const [],
  });

  bool get isEmpty => strokes.isEmpty && notes.isEmpty && stamps.isEmpty;

  AnnotationDocument copyWith({
    List<AnnotationStroke>? strokes,
    List<AnnotationNote>? notes,
    List<AnnotationStamp>? stamps,
  }) => AnnotationDocument(
    schemaVersion: currentSchemaVersion,
    strokes: strokes ?? this.strokes,
    notes: notes ?? this.notes,
    stamps: stamps ?? this.stamps,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
    'notes': notes.map((note) => note.toJson()).toList(),
    if (stamps.isNotEmpty)
      'stamps': stamps.map((stamp) => stamp.toJson()).toList(),
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
