import 'dart:convert';

enum AnnotationToolType { pen, highlighter, arrow, eraser, select }

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

  const AnnotationStroke({
    required this.id,
    required this.tool,
    required this.colorArgb,
    required this.width,
    required this.points,
    this.inputKind = AnnotationInputKind.unknown,
  });

  AnnotationStroke copyWith({
    AnnotationToolType? tool,
    int? colorArgb,
    double? width,
    AnnotationInputKind? inputKind,
    List<AnnotationPoint>? points,
  }) => AnnotationStroke(
    id: id,
    tool: tool ?? this.tool,
    colorArgb: colorArgb ?? this.colorArgb,
    width: width ?? this.width,
    inputKind: inputKind ?? this.inputKind,
    points: points ?? this.points,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tool': tool.name,
    'colorArgb': colorArgb,
    'width': width,
    'inputKind': inputKind.name,
    'points': points.map((point) => point.toJson()).toList(),
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
  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final List<AnnotationStroke> strokes;
  final List<AnnotationNote> notes;

  const AnnotationDocument({
    this.schemaVersion = currentSchemaVersion,
    this.strokes = const [],
    this.notes = const [],
  });

  bool get isEmpty => strokes.isEmpty && notes.isEmpty;

  AnnotationDocument copyWith({
    List<AnnotationStroke>? strokes,
    List<AnnotationNote>? notes,
  }) => AnnotationDocument(
    schemaVersion: schemaVersion,
    strokes: strokes ?? this.strokes,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
    'notes': notes.map((note) => note.toJson()).toList(),
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
