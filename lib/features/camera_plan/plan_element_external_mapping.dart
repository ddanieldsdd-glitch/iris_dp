import 'dart:convert';

/// Vínculos opcionales con catálogo de equipo y motores 3D (LUKA / Unreal / Cine Tracer).
class PlanElementExternalMapping {
  int? catalogCameraId;
  int? catalogLensId;
  int? catalogLightId;
  String? unrealMeshPath;
  String? cinetracerType;
  double? overrideIntensity;
  int? overrideColorTempK;

  PlanElementExternalMapping({
    this.catalogCameraId,
    this.catalogLensId,
    this.catalogLightId,
    this.unrealMeshPath,
    this.cinetracerType,
    this.overrideIntensity,
    this.overrideColorTempK,
  });

  bool get isEmpty =>
      catalogCameraId == null &&
      catalogLensId == null &&
      catalogLightId == null &&
      (unrealMeshPath == null || unrealMeshPath!.isEmpty) &&
      (cinetracerType == null || cinetracerType!.isEmpty) &&
      overrideIntensity == null &&
      overrideColorTempK == null;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (catalogCameraId != null) map['catalogCameraId'] = catalogCameraId;
    if (catalogLensId != null) map['catalogLensId'] = catalogLensId;
    if (catalogLightId != null) map['catalogLightId'] = catalogLightId;
    if (unrealMeshPath != null && unrealMeshPath!.isNotEmpty) {
      map['unrealMeshPath'] = unrealMeshPath;
    }
    if (cinetracerType != null && cinetracerType!.isNotEmpty) {
      map['cinetracerType'] = cinetracerType;
    }
    if (overrideIntensity != null) {
      map['overrideIntensity'] = overrideIntensity;
    }
    if (overrideColorTempK != null) {
      map['overrideColorTempK'] = overrideColorTempK;
    }
    return map;
  }

  static PlanElementExternalMapping fromJson(String? json) {
    if (json == null || json.trim().isEmpty) {
      return PlanElementExternalMapping();
    }
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      return PlanElementExternalMapping(
        catalogCameraId: (m['catalogCameraId'] as num?)?.toInt(),
        catalogLensId: (m['catalogLensId'] as num?)?.toInt(),
        catalogLightId: (m['catalogLightId'] as num?)?.toInt(),
        unrealMeshPath: m['unrealMeshPath'] as String?,
        cinetracerType: m['cinetracerType'] as String?,
        overrideIntensity: (m['overrideIntensity'] as num?)?.toDouble(),
        overrideColorTempK: (m['overrideColorTempK'] as num?)?.toInt(),
      );
    } catch (_) {
      return PlanElementExternalMapping();
    }
  }

  String encode() => jsonEncode(toJson());

  PlanElementExternalMapping copyWith({
    int? catalogCameraId,
    int? catalogLensId,
    int? catalogLightId,
    String? unrealMeshPath,
    String? cinetracerType,
    double? overrideIntensity,
    int? overrideColorTempK,
  }) {
    return PlanElementExternalMapping(
      catalogCameraId: catalogCameraId ?? this.catalogCameraId,
      catalogLensId: catalogLensId ?? this.catalogLensId,
      catalogLightId: catalogLightId ?? this.catalogLightId,
      unrealMeshPath: unrealMeshPath ?? this.unrealMeshPath,
      cinetracerType: cinetracerType ?? this.cinetracerType,
      overrideIntensity: overrideIntensity ?? this.overrideIntensity,
      overrideColorTempK: overrideColorTempK ?? this.overrideColorTempK,
    );
  }
}
