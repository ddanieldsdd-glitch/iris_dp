import 'dart:convert';

import 'catalog_data_status.dart';

/// Versión embebida del catálogo IRIS.
const kEmbeddedCatalogVersion = 10;

CatalogProvenance? _provenance(Map<String, dynamic> json) =>
    json.containsKey('dataStatus') ? CatalogProvenance.fromJson(json) : null;

class CatalogManifest {
  final int version;
  final String camerasUrl;
  final String lensesUrl;
  final String lightsUrl;

  const CatalogManifest({
    required this.version,
    this.camerasUrl = 'cameras.json',
    this.lensesUrl = 'lenses.json',
    this.lightsUrl = 'lights.json',
  });

  factory CatalogManifest.fromJson(Map<String, dynamic> json) => CatalogManifest(
        version: json['version'] as int? ?? 1,
        camerasUrl: json['camerasUrl'] as String? ?? 'cameras.json',
        lensesUrl: json['lensesUrl'] as String? ?? 'lenses.json',
        lightsUrl: json['lightsUrl'] as String? ?? 'lights.json',
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'camerasUrl': camerasUrl,
        'lensesUrl': lensesUrl,
        'lightsUrl': lightsUrl,
      };
}

class CatalogCameraEntry {
  final String externalId;
  final String brand;
  final String model;
  final double sensorWidthMm;
  final double sensorHeightMm;
  final String? mountType;
  final List<Map<String, dynamic>> sensorModes;
  final double? dynamicRangeStops;
  final String? colorScience;
  final int? nativeIso;
  final String? logFormats;
  final double? weightKg;
  final int? powerDrawW;
  final String? manufacturerUrl;
  final String? series;
  final bool vintage;
  final List<String> rentalTags;
  final bool lukaCompatible;
  final Map<String, dynamic>? lukaProfile;
  final String? recordingFormats;

  /// Estado y fuente de la ficha; null en packs anteriores al master.
  final CatalogProvenance? provenance;

  const CatalogCameraEntry({
    required this.externalId,
    required this.brand,
    required this.model,
    required this.sensorWidthMm,
    required this.sensorHeightMm,
    this.mountType,
    this.sensorModes = const [],
    this.dynamicRangeStops,
    this.colorScience,
    this.nativeIso,
    this.logFormats,
    this.weightKg,
    this.powerDrawW,
    this.manufacturerUrl,
    this.series,
    this.vintage = false,
    this.rentalTags = const [],
    this.lukaCompatible = false,
    this.lukaProfile,
    this.recordingFormats,
    this.provenance,
  });

