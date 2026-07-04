import 'dart:convert';

/// Metadatos del scan 3D de una localización o set.
class LocationScanMetadata {
  final int version;
  final String? topDownImagePath;
  final double topDownWidthPx;
  final double topDownHeightPx;
  final double metersPerPixel;
  final double topDownOpacity;
  final bool useTopDownInFloorPlan;
  final String? previewImagePath;

  const LocationScanMetadata({
    this.version = 1,
    this.topDownImagePath,
    this.topDownWidthPx = 800,
    this.topDownHeightPx = 600,
    this.metersPerPixel = 0.01,
    this.topDownOpacity = 0.85,
    this.useTopDownInFloorPlan = false,
    this.previewImagePath,
  });

  bool get hasTopDown =>
      topDownImagePath != null && topDownImagePath!.isNotEmpty;

  double get widthMeters => topDownWidthPx * metersPerPixel;

  double get heightMeters => topDownHeightPx * metersPerPixel;

  LocationScanMetadata copyWith({
    String? topDownImagePath,
    double? topDownWidthPx,
    double? topDownHeightPx,
    double? metersPerPixel,
    double? topDownOpacity,
    bool? useTopDownInFloorPlan,
    String? previewImagePath,
  }) {
    return LocationScanMetadata(
      version: version,
      topDownImagePath: topDownImagePath ?? this.topDownImagePath,
      topDownWidthPx: topDownWidthPx ?? this.topDownWidthPx,
      topDownHeightPx: topDownHeightPx ?? this.topDownHeightPx,
      metersPerPixel: metersPerPixel ?? this.metersPerPixel,
      topDownOpacity: topDownOpacity ?? this.topDownOpacity,
      useTopDownInFloorPlan:
          useTopDownInFloorPlan ?? this.useTopDownInFloorPlan,
      previewImagePath: previewImagePath ?? this.previewImagePath,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        if (topDownImagePath != null) 'topDownImagePath': topDownImagePath,
        'topDownWidthPx': topDownWidthPx,
        'topDownHeightPx': topDownHeightPx,
        'metersPerPixel': metersPerPixel,
        'topDownOpacity': topDownOpacity,
        'useTopDownInFloorPlan': useTopDownInFloorPlan,
        if (previewImagePath != null) 'previewImagePath': previewImagePath,
      };

  static LocationScanMetadata fromJson(String? json) {
    if (json == null || json.isEmpty) return const LocationScanMetadata();
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return LocationScanMetadata(
        version: (data['version'] as num?)?.toInt() ?? 1,
        topDownImagePath: data['topDownImagePath'] as String?,
        topDownWidthPx: (data['topDownWidthPx'] as num?)?.toDouble() ?? 800,
        topDownHeightPx: (data['topDownHeightPx'] as num?)?.toDouble() ?? 600,
        metersPerPixel: (data['metersPerPixel'] as num?)?.toDouble() ?? 0.01,
        topDownOpacity: (data['topDownOpacity'] as num?)?.toDouble() ?? 0.85,
        useTopDownInFloorPlan: data['useTopDownInFloorPlan'] as bool? ?? false,
        previewImagePath: data['previewImagePath'] as String?,
      );
    } catch (_) {
      return const LocationScanMetadata();
    }
  }

  static String encode(LocationScanMetadata meta) =>
      jsonEncode(meta.toJson());
}

/// Origen del scan capturado en campo.
abstract final class LocationScanSource {
  static const lumaAi = 'luma_ai';
  static const polycam = 'polycam';
  static const cineTracer = 'cinetracer';
  static const manual = 'manual';

  static String label(String? source) => switch (source) {
        lumaAi => 'Luma AI',
        polycam => 'Polycam',
        cineTracer => 'Cine Tracer',
        manual => 'Manual',
        _ => 'Sin origen',
      };

  static String? inferFromExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'luma' => lumaAi,
      'ply' => polycam,
      _ => null,
    };
  }
}

/// Extensiones aceptadas por tipo de destino.
abstract final class LocationScanFormats {
  static const gaussianSplat = ['ply', 'luma'];
  static const model3d = ['glb', 'gltf', 'usdz', 'fbx', 'obj'];
  static const topDown = ['png', 'jpg', 'jpeg', 'webp'];
  static const allScan = [...gaussianSplat, ...model3d];
}
