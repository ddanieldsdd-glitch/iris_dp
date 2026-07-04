import '../../core/database/app_database.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'plan_element_external_mapping.dart';

/// Plataformas destino soportadas por la planta de cámara.
enum ExportPlatform { luka, unreal, cinetracer }

/// Perfil de compatibilidad resuelto para un elemento de planta.
class PlanElementCompatProfile {
  final bool luka;
  final bool unreal;
  final bool cinetracer;
  final String? lukaFixtureId;
  final String? lukaFixtureLabel;
  final String unrealLightType;
  final String? unrealMeshPath;
  final String cinetracerType;
  final double intensity;
  final int colorTempK;
  final String movementKind;
  final double? sensorWidthMm;
  final double? sensorHeightMm;
  final String? cameraBrand;
  final String? cameraModel;
  final String? lensLabel;

  const PlanElementCompatProfile({
    required this.luka,
    required this.unreal,
    required this.cinetracer,
    this.lukaFixtureId,
    this.lukaFixtureLabel,
    required this.unrealLightType,
    this.unrealMeshPath,
    required this.cinetracerType,
    required this.intensity,
    required this.colorTempK,
    required this.movementKind,
    this.sensorWidthMm,
    this.sensorHeightMm,
    this.cameraBrand,
    this.cameraModel,
    this.lensLabel,
  });

  Map<String, dynamic> toExportJson() => {
        'luka_compatible': luka,
        'unreal_compatible': unreal,
        'cinetracer_compatible': cinetracer,
        if (lukaFixtureId != null) 'luka_fixture_id': lukaFixtureId,
        if (lukaFixtureLabel != null) 'luka_fixture_label': lukaFixtureLabel,
        'unreal_light_type': unrealLightType,
        if (unrealMeshPath != null) 'unreal_mesh_path': unrealMeshPath,
        'cinetracer_type': cinetracerType,
        'intensity': intensity,
        'color_temp_k': colorTempK,
        'movement_kind': movementKind,
        if (sensorWidthMm != null) 'sensor_width_mm': sensorWidthMm,
        if (sensorHeightMm != null) 'sensor_height_mm': sensorHeightMm,
        if (cameraBrand != null) 'camera_brand': cameraBrand,
        if (cameraModel != null) 'camera_model': cameraModel,
        if (lensLabel != null) 'lens_label': lensLabel,
      };
}

/// Presets de movimiento alineados con Unreal / Cine Tracer / guion técnico.
const kStabilizationPresets = [
  'STEADY',
  'STATIC',
  'DOLLY',
  'DOLLY IN',
  'DOLLY OUT',
  'TRACK',
  'PAN',
  'TILT',
  'CRANE',
  'HANDHELD',
  'STEADICAM',
  'GIMBAL',
  'ZOOM',
];

/// Registro central de mapeos IRIS DP → LUKA / Unreal / Cine Tracer.
class PlanElementCompat {
  PlanElementCompat._();

  static const defaultUnrealMesh = '/Engine/BasicShapes/Cube';

  static const lukaFixtures = <({String id, String label})>[
    (id: 'skypanel_s360', label: 'ARRI SkyPanel S360-C'),
    (id: 'skypanel_s120', label: 'ARRI SkyPanel S120-C'),
    (id: 'skypanel_s60', label: 'ARRI SkyPanel S60-C'),
    (id: 'skypanel_s30', label: 'ARRI SkyPanel S30-C'),
    (id: 'orbiter', label: 'ARRI Orbiter'),
    (id: 'l7c', label: 'ARRI L7-C'),
    (id: 't24', label: 'ARRI T24 Fresnel'),
    (id: 't12', label: 'ARRI T12 Fresnel'),
  ];

  static String? labelForLukaFixture(String? id) {
    if (id == null) return null;
    for (final f in lukaFixtures) {
      if (f.id == id) return f.label;
    }
    return id;
  }

  static String movementKind(String? movement) {
    final m = (movement ?? 'STEADY').trim().toUpperCase();
    return switch (m) {
      'DOLLY' || 'DOLLY IN' || 'DOLLY OUT' => 'dolly',
      'TRACK' || 'TRACKING' || 'TRAVELLING' => 'track',
      'PAN' || 'PAN L' || 'PAN R' => 'pan',
      'TILT' || 'TILT U' || 'TILT D' => 'tilt',
      'CRANE' || 'JIB' || 'GRUA' => 'crane',
      'HANDHELD' || 'MANO' || 'MANO AL HOMBRO' => 'handheld',
      'STEADICAM' || 'GIMBAL' => 'stabilized',
      'ZOOM' => 'zoom',
      'STATIC' || 'FIJO' || 'STEADY' || 'ESTATICA' => 'static',
      _ => 'other',
    };
  }

