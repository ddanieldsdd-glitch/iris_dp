import 'package:flutter/material.dart';

/// Presets de aspect ratio alineados con ARRI Frame Line Tool.
class AspectRatioPreset {
  final String id;
  final String label;
  final double? ratio;

  const AspectRatioPreset({
    required this.id,
    required this.label,
    this.ratio,
  });

  bool get isCustom => id == 'custom';
  bool get isNone => ratio == null;
}

const kAspectRatioPresets = <AspectRatioPreset>[
  AspectRatioPreset(id: 'none', label: 'None', ratio: null),
  AspectRatioPreset(id: '1.33', label: '1.33:1', ratio: 4 / 3),
  AspectRatioPreset(id: '1.43', label: '1.43:1', ratio: 1.43),
  AspectRatioPreset(id: '1.66', label: '1.66:1', ratio: 1.66),
  AspectRatioPreset(id: '1.78', label: '1.78:1', ratio: 16 / 9),
  AspectRatioPreset(id: '1.85', label: '1.85:1', ratio: 1.85),
  AspectRatioPreset(id: '1.90', label: '1.90:1', ratio: 1.90),
  AspectRatioPreset(id: '2.00', label: '2.00:1', ratio: 2.0),
  AspectRatioPreset(id: '2.20', label: '2.20:1', ratio: 2.20),
  AspectRatioPreset(id: '2.35', label: '2.35:1', ratio: 2.35),
  AspectRatioPreset(id: '2.39', label: '2.39:1', ratio: 2.39),
  AspectRatioPreset(id: 'custom', label: 'Personalizado…', ratio: null),
];

AspectRatioPreset presetForRatio(double ratio) {
  for (final p in kAspectRatioPresets) {
    if (p.ratio != null && (p.ratio! - ratio).abs() < 0.02) return p;
  }
  return const AspectRatioPreset(id: 'custom', label: 'Personalizado', ratio: null);
}

enum FrameLineShading { none, outsideFrameLine, outsideSensor }

enum FrameLineStyle { fullBox, corners, crosshair }

enum FrameLineCenterMark { none, cross, dot, crossDot }

enum FrameLineAlignCenterTo { none, lineA, lineB, lineC }

enum FrameLineStyleLength { regular, short }

/// Pestaña del panel FLT (A/B/C + guías).
enum FltSettingsTab { frameLineA, frameLineB, frameLineC, lensIlluminationGuide, frameLeader }

/// Opciones de la guía de iluminación de lente en el preview.
class LensIlluminationGuideConfig {
  final bool showImageCircle;
  final bool vignetteOutsideCircle;
  final bool showCoverageFill;

  const LensIlluminationGuideConfig({
    this.showImageCircle = true,
    this.vignetteOutsideCircle = false,
    this.showCoverageFill = false,
  });

  LensIlluminationGuideConfig copyWith({
    bool? showImageCircle,
    bool? vignetteOutsideCircle,
    bool? showCoverageFill,
  }) =>
      LensIlluminationGuideConfig(
        showImageCircle: showImageCircle ?? this.showImageCircle,
        vignetteOutsideCircle: vignetteOutsideCircle ?? this.vignetteOutsideCircle,
        showCoverageFill: showCoverageFill ?? this.showCoverageFill,
      );
}

/// Líder de imagen (Academy / ARRI) superpuesto al preview.
class FrameLeaderConfig {
  final bool enabled;
  final double aspectRatio;
  final bool showSafeArea;

  const FrameLeaderConfig({
    this.enabled = false,
    this.aspectRatio = 1.85,
    this.showSafeArea = true,
  });

  FrameLeaderConfig copyWith({
    bool? enabled,
    double? aspectRatio,
    bool? showSafeArea,
  }) =>
      FrameLeaderConfig(
        enabled: enabled ?? this.enabled,
        aspectRatio: aspectRatio ?? this.aspectRatio,
        showSafeArea: showSafeArea ?? this.showSafeArea,
      );
}

