import 'dart:math' as math;

import '../../core/database/app_database.dart';
import '../../core/utils/scene_format.dart';
import '../../core/utils/shot_technical_options.dart';
import '../luka_export/unreal_coords.dart';

/// Ancho de sensor full-frame (mm) para estimar HFOV desde focal.
const kDefaultSensorWidthMm = 36.0;

double horizontalFovDegrees(String? lens, {double sensorWidthMm = kDefaultSensorWidthMm}) {
  final mm = parseFocalLengthMm(lens);
  if (mm <= 0) return 0;
  return 2 * math.atan(sensorWidthMm / (2 * mm)) * 180 / math.pi;
}

String lensFovLabel(String? lens) {
  final mm = parseFocalLengthMm(lens);
  final fov = horizontalFovDegrees(lens);
  if (lens == null || lens.trim().isEmpty) {
    return '${mm.round()}mm · ${fov.round()}°';
  }
  return '${mm.round()}mm · ${fov.round()}° HFOV';
}

String sceneLocationLine(Scene scene) {
  final location = locationFromCanonical(scene.locationCanonical);
  return formatSceneMetaLine(
    intExt: scene.intExt,
    dayNight: scene.dayNight,
    location: location,
  );
}

String shotMetadataBlock(Shot shot, Scene scene) {
  final lines = <String>[
    'Plano ${shot.number}',
    if (formatShotTechnicalLine(shot).isNotEmpty) formatShotTechnicalLine(shot),
    sceneLocationLine(scene),
    if (shot.fStop?.isNotEmpty == true) 'T${shot.fStop}',
    if (shot.notes?.isNotEmpty == true) shot.notes!,
    if (shot.action?.isNotEmpty == true) shot.action!,
  ];
  return lines.join('\n');
}

/// Aspect ratio cinemático interior de las framelines (2.39:1).
const kFramelineAspect = 2.39;
