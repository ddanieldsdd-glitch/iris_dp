import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/meter.dart';
import 'light/photometry.dart';
import 'light/plan_light.dart';
import 'light_beam.dart';

/// Puente entre la pantalla Equipo y la planta: las luces, cámaras y lentes
/// del proyecto, con sus datos técnicos, convertidas en elementos de planta.
class PlanEquipment {
  PlanEquipment._();

  /// Símbolo de planta para un tipo de luz del catálogo.
  static LightType lightTypeFor(String catalogType) {
    final t = catalogType.toLowerCase();
    if (t.contains('hmi')) return LightType.hmi;
    if (t.contains('fresnel')) return LightType.fresnelMedium;
    if (t.contains('tube') || t.contains('flo')) return LightType.floSingle;
    if (t.contains('panel')) return LightType.lightPanel;
    if (t.contains('practical') || t.contains('balloon')) {
      return LightType.practical;
    }
    if (t.contains('par')) return LightType.par;
    return LightType.led;
  }

  /// Un aparato del catálogo como luz de planta, con su potencia, su
  /// tecnología, su haz y, si el catálogo la trae, su fotometría.
  static PlanElement lightFromCatalog(Light light) {
    final type = lightTypeFor(light.lightType);
    final defaults = LightBeam.defaultsFor(type);
    final cct = defaults.cct
        .clamp(light.colorTempMin.toDouble(), light.colorTempMax.toDouble())
        .toDouble();
    final el = PlanElement(
      id: 0,
      type: ElementType.light,
      position: Offset.zero,
      lightType: type,
      label: type.label,
      props: {
        'name': '${light.brand} ${light.model}',
        PlanLight.wattsKey: light.powerW.toDouble(),
        PlanLight.techKey: LightTechInfo.fromCatalogType(light.lightType).name,
        LightBeam.cctKey: cct,
        if (light.beamAngleDeg != null)
          LightBeam.spreadKey: light.beamAngleDeg!.clamp(5, 360),
        if (light.photometryLux != null &&
            light.photometryDistanceM != null) ...{
          PlanLight.measuredLuxKey: light.photometryLux,
          PlanLight.measuredMetersKey: light.photometryDistanceM,
          PlanLight.photometrySourceKey: PhotometryStatus.manufacturer.name,
        },
      },
    );
    el.externalMapping.catalogLightId = light.id;
    el.lukaCompatible = light.isLukaCompatible;
    el.lukaFixtureId = light.lukaFixtureId;
    return el;
  }

  /// Pone en una cámara de planta la cámara del proyecto: su sensor, para
  /// el cono de visión, y su ISO nativo, para leer la luz.
  static void applyCamera(PlanElement el, Camera camera) {
    el.externalMapping.catalogCameraId = camera.id;
    el.props['sensorWidthMm'] = camera.sensorWidthMm;
    el.props['cameraName'] = '${camera.brand} ${camera.model}';
    if (camera.nativeIso != null) {
      el.props[CameraExposure.isoKey] = camera.nativeIso!.toDouble();
    }
  }

  /// Pone en una cámara de planta una lente del proyecto.
  static void applyLens(PlanElement el, Lense lens) {
    el.externalMapping.catalogLensId = lens.id;
    el.lens = '${_trim(lens.focalLength)}mm';
    el.props['lensName'] = '${lens.brand} ${lens.model}';
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  static String lensLabel(Lense lens) =>
      '${_trim(lens.focalLength)} mm · ${lens.brand} ${lens.model}';
}

/// Equipo del proyecto, tal como lo necesita la planta.
class ProjectGear {
  final List<Light> lights;
  final List<Camera> cameras;
  final List<Lense> lenses;

  const ProjectGear({
    this.lights = const [],
    this.cameras = const [],
    this.lenses = const [],
  });

  static Future<ProjectGear> load(AppDatabase db, int projectId) async {
    final assigned = await db.getProjectEquipment(projectId);
    final lights = <Light>[];
    final cameras = <Camera>[];
    final lenses = <Lense>[];
    for (final item in assigned) {
      switch (item.equipmentType) {
        case 'light':
          final light = await db.getLightById(item.equipmentId);
          if (light != null) lights.add(light);
        case 'camera':
          final camera = await db.getCameraById(item.equipmentId);
          if (camera != null) cameras.add(camera);
        case 'lens':
          final lens = await db.getLensById(item.equipmentId);
          if (lens != null) lenses.add(lens);
      }
    }
    lenses.sort((a, b) => a.focalLength.compareTo(b.focalLength));
    return ProjectGear(lights: lights, cameras: cameras, lenses: lenses);
  }
}
