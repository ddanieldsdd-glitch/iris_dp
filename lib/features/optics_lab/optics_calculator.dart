import 'dart:math' as math;

/// Resultado de cálculos ópticos estilo ARRI FLT / Artemis.
class OpticsResult {
  final double sensorWidthMm;
  final double sensorHeightMm;
  final double activeWidthMm;
  final double activeHeightMm;
  final double focalEffectiveMm;
  final double hFovDeg;
  final double vFovDeg;
  final double dFovDeg;
  final double imageCircleMm;
  final double sensorDiagonalMm;
  final bool coversSensor;
  final bool portholingWarning;
  final double cocMm;
  final double? dofNearM;
  final double? dofFarM;
  final double? hyperfocalM;
  final int? activeWidthPx;
  final int? activeHeightPx;
  final int? recordingWidthPx;
  final int? recordingHeightPx;
  final double? fullSensorWidthMm;
  final double? fullSensorHeightMm;
  final double? cropWidthPercent;
  final double? cropHeightPercent;
  final String? mountWarning;

  const OpticsResult({
    required this.sensorWidthMm,
    required this.sensorHeightMm,
    required this.activeWidthMm,
    required this.activeHeightMm,
    required this.focalEffectiveMm,
    required this.hFovDeg,
    required this.vFovDeg,
    required this.dFovDeg,
    required this.imageCircleMm,
    required this.sensorDiagonalMm,
    required this.coversSensor,
    required this.portholingWarning,
    required this.cocMm,
    this.dofNearM,
    this.dofFarM,
    this.hyperfocalM,
    this.activeWidthPx,
    this.activeHeightPx,
    this.recordingWidthPx,
    this.recordingHeightPx,
    this.fullSensorWidthMm,
    this.fullSensorHeightMm,
    this.cropWidthPercent,
    this.cropHeightPercent,
    this.mountWarning,
  });

  bool get coverageOk => coversSensor;

  String get coverageLabel =>
      portholingWarning ? 'Portholing / vignetting' : (coversSensor ? 'OK' : 'Sin cobertura');

  String? get resolutionLabel {
    if (activeWidthPx == null || activeHeightPx == null) return null;
    return '${activeWidthPx!} × ${activeHeightPx!} px';
  }

  String? get recordingResolutionLabel {
    if (recordingWidthPx == null || recordingHeightPx == null) return null;
    return '${recordingWidthPx!} × ${recordingHeightPx!} px';
  }
}

class SensorModeSpec {
  final String name;
  final double widthMm;
  final double heightMm;
  final double cropFactor;
  final int? maxWidthPx;
  final int? maxHeightPx;
  final double anamorphicDesqueeze;
  final double? offsetXMm;
  final double? offsetYMm;

  const SensorModeSpec({
    required this.name,
    required this.widthMm,
    required this.heightMm,
    this.cropFactor = 1.0,
    this.maxWidthPx,
    this.maxHeightPx,
    this.anamorphicDesqueeze = 1.0,
    this.offsetXMm,
    this.offsetYMm,
  });

  factory SensorModeSpec.fromJson(Map<String, dynamic> json) => SensorModeSpec(
        name: json['name'] as String? ?? 'Open Gate',
        widthMm: (json['widthMm'] as num).toDouble(),
        heightMm: (json['heightMm'] as num).toDouble(),
        cropFactor: (json['cropFactor'] as num?)?.toDouble() ?? 1.0,
        maxWidthPx: json['maxWidthPx'] as int?,
        maxHeightPx: json['maxHeightPx'] as int?,
        anamorphicDesqueeze:
            (json['anamorphicDesqueeze'] as num?)?.toDouble() ?? 1.0,
        offsetXMm: (json['offsetXMm'] as num?)?.toDouble(),
        offsetYMm: (json['offsetYMm'] as num?)?.toDouble(),
      );
}

/// Motor de cálculo óptico para laboratorio FLT.
class OpticsCalculator {
  OpticsCalculator._();

  static const _mountCompat = <String, Set<String>>{
    'PL': {'PL', 'LPL'},
    'LPL': {'LPL', 'PL'},
    'EF': {'EF', 'RF', 'E'},
    'RF': {'RF', 'EF'},
    'E': {'E', 'EF', 'RF'},
    'PV': {'PV', 'PL'},
    'MFT': {'MFT', 'M43'},
  };

