import 'package:flutter/material.dart';

import '../camera_plan/plan_element_compat.dart';
import '../camera_plan/camera_plan_constants.dart';

/// Mapeo de [LightType] IRIS DP → tipo de luz en Unreal / LUKA fallback.
String unrealLightTypeKey(LightType? type) =>
    PlanElementCompat.unrealLightTypeKey(type);

/// Convierte coordenadas cenitales del lienzo 2D a Unreal (Z-up, cm).
Map<String, double> canvasToUnrealCoords(
  Offset pos, {
  required double canvasScale,
  required String elementKind,
}) {
  final height = switch (elementKind) {
    'camera' => 150.0,
    'light' => 280.0,
    'actor' => 90.0,
    _ => 0.0,
  };
  return {
    'x': pos.dx * canvasScale * 100,
    'y': pos.dy * canvasScale * 100,
    'z': height,
  };
}

double parseFocalLengthMm(String? lens) {
  if (lens == null || lens.trim().isEmpty) return 50.0;
  final match = RegExp(r'(\d+\.?\d*)').firstMatch(lens);
  return double.tryParse(match?.group(1) ?? '') ?? 50.0;
}

double parseTStop(String? fStop) {
  if (fStop == null || fStop.trim().isEmpty) return 2.8;
  final match = RegExp(r'(\d+\.?\d*)').firstMatch(fStop);
  return double.tryParse(match?.group(1) ?? '') ?? 2.8;
}

Set<String> detectActorNamesFromActions(Iterable<String?> actions) {
  final names = <String>{};
  final re = RegExp(r'\b([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ]{1,})\b');
  const skip = {'INT', 'EXT', 'DÍA', 'NOCHE', 'AMANECER', 'ATARDECER', 'CONT'};
  for (final action in actions) {
    if (action == null || action.isEmpty) continue;
    for (final m in re.allMatches(action)) {
      final word = m.group(1)!;
      if (!skip.contains(word)) names.add(word);
    }
  }
  return names;
}
