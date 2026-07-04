import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/utils/scene_color.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'plan_element_external_mapping.dart';

/// Serializa / deserializa elementos de planta para set o localización.
class FloorPlanJson {
  FloorPlanJson._();

  static String encode(List<PlanElement> elements) {
    final list = elements
        .map(
          (e) => {
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
            'pathPoints': e.pathPoints
                .map((p) => {'x': p.dx, 'y': p.dy})
                .toList(),
          },
        )
        .toList();
    return jsonEncode({'version': 1, 'elements': list});
  }

  static List<PlanElement> decode(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final raw = data['elements'] as List<dynamic>? ?? [];
      return raw.map((item) {
        final m = item as Map<String, dynamic>;
        final paths = (m['pathPoints'] as List<dynamic>? ?? [])
            .map((p) => Offset(
                  (p['x'] as num).toDouble(),
                  (p['y'] as num).toDouble(),
                ))
            .toList();
        return PlanElement(
          id: 0,
          type: ElementTypeCodec.fromDb(m['type'] as String),
          position: Offset(
            (m['x'] as num).toDouble(),
            (m['y'] as num).toDouble(),
          ),
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
            m['externalMapping'] != null
                ? jsonEncode(m['externalMapping'])
                : null,
          ),
          actorColor: colorFromHex(m['color'] as String?),
          pathPoints: paths,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
