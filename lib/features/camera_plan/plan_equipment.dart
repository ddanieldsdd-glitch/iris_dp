import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/meter.dart';
import 'light/photometry.dart';
import 'light/plan_light.dart';
import 'light_beam.dart';
import 'light_family.dart';

/// Puente entre la pantalla Equipo y la planta: las luces, cámaras y lentes
/// del proyecto, con sus datos técnicos, convertidas en elementos de planta.
class PlanEquipment {
  PlanEquipment._();

  /// Símbolo de planta para un tipo de luz del catálogo.
  static LightType lightTypeFor(String catalogType) =>
      lightGroupForCatalogType(catalogType).symbol;

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
    // Un zoom entra por su focal más corta; luego se mueve con su control.
    final focal = lens.focalLength > 0
        ? lens.focalLength
        : (lens.focalMin ?? lens.focalLength);
    el.lens = '${_trim(focal)}mm';
    el.props['lensName'] = '${lens.brand} ${lens.model}';
  }

  /// Focal de una cámara de planta, en milímetros.
  static double? focalOf(PlanElement el) {
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(el.lens ?? '');
    return match == null
        ? null
        : double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  static void setFocal(PlanElement el, double focal) =>
      el.lens = '${_trim(focal.roundToDouble())}mm';

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

  /// Todas las luces del catálogo de Equipo, estén o no en el proyecto.
  final List<Light> catalogLights;

  const ProjectGear({
    this.catalogLights = const [],
    this.lights = const [],
    this.cameras = const [],
    this.lenses = const [],
  });

  /// Letra de la cámara que ocupa el puesto [index]: A, B, C…
  static String letterAt(int index) => String.fromCharCode(65 + index);

  /// Cuerpo que lleva la cámara con esa letra, si el proyecto tiene tantas.
  Camera? cameraForLetter(String? letter) {
    if (letter == null || letter.isEmpty) return null;
    final index = letter.toUpperCase().codeUnitAt(0) - 65;
    return index >= 0 && index < cameras.length ? cameras[index] : null;
  }

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
    // La cámara A es la principal del proyecto; las demás siguen el orden
    // en que se añadieron.
    final primary = (await db.resolveProjectCamera(projectId))?.id;
    final at = cameras.indexWhere((c) => c.id == primary);
    if (at > 0) cameras.insert(0, cameras.removeAt(at));
    return ProjectGear(
      lights: lights,
      cameras: cameras,
      lenses: lenses,
      catalogLights: await db.getAllLights(),
    );
  }
}

/// Cambios en el equipo del proyecto hechos desde la planta. Escriben en
/// el mismo sitio que la pantalla Equipo.
class ProjectGearEdits {
  ProjectGearEdits._();

  /// Mete o saca del proyecto varias piezas del mismo tipo (`camera` o
  /// `lens`).
  static Future<void> set(
    AppDatabase db,
    int projectId,
    String type,
    List<int> ids, {
    required bool inProject,
  }) async {
    final assigned = await db.getProjectEquipment(projectId);
    for (final id in ids) {
      final rows = assigned.where(
        (a) => a.equipmentType == type && a.equipmentId == id,
      );
      if (inProject) {
        if (rows.isNotEmpty) continue;
        await db.assignEquipmentToProject(
          projectId: projectId,
          equipmentType: type,
          equipmentId: id,
        );
        await db.maybePromotePrimaryOnEquipmentAssign(
          projectId: projectId,
          equipmentType: type,
          equipmentId: id,
        );
      } else {
        for (final row in rows) {
          await db.unassignProjectEquipment(row.id);
        }
        await db.maybeReconcilePrimaryOnEquipmentUnassign(
          projectId: projectId,
          equipmentType: type,
          equipmentId: id,
        );
      }
    }
    await db.touchProjectContent(projectId);
  }

  /// Pone una cámara como A: la principal del proyecto.
  static Future<void> makePrimaryCamera(
    AppDatabase db,
    int projectId,
    Camera camera,
  ) async {
    await db.syncBiblePrimaryCamera(projectId, camera.id);
    await db.touchProjectContent(projectId);
  }
}
