import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/utils/scene_color.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'plan_element_external_mapping.dart';

/// Imagen de fondo de una planta: plano importado, boceto o foto.
class FloorPlanUnderlay {
  final String path;
  final Rect rect;
  final double opacity;

  /// plano | boceto | foto
  final String kind;

  const FloorPlanUnderlay({
    required this.path,
    required this.rect,
    this.opacity = 0.85,
    this.kind = 'plano',
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'x': rect.left,
    'y': rect.top,
    'width': rect.width,
    'height': rect.height,
    'opacity': opacity,
    'kind': kind,
  };

  static FloorPlanUnderlay? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['path'] as String?;
    if (path == null || path.isEmpty) return null;
    double n(String key, double fallback) =>
        (raw[key] as num?)?.toDouble() ?? fallback;
    return FloorPlanUnderlay(
      path: path,
      rect: Rect.fromLTWH(
        n('x', 0),
        n('y', 0),
        n('width', 1600),
        n('height', 1200),
      ),
      opacity: n('opacity', 0.85),
      kind: raw['kind'] as String? ?? 'plano',
    );
  }
}

/// Una capa de planta: elementos, escala y fondo.
class FloorPlanDocument {
  final List<PlanElement> elements;

  /// Metros que mide una unidad del lienzo. `null` = sin calibrar.
  final double? metersPerUnit;
  final FloorPlanUnderlay? underlay;

  const FloorPlanDocument({
    this.elements = const [],
    this.metersPerUnit,
    this.underlay,
  });

  bool get isEmpty => elements.isEmpty && underlay == null;
}

/// Serializa / deserializa las capas de planta guardadas como JSON
/// (localización, set y esquema de luz). Escribe la versión 2 y lee la 1.
class FloorPlanJson {
  FloorPlanJson._();

  static const version = 2;

  static String encode(List<PlanElement> elements) =>
      encodeDocument(FloorPlanDocument(elements: elements));

  static String encodeDocument(FloorPlanDocument document) {
    return jsonEncode({
      'version': version,
      'metersPerUnit': ?document.metersPerUnit,
      'underlay': ?document.underlay?.toJson(),
      'elements': document.elements.map(_elementToJson).toList(),
    });
  }

  static List<PlanElement> decode(String? json) =>
      decodeDocument(json).elements;

  static FloorPlanDocument decodeDocument(String? json) {
    if (json == null || json.isEmpty) return const FloorPlanDocument();
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final raw = data['elements'] as List<dynamic>? ?? [];
      return FloorPlanDocument(
        elements: raw
            .map((item) => _elementFromJson(item as Map<String, dynamic>))
            .toList(),
        metersPerUnit: (data['metersPerUnit'] as num?)?.toDouble(),
        underlay: FloorPlanUnderlay.fromJson(data['underlay']),
      );
    } catch (_) {
      return const FloorPlanDocument();
    }
  }

  static Map<String, dynamic> _elementToJson(PlanElement e) => {
    'type': e.type.dbValue,
    'x': e.position.dx,
    'y': e.position.dy,
    'rotation': e.rotation,
    'label': e.label,
    'stabilization': e.stabilization,
    'lens': e.lens,
    'cameraLetter': e.cameraLetter,
    'cameraNumber': e.cameraNumber,
    'lightType': e.lightType?.dbValue,
    'lukaCompatible': e.lukaCompatible,
    'lukaFixtureId': e.lukaFixtureId,
    'externalMapping': e.externalMapping.toJson(),
    'color': e.type == ElementType.actor ? hexFromColor(e.actorColor) : null,
    'pathPoints': e.pathPoints.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    if (e.props.isNotEmpty) 'props': e.props,
  };

  static PlanElement _elementFromJson(Map<String, dynamic> m) {
    final paths = (m['pathPoints'] as List<dynamic>? ?? [])
        .map(
          (p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
        )
        .toList();
    final props = m['props'];
    return PlanElement(
      id: 0,
      type: ElementTypeCodec.fromDb(m['type'] as String),
      position: Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble()),
      rotation: (m['rotation'] as num?)?.toDouble() ?? 0,
      label: m['label'] as String?,
      stabilization: m['stabilization'] as String?,
      lens: m['lens'] as String?,
      cameraLetter: m['cameraLetter'] as String? ?? 'A',
      cameraNumber: (m['cameraNumber'] as num?)?.toInt() ?? 1,
      lightType: LightTypeLabel.fromDb(m['lightType'] as String?),
      lukaCompatible: m['lukaCompatible'] as bool? ?? false,
      lukaFixtureId: m['lukaFixtureId'] as String?,
      externalMapping: PlanElementExternalMapping.fromJson(
        m['externalMapping'] != null ? jsonEncode(m['externalMapping']) : null,
      ),
      actorColor: colorFromHex(m['color'] as String?),
      pathPoints: paths,
      props: props is Map ? Map<String, dynamic>.from(props) : null,
    );
  }
}
