import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../core/database/app_database.dart';
import '../../shared/annotations/annotation_document.dart';
import '../locations/location_scan_service.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'camera_plan_painter.dart';
import 'plan_data.dart';
import 'plan_images.dart';
import 'plan_segment.dart';
import 'plan_thumbnail.dart';

/// Qué planta lleva un documento: la de cámara y actores, la de luz, o las
/// dos seguidas.
enum PlanExportView {
  stage('Cámara y actores'),
  light('Luz'),
  both('Las dos');

  final String label;
  const PlanExportView(this.label);

  bool get hasStage => this != light;
  bool get hasLight => this != stage;

  String get documentTitle => switch (this) {
    stage => 'PLANTA DE CÁMARA',
    light => 'PLANTA DE LUZ',
    both => 'PLANTA DE CÁMARA Y LUZ',
  };
}

/// Una planta de documento: cámaras y actores con sus nombres al margen, o
/// las luces numeradas con cámaras y actores atenuados.
enum PlanSheetView { stage, light }

/// Pinta plantas para los documentos tal como se ven en el editor: con la
/// luz del grupo, las imágenes, la cenital y los recorridos. Las plantas del
/// proyecto se cargan una sola vez, por muchos planos que se exporten.
class PlanRenderer {
  final AppDatabase db;
  final int projectId;
  final PlanProjectData data;

  // Se guarda la tarea y no su resultado: los planos se preparan a la vez y
  // una cenital grande no debe descomprimirse una vez por plano.
  final _store = <String, Future<ui.Image?>>{};
  final _backgrounds =
      <(int?, int?), Future<({ui.Image? image, Rect? rect, double opacity})>>{};

  PlanRenderer._(this.db, this.projectId, this.data);

  static Future<PlanRenderer> load(AppDatabase db, int projectId) async =>
      PlanRenderer._(db, projectId, await PlanProjectData.load(db, projectId));

  Future<ui.Image?> _decode(String? path) async {
    if (path == null) return null;
    return _store[path] ??= _read(path);
  }