  static String unrealLightTypeKey(LightType? type) {
    if (type == null) return 'led_panel';
    return switch (type) {
      LightType.fresnelSmall ||
      LightType.fresnelMedium ||
      LightType.fresnelLarge =>
        'fresnel',
      LightType.hmi => 'hmi',
      LightType.led ||
      LightType.led1x1 ||
      LightType.lightPanel ||
      LightType.flo4Tubes ||
      LightType.flo2Tubes ||
      LightType.floSingle =>
        'led_panel',
      LightType.softbox ||
      LightType.chimera ||
      LightType.octagon =>
        'softbox',
      LightType.bounce => 'bounce',
      LightType.practical => 'practical',
      LightType.sun => 'hmi',
      LightType.ellipsoidal || LightType.par || LightType.scoop => 'spot',
      _ => 'led_panel',
    };
  }

  static String cinetracerLightType(LightType? type) {
    if (type == null) return 'panel';
    return switch (type) {
      LightType.sun => 'sun',
      LightType.fresnelSmall ||
      LightType.fresnelMedium ||
      LightType.fresnelLarge ||
      LightType.hmi ||
      LightType.openFace ||
      LightType.ellipsoidal ||
      LightType.par ||
      LightType.scoop =>
        'fresnel',
      LightType.softbox ||
      LightType.chimera ||
      LightType.octagon =>
        'soft',
      LightType.bounce => 'bounce',
      LightType.practical => 'practical',
      LightType.flag || LightType.cutter || LightType.gel => 'modifier',
      _ => 'panel',
    };
  }

  static String unrealMeshForProp(PropType? type) => switch (type) {
        PropType.table => '/Engine/BasicShapes/Cube',
        PropType.chair => '/Engine/BasicShapes/Cylinder',
        PropType.sofa => '/Engine/BasicShapes/Cube',
        PropType.bed => '/Engine/BasicShapes/Cube',
        PropType.rectangle || null => defaultUnrealMesh,
      };

  static String cinetracerPropType(PropType? type) => switch (type) {
        PropType.table => 'furniture_table',
        PropType.chair => 'furniture_chair',
        PropType.sofa => 'furniture_sofa',
        PropType.bed => 'furniture_bed',
        PropType.rectangle || null => 'prop_generic',
      };

  static String unrealMeshForArchitecture(ArchitectureType? type) =>
      switch (type) {
        ArchitectureType.wall => defaultUnrealMesh,
        ArchitectureType.window => '/Engine/BasicShapes/Cube',
        ArchitectureType.doorOpen ||
        ArchitectureType.doorClosed ||
        ArchitectureType.doubleDoor =>
          '/Engine/BasicShapes/Cube',
        ArchitectureType.opening => defaultUnrealMesh,
        ArchitectureType.prisonBars => '/Engine/BasicShapes/Cube',
        null => defaultUnrealMesh,
      };

  static String cinetracerArchitectureType(ArchitectureType? type) =>
      switch (type) {
        ArchitectureType.wall => 'architecture_wall',
        ArchitectureType.window => 'architecture_window',
        ArchitectureType.doorOpen => 'architecture_door_open',
        ArchitectureType.doorClosed => 'architecture_door_closed',
        ArchitectureType.doubleDoor => 'architecture_door_double',
        ArchitectureType.opening => 'architecture_opening',
        ArchitectureType.prisonBars => 'architecture_bars',
        null => 'architecture_wall',
      };

  static ({bool compatible, String? fixtureId}) inferLukaFixture(LightType? type) {
    if (type == null) return (compatible: false, fixtureId: null);
    final fixtureId = switch (type) {
      LightType.fresnelSmall => 't12',
      LightType.fresnelMedium => 't12',
      LightType.fresnelLarge => 't24',
      LightType.hmi || LightType.openFace => 't24',
      LightType.led ||
      LightType.led1x1 ||
      LightType.lightPanel =>
        'skypanel_s60',
      LightType.flo4Tubes ||
      LightType.flo2Tubes ||
      LightType.floSingle =>
        'skypanel_s120',
      LightType.softbox ||
      LightType.chimera ||
      LightType.octagon =>
        'orbiter',
      LightType.ellipsoidal || LightType.par => 'l7c',
      _ => null,
    };
    return (compatible: fixtureId != null, fixtureId: fixtureId);
  }

  static bool isLukaCompatibleLightType(LightType? type) =>
      inferLukaFixture(type).compatible;

  static bool isUnrealCompatible(ElementType type, LightType? lightType) {
    return switch (type) {
      ElementType.camera ||
      ElementType.actor ||
      ElementType.prop ||
      ElementType.wall =>
        true,
      ElementType.light =>
        lightType != LightType.flag &&
            lightType != LightType.cutter &&
            lightType != LightType.gel &&
            lightType != LightType.cStand &&
            lightType != LightType.generator,
    };
  }