  /// Diámetro de círculo de imagen típico según cobertura de formato (datasheets).
  static double imageCircleForFormat(String formatCoverage) {
    final f = formatCoverage.toUpperCase().trim();
    if (f.contains('LF') || f.contains('LARGE')) return 54.0;
    if (f.contains('VV') || f.contains('VISTA')) return 48.0;
    if (f.contains('FF') || f.contains('FULL')) return 43.3;
    if (f.contains('MFT') || f.contains('MICRO')) return 21.6;
    if (f.contains('S16') || f.contains('16MM')) return 14.5;
    if (f.contains('S35') || f.contains('SUPER')) return 31.2;
    return 31.2;
  }

  static String? checkMountCompatibility({
    required String? cameraMount,
    required String? lensMount,
  }) {
    if (cameraMount == null || lensMount == null) return null;
    final cam = cameraMount.toUpperCase();
    final lens = lensMount.toUpperCase();
    if (cam == lens) return null;
    final compatible = _mountCompat[cam];
    if (compatible != null && compatible.contains(lens)) return null;
    return 'Montura $lens en cámara $cam — verificar adaptador';
  }

  static double horizontalFovDegrees({
    required double focalMm,
    required double sensorWidthMm,
    bool isAnamorphic = false,
    double squeezeRatio = 1.0,
    double desqueeze = 1.0,
  }) {
    if (focalMm <= 0 || sensorWidthMm <= 0) return 0;
    var effective = isAnamorphic ? focalMm / squeezeRatio : focalMm;
    effective /= desqueeze;
    return 2 * math.atan(sensorWidthMm / (2 * effective)) * 180 / math.pi;
  }

  static double verticalFovDegrees({
    required double focalMm,
    required double sensorHeightMm,
    bool isAnamorphic = false,
    double squeezeRatio = 1.0,
  }) {
    if (focalMm <= 0 || sensorHeightMm <= 0) return 0;
    final effective = isAnamorphic ? focalMm : focalMm;
    return 2 * math.atan(sensorHeightMm / (2 * effective)) * 180 / math.pi;
  }

  static double diagonalFovDegrees({
    required double focalMm,
    required double widthMm,
    required double heightMm,
    bool isAnamorphic = false,
    double squeezeRatio = 1.0,
    double desqueeze = 1.0,
  }) {
    var w = widthMm;
    if (isAnamorphic && desqueeze > 1) w *= desqueeze;
    final diag = math.sqrt(w * w + heightMm * heightMm);
    if (focalMm <= 0 || diag <= 0) return 0;
    return 2 * math.atan(diag / (2 * focalMm)) * 180 / math.pi;
  }

  static double circleOfConfusionMm(String formatCoverage, {double cropFactor = 1.0}) {
    final base = switch (formatCoverage.toUpperCase()) {
      'FF' || 'LF' || 'FULL FRAME' || 'LARGE FORMAT' => 0.03,
      'VV' || 'VISTA VISION' => 0.035,
      'S35' || 'SUPER 35' => 0.02,
      'MFT' || 'MICRO FOUR THIRDS' => 0.015,
      'S16' || 'SUPER 16' => 0.01,
      _ => 0.02,
    };
    return base / cropFactor.clamp(0.5, 4.0);
  }

  static (double width, double height) activeAreaForAspect({
    required double sensorWidthMm,
    required double sensorHeightMm,
    required double aspectRatio,
  }) {
    if (aspectRatio <= 0) {
      return (sensorWidthMm, sensorHeightMm);
    }
    final sensorAr = sensorWidthMm / sensorHeightMm;
    if (aspectRatio >= sensorAr) {
      final h = sensorHeightMm;
      final w = h * aspectRatio;
      if (w > sensorWidthMm) {
        return (sensorWidthMm, sensorWidthMm / aspectRatio);
      }
      return (w, h);
    }
    final w = sensorWidthMm;
    final h = w / aspectRatio;
    if (h > sensorHeightMm) {
      return (sensorHeightMm * aspectRatio, sensorHeightMm);
    }
    return (w, h);
  }

