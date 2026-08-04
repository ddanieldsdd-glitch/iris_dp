import 'dart:math' as math;
import 'dart:ui';

import 'frame_line_models.dart';
import 'optics_calculator.dart';
import 'sensor_mode_utils.dart';

/// Geometría calculada de sensor y framelines en espacio normalizado (0–1).
class FrameLineLayout {
  final Rect fullChipRect;
  final Rect sensorRect;
  final Rect modeActiveRect;
  final Rect imageCircleRect;
  final Rect activeGateRect;
  final List<ComputedFrameLine> frameLines;
  final double sensorWidthMm;
  final double sensorHeightMm;
  final double fullChipWidthMm;
  final double fullChipHeightMm;
  final int? sensorWidthPx;
  final int? sensorHeightPx;
  final int? recordingWidthPx;
  final int? recordingHeightPx;
  final double imageCircleMm;
  final double fovImageScale;
  final double previewDesqueeze;
  final String? cropLabel;

  const FrameLineLayout({
    required this.fullChipRect,
    required this.sensorRect,
    required this.modeActiveRect,
    required this.imageCircleRect,
    required this.activeGateRect,
    required this.frameLines,
    required this.sensorWidthMm,
    required this.sensorHeightMm,
    required this.fullChipWidthMm,
    required this.fullChipHeightMm,
    this.sensorWidthPx,
    this.sensorHeightPx,
    this.recordingWidthPx,
    this.recordingHeightPx,
    required this.imageCircleMm,
    required this.fovImageScale,
    this.previewDesqueeze = 1.0,
    this.cropLabel,
  });
}

class ComputedFrameLine {
  final FrameLineConfig config;
  final Rect rectNorm;
  final double widthMm;
  final double heightMm;
  final int? widthPx;
  final int? heightPx;
  final int? pixelCount;

  const ComputedFrameLine({
    required this.config,
    required this.rectNorm,
    required this.widthMm,
    required this.heightMm,
    this.widthPx,
    this.heightPx,
    this.pixelCount,
  });
}

class FrameLineGeometry {
  FrameLineGeometry._();

  /// Escala de zoom de imagen según HFOV (tan(θ/2) — referencia 50 mm).
  static double fovImageScale({
    required double hFovDeg,
    required double referenceHfovDeg,
  }) {
    if (hFovDeg <= 0 || referenceHfovDeg <= 0) return 1;
    final cur = math.tan(hFovDeg * math.pi / 360);
    final ref = math.tan(referenceHfovDeg * math.pi / 360);
    if (cur <= 0) return 1;
    return (ref / cur).clamp(0.15, 8.0);
  }

  static double referenceHfovDeg({
    required double sensorWidthMm,
    required double referenceFocalMm,
  }) {
    if (referenceFocalMm <= 0 || sensorWidthMm <= 0) return 39.6;
    return 2 *
        math.atan(sensorWidthMm / (2 * referenceFocalMm)) *
        180 /
        math.pi;
  }