  static bool isCinetracerCompatible(ElementType type, LightType? lightType) {
    return switch (type) {
      ElementType.camera || ElementType.actor || ElementType.prop ||
      ElementType.wall =>
        true,
      ElementType.light =>
        lightType != LightType.cStand && lightType != LightType.generator,
    };
  }

  static PlanElementCompatProfile resolve(
    PlanElement element, {
    List<Light> catalog = const [],
    Camera? catalogCamera,
    Lense? catalogLens,
    Light? catalogLight,
  }) {
    final mapping = element.externalMapping;

    switch (element.type) {
      case ElementType.camera:
        return _cameraProfile(element, mapping, catalogCamera, catalogLens);
      case ElementType.light:
        return _lightProfile(element, mapping, catalog, catalogLight);
      case ElementType.actor:
        return PlanElementCompatProfile(
          luka: false,
          unreal: true,
          cinetracer: true,
          unrealLightType: 'actor',
          cinetracerType: mapping.cinetracerType ?? 'actor_marker',
          intensity: 1,
          colorTempK: 5600,
          movementKind: movementKind(element.stabilization),
        );
      case ElementType.prop:
        final mesh = mapping.unrealMeshPath ??
            unrealMeshForProp(element.propType);
        return PlanElementCompatProfile(
          luka: false,
          unreal: true,
          cinetracer: true,
          unrealLightType: 'prop',
          unrealMeshPath: mesh,
          cinetracerType:
              mapping.cinetracerType ?? cinetracerPropType(element.propType),
          intensity: 1,
          colorTempK: 5600,
          movementKind: 'static',
        );
      case ElementType.wall:
        final mesh = mapping.unrealMeshPath ??
            unrealMeshForArchitecture(element.architectureType);
        return PlanElementCompatProfile(
          luka: false,
          unreal: true,
          cinetracer: true,
          unrealLightType: 'architecture',
          unrealMeshPath: mesh,
          cinetracerType: mapping.cinetracerType ??
              cinetracerArchitectureType(element.architectureType),
          intensity: 1,
          colorTempK: 5600,
          movementKind: 'static',
        );
    }
  }

  static PlanElementCompatProfile _cameraProfile(
    PlanElement element,
    PlanElementExternalMapping mapping,
    Camera? catalogCamera,
    Lense? catalogLens,
  ) {
    return PlanElementCompatProfile(
      luka: false,
      unreal: true,
      cinetracer: true,
      unrealLightType: 'camera',
      cinetracerType: mapping.cinetracerType ?? 'cinema_camera',
      intensity: 1,
      colorTempK: 5600,
      movementKind: movementKind(element.stabilization),
      sensorWidthMm: catalogCamera?.sensorWidthMm,
      sensorHeightMm: catalogCamera?.sensorHeightMm,
      cameraBrand: catalogCamera?.brand,
      cameraModel: catalogCamera?.model,
      lensLabel: catalogLens != null
          ? '${catalogLens.brand} ${catalogLens.model}'
          : element.lens,
    );
  }

  static PlanElementCompatProfile _lightProfile(
    PlanElement element,
    PlanElementExternalMapping mapping,
    List<Light> catalog,
    Light? catalogLight,
  ) {
    final inferred = _resolveLuka(element, catalog);
    final lightType = element.lightType;
    final intensity = mapping.overrideIntensity ??
        _intensityFromCatalog(catalogLight, lightType);
    final colorTemp = mapping.overrideColorTempK ??
        catalogLight?.colorTempMax ??
        _defaultColorTemp(lightType);

    return PlanElementCompatProfile(
      luka: inferred.compatible,
      unreal: isUnrealCompatible(ElementType.light, lightType),
      cinetracer: isCinetracerCompatible(ElementType.light, lightType),
      lukaFixtureId: inferred.fixtureId,
      lukaFixtureLabel: labelForLukaFixture(inferred.fixtureId) ??
          (catalogLight != null
              ? '${catalogLight.brand} ${catalogLight.model}'
              : null),
      unrealLightType: unrealLightTypeKey(lightType),
      cinetracerType:
          mapping.cinetracerType ?? cinetracerLightType(lightType),
      intensity: intensity,
      colorTempK: colorTemp,
      movementKind: 'static',
    );
  }

  static ({bool compatible, String? fixtureId}) _resolveLuka(
    PlanElement element,
    List<Light> catalog,
  ) {
    if (element.lukaCompatible &&
        element.lukaFixtureId != null &&
        element.lukaFixtureId!.isNotEmpty) {
      return (compatible: true, fixtureId: element.lukaFixtureId);
    }
    if (element.lukaCompatible) {
      return inferLukaFixture(element.lightType);
    }

    final catalogLight = _matchCatalogLight(catalog, element);
    if (catalogLight?.isLukaCompatible == true &&
        catalogLight?.lukaFixtureId != null) {
      return (
        compatible: true,
        fixtureId: catalogLight!.lukaFixtureId,
      );
    }

    return (compatible: false, fixtureId: null);
  }