  static (int?, int?) activeResolutionPx({
    required int? maxWidthPx,
    required int? maxHeightPx,
    required double sensorWidthMm,
    required double sensorHeightMm,
    required double activeWidthMm,
    required double activeHeightMm,
  }) {
    if (maxWidthPx == null || maxHeightPx == null) return (null, null);
    if (sensorWidthMm <= 0 || sensorHeightMm <= 0) return (null, null);
    final wRatio = activeWidthMm / sensorWidthMm;
    final hRatio = activeHeightMm / sensorHeightMm;
    return (
      (maxWidthPx * wRatio).round().clamp(1, maxWidthPx),
      (maxHeightPx * hRatio).round().clamp(1, maxHeightPx),
    );
  }

  static double? hyperfocalDistanceM({
    required double focalMm,
    required double tStop,
    required double cocMm,
  }) {
    if (focalMm <= 0 || tStop <= 0 || cocMm <= 0) return null;
    return (focalMm * focalMm) / (tStop * cocMm * 1000) + focalMm / 1000;
  }

  static (double? near, double? far) depthOfFieldM({
    required double focalMm,
    required double subjectDistanceM,
    required double tStop,
    required double cocMm,
  }) {
    if (focalMm <= 0 || subjectDistanceM <= 0 || tStop <= 0 || cocMm <= 0) {
      return (null, null);
    }
    final f = focalMm / 1000;
    final s = subjectDistanceM;
    final c = cocMm / 1000;
    final h = (f * f) / (tStop * c) + f;
    if (h <= 0) return (null, null);

    final near = (s * (h - f)) / (h + s - 2 * f);
    double far;
    if (s >= h) {
      far = double.infinity;
    } else {
      far = (s * (h - f)) / (h - s);
    }
    return (near.isFinite && near > 0 ? near : 0, far.isFinite ? far : null);
  }

  static OpticsResult compute({
    required double sensorWidthMm,
    required double sensorHeightMm,
    required double focalMm,
    required double imageCircleMm,
    required String formatCoverage,
    double aspectRatio = 1.78,
    double tStop = 2.8,
    double subjectDistanceM = 3.0,
    bool isAnamorphic = false,
    double squeezeRatio = 2.0,
    double? customCocMm,
    double cropFactor = 1.0,
    double anamorphicDesqueeze = 1.0,
    int? maxWidthPx,
    int? maxHeightPx,
    String? cameraMount,
    String? lensMount,
    double? fullSensorWidthMm,
    double? fullSensorHeightMm,
    int? recordingWidthPx,
    int? recordingHeightPx,
    double? cropWidthPercent,
    double? cropHeightPercent,
  }) {
    final (activeW, activeH) = activeAreaForAspect(
      sensorWidthMm: sensorWidthMm,
      sensorHeightMm: sensorHeightMm,
      aspectRatio: aspectRatio,
    );
    final effectiveFocal =
        isAnamorphic ? focalMm / squeezeRatio : focalMm;
    final diag = math.sqrt(activeW * activeW + activeH * activeH);
    final fullDiag = math.sqrt(
      sensorWidthMm * sensorWidthMm + sensorHeightMm * sensorHeightMm,
    );
    final circle = imageCircleMm > 0
        ? imageCircleMm
        : math.max(fullDiag * 1.02, imageCircleForFormat(formatCoverage));
    final covers = circle >= diag * 0.98;
    final portholing = circle < fullDiag * 0.98;
    final coc = customCocMm ?? circleOfConfusionMm(formatCoverage, cropFactor: cropFactor);
    final hFov = horizontalFovDegrees(
      focalMm: focalMm,
      sensorWidthMm: activeW,
      isAnamorphic: isAnamorphic,
      squeezeRatio: squeezeRatio,
      desqueeze: anamorphicDesqueeze,
    );
    final vFov = verticalFovDegrees(
      focalMm: focalMm,
      sensorHeightMm: activeH,
      isAnamorphic: isAnamorphic,
      squeezeRatio: squeezeRatio,
    );
    final dFov = diagonalFovDegrees(
      focalMm: focalMm,
      widthMm: activeW,
      heightMm: activeH,
      isAnamorphic: isAnamorphic,
      squeezeRatio: squeezeRatio,
      desqueeze: anamorphicDesqueeze,
    );
    final hyper = hyperfocalDistanceM(
      focalMm: focalMm,
      tStop: tStop,
      cocMm: coc,
    );
    final (near, far) = depthOfFieldM(
      focalMm: focalMm,
      subjectDistanceM: subjectDistanceM,
      tStop: tStop,
      cocMm: coc,
    );
    final (resW, resH) = activeResolutionPx(
      maxWidthPx: maxWidthPx,
      maxHeightPx: maxHeightPx,
      sensorWidthMm: sensorWidthMm,
      sensorHeightMm: sensorHeightMm,
      activeWidthMm: activeW,
      activeHeightMm: activeH,
    );

    return OpticsResult(
      sensorWidthMm: sensorWidthMm,
      sensorHeightMm: sensorHeightMm,
      activeWidthMm: activeW,
      activeHeightMm: activeH,
      focalEffectiveMm: effectiveFocal,
      hFovDeg: hFov,
      vFovDeg: vFov,
      dFovDeg: dFov,
      imageCircleMm: circle,
      sensorDiagonalMm: diag,
      coversSensor: covers,
      portholingWarning: portholing && !covers,
      cocMm: coc,
      dofNearM: near,
      dofFarM: far,
      hyperfocalM: hyper,
      activeWidthPx: resW,
      activeHeightPx: resH,
      recordingWidthPx: recordingWidthPx,
      recordingHeightPx: recordingHeightPx,
      fullSensorWidthMm: fullSensorWidthMm,
      fullSensorHeightMm: fullSensorHeightMm,
      cropWidthPercent: cropWidthPercent,
      cropHeightPercent: cropHeightPercent,
      mountWarning: checkMountCompatibility(
        cameraMount: cameraMount,
        lensMount: lensMount,
      ),
    );
  }