  static FrameLineLayout compute({
    required SensorModeContext context,
    required OpticsResult optics,
    required List<FrameLineConfig> frameLines,
    double referenceFocalMm = 50,
    double previewDesqueeze = 1.0,
    int? recordingWidthPx,
    int? recordingHeightPx,
  }) {
    final mode = context.mode;
    const pad = 0.08;
    final chipAspect = context.fullWidthMm / context.fullHeightMm;
    final availW = 1.0 - pad * 2;
    final availH = 1.0 - pad * 2;

    double chipW;
    double chipH;
    if (chipAspect >= availW / availH) {
      chipW = availW;
      chipH = availW / chipAspect;
    } else {
      chipH = availH;
      chipW = availH * chipAspect;
    }

    final chipLeft = (1 - chipW) / 2;
    final chipTop = (1 - chipH) / 2;
    final fullChipRect = Rect.fromLTWH(chipLeft, chipTop, chipW, chipH);

    final modeNorm = context.modeRectOnChipNorm;
    final modeActiveRect = Rect.fromLTWH(
      chipLeft + modeNorm.left * chipW,
      chipTop + modeNorm.top * chipH,
      modeNorm.width * chipW,
      modeNorm.height * chipH,
    );

    // Compat: sensorRect = área activa del modo (donde va la imagen de referencia)
    final sensorRect = modeActiveRect;

    final mmPerNormX = context.fullWidthMm / chipW;
    final mmPerNormY = context.fullHeightMm / chipH;
    final chipCenter = fullChipRect.center;

    final circleDiamNorm = optics.imageCircleMm / mmPerNormX;
    final circleRect = Rect.fromCenter(
      center: chipCenter,
      width: circleDiamNorm,
      height: circleDiamNorm,
    );

    final gateW = optics.activeWidthMm / mmPerNormX;
    final gateH = optics.activeHeightMm / mmPerNormY;
    final gateCenter = Offset(
      modeActiveRect.left + modeActiveRect.width / 2,
      modeActiveRect.top + modeActiveRect.height / 2,
    );
    final activeGateRect = Rect.fromCenter(
      center: gateCenter,
      width: gateW,
      height: gateH,
    );

    final (nativeW, nativeH, _) = context.recordingPixels;
    final recW = recordingWidthPx ?? nativeW;
    final recH = recordingHeightPx ?? nativeH;
    final pxPerMmX = recW / mode.widthMm;
    final pxPerMmY = recH / mode.heightMm;

    final computed = <ComputedFrameLine>[];
    final baseRects = <String, Rect>{};

    for (final cfg in frameLines) {
      final ar = cfg.effectiveAspectRatio;
      if (ar == null) continue;
      baseRects[cfg.id] = _frameRectInSensor(
        sensorRect: modeActiveRect,
        aspectRatio: ar,
        scalingPercent: cfg.scalingPercent,
        offsetLeftPx: cfg.offsetLeftPx,
        offsetTopPx: cfg.offsetTopPx,
        pxPerMmX: pxPerMmX,
        pxPerMmY: pxPerMmY,
        sensorWidthMm: mode.widthMm,
        sensorHeightMm: mode.heightMm,
      );
    }

    for (final cfg in frameLines) {
      final ar = cfg.effectiveAspectRatio;
      if (ar == null) continue;
      var rect = baseRects[cfg.id];
      if (rect == null) continue;

      final alignId = switch (cfg.alignCenterTo) {
        FrameLineAlignCenterTo.lineA => 'A',
        FrameLineAlignCenterTo.lineB => 'B',
        FrameLineAlignCenterTo.lineC => 'C',
        FrameLineAlignCenterTo.none => null,
      };
      if (alignId != null && alignId != cfg.id) {
        final target = baseRects[alignId];
        if (target != null) {
          final delta = target.center - rect.center;
          rect = Rect.fromLTWH(
            (rect.left + delta.dx).clamp(modeActiveRect.left, modeActiveRect.right - rect.width),
            (rect.top + delta.dy).clamp(modeActiveRect.top, modeActiveRect.bottom - rect.height),
            rect.width,
            rect.height,
          );
        }
      }

      final wMm = rect.width / modeActiveRect.width * mode.widthMm;
      final hMm = rect.height / modeActiveRect.height * mode.heightMm;
      final wPx = (wMm * pxPerMmX).round();
      final hPx = (hMm * pxPerMmY).round();
      computed.add(ComputedFrameLine(
        config: cfg,
        rectNorm: rect,
        widthMm: wMm,
        heightMm: hMm,
        widthPx: wPx,
        heightPx: hPx,
        pixelCount: wPx * hPx,
      ));
    }

    final refHfov = referenceHfovDeg(
      sensorWidthMm: mode.widthMm,
      referenceFocalMm: referenceFocalMm,
    );

    return FrameLineLayout(
      fullChipRect: fullChipRect,
      sensorRect: sensorRect,
      modeActiveRect: modeActiveRect,
      imageCircleRect: circleRect,
      activeGateRect: activeGateRect,
      frameLines: computed,
      sensorWidthMm: mode.widthMm,
      sensorHeightMm: mode.heightMm,
      fullChipWidthMm: context.fullWidthMm,
      fullChipHeightMm: context.fullHeightMm,
      sensorWidthPx: recW,
      sensorHeightPx: recH,
      recordingWidthPx: recW,
      recordingHeightPx: recH,
      imageCircleMm: optics.imageCircleMm,
      fovImageScale: fovImageScale(
        hFovDeg: optics.hFovDeg,
        referenceHfovDeg: refHfov,
      ),
      previewDesqueeze: previewDesqueeze.clamp(1.0, 3.0),
      cropLabel: context.cropLabel,
    );
  }

  static Rect _frameRectInSensor({
    required Rect sensorRect,
    required double aspectRatio,
    required double scalingPercent,
    required double offsetLeftPx,
    required double offsetTopPx,
    required double? pxPerMmX,
    required double? pxPerMmY,
    required double sensorWidthMm,
    required double sensorHeightMm,
  }) {
    final sensorAr = sensorRect.width / sensorRect.height;
    double fw;
    double fh;
    if (aspectRatio >= sensorAr) {
      fh = sensorRect.height;
      fw = fh * aspectRatio;
      if (fw > sensorRect.width) {
        fw = sensorRect.width;
        fh = fw / aspectRatio;
      }
    } else {
      fw = sensorRect.width;
      fh = fw / aspectRatio;
      if (fh > sensorRect.height) {
        fh = sensorRect.height;
        fw = fh * aspectRatio;
      }
    }

    final scale = (scalingPercent / 100).clamp(0.1, 1.0);
    fw *= scale;
    fh *= scale;

    var left = sensorRect.center.dx - fw / 2;
    var top = sensorRect.center.dy - fh / 2;

    if (pxPerMmX != null && pxPerMmY != null) {
      final offX = offsetLeftPx / (sensorWidthMm * pxPerMmX) * sensorRect.width;
      final offY = offsetTopPx / (sensorHeightMm * pxPerMmY) * sensorRect.height;
      left += offX;
      top += offY;
    }

    left = left.clamp(sensorRect.left, sensorRect.right - fw);
    top = top.clamp(sensorRect.top, sensorRect.bottom - fh);

    return Rect.fromLTWH(left, top, fw, fh);
  }

  static OpticsResult resultForFrameLine({
    required SensorModeSpec mode,
    required double focalMm,
    required double imageCircleMm,
    required String formatCoverage,
    required double aspectRatio,
    required double tStop,
    required double subjectDistanceM,
    required bool isAnamorphic,
    required double squeezeRatio,
    String? cameraMount,
    String? lensMount,
  }) =>
      OpticsCalculator.computeFromMode(
        mode: mode,
        focalMm: focalMm,
        imageCircleMm: imageCircleMm,
        formatCoverage: formatCoverage,
        aspectRatio: aspectRatio,
        tStop: tStop,
        subjectDistanceM: subjectDistanceM,
        isAnamorphic: isAnamorphic,
        squeezeRatio: squeezeRatio,
        cameraMount: cameraMount,
        lensMount: lensMount,
      );
}