  Future<ui.Image?> _read(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final codec = await ui.instantiateImageCodec(await file.readAsBytes());
        return (await codec.getNextFrame()).image;
      }
    } catch (_) {
      // Una imagen que no se puede leer se queda sin pintar.
    }
    return null;
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

  /// Las luces heredadas, que en un documento van a plena fuerza.
  List<PlanElement> _lightsOf(List<PlanElement> list, bool light) => light
      ? list.where((e) => e.type == ElementType.light).toList()
      : const [];

  List<PlanElement> _withoutLights(List<PlanElement> list) =>
      list.where((e) => e.type != ElementType.light).toList();

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
  ) => _backgrounds[(siteId, setId)] ??= _readBackground(siteId, setId);

  Future<({ui.Image? image, Rect? rect, double opacity})> _readBackground(
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

  /// Todo lo que lleva la planta de un plano, con su sección elegida.
  Future<PlanPicture> shotPicture(Shot shot, {bool light = true}) async {
    final setup = data.setup(shot.lightSetupId);
    final setId = data.setIdOfShot(shot);
    final siteId =
        data.set(setId)?.siteId ?? data.scene(shot.sceneId)?.locationSiteId;
    final (:focus, :crop) = data.framingOf(shot);
    final background = await _background(siteId, setId);
    final base = data.baseOfShot(shot);
    return PlanPicture(
      elements: [
        ..._lightsOf(base, light),
        ..._visible([
          if (setup != null) ...data.groupLightOf(setup),
          ...data.lightOfShot(shot),
          ...data.ownOfShot(shot),
        ], light),
      ],
      inherited: _withoutLights(base),
      drawings: data.drawingsOfShot(shot),
      focus: focus,
      crop: crop,
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
    );
  }

  /// Todo lo que lleva la planta general de un esquema de luz.
  Future<PlanPicture> setupPicture(
    LightSetup setup, {
    bool light = true,
  }) async {
    final setId = setup.locationBasePlanId;
    final siteId = data.siteIdOfSetup(setup);
    final background = await _background(siteId, setId);
    final base = data.inheritedOfSetup(setup);
    return PlanPicture(
      elements: [
        ..._lightsOf(base, light),
        ..._visible([
          ...data.groupLightOf(setup),
          ...data.ownOfSetup(setup),
        ], light),
      ],
      inherited: _withoutLights(base),
      drawings: data.drawingsOfSetup(setup),
      crop: data.documentViewOf(setup),
      images: await _images(
        siteId: siteId,
        setId: setId,
        lightSetupId: setup.id,
      ),
      background: background.image,
      backgroundRect: background.rect,
      backgroundOpacity: background.opacity,
    );
  }

  /// Pinta [picture]. Con [view], esa parte en lugar de su sección. Con
  /// [backdrop], esa imagen en lugar del fondo negro. Con [lightNumbers],
  /// cada luz lleva su número de [legendOf] en vez de su rótulo.
  Future<Uint8List?> png(
    PlanPicture picture, {
    Size size = const Size(640, 420),
    double pixelRatio = 1,
    Rect? view,
    bool jpeg = false,
    bool beams = true,
    String? backdrop,
    bool lightNumbers = false,
    PlanSheetView? sheet,
  }) async => PlanThumbnail.renderPng(
    elements: picture.elements,
    inherited: picture.inherited,
    drawings: picture.drawings,
    focus: picture.focus,
    crop: view ?? picture.crop,
    size: size,
    routes: picture.routes,
    images: picture.images,
    background: picture.background,
    backgroundRect: picture.backgroundRect,
    backgroundOpacity: picture.backgroundOpacity,
    pixelRatio: pixelRatio,
    documentMarks: true,
    documentBackdrop: await _decode(backdrop),
    showBeams: beams,
    jpeg: jpeg,
    documentLightNumbers: lightNumbers,
    documentGutter: sheet == PlanSheetView.stage ? documentGutterFor(size) : 0,
    documentLightOnly: sheet == PlanSheetView.light,
  );

  /// Ancho de cada margen de los nombres en una planta de cámara y actores.
  static double documentGutterFor(Size size) =>
      (size.width * 0.19).clamp(70.0, 130.0).toDouble();

  /// Las luces numeradas de [picture], en el mismo orden que sus números
  /// en la planta pintada con `lightNumbers`.
  static List<PlanLightLegendEntry> legendOf(PlanPicture picture) =>
      CameraPlanPainter.documentLightLegend([
        ...picture.inherited,
        ...picture.elements,
      ]);

  /// La planta de un plano para un documento: luces numeradas y su
  /// leyenda aparte.
  Future<PlanSheet> shotSheet(
    Shot shot, {
    PlanSheetView view = PlanSheetView.light,
    bool beams = true,
    Size size = const Size(640, 420),
    double pixelRatio = 1,
    String? backdrop,
  }) async {
    final picture = await shotPicture(shot, light: view == PlanSheetView.light);
    return PlanSheet(
      await png(
        picture,
        size: size,
        pixelRatio: pixelRatio,
        jpeg: true,
        beams: beams,
        backdrop: backdrop,
        lightNumbers: true,
        sheet: view,
      ),
      view == PlanSheetView.light ? legendOf(picture) : const [],
    );
  }

  /// La planta general de un esquema de luz para un documento, como
  /// [shotSheet].
  Future<PlanSheet> setupSheet(
    LightSetup setup, {
    PlanSheetView view = PlanSheetView.light,
    bool beams = true,
    Size size = const Size(640, 420),
    double pixelRatio = 1,
    String? backdrop,
  }) async {
    final picture = await setupPicture(
      setup,
      light: view == PlanSheetView.light,
    );
    return PlanSheet(
      await png(
        picture,
        size: size,
        pixelRatio: pixelRatio,
        jpeg: true,
        beams: beams,
        backdrop: backdrop,
        lightNumbers: true,
        sheet: view,
      ),
      view == PlanSheetView.light ? legendOf(picture) : const [],
    );
  }

  /// La planta de un plano, con su sección elegida. Nula si no hay nada.
  Future<Uint8List?> shot(
    Shot shot, {
    bool light = true,
    bool beams = true,
    Size size = const Size(640, 420),
    double pixelRatio = 1,
    String? backdrop,
  }) async => png(
    await shotPicture(shot, light: light),
    size: size,
    pixelRatio: pixelRatio,
    jpeg: true,
    beams: beams,
    backdrop: backdrop,
  );

  /// La planta general de un esquema de luz, con su sección si tiene.
  Future<Uint8List?> setup(
    LightSetup setup, {
    bool light = true,
    bool beams = true,
    Size size = const Size(640, 420),
    double pixelRatio = 1,
    String? backdrop,
  }) async => png(
    await setupPicture(setup, light: light),
    size: size,
    pixelRatio: pixelRatio,
    jpeg: true,
    beams: beams,
    backdrop: backdrop,
  );
}

/// Una planta pintada para un documento y la leyenda de sus luces.
class PlanSheet {
  final Uint8List? image;
  final List<PlanLightLegendEntry> legend;

  const PlanSheet(this.image, this.legend);
}

/// Lo que se pinta de una planta, sin decidir aún qué parte se ve.
class PlanPicture {
  final List<PlanElement> elements;
  final List<PlanElement> inherited;
  final List<AnnotationDocument> drawings;
  final Rect? focus;
  final Rect? crop;
  final List<List<Offset>> routes;
  final List<PlanImageDraw> images;
  final ui.Image? background;
  final Rect? backgroundRect;
  final double backgroundOpacity;

  const PlanPicture({
    this.elements = const [],
    this.inherited = const [],
    this.drawings = const [],
    this.focus,
    this.crop,
    this.routes = const [],
    this.images = const [],
    this.background,
    this.backgroundRect,
    this.backgroundOpacity = 0.85,
  });

  /// Margen alrededor de los elementos, en unidades del lienzo.
  static const _margin = 90.0;

  /// Lo que ocupa todo: elementos, dibujos, imágenes y cenital. Nulo si no
  /// hay nada que enseñar.
  Rect? get extent {
    Rect? all;
    void include(Rect? rect) {
      if (rect == null) return;
      all = all == null ? rect : all!.expandToInclude(rect);
    }

    void point(Offset p) =>
        include(Rect.fromCircle(center: p, radius: _margin));
    for (final el in [...inherited, ...elements]) {
      point(el.position);
      if (PlanSegment.isSegment(el)) point(PlanSegment.end(el));
      el.pathPoints.forEach(point);
    }
    include(PlanThumbnail.drawingBounds(drawings));
    for (final image in images) {
      include(image.rect);
    }
    if (background != null) include(backgroundRect);
    if (all == null) return null;
    include(focus);
    include(crop);
    return all;
  }
}