  factory CatalogCameraEntry.fromJson(Map<String, dynamic> json) =>
      CatalogCameraEntry(
        externalId: json['externalId'] as String,
        brand: json['brand'] as String,
        model: json['model'] as String,
        sensorWidthMm: (json['sensorWidthMm'] as num).toDouble(),
        sensorHeightMm: (json['sensorHeightMm'] as num).toDouble(),
        mountType: json['mountType'] as String?,
        sensorModes: (json['sensorModes'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [],
        dynamicRangeStops: (json['dynamicRangeStops'] as num?)?.toDouble(),
        colorScience: json['colorScience'] as String?,
        nativeIso: json['nativeIso'] as int?,
        logFormats: json['logFormats'] as String?,
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        powerDrawW: json['powerDrawW'] as int?,
        manufacturerUrl: json['manufacturerUrl'] as String?,
        series: json['series'] as String?,
        vintage: json['vintage'] as bool? ?? false,
        rentalTags: (json['rentalTags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        lukaCompatible: json['lukaCompatible'] as bool? ?? false,
        lukaProfile: json['lukaProfile'] as Map<String, dynamic>?,
        recordingFormats: json['recordingFormats'] as String?,
        provenance: _provenance(json),
      );

  Map<String, dynamic> toJson() => {
        'externalId': externalId,
        'brand': brand,
        'model': model,
        'sensorWidthMm': sensorWidthMm,
        'sensorHeightMm': sensorHeightMm,
        if (mountType != null) 'mountType': mountType,
        if (sensorModes.isNotEmpty) 'sensorModes': sensorModes,
        if (dynamicRangeStops != null) 'dynamicRangeStops': dynamicRangeStops,
        if (colorScience != null) 'colorScience': colorScience,
        if (nativeIso != null) 'nativeIso': nativeIso,
        if (logFormats != null) 'logFormats': logFormats,
        if (weightKg != null) 'weightKg': weightKg,
        if (powerDrawW != null) 'powerDrawW': powerDrawW,
        if (manufacturerUrl != null) 'manufacturerUrl': manufacturerUrl,
        if (series != null) 'series': series,
        'vintage': vintage,
        if (rentalTags.isNotEmpty) 'rentalTags': rentalTags,
        'lukaCompatible': lukaCompatible,
        if (lukaProfile != null) 'lukaProfile': lukaProfile,
        if (recordingFormats != null) 'recordingFormats': recordingFormats,
        ...?provenance?.toJson(),
      };
}

class CatalogLensEntry {
  final String externalId;
  final String brand;
  final String model;
  final double focalLength;
  final double? focalMin;
  final double? focalMax;
  final double minTStop;
  final String formatCoverage;
  final String? mountType;
  final double? imageCircleMm;
  final bool isAnamorphic;
  final double? squeezeRatio;
  final double? closeFocusM;
  final String? lensType;
  final String? series;
  final double? frontDiameterMm;
  final double? weightKg;
  final double? lengthMm;
  final int? yearIntroduced;
  final bool vintage;
  final List<String> rentalTags;
  final bool lukaCompatible;
  final Map<String, dynamic>? lukaProfile;

  /// ESFÉRICA o ANAMÓRFICA, según el master.
  final String? projectionType;
  final double? imageAreaWidthMm;
  final double? imageAreaHeightMm;
  final String? illuminationArea;
  final String? vignettingStatus;
  final String? shadingStatus;
  final String? portholingStatus;

  /// Ficha por focal publicada por el fabricante.
  final Map<String, dynamic>? specs;
  final CatalogProvenance? provenance;

  const CatalogLensEntry({
    required this.externalId,
    required this.brand,
    required this.model,
    required this.focalLength,
    this.focalMin,
    this.focalMax,
    required this.minTStop,
    required this.formatCoverage,
    this.mountType,
    this.imageCircleMm,
    this.isAnamorphic = false,
    this.squeezeRatio,
    this.closeFocusM,
    this.lensType,
    this.series,
    this.frontDiameterMm,
    this.weightKg,
    this.lengthMm,
    this.yearIntroduced,
    this.vintage = false,
    this.rentalTags = const [],
    this.lukaCompatible = false,
    this.lukaProfile,
    this.projectionType,
    this.imageAreaWidthMm,
    this.imageAreaHeightMm,
    this.illuminationArea,
    this.vignettingStatus,
    this.shadingStatus,
    this.portholingStatus,
    this.specs,
    this.provenance,
  });

  factory CatalogLensEntry.fromJson(Map<String, dynamic> json) =>
      CatalogLensEntry(
        externalId: json['externalId'] as String,
        brand: json['brand'] as String,
        model: json['model'] as String,
        focalLength: (json['focalLength'] as num?)?.toDouble() ?? 0,
        focalMin: (json['focalMin'] as num?)?.toDouble(),
        focalMax: (json['focalMax'] as num?)?.toDouble(),
        minTStop: (json['minTStop'] as num).toDouble(),
        formatCoverage: json['formatCoverage'] as String,
        mountType: json['mountType'] as String?,
        imageCircleMm: (json['imageCircleMm'] as num?)?.toDouble(),
        isAnamorphic: json['isAnamorphic'] as bool? ?? false,
        squeezeRatio: (json['squeezeRatio'] as num?)?.toDouble(),
        closeFocusM: (json['closeFocusM'] as num?)?.toDouble(),
        lensType: json['lensType'] as String?,
        series: json['series'] as String?,
        frontDiameterMm: (json['frontDiameterMm'] as num?)?.toDouble(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        lengthMm: (json['lengthMm'] as num?)?.toDouble(),
        yearIntroduced: json['yearIntroduced'] as int?,
        vintage: json['vintage'] as bool? ?? false,
        rentalTags: (json['rentalTags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        lukaCompatible: json['lukaCompatible'] as bool? ?? false,
        lukaProfile: json['lukaProfile'] as Map<String, dynamic>?,
        projectionType: json['projectionType'] as String?,
        imageAreaWidthMm: (json['imageAreaWidthMm'] as num?)?.toDouble(),
        imageAreaHeightMm: (json['imageAreaHeightMm'] as num?)?.toDouble(),
        illuminationArea: json['illuminationArea'] as String?,
        vignettingStatus: json['vignettingStatus'] as String?,
        shadingStatus: json['shadingStatus'] as String?,
        portholingStatus: json['portholingStatus'] as String?,
        specs: (json['specs'] as Map?)?.cast<String, dynamic>(),
        provenance: _provenance(json),
      );

  Map<String, dynamic> toJson() => {
        'externalId': externalId,
        'brand': brand,
        'model': model,
        'focalLength': focalLength,
        if (focalMin != null) 'focalMin': focalMin,
        if (focalMax != null) 'focalMax': focalMax,
        'minTStop': minTStop,
        'formatCoverage': formatCoverage,
        if (mountType != null) 'mountType': mountType,
        if (imageCircleMm != null) 'imageCircleMm': imageCircleMm,
        'isAnamorphic': isAnamorphic,
        if (squeezeRatio != null) 'squeezeRatio': squeezeRatio,
        if (closeFocusM != null) 'closeFocusM': closeFocusM,
        if (lensType != null) 'lensType': lensType,
        if (series != null) 'series': series,
        if (frontDiameterMm != null) 'frontDiameterMm': frontDiameterMm,
        if (weightKg != null) 'weightKg': weightKg,
        if (lengthMm != null) 'lengthMm': lengthMm,
        if (yearIntroduced != null) 'yearIntroduced': yearIntroduced,
        'vintage': vintage,
        if (rentalTags.isNotEmpty) 'rentalTags': rentalTags,
        'lukaCompatible': lukaCompatible,
        if (lukaProfile != null) 'lukaProfile': lukaProfile,
        if (projectionType != null) 'projectionType': projectionType,
        if (imageAreaWidthMm != null) 'imageAreaWidthMm': imageAreaWidthMm,
        if (imageAreaHeightMm != null) 'imageAreaHeightMm': imageAreaHeightMm,
        if (illuminationArea != null) 'illuminationArea': illuminationArea,
        if (vignettingStatus != null) 'vignettingStatus': vignettingStatus,
        if (shadingStatus != null) 'shadingStatus': shadingStatus,
        if (portholingStatus != null) 'portholingStatus': portholingStatus,
        if (specs != null) 'specs': specs,
        ...?provenance?.toJson(),
      };
}

class CatalogLightEntry {
  final String externalId;
  final String brand;
  final String model;
  final String lightType;
  final int powerW;
  final int colorTempMin;
  final int colorTempMax;
  final double? beamAngleDeg;

  /// Fotometría del fabricante: lux en el eje a [photometryDistanceM].
  final double? photometryLux;
  final double? photometryDistanceM;
  final int? cri;
  final int? tlci;
  final String? dimmingType;
  final bool lukaCompatible;
  final String? lukaFixtureId;
  final String? series;
  final bool vintage;
  final List<String> rentalTags;
  final Map<String, dynamic>? lukaProfile;

  /// Rango de foco y fotometría en varios haces (ver `LightOptics`). No va
  /// a la base: la planta la lee de `lights.json` por su `externalId`.
  final Map<String, dynamic>? optics;
  final CatalogProvenance? provenance;

  const CatalogLightEntry({
    required this.externalId,
    required this.brand,
    required this.model,
    required this.lightType,
    required this.powerW,
    required this.colorTempMin,
    required this.colorTempMax,
    this.beamAngleDeg,
    this.photometryLux,
    this.photometryDistanceM,
    this.cri,
    this.tlci,
    this.dimmingType,
    this.lukaCompatible = false,
    this.lukaFixtureId,
    this.series,
    this.vintage = false,
    this.rentalTags = const [],
    this.lukaProfile,
    this.optics,
    this.provenance,
  });

  factory CatalogLightEntry.fromJson(Map<String, dynamic> json) =>
      CatalogLightEntry(
        externalId: json['externalId'] as String,
        brand: json['brand'] as String,
        model: json['model'] as String,
        lightType: json['lightType'] as String,
        powerW: json['powerW'] as int,
        colorTempMin: json['colorTempMin'] as int,
        colorTempMax: json['colorTempMax'] as int,
        beamAngleDeg: (json['beamAngleDeg'] as num?)?.toDouble(),
        photometryLux: (json['photometryLux'] as num?)?.toDouble(),
        photometryDistanceM:
            (json['photometryDistanceM'] as num?)?.toDouble(),
        cri: json['cri'] as int?,
        tlci: json['tlci'] as int?,
        dimmingType: json['dimmingType'] as String?,
        lukaCompatible: json['lukaCompatible'] as bool? ?? false,
        lukaFixtureId: json['lukaFixtureId'] as String?,
        series: json['series'] as String?,
        vintage: json['vintage'] as bool? ?? false,
        rentalTags: (json['rentalTags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        lukaProfile: json['lukaProfile'] as Map<String, dynamic>?,
        optics: json['optics'] as Map<String, dynamic>?,
        provenance: _provenance(json),
      );

  Map<String, dynamic> toJson() => {
        'externalId': externalId,
        'brand': brand,
        'model': model,
        'lightType': lightType,
        'powerW': powerW,
        'colorTempMin': colorTempMin,
        'colorTempMax': colorTempMax,
        if (beamAngleDeg != null) 'beamAngleDeg': beamAngleDeg,
        if (photometryLux != null) 'photometryLux': photometryLux,
        if (photometryDistanceM != null)
          'photometryDistanceM': photometryDistanceM,
        if (cri != null) 'cri': cri,
        if (tlci != null) 'tlci': tlci,
        if (dimmingType != null) 'dimmingType': dimmingType,
        'lukaCompatible': lukaCompatible,
        if (lukaFixtureId != null) 'lukaFixtureId': lukaFixtureId,
        if (series != null) 'series': series,
        'vintage': vintage,
        if (rentalTags.isNotEmpty) 'rentalTags': rentalTags,
        if (lukaProfile != null) 'lukaProfile': lukaProfile,
        if (optics != null) 'optics': optics,
        ...?provenance?.toJson(),
      };
}

List<CatalogCameraEntry> parseCameraCatalog(String jsonStr) {
  final list = jsonDecode(jsonStr) as List<dynamic>;
  return list
      .map((e) => CatalogCameraEntry.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

List<CatalogLensEntry> parseLensCatalog(String jsonStr) {
  final list = jsonDecode(jsonStr) as List<dynamic>;
  return list
      .map((e) => CatalogLensEntry.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

List<CatalogLightEntry> parseLightCatalog(String jsonStr) {
  final list = jsonDecode(jsonStr) as List<dynamic>;
  return list
      .map((e) => CatalogLightEntry.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}