  static Light? _matchCatalogLight(List<Light> catalog, PlanElement element) {
    final id = element.externalMapping.catalogLightId;
    if (id != null) {
      for (final light in catalog) {
        if (light.id == id) return light;
      }
    }
    if (element.lightType == null || catalog.isEmpty) return null;
    final preferred = _catalogTypesForLightType(element.lightType!);
    for (final t in preferred) {
      for (final light in catalog) {
        if (light.lightType.toLowerCase() == t) return light;
      }
    }
    return null;
  }

  static List<String> _catalogTypesForLightType(LightType type) {
    return switch (type) {
      LightType.fresnelSmall ||
      LightType.fresnelMedium ||
      LightType.fresnelLarge ||
      LightType.hmi ||
      LightType.openFace =>
        ['fresnel', 'hmi'],
      LightType.led ||
      LightType.led1x1 ||
      LightType.lightPanel ||
      LightType.flo4Tubes ||
      LightType.flo2Tubes ||
      LightType.floSingle =>
        ['led_panel', 'led', 'led_tube'],
      LightType.softbox ||
      LightType.chimera ||
      LightType.octagon =>
        ['led', 'led_panel'],
      _ => ['led_panel', 'fresnel', 'led'],
    };
  }

  static double _intensityFromCatalog(Light? light, LightType? type) {
    if (light != null && light.powerW > 0) {
      return (light.powerW / 475).clamp(0.25, 4.0);
    }
    return switch (type) {
      LightType.sun || LightType.hmi => 2.0,
      LightType.fresnelLarge => 1.5,
      LightType.practical => 0.5,
      LightType.bounce => 0.75,
      _ => 1.0,
    };
  }

  static int _defaultColorTemp(LightType? type) {
    return switch (type) {
      LightType.sun || LightType.hmi || LightType.openFace => 5600,
      LightType.practical => 3200,
      LightType.led ||
      LightType.led1x1 ||
      LightType.lightPanel =>
        5600,
      _ => 5600,
    };
  }

  /// Aplica vínculos automáticos desde catálogo y tipo simbólico.
  static void applyAutoMapping(
    PlanElement element, {
    List<Light> catalog = const [],
    List<Camera> cameras = const [],
    List<Lense> lenses = const [],
  }) {
    if (element.type == ElementType.light) {
      final match = _matchCatalogLight(catalog, element);
      if (match != null) {
        element.externalMapping.catalogLightId = match.id;
        if (match.isLukaCompatible && match.lukaFixtureId != null) {
          element.lukaCompatible = true;
          element.lukaFixtureId = match.lukaFixtureId;
        }
      } else {
        final inferred = inferLukaFixture(element.lightType);
        element.lukaCompatible = inferred.compatible;
        element.lukaFixtureId = inferred.fixtureId;
      }
      element.externalMapping.cinetracerType ??=
          cinetracerLightType(element.lightType);
    }

    if (element.type == ElementType.camera && lenses.isNotEmpty) {
      final focal = _parseFocal(element.lens);
      Lense? best;
      var bestDelta = double.infinity;
      for (final lens in lenses) {
        final target = lens.focalLength > 0
            ? lens.focalLength
            : (lens.focalMin ?? lens.focalMax ?? 50);
        final delta = (target - focal).abs();
        if (delta < bestDelta) {
          bestDelta = delta;
          best = lens;
        }
      }
      if (best != null && bestDelta <= 15) {
        element.externalMapping.catalogLensId = best.id;
        element.lens ??= best.focalLength > 0
            ? '${best.focalLength.round()}mm'
            : '${best.focalMin?.round() ?? 24}-${best.focalMax?.round() ?? 290}mm';
      }
      if (cameras.isNotEmpty && element.externalMapping.catalogCameraId == null) {
        element.externalMapping.catalogCameraId = cameras.first.id;
      }
    }

    if (element.type == ElementType.prop) {
      element.externalMapping.unrealMeshPath ??=
          unrealMeshForProp(element.propType);
      element.externalMapping.cinetracerType ??=
          cinetracerPropType(element.propType);
    }

    if (element.type == ElementType.wall) {
      element.externalMapping.unrealMeshPath ??=
          unrealMeshForArchitecture(element.architectureType);
      element.externalMapping.cinetracerType ??=
          cinetracerArchitectureType(element.architectureType);
    }
  }

  static double _parseFocal(String? lens) {
    if (lens == null || lens.trim().isEmpty) return 50;
    final match = RegExp(r'(\d+\.?\d*)').firstMatch(lens);
    return double.tryParse(match?.group(1) ?? '') ?? 50;
  }
}