  static OpticsResult computeFromMode({
    required SensorModeSpec mode,
    required double focalMm,
    required double imageCircleMm,
    required String formatCoverage,
    double aspectRatio = 1.78,
    double tStop = 2.8,
    double subjectDistanceM = 3.0,
    bool isAnamorphic = false,
    double squeezeRatio = 2.0,
    String? cameraMount,
    String? lensMount,
    double? fullSensorWidthMm,
    double? fullSensorHeightMm,
    int? recordingWidthPx,
    int? recordingHeightPx,
    double? cropWidthPercent,
    double? cropHeightPercent,
  }) =>
      compute(
        sensorWidthMm: mode.widthMm,
        sensorHeightMm: mode.heightMm,
        focalMm: focalMm,
        imageCircleMm: imageCircleMm,
        formatCoverage: formatCoverage,
        aspectRatio: aspectRatio,
        tStop: tStop,
        subjectDistanceM: subjectDistanceM,
        isAnamorphic: isAnamorphic,
        squeezeRatio: squeezeRatio,
        cropFactor: mode.cropFactor,
        anamorphicDesqueeze: mode.anamorphicDesqueeze,
        maxWidthPx: mode.maxWidthPx,
        maxHeightPx: mode.maxHeightPx,
        cameraMount: cameraMount,
        lensMount: lensMount,
        fullSensorWidthMm: fullSensorWidthMm,
        fullSensorHeightMm: fullSensorHeightMm,
        recordingWidthPx: recordingWidthPx,
        recordingHeightPx: recordingHeightPx,
        cropWidthPercent: cropWidthPercent,
        cropHeightPercent: cropHeightPercent,
      );

  static double parseAspectRatio(String? label) {
    if (label == null || label.trim().isEmpty) return 16 / 9;
    final s = label.trim().toLowerCase();
    if (s.contains('2.39') || s.contains('2.40') || s.contains('anamorphic')) {
      return 2.39;
    }
    if (s.contains('2.35')) return 2.35;
    if (s.contains('1.85')) return 1.85;
    if (s.contains('4:3') || s.contains('1.33')) return 4 / 3;
    if (s.contains('1:1')) return 1.0;
    if (s.contains('16:9')) return 16 / 9;
    final parts = s.split(':');
    if (parts.length == 2) {
      final a = double.tryParse(parts[0]);
      final b = double.tryParse(parts[1]);
      if (a != null && b != null && b > 0) return a / b;
    }
    return 16 / 9;
  }
}