/// Perfil de grabación (resolución + códec informativo) — ver [RecordingProfileOption].
class FrameLineConfig {
  final String id;
  final String label;
  final AspectRatioPreset aspectPreset;
  final double? customAspectRatio;
  final bool showFrameLine;
  final bool aspectLock;
  final double scalingPercent;
  final FrameLineShading shading;
  final double offsetLeftPx;
  final double offsetTopPx;
  final FrameLineCenterMark centerMark;
  final FrameLineAlignCenterTo alignCenterTo;
  final FrameLineStyle style;
  final FrameLineStyleLength styleLength;
  final double lineWidth;
  final Color lineColor;
  final String? formatName;

  const FrameLineConfig({
    required this.id,
    required this.label,
    this.aspectPreset = const AspectRatioPreset(id: '1.66', label: '1.66:1', ratio: 1.66),
    this.customAspectRatio,
    this.showFrameLine = true,
    this.aspectLock = true,
    this.scalingPercent = 100,
    this.shading = FrameLineShading.none,
    this.offsetLeftPx = 0,
    this.offsetTopPx = 0,
    this.centerMark = FrameLineCenterMark.none,
    this.alignCenterTo = FrameLineAlignCenterTo.none,
    this.style = FrameLineStyle.fullBox,
    this.styleLength = FrameLineStyleLength.regular,
    this.lineWidth = 4,
    this.lineColor = const Color(0xFFFFD600),
    this.formatName,
  });

  double? get effectiveAspectRatio =>
      aspectPreset.isCustom ? customAspectRatio : aspectPreset.ratio;

  FrameLineConfig copyWith({
    AspectRatioPreset? aspectPreset,
    double? customAspectRatio,
    bool? showFrameLine,
    bool? aspectLock,
    double? scalingPercent,
    FrameLineShading? shading,
    double? offsetLeftPx,
    double? offsetTopPx,
    FrameLineCenterMark? centerMark,
    FrameLineAlignCenterTo? alignCenterTo,
    FrameLineStyle? style,
    FrameLineStyleLength? styleLength,
    double? lineWidth,
    Color? lineColor,
    String? formatName,
  }) =>
      FrameLineConfig(
        id: id,
        label: label,
        aspectPreset: aspectPreset ?? this.aspectPreset,
        customAspectRatio: customAspectRatio ?? this.customAspectRatio,
        showFrameLine: showFrameLine ?? this.showFrameLine,
        aspectLock: aspectLock ?? this.aspectLock,
        scalingPercent: scalingPercent ?? this.scalingPercent,
        shading: shading ?? this.shading,
        offsetLeftPx: offsetLeftPx ?? this.offsetLeftPx,
        offsetTopPx: offsetTopPx ?? this.offsetTopPx,
        centerMark: centerMark ?? this.centerMark,
        alignCenterTo: alignCenterTo ?? this.alignCenterTo,
        style: style ?? this.style,
        styleLength: styleLength ?? this.styleLength,
        lineWidth: lineWidth ?? this.lineWidth,
        lineColor: lineColor ?? this.lineColor,
        formatName: formatName ?? this.formatName,
      );

  static List<FrameLineConfig> defaults() => [
        const FrameLineConfig(
          id: 'A',
          label: 'Frame Line A',
          aspectPreset: AspectRatioPreset(id: '1.66', label: '1.66:1', ratio: 1.66),
          lineColor: Color(0xFFFFD600),
        ),
        const FrameLineConfig(
          id: 'B',
          label: 'Frame Line B',
          aspectPreset: AspectRatioPreset(id: '2.39', label: '2.39:1', ratio: 2.39),
          showFrameLine: false,
          lineColor: Color(0xFF00E5FF),
        ),
        const FrameLineConfig(
          id: 'C',
          label: 'Frame Line C',
          aspectPreset: AspectRatioPreset(id: '1.85', label: '1.85:1', ratio: 1.85),
          showFrameLine: false,
          lineColor: Color(0xFFFF5252),
        ),
      ];
}

/// Fondo de referencia del preview.
enum ReferenceBackgroundKind { white, black, image }

class ReferenceBackground {
  final ReferenceBackgroundKind kind;
  final String? imagePath;

  const ReferenceBackground({required this.kind, this.imagePath});

  const ReferenceBackground.white() : this(kind: ReferenceBackgroundKind.white);
  const ReferenceBackground.black() : this(kind: ReferenceBackgroundKind.black);
  ReferenceBackground.image(this.imagePath) : kind = ReferenceBackgroundKind.image;
}
