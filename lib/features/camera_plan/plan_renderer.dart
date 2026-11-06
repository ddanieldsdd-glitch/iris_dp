import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../core/database/app_database.dart';
import '../locations/location_scan_service.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'plan_data.dart';
import 'plan_images.dart';
import 'plan_thumbnail.dart';

/// Pinta plantas para los documentos tal como se ven en el editor: con la
/// luz del grupo, las imágenes, la cenital y los recorridos. Las plantas del
/// proyecto se cargan una sola vez, por muchos planos que se exporten.
class PlanRenderer {
  final AppDatabase db;
  final int projectId;
  final PlanProjectData data;
  final _store = <String, ui.Image?>{};

  PlanRenderer._(this.db, this.projectId, this.data);

  static Future<PlanRenderer> load(AppDatabase db, int projectId) async =>
      PlanRenderer._(db, projectId, await PlanProjectData.load(db, projectId));

  Future<ui.Image?> _decode(String? path) async {
    if (path == null) return null;
    if (_store.containsKey(path)) return _store[path];
    ui.Image? image;
    try {
      final file = File(path);
      if (await file.exists()) {
        final codec = await ui.instantiateImageCodec(await file.readAsBytes());
        image = (await codec.getNextFrame()).image;
      }
    } catch (_) {
      // Una imagen que no se puede leer se queda sin pintar.
    }
    return _store[path] = image;
  }

  Future<List<PlanImageDraw>> _images({
    int? siteId,
    int? setId,
    int? lightSetupId,
    int? shotId,
  }) async {
    final rows = await PlanImageStore(db).forLayers(
      projectId: projectId,
      siteId: siteId,
      setId: setId,
      lightSetupId: lightSetupId,
      shotId: shotId,
    );
    return [
      for (final row in rows)
        PlanImageDraw(
          image: await _decode(row.path),
          rect: planImageRect(row),
          rotation: row.rotation,
          opacity: row.opacity,
          above: row.above,
        ),
    ];
  }

  List<PlanElement> _visible(List<PlanElement> list, bool light) =>
      light ? list : list.where((e) => e.type != ElementType.light).toList();

  /// Recorrido de un plano secuencia, de zona a zona.
  List<List<Offset>> _routeOf(Shot shot) {
    final points = [
      for (final leg in data.legsOf(shot))
        if (data.zoneOf(data.set(leg.setId)) case final zone?) zone.center,
    ];
    return points.length < 2 ? const [] : [points];
  }

  /// La cenital de la localización o el set, si tiene.
  Future<({ui.Image? image, Rect? rect, double opacity})> _background(
    int? siteId,
    int? setId,
  ) async {
    final meta = await LocationScanService(db).resolveFloorPlanBackground(
      scope: FloorPlanScopeKind.shot,
      siteId: siteId,
      setId: setId,
    );
    final image = await _decode(meta?.topDownImagePath);
    if (meta == null || image == null) {
      return (image: null, rect: null, opacity: 0.85);
    }
    return (
      image: image,
      rect: Rect.fromLTWH(0, 0, meta.topDownWidthPx, meta.topDownHeightPx),
      opacity: meta.topDownOpacity,
    );
  }

  /// La planta de un plano, con su sección elegida. Nula si no hay nada.
  Future<Uint8List?> shot(
    Shot shot, {
    bool light = true,
    Size size = const Size(640, 420),
    double pixelRatio = 1,
  }) async {
    final setup = data.setup(shot.lightSetupId);
    final setId = data.setIdOfShot(shot);
    final siteId =
        data.set(setId)?.siteId ?? data.scene(shot.sceneId)?.locationSiteId;
    final (:focus, :crop) = data.framingOf(shot);
    final background = await _background(siteId, setId);
    return PlanThumbnail.renderPng(
      elements: _visible([
        if (setup != null) ...data.groupLightOf(setup),
        ...data.lightOfShot(shot),
        ...data.ownOfShot(shot),
      ], light),
      inherited: _visible(data.baseOfShot(shot), light),
      drawings: data.drawingsOfShot(shot),
      focus: focus,
      crop: crop,
      size: size,
      routes: _routeOf(shot),
      images: await _images(
        siteId: siteId,
        setId: setId,
        lightSetupId: setup?.id,
        shotId: shot.id,
      ),
      background: background.image,
      backgroundRect: background.rect,
      backgroundOpacity: background.opacity,
      pixelRatio: pixelRatio,
    );
  }

  /// La planta general de un esquema de luz, entera.
  Future<Uint8List?> setup(
    LightSetup setup, {
    bool light = true,
    Size size = const Size(640, 420),
    double pixelRatio = 1,
  }) async {
    final setId = setup.locationBasePlanId;
    final siteId = data.siteIdOfSetup(setup);
    final background = await _background(siteId, setId);
    return PlanThumbnail.renderPng(
      elements: _visible([
        ...data.groupLightOf(setup),
        ...data.ownOfSetup(setup),
      ], light),
      inherited: _visible(data.inheritedOfSetup(setup), light),
      drawings: data.drawingsOfSetup(setup),
      size: size,
      images: await _images(
        siteId: siteId,
        setId: setId,
        lightSetupId: setup.id,
      ),
      background: background.image,
      backgroundRect: background.rect,
      backgroundOpacity: background.opacity,
      pixelRatio: pixelRatio,
    );
  }
}
