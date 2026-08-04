import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import '../../core/database/app_database.dart';
import 'optics_calculator.dart';

/// Contexto enriquecido de modo sensor estilo ARRI FLT.
class SensorModeContext {
  final double fullWidthMm;
  final double fullHeightMm;
  final int? openGateWidthPx;
  final int? openGateHeightPx;
  final SensorModeSpec mode;
  final double offsetXMm;
  final double offsetYMm;

  const SensorModeContext({
    required this.fullWidthMm,
    required this.fullHeightMm,
    required this.mode,
    this.openGateWidthPx,
    this.openGateHeightPx,
    this.offsetXMm = 0,
    this.offsetYMm = 0,
  });

  factory SensorModeContext.fromCamera(Camera camera, SensorModeSpec mode) {
    final openGate = findOpenGateMode(camera);
    final fullW = openGate?.widthMm ?? camera.sensorWidthMm;
    final fullH = openGate?.heightMm ?? camera.sensorHeightMm;
    return SensorModeContext(
      fullWidthMm: fullW,
      fullHeightMm: fullH,
      openGateWidthPx: openGate?.maxWidthPx,
      openGateHeightPx: openGate?.maxHeightPx,
      mode: mode,
      offsetXMm: mode.offsetXMm ?? 0,
      offsetYMm: mode.offsetYMm ?? 0,
    );
  }

  double get cropWidthPercent =>
      fullWidthMm > 0 ? mode.widthMm / fullWidthMm * 100 : 100;

  double get cropHeightPercent =>
      fullHeightMm > 0 ? mode.heightMm / fullHeightMm * 100 : 100;

  double get cropFactorDiagonal {
    final fullDiag = math.sqrt(fullWidthMm * fullWidthMm + fullHeightMm * fullHeightMm);
    final modeDiag = math.sqrt(mode.widthMm * mode.widthMm + mode.heightMm * mode.heightMm);
    if (modeDiag <= 0) return 1;
    return fullDiag / modeDiag;
  }

  bool get isFullOpenGate =>
      (mode.widthMm - fullWidthMm).abs() < 0.05 &&
      (mode.heightMm - fullHeightMm).abs() < 0.05;

  Rect get modeRectOnChipNorm {
    final w = (mode.widthMm / fullWidthMm).clamp(0.01, 1.0);
    final h = (mode.heightMm / fullHeightMm).clamp(0.01, 1.0);
    final offX = fullWidthMm > 0 ? offsetXMm / fullWidthMm : 0;
    final offY = fullHeightMm > 0 ? offsetYMm / fullHeightMm : 0;
    var left = (1 - w) / 2 + offX;
    var top = (1 - h) / 2 + offY;
    left = left.clamp(0.0, 1.0 - w);
    top = top.clamp(0.0, 1.0 - h);
    return Rect.fromLTWH(left, top, w, h);
  }

  (int width, int height, bool estimated) get recordingPixels {
    if (mode.maxWidthPx != null &&
        mode.maxHeightPx != null &&
        mode.maxWidthPx! > 0 &&
        mode.maxHeightPx! > 0) {
      return (mode.maxWidthPx!, mode.maxHeightPx!, false);
    }
    if (openGateWidthPx != null &&
        openGateHeightPx != null &&
        fullWidthMm > 0 &&
        fullHeightMm > 0) {
      return (
        (openGateWidthPx! * mode.widthMm / fullWidthMm).round().clamp(640, 16384),
        (openGateHeightPx! * mode.heightMm / fullHeightMm).round().clamp(480, 16384),
        true,
      );
    }
    const pxPerMm = 121.0;
    return (
      (mode.widthMm * pxPerMm).round().clamp(640, 16384),
      (mode.heightMm * pxPerMm).round().clamp(480, 16384),
      true,
    );
  }

  String get cropLabel {
    if (isFullOpenGate) return 'Open Gate (100%)';
    return 'Crop ${cropWidthPercent.toStringAsFixed(0)}×${cropHeightPercent.toStringAsFixed(0)}% · '
        '${cropFactorDiagonal.toStringAsFixed(2)}× diag';
  }

  String get recordingLabel {
    final (w, h, est) = recordingPixels;
    return est ? '$w × $h px (est.)' : '$w × $h px';
  }

  /// Perfiles de resolución de grabación (nativo + downscale comunes).
  List<RecordingProfileOption> recordingProfiles({String codec = 'ProRes'}) {
    final (fullW, fullH, _) = recordingPixels;
    final options = <RecordingProfileOption>[
      RecordingProfileOption(
        id: 'full',
        label: '$fullW × $fullH',
        widthPx: fullW,
        heightPx: fullH,
        codec: codec,
      ),
    ];
    for (final scale in const [0.67, 0.5, 0.33]) {
      final w = (fullW * scale).round().clamp(640, fullW);
      final h = (fullH * scale).round().clamp(480, fullH);
      if (w == fullW && h == fullH) continue;
      final pct = (scale * 100).round();
      options.add(RecordingProfileOption(
        id: 'scale_$pct',
        label: '$w × $h (~$pct%)',
        widthPx: w,
        heightPx: h,
        codec: codec,
      ));
    }
    return options;
  }

  static const kRecordingCodecs = [
    'Apple ProRes',
    'ProRes RAW',
    'ARRIRAW',
    'Blackmagic RAW',
    'REDCODE RAW',
    'X-OCN',
    'H.264',
    'H.265',
  ];

  static String defaultCodecForCamera(Camera camera) {
    final fmt = (camera.logFormats ?? '').toUpperCase();
    if (fmt.contains('BRAW')) return 'Blackmagic RAW';
    if (fmt.contains('R3D') || fmt.contains('REDCODE')) return 'REDCODE RAW';
    if (fmt.contains('X-OCN')) return 'X-OCN';
    if (fmt.contains('ARRIRAW')) return 'ARRIRAW';
    return 'Apple ProRes';
  }
}

class RecordingProfileOption {
  final String id;
  final String label;
  final int widthPx;
  final int heightPx;
  final String codec;

  const RecordingProfileOption({
    required this.id,
    required this.label,
    required this.widthPx,
    required this.heightPx,
    required this.codec,
  });
}

List<SensorModeSpec> parseSensorModesJson(String? jsonStr) {
  if (jsonStr == null || jsonStr.isEmpty) return [];
  try {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => SensorModeSpec.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (_) {
    return [];
  }
}

SensorModeSpec? findOpenGateMode(Camera camera) {
  final modes = parseSensorModesJson(camera.sensorModesJson);
  if (modes.isEmpty) return null;
  for (final m in modes) {
    final n = m.name.toLowerCase();
    if (n.contains('open gate') || n.contains('opengate')) return m;
  }
  SensorModeSpec? largest;
  var area = 0.0;
  for (final m in modes) {
    final a = m.widthMm * m.heightMm;
    if (a > area) {
      area = a;
      largest = m;
    }
  }
  return largest;
}

SensorModeSpec modeOrFallback(Camera camera, SensorModeSpec? selected) {
  if (selected != null) return selected;
  final modes = parseSensorModesJson(camera.sensorModesJson);
  if (modes.isNotEmpty) return modes.first;
  return SensorModeSpec(
    name: 'Open Gate',
    widthMm: camera.sensorWidthMm,
    heightMm: camera.sensorHeightMm,
  );
}
