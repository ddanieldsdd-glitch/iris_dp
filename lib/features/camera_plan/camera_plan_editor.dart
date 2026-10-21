import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value, OrderingTerm;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../core/utils/scene_color.dart';
import '../../shared/annotations/annotation_canvas.dart';
import '../../shared/equipment/light_optics.dart';
import '../../shared/annotations/annotation_document.dart';
import 'camera_plan_grouping.dart';
import '../equipment/widgets/light_quick_add_sheet.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'camera_plan_painter.dart';
import 'camera_plan_scene_badge.dart';
import 'floor_plan_repository.dart';
import 'floor_plan_json.dart';
import 'floor_plan_scope.dart';
import 'light_beam.dart';
import 'plan_data.dart' show kLightSetupColors;
import 'plan_cast.dart';
import 'plan_gear_list.dart';
import 'plan_elevation_screen.dart';
import 'plan_light_map.dart';
import 'plan_project_gear_dialog.dart';
import 'plan_marks.dart';
import 'plan_room_panel.dart';
import 'light/ambient.dart';
import 'light/exposure.dart';
import 'light/plan_light.dart';
import 'light_overrides.dart';
import 'plan_ambient_sheet.dart';
import 'plan_equipment.dart';
import 'light/light_scene.dart';
import 'light/meter.dart';
import 'plan_light_controls.dart';
import 'plan_meter_panel.dart';
import 'plan_opening.dart';
import 'plan_palette.dart';
import 'plan_piece_controls.dart';
import 'plan_segment.dart';
import 'plan_target.dart';
import 'shot_route.dart';
import '../locations/location_scan_service.dart';
import 'plan_element_compat.dart';
import 'plan_element_compat_panel.dart';
import '../luka_export/luka_light_mapping.dart';
import 'light_grid_tile.dart';
import '../../core/widgets/app_snackbar.dart';

class CameraPlanEditor extends ConsumerStatefulWidget {
  final int projectId;
  final String label;
  final FloorPlanScope scope;
  final int? siteId;
  final int? setId;
  final int? lightSetupId;
  final int? shotId;

  /// Tramo de un plano secuencia: su set, su luz y lo colocado en él.
  final int? leg;

  /// En la pantalla de trabajo, abrir otra planta cambia la que se ve en
  /// lugar de apilar una pantalla nueva.
  final void Function(PlanTarget target)? onNavigate;

  const CameraPlanEditor({
    super.key,
    required this.projectId,
    required this.label,
    this.scope = FloorPlanScope.shot,
    this.siteId,
    this.setId,
    this.lightSetupId,
    this.shotId,
    this.leg,
    this.onNavigate,
  });

  /// Plano maestro de localización.
  const CameraPlanEditor.site({
    super.key,
    required this.projectId,
    required int this.siteId,
    required String siteName,
    this.onNavigate,
  }) : label = siteName,
       scope = FloorPlanScope.site,
       setId = null,
       lightSetupId = null,
       shotId = null,
       leg = null;

  /// Plano base del set de rodaje.
  const CameraPlanEditor.set({
    super.key,
    required this.projectId,
    required int this.setId,
    required String setName,
    this.onNavigate,
  }) : label = setName,
       scope = FloorPlanScope.set,
       siteId = null,
       lightSetupId = null,
       shotId = null,
       leg = null;

  /// Esquema de luz compartido entre planos.
  const CameraPlanEditor.lightSetup({
    super.key,
    required this.projectId,
    required int this.lightSetupId,
    required String setupName,
    this.onNavigate,
  }) : label = setupName,
       scope = FloorPlanScope.lightSetup,
       siteId = null,
       setId = null,
       shotId = null,
       leg = null;

  /// Planta de cámara de un plano concreto.
  const CameraPlanEditor.shot({
    super.key,
    required this.projectId,
    required int this.shotId,
    required String shotLabel,
    this.leg,
    this.onNavigate,
  }) : label = shotLabel,
       scope = FloorPlanScope.shot,
       siteId = null,
       setId = null,
       lightSetupId = null;

  @override
  ConsumerState<CameraPlanEditor> createState() => _CameraPlanEditorState();
}

extension on PlanElement {
  /// Una cámara nueva nace con la cámara del proyecto, si hay una sola
  /// clara: la primera de Equipo.
  void applyProjectGear(ProjectGear gear) {
    // La cámara B coge el cuerpo B del proyecto; si no hay tantas, el A.
    final body =
        gear.cameraForLetter(cameraLetter) ??
        (gear.cameras.isEmpty ? null : gear.cameras.first);
    if (body != null) PlanEquipment.applyCamera(this, body);
  }
}

class _CameraPlanEditorState extends ConsumerState<CameraPlanEditor> {
  /// Encuadre actual del lienzo, para los tests.
  @visibleForTesting
  ({Offset offset, double scale}) get debugView =>
      (offset: _canvasOffset, scale: _scale);

  static const _annotationDocumentSize = Size(1600, 1200);

  final List<PlanElement> _elements = [];
  LightSetup? _lightSetup;

  /// Esquema que se enseña cuando no lo decide un plano.
  int? _pickedSetupId;
  bool _setupPicked = false;

  /// Ids temporales de los elementos de las capas guardadas como JSON.
  int _tempId = 0;
  final Set<PlanLayer> _hiddenLayers = {};
  bool _wallsToEnvironment = false;
  List<PlanZone> _zones = const [];
  Rect? _setZone;
  bool _zoneMode = false;
  Offset? _zoneStart;
  Rect? _zoneDraft;
  Rect? _pendingFit;
  Size _canvasSize = Size.zero;
  int _setupShotCount = 0;
  Color _setupColor = kLightSetupColors.first;

  // Herramientas.
  PlanTool _tool = PlanTool.select;

  /// Primer punto del tramo que se está dibujando y dónde está el cursor.
  Offset? _segmentStart;
  Offset? _segmentHover;
  ({Offset from, Offset to})? _measure;

  /// Asa del tramo seleccionado que se arrastra: 0 inicio, 1 final, 2 curva.
  int? _segmentHandle;

  /// Imán: lo que se mueve o se dibuja se ajusta a la rejilla y a los
  /// extremos de otros tramos.
  bool _snap = true;

  /// Selección múltiple (con Mayús); incluye a `_selected`.
  final Set<PlanElement> _multi = {};

  // Deshacer y rehacer: fotos de las capas, de antes de cada cambio.
  final List<Map<PlanLayer, String>> _undoStack = [];
  final List<Map<PlanLayer, String>> _redoStack = [];
  Map<PlanLayer, String> _lastSaved = {};

  // Ajuste de la zona del set con asas.
  Rect? _zoneEditRect;

  /// Esquina que se arrastra (0–3) o -1 si se mueve la zona entera.
  int? _zoneGrip;

  /// Metros que mide una unidad del lienzo.
  double _metersPerUnit = defaultMetersPerUnit;
  final FocusNode _canvasFocus = FocusNode(debugLabel: 'planta');

  /// Luces, cámaras y lentes del proyecto, de la pantalla Equipo.
  /// La luz de la planta, calculada punto a punto.
  final _lightMap = PlanLightMapCache();

  ProjectGear _gear = const ProjectGear();

  /// Personajes del proyecto, con su color: el mismo en todas las plantas.
  Map<String, ({String name, Color color})> _cast = const {};

  /// Sol, cielo y rebote de paredes del esquema de luz abierto.
  PlanAmbient _ambient = const PlanAmbient();

  /// Cámaras de los otros planos que comparten este esquema de luz, y a
  /// qué plano lleva cada una.
  List<PlanElement> _otherCameras = const [];
  final Map<PlanElement, PlanTarget> _otherCameraShot = {};
  bool _showOtherCameras = true;

  /// Cómo es en el esquema cada luz que este plano tiene ajustada, por su
  /// identificador.
  final Map<String, PlanElement> _setupOriginals = {};

  /// Mapa de exposición en falso color, en lugar de los haces.
  bool _exposureMap = false;

  /// La luz a la exposición de la cámara o, en «Ver todo», autoexpuesta.
  LightView _lightView = LightView.camera;

  /// Rótulos de equipo y leyenda, como en una hoja de luces.
  bool _gearLabels = false;

  /// Lecturas de diafragma bajo cada actor.
  bool _showReadings = true;

  /// La cámara con la que se lee la luz: la del plano abierto o, si no hay,
  /// la primera que haya en la planta.
  PlanElement? get _meterCamera {
    PlanElement? any;
    for (final el in _elements) {
      if (el.type != ElementType.camera) continue;
      if (el.layer == PlanLayer.shot) return el;
      any ??= el;
    }
    return any;
  }

  /// Ajustes de exposición: los de la cámara y, lo que no diga, del plano.
  ExposureSettings get _exposure {
    final camera = _meterCamera;
    final shot = _shot;
    double pick(String key, double? fromShot, double fallback) =>
        (camera?.props[key] as num?)?.toDouble() ?? fromShot ?? fallback;
    return ExposureSettings(
      iso: pick(CameraExposure.isoKey, null, 800),
      shutterDeg: pick(
        CameraExposure.shutterKey,
        CameraExposure.parseStop(shot?.shutterAngle),
        180,
      ),
      fps: pick(CameraExposure.fpsKey, shot?.fps?.toDouble(), 24),
      ndStops: pick(CameraExposure.ndKey, null, 0),
    );
  }

  /// Diafragma de trabajo: el de la cámara, el del plano o T2.8.
  double get _targetStop =>
      (_meterCamera?.props[CameraExposure.stopKey] as num?)?.toDouble() ??
      CameraExposure.parseStop(_shot?.fStop) ??
      CameraExposure.defaultStop;

  /// Lectura de fotómetro donde está un elemento.
  MeterReading _readingFor(PlanElement el) => MeterReading.at(
    LightScene.from(
      _visibleElements,
      metersPerUnit: _metersPerUnit,
      ambient: _lightSetup == null ? null : _ambient,
    ),
    el.position,
    camera: _meterCamera,
    exposure: _exposure,
    targetStop: _targetStop,
  );

  int _setShotCount = 0;
  final AnnotationCanvasController _annotationController =
      AnnotationCanvasController();
  PlanElement? _selected;
  Offset _canvasOffset = Offset.zero;
  double _scale = 1.0;
  bool _loading = true;
  bool _isRotating = false;

  /// Punto tocado dentro de un recinto: abre sus propiedades.
  Offset? _selectedRoom;
  bool _isDraggingPathPoint = false;

  /// Algo se ha movido en el arrastre en curso y hay que guardarlo.
  bool _dragDirty = false;

  /// Elemento que se está arrastrando. Si no hay, el arrastre mueve el lienzo.
  PlanElement? _dragging;
  int? _selectedPathIndex;
  Shot? _shot;
  Scene? _scene;
  LocationBasePlan? _linkedSet;
  LocationSite? _linkedSite;
  List<CameraPlanNavTarget> _navTargets = [];
  Color _sceneColor = const Color(0xFF94A3B8);
  ui.Image? _backgroundImage;
  Rect? _backgroundRect;
  double _backgroundOpacity = 0.85;
  bool _annotationMode = false;
  AnnotationToolType _annotationTool = AnnotationToolType.pen;
  Color _annotationColor = const Color(0xFF007AFF);
  double _annotationWidth = 6;
  late FloorPlanRepository _repo;

  bool get _isShotMode => widget.scope == FloorPlanScope.shot;
  String get _annotationTargetType => switch (widget.scope) {
    FloorPlanScope.site => 'camera_plan_site',
    FloorPlanScope.set => 'camera_plan_set',
    FloorPlanScope.lightSetup => 'camera_plan_light_setup',
    FloorPlanScope.shot => 'camera_plan_shot',
  };
  String get _annotationTargetId {
    final id =
        widget.siteId ?? widget.setId ?? widget.lightSetupId ?? widget.shotId;
    return id?.toString() ?? '${widget.scope.name}:${widget.label}';
  }

  @override
  void initState() {
    super.initState();
    _repo = FloorPlanRepository(ref.read(databaseProvider));
    _load();
  }

  @override
  void dispose() {
    _lightMap.dispose();
    _annotationController.dispose();
    _canvasFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    LightSetup? lightSetup;
    final annotationRow = await db.getProjectAnnotationDocument(
      projectId: widget.projectId,
      targetType: _annotationTargetType,
      targetId: _annotationTargetId,
    );

    Shot? shot;
    Scene? scene;
    LocationBasePlan? linkedSet;
    LocationSite? linkedSite;
    Color sceneColor = sceneDisplayColor(null);

    final sites = await (db.select(
      db.locationSites,
    )..where((s) => s.projectId.equals(widget.projectId))).get();
    final allSets = await (db.select(
      db.locationBasePlans,
    )..where((s) => s.projectId.equals(widget.projectId))).get();
    final allScenes = await (db.select(
      db.scenes,
    )..where((s) => s.projectId.equals(widget.projectId))).get();
    final colors = ProjectColorScheme.resolve(
      sites: sites,
      sets: allSets,
      scenes: allScenes,
    );

    if (_isShotMode && widget.shotId != null) {
      shot = await (db.select(
        db.shots,
      )..where((s) => s.id.equals(widget.shotId!))).getSingleOrNull();

      if (shot != null) {
        scene = await (db.select(
          db.scenes,
        )..where((s) => s.id.equals(shot!.sceneId))).getSingleOrNull();
        // El set es el del tramo (plano secuencia), el propio del plano
        // o, si no, el de su escena.
        final ownLeg = _legOf(shot);
        final shotSetId =
            ownLeg?.setId ?? shot.locationBasePlanId ?? scene?.locationId;
        if (shotSetId != null) {
          linkedSet = await db.getLocationById(shotSetId);
        }
        final shotSiteId =
            ownLeg?.siteId ?? linkedSet?.siteId ?? scene?.locationSiteId;
        if (shotSiteId != null) {
          linkedSite = await db.getSiteById(shotSiteId);
        }
        if (scene != null) sceneColor = colors.sceneColor(scene);
      }
    } else if (widget.scope == FloorPlanScope.set && widget.setId != null) {
      linkedSet = await db.getLocationById(widget.setId!);
      if (linkedSet?.siteId != null) {
        linkedSite = await db.getSiteById(linkedSet!.siteId!);
      }
      sceneColor = colors.setColor(linkedSet!);
    } else if (widget.scope == FloorPlanScope.lightSetup &&
        widget.lightSetupId != null) {
      lightSetup = await db.getLightSetupById(widget.lightSetupId!);
      if (lightSetup?.locationBasePlanId != null) {
        linkedSet = await db.getLocationById(lightSetup!.locationBasePlanId!);
      }
      final setupSiteId = lightSetup?.locationSiteId ?? linkedSet?.siteId;
      if (setupSiteId != null) {
        linkedSite = await db.getSiteById(setupSiteId);
      }
      sceneColor = linkedSet != null
          ? colors.setColor(linkedSet)
          : colors.siteColor(linkedSite?.id);
    } else if (widget.scope == FloorPlanScope.site && widget.siteId != null) {
      linkedSite = await db.getSiteById(widget.siteId!);
      sceneColor = colors.siteColor(widget.siteId);
    }

    final navTargets = await _loadNavTargets(db);
    final gear = await ProjectGear.load(db, widget.projectId);
    final cast = await PlanCast.load(db, widget.projectId);

    // Esquema de luz que se enseña: el del plano, el elegido a mano o, si
    // no, el primero del set o de la localización.
    final projectSetups = await db.getLightSetupsForProject(widget.projectId);
    LightSetup? setupById(int? id) {
      for (final s in projectSetups) {
        if (s.id == id) return s;
      }
      return null;
    }

    if (shot != null) {
      final ownLeg = _legOf(shot);
      lightSetup = setupById(
        ownLeg != null ? ownLeg.lightSetupId : shot.lightSetupId,
      );
    } else if (_setupPicked) {
      lightSetup = setupById(_pickedSetupId);
    } else if (lightSetup == null) {
      for (final s in projectSetups) {
        final matches = linkedSet != null
            ? s.locationBasePlanId == linkedSet.id
            : linkedSite != null &&
                  s.locationBasePlanId == null &&
                  s.locationSiteId == linkedSite.id;
        if (matches) {
          lightSetup = s;
          break;
        }
      }
    }

    // Un solo lienzo: las cuatro capas, todas editables.
    final elements = <PlanElement>[];
    void addLayer(PlanLayer layer, List<PlanElement> list) {
      for (final el in list) {
        el.layer = layer;
        if (layer != PlanLayer.shot) el.id = --_tempId;
        elements.add(el);
      }
    }

    addLayer(
      PlanLayer.environment,
      FloorPlanJson.decode(linkedSite?.floorPlanJson),
    );
    addLayer(PlanLayer.set, FloorPlanJson.decode(linkedSet?.floorPlanJson));
    // La luz del esquema. Si el plano tiene ajustes propios, se ve con
    // ellos y se recuerda cómo es en el esquema.
    final setupLights = FloorPlanJson.decode(lightSetup?.planJson);
    final originals = <String, PlanElement>{};
    final overrides = LightOverrides.decode(shot?.lightOverridesJson);
    final shownLights = [
      for (final el in setupLights)
        if (overrides[LightOverrides.uidOf(el)] case final own?)
          () {
            final uid = LightOverrides.uidOf(el)!;
            originals[uid] = el;
            return own
              ..props[LightOverrides.uidKey] = uid
              ..shotOverride = true;
          }()
        else
          el,
    ];
    addLayer(PlanLayer.light, shownLights);
    if (shot != null) {
      // En una secuencia, cada tramo ve solo lo que se colocó en él.
      final inSequence = ShotRoute.decode(shot.routeJson).isNotEmpty;
      addLayer(PlanLayer.shot, [
        for (final el in await _repo.loadElements(
          scope: FloorPlanScope.shot,
          shotId: shot.id,
        ))
          if (!inSequence || FloorPlanRepository.legOf(el) == (widget.leg ?? 0))
            el,
      ]);
    }

    // Zonas de los sets sobre el plano maestro.
    final zones = <PlanZone>[];
    Rect? setZone;
    for (final set in allSets) {
      if (linkedSite == null || set.siteId != linkedSite.id) continue;
      final rect = SetZone.decode(set.sitePlacementJson);
      if (rect == null) continue;
      final active = set.id == linkedSet?.id;
      if (active) setZone = rect;
      zones.add(
        PlanZone(
          rect: rect,
          color: colors.setColor(set),
          label: set.locationName,
          active: active,
        ),
      );
    }

    // Color del esquema: su orden entre los de su mismo set.
    var setupColor = kLightSetupColors.first;
    if (lightSetup != null) {
      final siblings = projectSetups
          .where(
            (s) =>
                s.locationBasePlanId == lightSetup!.locationBasePlanId &&
                s.locationSiteId == lightSetup.locationSiteId,
          )
          .toList();
      final index = siblings.indexWhere((s) => s.id == lightSetup!.id);
      setupColor =
          kLightSetupColors[(index < 0 ? 0 : index) % kLightSetupColors.length];
    }

    final allShots = await (db.select(
      db.shots,
    )..where((s) => s.projectId.equals(widget.projectId))).get();
    // Las cámaras de los otros planos que comparten este esquema de luz.
    final otherCameras = <PlanElement>[];
    final otherCameraShot = <PlanElement, PlanTarget>{};
    if (lightSetup != null) {
      for (final other in allShots) {
        if (other.lightSetupId != lightSetup.id || other.id == shot?.id) {
          continue;
        }
        final sceneNumber = allScenes
            .where((s) => s.id == other.sceneId)
            .map((s) => s.number)
            .firstOrNull;
        final tag = sceneNumber == null
            ? 'P${other.number}'
            : '$sceneNumber·${other.number}';
        for (final row in await db.getCameraPlanElementsForShot(other.id)) {
          if (row.type != 'camera') continue;
          final ghost = PlanElement.fromDb(row)
            ..id = --_tempId
            ..props['shotTag'] = tag
            // Una cámara que no está en este plano no le hace sombra.
            ..props[LightScene.noShadowKey] = true;
          otherCameras.add(ghost);
          otherCameraShot[ghost] = PlanTarget.shot(
            other.id,
            sceneNumber == null
                ? 'Plano ${other.number}'
                : 'Esc $sceneNumber · Plano ${other.number}',
          );
        }
      }
    }

    final setSceneIds = {
      for (final s in allScenes)
        if (linkedSet != null && s.locationId == linkedSet.id) s.id,
    };
    final setShotCount = allShots
        .where((s) => setSceneIds.contains(s.sceneId))
        .length;
    final setupShotCount = allShots
        .where((s) => lightSetup != null && s.lightSetupId == lightSetup.id)
        .length;

    ui.Image? bgImage;
    Rect? bgRect;
    var bgOpacity = 0.85;
    final scanService = LocationScanService(db);
    final scopeKind = switch (widget.scope) {
      FloorPlanScope.site => FloorPlanScopeKind.site,
      FloorPlanScope.set => FloorPlanScopeKind.set,
      FloorPlanScope.lightSetup ||
      FloorPlanScope.shot => FloorPlanScopeKind.shot,
    };
    final bgMeta = await scanService.resolveFloorPlanBackground(
      scope: scopeKind,
      siteId: widget.siteId ?? linkedSite?.id,
      setId: widget.setId ?? linkedSet?.id,
    );
    if (bgMeta != null && bgMeta.topDownImagePath != null) {
      final file = File(bgMeta.topDownImagePath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        bgImage = frame.image;
        bgRect = Rect.fromLTWH(
          0,
          0,
          bgMeta.topDownWidthPx,
          bgMeta.topDownHeightPx,
        );
        bgOpacity = bgMeta.topDownOpacity;
      }
    }

    if (!mounted) return;
    _annotationController.replaceDocument(
      AnnotationDocument.decode(annotationRow?.documentJson),
    );
    setState(() {
      _elements
        ..clear()
        ..addAll(elements);
      _selected = null;
      _selectedPathIndex = null;
      _multi.clear();
      _segmentStart = null;
      _segmentHover = null;
      _zoneEditRect = null;
      _undoStack.clear();
      _redoStack.clear();
      _metersPerUnit =
          FloorPlanJson.decodeDocument(
            linkedSite?.floorPlanJson,
          ).metersPerUnit ??
          FloorPlanJson.decodeDocument(
            linkedSet?.floorPlanJson,
          ).metersPerUnit ??
          FloorPlanJson.decodeDocument(lightSetup?.planJson).metersPerUnit ??
          defaultMetersPerUnit;
      _lightSetup = lightSetup;
      _zones = zones;
      if (_setZone == null && setZone != null) _pendingFit = setZone;
      _setZone = setZone;
      _setShotCount = setShotCount;
      _setupShotCount = setupShotCount;
      _setupColor = setupColor;
      _gear = gear;
      _cast = cast;
      _ambient = FloorPlanRepository.ambientOf(lightSetup);
      _setupOriginals
        ..clear()
        ..addAll(originals);
      _otherCameras = otherCameras;
      _otherCameraShot
        ..clear()
        ..addAll(otherCameraShot);
      _shot = shot;
      _scene = scene;
      _linkedSet = linkedSet;
      _linkedSite = linkedSite;
      _sceneColor = sceneColor;
      _navTargets = navTargets;
      _backgroundImage = bgImage;
      _backgroundRect = bgRect;
      _backgroundOpacity = bgOpacity;
      _loading = false;
    });
    _lastSaved = _snapshot();
  }

  Future<void> _saveAnnotations(AnnotationDocument document) => ref
      .read(databaseProvider)
      .saveProjectAnnotationDocument(
        projectId: widget.projectId,
        targetType: _annotationTargetType,
        targetId: _annotationTargetId,
        documentJson: document.encode(),
        documentSchemaVersion: document.schemaVersion,
      );

  Future<List<CameraPlanNavTarget>> _loadNavTargets(AppDatabase db) async {
    final scenes =
        await (db.select(db.scenes)
              ..where((s) => s.projectId.equals(widget.projectId))
              ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
            .get();
    final sets = await db.getLocationsMapForProject(widget.projectId);
    final sites = await (db.select(
      db.locationSites,
    )..where((s) => s.projectId.equals(widget.projectId))).get();
    final allSets = sets.values.toList();
    final colors = ProjectColorScheme.resolve(
      sites: sites,
      sets: allSets,
      scenes: scenes,
    );
    final sitesById = {for (final s in sites) s.id: s};
    final targets = <CameraPlanNavTarget>[];

    for (final scene in scenes) {
      final color = colors.sceneColor(scene);
      final site = scene.locationSiteId != null
          ? sitesById[scene.locationSiteId]
          : null;
      final siteName =
          site?.name ??
          (scene.locationPureName.trim().isNotEmpty
              ? scene.locationPureName.trim()
              : 'Sin localización');
      final shots = await db.getShotsForScene(scene.id);
      for (final shot in shots) {
        targets.add(
          CameraPlanNavTarget(
            shotId: shot.id,
            sceneId: scene.id,
            sceneNumber: scene.number,
            shotNumber: shot.number,
            sceneName: scene.name,
            sceneColor: color,
            siteName: siteName,
          ),
        );
      }
    }
    return targets;
  }

  /// Tramo de secuencia que se está viendo, si el plano lo es.
  ShotLeg? _legOf(Shot shot) {
    final route = ShotRoute.decode(shot.routeJson);
    final index = widget.leg;
    return index != null && index >= 0 && index < route.length
        ? route[index]
        : null;
  }

  /// Pone un esquema de luz al plano o, en una secuencia, a su tramo.
  Future<void> _assignSetup(Shot shot, int? setupId) async {
    final db = ref.read(databaseProvider);
    final route = ShotRoute.decode(shot.routeJson);
    final index = widget.leg;
    if (index == null || index < 0 || index >= route.length) {
      await db.assignLightSetupToShot(shot.id, setupId);
      return;
    }
    final next = [...route];
    next[index] = ShotLeg(
      siteId: route[index].siteId,
      setId: route[index].setId,
      lightSetupId: setupId,
    );
    await db.saveShotRoute(shot.id, ShotRoute.encode(next));
    // El primer tramo es también el esquema «del plano».
    if (index == 0) await db.assignLightSetupToShot(shot.id, setupId);
  }

  void _jumpToShot(CameraPlanNavTarget target) {
    if (target.shotId == widget.shotId) return;
    if (widget.onNavigate != null) {
      widget.onNavigate!(PlanTarget.shot(target.shotId, target.label));
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CameraPlanEditor.shot(
          projectId: widget.projectId,
          shotId: target.shotId,
          shotLabel: target.label,
        ),
      ),
    );
  }

  Future<void> _saveCurrentPlan() async {
    await _persistAllElements();
    if (!mounted) return;
    _showSnack('Planta guardada.');
  }

  /// Elige el esquema de luz que usa este plano.
  Future<void> _chooseLightSetup() async {
    final scene = _scene;
    final shot = _shot;
    final palette = context.palette;
    final db0 = ref.read(databaseProvider);
    final List<LightSetup> setups;
    if (scene != null) {
      setups = await _repo.lightSetupsForScene(scene);
    } else {
      final all = await db0.getLightSetupsForProject(widget.projectId);
      setups = all.where((s) {
        if (_linkedSet != null) {
          return s.locationBasePlanId == _linkedSet!.id ||
              (s.locationBasePlanId == null &&
                  s.locationSiteId != null &&
                  s.locationSiteId == _linkedSite?.id);
        }
        if (_linkedSite != null) {
          return s.locationBasePlanId == null &&
              s.locationSiteId == _linkedSite!.id;
        }
        return s.locationBasePlanId == null && s.locationSiteId == null;
      }).toList();
    }
    if (!mounted) return;
    final currentId = _lightSetup?.id;

    const none = -1;
    const create = -2;
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  shot != null ? 'Esquema de luz del plano' : 'Esquema de luz',
                  style: AppTypography.titleMedium(palette),
                ),
              ),
              for (final setup in setups)
                ListTile(
                  leading: Icon(
                    setup.id == currentId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: palette.accent,
                  ),
                  title: Text(
                    setup.name,
                    style: AppTypography.bodyLarge(palette),
                  ),
                  subtitle: Text(
                    lightSetupStatusLabel(setup.status),
                    style: AppTypography.caption(palette),
                  ),
                  onTap: () => Navigator.pop(ctx, setup.id),
                ),
              ListTile(
                leading: Icon(Icons.add, color: palette.accent),
                title: Text(
                  'Nuevo esquema de luz',
                  style: AppTypography.bodyLarge(palette),
                ),
                onTap: () => Navigator.pop(ctx, create),
              ),
              if (currentId != null)
                ListTile(
                  leading: Icon(Icons.link_off, color: palette.textSecondary),
                  title: Text(
                    'Sin esquema de luz',
                    style: AppTypography.bodyLarge(palette),
                  ),
                  onTap: () => Navigator.pop(ctx, none),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;

    LightSetup? chosen;
    if (choice == create) {
      chosen = await _repo.createLightSetup(
        projectId: widget.projectId,
        setId: _linkedSet?.id,
        siteId: _linkedSet == null ? _linkedSite?.id : null,
      );
    } else if (choice != none) {
      chosen = setups.firstWhere((s) => s.id == choice);
    }
    if (shot != null) {
      await _assignSetup(shot, chosen?.id);
    } else if (chosen != null &&
        widget.scope == FloorPlanScope.lightSetup &&
        widget.onNavigate != null) {
      widget.onNavigate!(PlanTarget.lightSetup(chosen.id, chosen.name));
      return;
    } else {
      _pickedSetupId = chosen?.id;
      _setupPicked = true;
    }
    await _load();
  }

  /// El esquema de luz activo; lo crea si aún no hay ninguno.
  Future<LightSetup> _ensureLightSetup() async {
    final existing = _lightSetup;
    if (existing != null) return existing;
    final created = await _repo.createLightSetup(
      projectId: widget.projectId,
      setId: _linkedSet?.id,
      siteId: _linkedSet == null ? _linkedSite?.id : null,
    );
    final shot = _shot;
    if (shot != null) {
      final db = ref.read(databaseProvider);
      await _assignSetup(shot, created.id);
      _shot = await (db.select(
        db.shots,
      )..where((s) => s.id.equals(shot.id))).getSingleOrNull();
    } else {
      _pickedSetupId = created.id;
      _setupPicked = true;
    }
    if (mounted) {
      setState(() => _lightSetup = created);
      _showSnack('Se ha creado «${created.name}» para la luz.');
    }
    return created;
  }

  /// Capa en la que se guarda un elemento nuevo, según su tipo.
  Future<PlanLayer> _layerForNew(ElementType type) async {
    switch (type) {
      case ElementType.light:
        await _ensureLightSetup();
        return PlanLayer.light;
      case ElementType.camera || ElementType.actor:
        if (_shot != null) return PlanLayer.shot;
        await _ensureLightSetup();
        return PlanLayer.light;
      case ElementType.wall || ElementType.prop:
        if (_linkedSet != null && !_wallsToEnvironment) return PlanLayer.set;
        if (_linkedSite != null) return PlanLayer.environment;
        if (_linkedSet != null) return PlanLayer.set;
        if (_shot != null) return PlanLayer.shot;
        await _ensureLightSetup();
        return PlanLayer.light;
    }
  }

  bool _hasLayer(PlanLayer layer) => switch (layer) {
    PlanLayer.environment => _linkedSite != null,
    PlanLayer.set => _linkedSet != null,
    PlanLayer.light => _lightSetup != null,
    PlanLayer.shot => _shot != null,
  };

  List<PlanElement> _layerElements(PlanLayer layer) =>
      _elements.where((e) => e.layer == layer).toList();

  List<PlanElement> get _visibleElements => _hiddenLayers.isEmpty
      ? _elements
      : _elements.where((e) => !_hiddenLayers.contains(e.layer)).toList();

  /// Guarda una capa entera en su sitio.
  Future<void> _saveLayer(PlanLayer layer) async {
    if (!_hasLayer(layer)) return;
    final list = _layerElements(layer);
    switch (layer) {
      case PlanLayer.environment:
        await _repo.saveElements(
          scope: FloorPlanScope.site,
          elements: list,
          siteId: _linkedSite!.id,
        );
      case PlanLayer.set:
        await _repo.saveElements(
          scope: FloorPlanScope.set,
          elements: list,
          setId: _linkedSet!.id,
        );
      case PlanLayer.light:
        // Cada elemento del esquema lleva un identificador estable, para
        // que un plano pueda ajustarlo sin tocar el de los demás.
        LightOverrides.ensureUids(list);
        final own = <String, PlanElement>{};
        final shared = <PlanElement>[];
        for (final el in list) {
          final uid = LightOverrides.uidOf(el)!;
          final original = _setupOriginals[uid];
          if (el.shotOverride && original != null && _shot != null) {
            // Ajustado solo en este plano: el esquema conserva el suyo.
            own[uid] = el;
            shared.add(original);
          } else {
            shared.add(el);
          }
        }
        await _repo.saveElements(
          scope: FloorPlanScope.lightSetup,
          elements: shared,
          lightSetupId: _lightSetup!.id,
        );
        final shot = _shot;
        if (shot != null) {
          await _repo.saveLightOverrides(shot.id, own);
          _shot =
              await (ref
                      .read(databaseProvider)
                      .select(ref.read(databaseProvider).shots)
                    ..where((s) => s.id.equals(shot.id)))
                  .getSingleOrNull();
        }
      case PlanLayer.shot:
        await _repo.saveElements(
          scope: FloorPlanScope.shot,
          elements: list,
          shotId: _shot!.id,
        );
    }
  }

  /// Hace que una luz del esquema se ajuste solo en este plano, o la
  /// devuelve a como está en el esquema.
  Future<void> _setShotOverride(PlanElement el, bool own) async {
    if (_shot == null || el.layer != PlanLayer.light) return;
    LightOverrides.ensureUids([el]);
    final uid = LightOverrides.uidOf(el)!;
    if (own) {
      _setupOriginals[uid] = LightOverrides.clone(el);
      setState(() => el.shotOverride = true);
    } else {
      final original = _setupOriginals.remove(uid);
      if (original != null) {
        final index = _elements.indexOf(el);
        original
          ..layer = PlanLayer.light
          ..id = --_tempId
          ..shotOverride = false;
        setState(() {
          if (index >= 0) _elements[index] = original;
          _selected = original;
          _multi.clear();
        });
      } else {
        setState(() => el.shotOverride = false);
      }
    }
    await _saveLayer(PlanLayer.light);
    _commitHistory();
  }

  /// Añade a la planta un aparato del catálogo de Equipo, con sus datos.
  Future<void> _addCatalogLight(Light light) =>
      _addElement(PlanEquipment.lightFromCatalog(light));

  /// Da de alta una luz que no está en el catálogo, la mete en el proyecto
  /// y la pone en la planta.
  Future<void> _quickAddLight(String query) async {
    final light = await showLightQuickAdd(
      context,
      initialModel: query,
      confirmLabel: 'Añadir a la planta',
    );
    if (light == null || !mounted) return;
    final db = ref.read(databaseProvider);
    await ProjectGearEdits.set(db, widget.projectId, 'light', [
      light.id,
    ], inProject: true);
    final gear = await ProjectGear.load(db, widget.projectId);
    if (!mounted) return;
    setState(() => _gear = gear);
    await _addCatalogLight(light);
  }

  /// Sol, cielo y rebote de paredes: se guardan con el esquema de luz.
  Future<void> _editAmbient() async {
    final setup = await _ensureLightSetup();
    if (!mounted) return;
    final palette = context.palette;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      builder: (_) => PlanAmbientSheet(
        initial: _ambient,
        onChanged: (next) {
          setState(() => _ambient = next);
          _repo.saveAmbient(setup.id, next);
        },
      ),
    );
  }

  /// A qué afecta cambiar un elemento de esta capa.
  String _scopeNotice(PlanLayer layer) {
    String shots(int n) => '$n plano${n == 1 ? '' : 's'}';
    return switch (layer) {
      PlanLayer.environment =>
        'Entorno · cambia en toda la localización'
            '${_linkedSite != null ? ' «${_linkedSite!.name}»' : ''}',
      PlanLayer.set =>
        'Set «${_linkedSet?.locationName ?? ''}» · '
            'cambia en sus ${shots(_setShotCount)}',
      PlanLayer.light =>
        '${_lightSetup?.name ?? 'Luz'} · '
            'lo usan ${shots(_setupShotCount)}',
      PlanLayer.shot => 'Solo este plano',
    };
  }

  /// Pasa un elemento a otra capa.
  Future<void> _moveToLayer(PlanElement el, PlanLayer target) async {
    final source = el.layer;
    if (source == target || !_hasLayer(target)) return;
    if (source == PlanLayer.shot && el.id > 0) {
      await ref.read(databaseProvider).deleteCameraPlanElement(el.id);
    }
    setState(() {
      el.layer = target;
      el.id = target == PlanLayer.shot ? 0 : --_tempId;
    });
    if (source != PlanLayer.shot) await _saveLayer(source);
    await _persistElement(el);
    if (mounted) setState(() {});
  }

  /// Luces, cámaras y actores guardados en el entorno o en el set.
  List<PlanElement> get _misplaced => _elements
      .where(
        (e) =>
            (e.layer == PlanLayer.environment || e.layer == PlanLayer.set) &&
            (e.type == ElementType.light ||
                e.type == ElementType.camera ||
                e.type == ElementType.actor),
      )
      .toList();

  /// Pasa las luces a un esquema de luz y las cámaras y actores al plano.
  Future<void> _tidyLayers() async {
    final misplaced = _misplaced;
    if (misplaced.isEmpty) return;
    for (final el in misplaced) {
      final target = await _layerForNew(el.type);
      el.layer = target;
      el.id = target == PlanLayer.shot ? 0 : --_tempId;
    }
    await _persistAllElements();
    if (!mounted) return;
    setState(() {});
    _showSnack('Capas ordenadas.');
  }

  // ── Zona del set ──────────────────────────────────────────────────────────

  Future<void> _saveZone(Rect rect) async {
    final set = _linkedSet;
    if (set == null) return;
    final db = ref.read(databaseProvider);
    await db.updateLocation(
      set.copyWith(sitePlacementJson: Value(SetZone.encode(rect))),
    );
    await _load();
  }

  Future<void> _clearZone() async {
    final set = _linkedSet;
    if (set == null) return;
    await ref
        .read(databaseProvider)
        .updateLocation(set.copyWith(sitePlacementJson: const Value(null)));
    await _load();
  }

  /// Encuadra el lienzo en un rectángulo del plano.
  void _fitTo(Rect rect) {
    if (_canvasSize.isEmpty) return;
    final target = rect.inflate(60);
    final scale = math
        .min(
          _canvasSize.width / target.width,
          _canvasSize.height / target.height,
        )
        .clamp(0.2, 2.5);
    setState(() {
      _scale = scale;
      _canvasOffset = _canvasSize.center(Offset.zero) - target.center * scale;
    });
  }

  /// Centro de lo que se ve, en coordenadas del plano.
  Offset get _viewCenter => _canvasSize.isEmpty
      ? const Offset(300, 250)
      : _toCanvasCoords(_canvasSize.center(Offset.zero));

  void _showSnack(String message) {
    AppSnackBar.show(context, message);
  }

  void _showSceneNavigator() {
    final palette = context.palette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          final groups = groupNavTargetsBySite(_navTargets);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Text(
                      'Escenas y planos',
                      style: AppTypography.titleMedium(palette),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: palette.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: groups.length,
                  itemBuilder: (context, gi) {
                    final group = groups[gi];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: group.accentColor.withValues(alpha: 0.12),
                            border: Border(
                              left: BorderSide(
                                color: group.accentColor,
                                width: 4,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_city_outlined,
                                size: 16,
                                color: palette.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  group.siteName,
                                  style: AppTypography.label(palette),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...group.targets.map((t) {
                          final selected = t.shotId == widget.shotId;
                          return ListTile(
                            leading: SceneNumberBadge(
                              sceneNumber: t.sceneNumber,
                              color: t.sceneColor,
                              size: 28,
                            ),
                            title: Text(
                              t.label,
                              style: AppTypography.bodyLarge(palette).copyWith(
                                color: selected
                                    ? palette.accent
                                    : palette.textPrimary,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            subtitle: t.sceneName.isNotEmpty
                                ? Text(
                                    t.sceneName,
                                    style: AppTypography.caption(palette),
                                  )
                                : null,
                            trailing: selected
                                ? Icon(
                                    Icons.check_circle,
                                    color: palette.accent,
                                    size: 20,
                                  )
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              _jumpToShot(t);
                            },
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _persistElement(
    PlanElement el, {
    int? sortOrder,
    bool commit = true,
  }) async {
    if (el.layer != PlanLayer.shot) {
      await _saveLayer(el.layer);
      if (commit) _commitHistory();
      return;
    }
    final shotId = _shot?.id;
    if (shotId == null) return;

    final db = ref.read(databaseProvider);
    final shotElements = _layerElements(PlanLayer.shot);
    final index = shotElements.indexOf(el);
    final order = sortOrder ?? (index >= 0 ? index : shotElements.length);

    if (el.id <= 0) {
      // Lo que se coloca en un tramo de secuencia es de ese tramo.
      if (widget.leg != null) {
        el.props[FloorPlanRepository.legKey] = widget.leg;
      }
      final newId = await db.insertCameraPlanElement(
        el.toCompanion(shotId, sortOrder: order),
      );
      el.id = newId;
      await db.replacePathPoints(
        newId,
        el.pathPoints.map((p) => (x: p.dx, y: p.dy)).toList(),
      );
    } else {
      await db.updateCameraPlanElement(
        CameraPlanElement(
          id: el.id,
          shotId: shotId,
          type: el.type.dbValue,
          x: el.position.dx,
          y: el.position.dy,
          rotation: el.rotation,
          label: el.label,
          color: el.type == ElementType.actor
              ? hexFromColor(el.actorColor)
              : null,
          cameraStabilization: el.stabilization,
          cameraLens: el.lens,
          cameraLetter: el.cameraLetter,
          cameraNumber: el.cameraNumber,
          lightType: el.lightType?.dbValue,
          lukaCompatible: el.lukaCompatible,
          lukaFixtureId: el.lukaFixtureId,
          externalMappingJson: el.externalMapping.isEmpty
              ? null
              : el.externalMapping.encode(),
          propsJson: el.props.isEmpty ? null : jsonEncode(el.props),
          sortOrder: order,
        ),
      );
      await db.replacePathPoints(
        el.id,
        el.pathPoints.map((p) => (x: p.dx, y: p.dy)).toList(),
      );
    }

    await db.touchProjectContent(widget.projectId);

    if (el.type == ElementType.camera && _shot != null) {
      await db.updateShot(
        _shot!.copyWith(
          lens: Value(el.lens ?? _shot!.lens),
          movement: Value(el.stabilization ?? _shot!.movement),
        ),
      );
      _shot = (await (db.select(
        db.shots,
      )..where((s) => s.id.equals(shotId))).getSingleOrNull());
    }
    if (commit) _commitHistory();
  }

  Future<void> _persistAllElements() async {
    for (final layer in PlanLayer.values) {
      await _saveLayer(layer);
    }
    _commitHistory();
  }

  // ── Deshacer y rehacer ────────────────────────────────────────────────────

  /// Foto de las capas tal como están ahora.
  Map<PlanLayer, String> _snapshot() => {
    for (final layer in PlanLayer.values)
      if (_hasLayer(layer)) layer: FloorPlanJson.encode(_layerElements(layer)),
  };

  bool _sameSnapshot(Map<PlanLayer, String> a, Map<PlanLayer, String> b) =>
      a.length == b.length && a.keys.every((k) => a[k] == b[k]);

  /// Tras guardar un cambio, apila el estado anterior para poder deshacerlo.
  void _commitHistory() {
    final current = _snapshot();
    if (_sameSnapshot(current, _lastSaved)) return;
    _undoStack.add(_lastSaved);
    if (_undoStack.length > 60) _undoStack.removeAt(0);
    _redoStack.clear();
    _lastSaved = current;
    if (mounted) setState(() {});
  }

  Future<void> _restore(Map<PlanLayer, String> snapshot) async {
    final restored = <PlanElement>[];
    for (final layer in PlanLayer.values) {
      if (!_hasLayer(layer)) continue;
      // Una capa que no existía en la foto se queda como está.
      final json = snapshot[layer];
      final list = json == null
          ? _layerElements(layer)
          : FloorPlanJson.decode(json);
      for (final el in list) {
        el.layer = layer;
        el.id = layer == PlanLayer.shot ? 0 : --_tempId;
        restored.add(el);
      }
    }
    setState(() {
      _elements
        ..clear()
        ..addAll(restored);
      _selected = null;
      _selectedPathIndex = null;
      _multi.clear();
    });
    for (final layer in PlanLayer.values) {
      await _saveLayer(layer);
    }
    _lastSaved = _snapshot();
    if (mounted) setState(() {});
  }

  Future<void> _undo() async {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_snapshot());
    await _restore(_undoStack.removeLast());
  }

  Future<void> _redo() async {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_snapshot());
    await _restore(_redoStack.removeLast());
  }

  // ── Selección ─────────────────────────────────────────────────────────────

  /// Lo seleccionado: varios con Mayús, o el único elemento activo.
  List<PlanElement> get _selection =>
      _multi.isNotEmpty ? _multi.toList() : [if (_selected != null) _selected!];

  void _select(PlanElement? el, {bool add = false}) {
    setState(() {
      _selectedPathIndex = null;
      if (add && el != null) {
        if (_multi.isEmpty && _selected != null) _multi.add(_selected!);
        if (!_multi.remove(el)) _multi.add(el);
        _selected = _multi.isEmpty ? null : _multi.last;
        if (_multi.length < 2) _multi.clear();
      } else {
        _multi.clear();
        _selected = el;
      }
    });
  }

  /// Guarda varios elementos, cada uno en su capa.
  Future<void> _persistMany(Iterable<PlanElement> elements) async {
    final layers = <PlanLayer>{};
    for (final el in elements) {
      if (el.layer == PlanLayer.shot) {
        await _persistElement(el, commit: false);
      } else {
        layers.add(el.layer);
      }
    }
    for (final layer in layers) {
      await _saveLayer(layer);
    }
    _commitHistory();
  }

  /// Copia lo seleccionado, un poco desplazado y en su misma capa.
  Future<void> _duplicateSelection() async {
    final originals = _selection;
    if (originals.isEmpty) return;
    final copies = <PlanElement>[];
    for (final original in originals) {
      final copy = FloorPlanJson.decode(
        FloorPlanJson.encode([original]),
      ).single;
      copy
        ..layer = original.layer
        ..id = original.layer == PlanLayer.shot ? 0 : --_tempId
        ..position = original.position + const Offset(30, 30)
        ..pathPoints = [
          for (final p in original.pathPoints) p + const Offset(30, 30),
        ];
      copies.add(copy);
    }
    setState(() {
      _elements.addAll(copies);
      _multi
        ..clear()
        ..addAll(copies.length > 1 ? copies : const []);
      _selected = copies.last;
      _selectedPathIndex = null;
    });
    await _persistMany(copies);
  }

  // ── Imán ──────────────────────────────────────────────────────────────────

  static const double _gridStep = 10;

  Offset _snapToGrid(Offset p) => _snap
      ? Offset(
          (p.dx / _gridStep).round() * _gridStep,
          (p.dy / _gridStep).round() * _gridStep,
        )
      : p;

  /// Punto para un tramo: se pega a los extremos de otros tramos y, si no
  /// hay ninguno cerca, a la rejilla.
  Offset _snapSegmentPoint(Offset p, {PlanElement? except}) {
    if (_snap) {
      final reach = 14 / _scale;
      for (final el in _visibleElements) {
        if (el == except || !PlanSegment.isSegment(el)) continue;
        for (final corner in [PlanSegment.start(el), PlanSegment.end(el)]) {
          if ((corner - p).distance <= reach) return corner;
        }
      }
    }
    return _snapToGrid(p);
  }

  void _setTool(PlanTool tool) {
    setState(() {
      _tool = tool;
      _segmentStart = null;
      _segmentHover = null;
      _measure = null;
      if (tool != PlanTool.select) {
        _selected = null;
        _selectedPathIndex = null;
        _multi.clear();
      }
    });
  }

  String get _segmentKind => switch (_tool) {
    PlanTool.street => PlanSegment.kindStreet,
    PlanTool.relief => PlanSegment.kindRelief,
    _ => PlanSegment.kindWall,
  };

  Future<void> _addSegment(Offset from, Offset to) async {
    if ((to - from).distance < 8) return;
    await _addElement(
      PlanSegment.create(start: from, end: to, kind: _segmentKind),
      keepPosition: true,
      select: false,
    );
  }

  // ── Ajuste de la zona del set ─────────────────────────────────────────────

  void _startZoneEdit() {
    final zone = _setZone;
    if (zone == null) return;
    setState(() {
      _zoneEditRect = zone;
      _selected = null;
      _multi.clear();
      _tool = PlanTool.select;
    });
  }

  Future<void> _finishZoneEdit() async {
    final rect = _zoneEditRect;
    setState(() => _zoneEditRect = null);
    if (rect != null && rect != _setZone) await _saveZone(rect);
  }

  static List<Offset> _corners(Rect r) => [
    r.topLeft,
    r.topRight,
    r.bottomRight,
    r.bottomLeft,
  ];

  Future<void> _addElement(
    PlanElement el, {
    bool keepPosition = false,
    bool select = true,
  }) async {
    final layer = await _layerForNew(el.type);
    if (!mounted) return;
    el.layer = layer;
    if (layer != PlanLayer.shot) el.id = --_tempId;
    if (!keepPosition) {
      // Lo nuevo aparece en lo que se está viendo.
      final same = _elements.where((e) => e.type == el.type).length;
      el.position = _snapToGrid(
        _viewCenter + Offset(same % 5 * 36.0, same % 5 * 24.0),
      );
    }
    // Una puerta o una ventana nace enganchada a la pared más cercana.
    if (PlanOpening.isOpening(el)) {
      PlanOpening.snapToWall(el, _visibleElements);
    }
    _hiddenLayers.remove(layer);
    setState(() => _elements.add(el));
    await _persistElement(el);
    if (select && mounted) _select(el);
  }

  Future<void> _addCamera() async {
    final cameras = _elements.where((e) => e.type == ElementType.camera).length;
    final letter = String.fromCharCode(65 + cameras);
    await _addElement(
      PlanElement(
        id: 0,
        type: ElementType.camera,
        position: const Offset(200, 200),
        cameraLetter: letter,
        cameraNumber: cameras + 1,
        stabilization: _shot?.movement ?? 'STEADY',
        lens: _shot?.lens ?? '50mm',
      )..applyProjectGear(_gear),
    );
  }

  /// Color del siguiente actor: uno distinto por cada uno que ya hay.
  Color get _nextActorColor => PlanCast.freeColor([
    for (final c in _knownCast.values) c.color,
    for (final e in _elements)
      if (e.type == ElementType.actor) e.actorColor,
  ]);

  /// Abre las cámaras y los juegos de lentes del proyecto y, al volver,
  /// recoge lo que haya cambiado.
  Future<void> _manageGear() async {
    await PlanProjectGearDialog.show(context, widget.projectId);
    if (!mounted) return;
    final gear = await ProjectGear.load(
      ref.read(databaseProvider),
      widget.projectId,
    );
    if (mounted) setState(() => _gear = gear);
  }

  /// Con una cámara del catálogo enlazada, el cono usa su ancho de sensor.
  Future<void> _syncCameraSensor(PlanElement el) async {
    if (el.type != ElementType.camera) return;
    final id = el.externalMapping.catalogCameraId;
    if (id == null) {
      el.props.remove('sensorWidthMm');
      return;
    }
    final db = ref.read(databaseProvider);
    final camera = await (db.select(
      db.cameras,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (camera != null) el.props['sensorWidthMm'] = camera.sensorWidthMm;
  }

  /// Material de la planta abierta: la luz del esquema y la cámara del plano.
  GearList get _gearList => GearList.from(
    _elements.where(
      (e) => e.layer == PlanLayer.light || e.layer == PlanLayer.shot,
    ),
  );

  /// Tocar una línea de la lista de material selecciona en la planta lo
  /// que suma; tocarla otra vez pasa al siguiente.
  void _pickGearLine(GearLine line) {
    final live = [
      for (final el in line.elements)
        if (_elements.contains(el)) el,
    ];
    if (live.isEmpty) return;
    final at = live.indexOf(_selected ?? live.last);
    _select(live[(at + 1) % live.length]);
  }

  String get _gearTitle => [
    _lightSetup?.name ?? 'Sin esquema de luz',
    if (_shot != null) widget.label,
  ].join(' · ');

  Future<void> _addActor(Color color, {String? name}) async {
    final actorCount = _elements
        .where((e) => e.type == ElementType.actor)
        .length;
    await _addElement(
      PlanElement(
        id: 0,
        type: ElementType.actor,
        position: Offset(150 + actorCount * 60.0, 150),
        label: name ?? 'Actor ${actorCount + 1}',
        actorColor: color,
      ),
    );
  }

  /// Los personajes de esta planta y los del resto del proyecto.
  Map<String, ({String name, Color color})> get _knownCast => {
    ..._cast,
    for (final el in _elements)
      if (el.type == ElementType.actor && PlanCast.isNamed(el.label))
        PlanCast.key(el.label): (name: el.label!.trim(), color: el.actorColor),
  };

  /// Un personaje cambia de color: en esta planta y en todas las demás.
  Future<void> _recolourCast(PlanElement actor, Color color) async {
    final key = PlanCast.key(actor.label);
    final same = [
      for (final el in _elements)
        if (el.type == ElementType.actor &&
            (identical(el, actor) ||
                (PlanCast.isNamed(actor.label) &&
                    PlanCast.key(el.label) == key)))
          el,
    ];
    setState(() {
      for (final el in same) {
        el.actorColor = color;
      }
    });
    await _persistMany(same);
    if (!PlanCast.isNamed(actor.label)) return;
    final db = ref.read(databaseProvider);
    await PlanCast.recolour(db, widget.projectId, actor.label!, color);
    final cast = await PlanCast.load(db, widget.projectId);
    if (mounted) setState(() => _cast = cast);
  }

  Future<void> _addLight(LightType type) async {
    final count = _elements.where((e) => e.type == ElementType.light).length;
    final el = PlanElement(
      id: 0,
      type: ElementType.light,
      position: Offset(300 + count * 40.0, 150),
      lightType: type,
      label: type.label,
    );
    final catalog = await ref.read(databaseProvider).watchAllLights().first;
    final cameras = await ref.read(databaseProvider).watchAllCameras().first;
    final lenses = await ref.read(databaseProvider).watchAllLenses().first;
    LukaLightMapping.applyDefaults(
      el,
      catalog: catalog,
      cameras: cameras,
      lenses: lenses,
    );
    await _addElement(el);
  }

  /// Un fotómetro mide la luz del esquema: se guarda con él.
  Future<void> _addMeter() async {
    await _ensureLightSetup();
    final el = PlanElement(
      id: 0,
      type: ElementType.prop,
      position: Offset.zero,
      label: PropType.meter.dbValue,
    );
    if (!mounted) return;
    el
      ..layer = PlanLayer.light
      ..id = --_tempId
      ..position = _snapToGrid(_viewCenter);
    _hiddenLayers.remove(PlanLayer.light);
    setState(() => _elements.add(el));
    await _persistElement(el);
    if (mounted) _select(el);
  }

  Future<void> _addProp(PropType type) async {
    final count = _elements.where((e) => e.type == ElementType.prop).length;
    final el = PlanElement(
      id: 0,
      type: ElementType.prop,
      position: Offset(250 + count * 50.0, 250),
      label: type.dbValue,
    );
    PlanElementCompat.applyAutoMapping(el);
    await _addElement(el);
  }

  Future<void> _addArchitecture(ArchitectureType type) async {
    final count = _elements.where((e) => e.type == ElementType.wall).length;
    final el = PlanElement(
      id: 0,
      type: ElementType.wall,
      position: Offset(200, 300 + count * 50.0),
      label: type.dbValue,
    );
    PlanElementCompat.applyAutoMapping(el);
    await _addElement(el);
  }

  Future<void> _deleteSelected() async {
    final doomed = _selection;
    if (doomed.isEmpty) return;
    final db = ref.read(databaseProvider);
    final layers = <PlanLayer>{};
    for (final el in doomed) {
      if (el.layer == PlanLayer.shot) {
        if (el.id > 0) await db.deleteCameraPlanElement(el.id);
      } else {
        layers.add(el.layer);
      }
    }
    setState(() {
      _elements.removeWhere(doomed.contains);
      _selected = null;
      _selectedPathIndex = null;
      _multi.clear();
    });
    for (final layer in layers) {
      await _saveLayer(layer);
    }
    await db.touchProjectContent(widget.projectId);
    _commitHistory();
  }

  Offset _toCanvasCoords(Offset localPos) {
    return (localPos - _canvasOffset) / _scale;
  }

  PlanElement? _elementAt(Offset canvasPos) {
    final slack = 1 / math.min(1.0, _scale);
    for (final el in _visibleElements.reversed) {
      if (PlanSegment.isSegment(el)) continue;
      if ((el.position - canvasPos).distance < 28 * slack) return el;
    }
    // Los tramos, después: lo que está encima de una pared se coge antes.
    for (final el in _visibleElements.reversed) {
      if (!PlanSegment.isSegment(el)) continue;
      final reach = PlanSegment.kind(el) == PlanSegment.kindStreet ? 30 : 10;
      if (PlanSegment.distanceTo(el, canvasPos) < reach * slack) return el;
    }
    return null;
  }

  /// Asa del tramo seleccionado bajo el cursor: 0 inicio, 1 final, 2 curva.
  int? _segmentHandleAt(Offset canvasPos) {
    final el = _selected;
    if (el == null || !PlanSegment.isSegment(el) || _multi.isNotEmpty) {
      return null;
    }
    final reach = 12 / _scale;
    if ((PlanSegment.start(el) - canvasPos).distance < reach) return 0;
    if ((PlanSegment.end(el) - canvasPos).distance < reach) return 1;
    if ((PlanSegment.midpoint(el) - canvasPos).distance < reach) return 2;
    return null;
  }

  /// La marca seleccionada del elemento, si la hay: se gira ella y no el
  /// elemento.
  int? _markOf(PlanElement el) {
    final index = _selectedPathIndex;
    return index != null &&
            PlanMarks.supports(el) &&
            index >= 0 &&
            index < el.pathPoints.length
        ? index
        : null;
  }

  /// El toque cae donde se gira el seleccionado: en su asa o en la corona
  /// que lo rodea (si ahí no hay otro elemento que coger).
  bool _hitRotationHandle(Offset canvasPos) {
    final el = _selected;
    if (el == null || PlanSegment.isSegment(el) || _multi.length > 1) {
      return false;
    }
    if (CameraPlanPainter.isAttachedOpening(el, _visibleElements)) {
      return false;
    }
    final mark = _markOf(el);
    final centre = mark == null ? el.position : el.pathPoints[mark];
    final rotation = mark == null
        ? el.rotation
        : PlanMarks.rotationAt(el, mark);
    final handle = CameraPlanPainter.rotationHandleAt(centre, rotation, _scale);
    if ((canvasPos - handle).distance < 18 / _scale) return true;
    final distance = (canvasPos - centre).distance;
    final inner = 28 / math.min(1.0, _scale);
    final outer =
        CameraPlanPainter.rotationHandleDistance(_scale) + 10 / _scale;
    if (distance < inner || distance > outer) return false;
    final under = _elementAt(canvasPos);
    return under == null || (mark == null && identical(under, el));
  }

  void _updateRotation(PlanElement el, Offset canvasPos) {
    final mark = _markOf(el);
    final centre = mark == null ? el.position : el.pathPoints[mark];
    final angle = math.atan2(
      canvasPos.dy - centre.dy,
      canvasPos.dx - centre.dx,
    );
    var degrees = ((angle * 180 / math.pi) + 90) % 360;
    // Con Mayús, de 15 en 15 grados.
    if (HardwareKeyboard.instance.isShiftPressed) {
      degrees = (degrees / 15).round() * 15.0;
    }
    degrees = (degrees % 360 + 360) % 360;
    if (mark == null) {
      el.rotation = degrees;
    } else {
      PlanMarks.setRotation(el, mark, degrees);
    }
  }

  Future<void> _addPathPointAt(Offset canvasPos) async {
    final cam = _selected;
    if (cam == null || !PlanMarks.supports(cam)) return;
    setState(() {
      PlanMarks.add(cam, canvasPos);
      _selectedPathIndex = cam.pathPoints.length - 1;
    });
    await _persistElement(cam);
  }

  /// Nueva posición, un paso más allá de la última, hacia donde mira.
  Future<void> _addPathPointAhead() async {
    final cam = _selected;
    if (cam == null || !PlanMarks.supports(cam)) return;
    final last = cam.pathPoints.length - 1;
    final rad =
        (last < 0 ? cam.rotation : PlanMarks.rotationAt(cam, last)) *
        math.pi /
        180;
    final forward = Offset(math.sin(rad), -math.cos(rad));
    final origin = cam.pathPoints.isEmpty ? cam.position : cam.pathPoints.last;
    // Una cámara avanza; un actor suele cruzar el cuadro.
    final step = cam.type == ElementType.camera
        ? forward * 80
        : Offset(-forward.dy, forward.dx) * 80;
    await _addPathPointAt(origin + step);
  }

  Future<void> _deleteSelectedPathPoint() async {
    final cam = _selected;
    final index = _selectedPathIndex;
    if (cam == null ||
        !PlanMarks.supports(cam) ||
        index == null ||
        index < 0 ||
        index >= cam.pathPoints.length) {
      return;
    }
    setState(() {
      PlanMarks.removeAt(cam, index);
      _selectedPathIndex = null;
    });
    await _persistElement(cam);
  }

  Future<void> _clearCameraPath() async {
    final cam = _selected;
    if (cam == null || !PlanMarks.supports(cam)) return;
    setState(() {
      PlanMarks.clear(cam);
      _selectedPathIndex = null;
    });
    await _persistElement(cam);
  }

  int? _pathPointIndexAt(PlanElement camera, Offset canvasPos) =>
      CameraPlanPainter.pathPointAt(camera, canvasPos, scale: _scale);

  void _onPanStart(DragStartDetails d) {
    _canvasFocus.requestFocus();
    final canvasPos = _toCanvasCoords(d.localPosition);
    if (_zoneMode) {
      setState(() {
        _zoneStart = canvasPos;
        _zoneDraft = Rect.fromPoints(canvasPos, canvasPos);
      });
      return;
    }
    final zoneEdit = _zoneEditRect;
    if (zoneEdit != null) {
      final reach = 16 / _scale;
      final corners = _corners(zoneEdit);
      _zoneGrip = null;
      for (var i = 0; i < corners.length; i++) {
        if ((corners[i] - canvasPos).distance < reach) _zoneGrip = i;
      }
      if (_zoneGrip == null && zoneEdit.contains(canvasPos)) _zoneGrip = -1;
      return;
    }
    if (_tool.drawsSegment) {
      setState(() {
        _segmentStart ??= _snapSegmentPoint(canvasPos);
        _segmentHover = _segmentStart;
      });
      return;
    }
    if (_tool == PlanTool.measure) {
      setState(() => _measure = (from: canvasPos, to: canvasPos));
      return;
    }
    for (final el in _elements.reversed) {
      if (!PlanMarks.supports(el)) continue;
      final pathIdx = _pathPointIndexAt(el, canvasPos);
      if (pathIdx != null) {
        _isDraggingPathPoint = true;
        _isRotating = false;
        setState(() {
          _selected = el;
          _selectedPathIndex = pathIdx;
        });
        return;
      }
    }
    _segmentHandle = _segmentHandleAt(canvasPos);
    if (_segmentHandle != null) return;
    if (_selected != null && _hitRotationHandle(canvasPos)) {
      setState(() => _isRotating = true);
      _isDraggingPathPoint = false;
      return;
    }
    _isRotating = false;
    _isDraggingPathPoint = false;
    final tapped = _elementAt(canvasPos);
    _dragging = tapped;
    if (tapped != null && !_multi.contains(tapped)) _select(tapped);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final canvasPos = _toCanvasCoords(d.localPosition);
    if (_zoneMode) {
      final start = _zoneStart;
      if (start == null) return;
      setState(() => _zoneDraft = Rect.fromPoints(start, canvasPos));
      return;
    }
    final zoneEdit = _zoneEditRect;
    if (zoneEdit != null) {
      final grip = _zoneGrip;
      if (grip == null) {
        setState(() => _canvasOffset += d.delta);
        return;
      }
      final delta = d.delta / _scale;
      setState(() {
        if (grip == -1) {
          _zoneEditRect = zoneEdit.shift(delta);
        } else {
          // La esquina contraria se queda fija.
          final fixed = _corners(zoneEdit)[(grip + 2) % 4];
          final next = Rect.fromPoints(fixed, _snapToGrid(canvasPos));
          if (next.width > 40 && next.height > 40) {
            _zoneEditRect = next;
            // Tras cruzar la esquina fija, se sigue cogiendo la misma mano.
            _zoneGrip = _corners(next).indexWhere(
              (c) =>
                  (c - fixed).distance > 1 &&
                  c.dx != fixed.dx &&
                  c.dy != fixed.dy,
            );
          }
        }
      });
      return;
    }
    if (_tool.drawsSegment) {
      setState(() => _segmentHover = _snapSegmentPoint(canvasPos));
      return;
    }
    if (_tool == PlanTool.measure) {
      final m = _measure;
      if (m != null) setState(() => _measure = (from: m.from, to: canvasPos));
      return;
    }

    final delta = d.delta / _scale;
    final selected = _selected;
    final handle = _segmentHandle;
    if (selected != null && handle != null) {
      _dragDirty = true;
      setState(() {
        switch (handle) {
          case 0:
            PlanSegment.setStart(
              selected,
              _snapSegmentPoint(canvasPos, except: selected),
            );
          case 1:
            PlanSegment.setEnd(
              selected,
              _snapSegmentPoint(canvasPos, except: selected),
            );
          default:
            PlanSegment.bendThrough(selected, canvasPos);
        }
      });
      return;
    }
    if (selected != null &&
        (_isDraggingPathPoint || _isRotating || _dragging != null)) {
      _dragDirty = true;
    }
    if (selected != null &&
        _isDraggingPathPoint &&
        _selectedPathIndex != null) {
      setState(() => selected.pathPoints[_selectedPathIndex!] += delta);
    } else if (selected != null && _isRotating) {
      setState(() => _updateRotation(selected, canvasPos));
    } else if (_dragging != null) {
      setState(() {
        for (final el in _multi.contains(_dragging) ? _multi : {_dragging!}) {
          el.position += delta;
          el.pathPoints = [for (final p in el.pathPoints) p + delta];
        }
      });
    } else {
      setState(() => _canvasOffset += d.delta);
    }
  }

  Future<void> _onPanEnd(DragEndDetails d) async {
    if (_zoneMode) {
      final draft = _zoneDraft;
      setState(() {
        _zoneMode = false;
        _zoneStart = null;
        _zoneDraft = null;
      });
      if (draft != null && draft.width > 40 && draft.height > 40) {
        await _saveZone(draft);
      }
      return;
    }
    if (_zoneEditRect != null) {
      _zoneGrip = null;
      return;
    }
    if (_tool.drawsSegment) {
      // Arrastrar dibuja un tramo; tocar punto a punto los encadena.
      final from = _segmentStart;
      final to = _segmentHover;
      setState(() {
        _segmentStart = null;
        _segmentHover = null;
      });
      if (from != null && to != null) await _addSegment(from, to);
      return;
    }
    if (_tool == PlanTool.measure) return;

    // Se guarda siempre que algo se haya movido, se suelte como se suelte.
    final moved = _dragDirty;
    final dragged = _dragging;
    final wasHandle = _segmentHandle != null;
    _dragDirty = false;
    _dragging = null;
    _segmentHandle = null;
    if (_isRotating) setState(() => _isRotating = false);
    _isDraggingPathPoint = false;
    if (!moved || _selected == null) return;

    if (dragged != null && !wasHandle) {
      final group = _multi.contains(dragged) ? _multi.toList() : [dragged];
      // El imán coloca lo que se ha movido sobre la rejilla.
      final anchor = group.first;
      final shift = _snapToGrid(anchor.position) - anchor.position;
      setState(() {
        for (final el in group) {
          // Puertas y ventanas se enganchan a la pared sobre la que caen.
          if (PlanOpening.isOpening(el) &&
              PlanOpening.snapToWall(el, _visibleElements)) {
            continue;
          }
          el.position += shift;
          el.pathPoints = [for (final p in el.pathPoints) p + shift];
        }
      });
      await _persistMany(group);
    } else {
      await _persistElement(_selected!);
    }
  }

  void _onTapCanvas(TapDownDetails d) {
    _canvasFocus.requestFocus();
    if (_zoneMode || _zoneEditRect != null) return;
    final canvasPos = _toCanvasCoords(d.localPosition);
    if (_tool.drawsSegment) {
      final point = _snapSegmentPoint(canvasPos);
      final from = _segmentStart;
      if (from == null) {
        setState(() {
          _segmentStart = point;
          _segmentHover = point;
        });
      } else {
        // Encadena: el final de este tramo es el inicio del siguiente.
        setState(() {
          _segmentStart = point;
          _segmentHover = point;
        });
        _addSegment(from, point);
      }
      return;
    }
    if (_tool == PlanTool.measure) {
      setState(() => _measure = null);
      return;
    }
    for (final el in _elements.reversed) {
      if (!PlanMarks.supports(el)) continue;
      final pathIdx = _pathPointIndexAt(el, canvasPos);
      if (pathIdx != null) {
        setState(() {
          _selected = el;
          _selectedPathIndex = pathIdx;
        });
        return;
      }
    }
    if (_segmentHandleAt(canvasPos) != null) return;
    // Pulsar el asa de giro no es tocar en vacío: no deselecciona.
    if (_hitRotationHandle(canvasPos)) return;
    final hit = _elementAt(canvasPos);
    if (hit == null && _showOtherCameras) {
      // Tocar la cámara de otro plano abre ese plano.
      for (final ghost in _otherCameras) {
        if ((ghost.position - canvasPos).distance < 28) {
          final target = _otherCameraShot[ghost];
          if (target != null) {
            _openTarget(target);
            return;
          }
        }
      }
    }
    _select(hit, add: HardwareKeyboard.instance.isShiftPressed);
    // Tocar el suelo de un recinto cerrado abre sus propiedades.
    final room = hit == null ? _lightScene.roomAt(canvasPos) : null;
    setState(() => _selectedRoom = room == null ? null : canvasPos);
  }

  LightScene get _lightScene => LightScene.from(
    _visibleElements,
    metersPerUnit: _metersPerUnit,
    ambient: _lightSetup == null ? null : _ambient,
  );

  /// Guarda lo que se ha decidido de un recinto, con el esquema de luz.
  Future<void> _saveRoom(RoomSetting setting) async {
    final room = _lightScene.roomAt(setting.point);
    final setup = await _ensureLightSetup();
    if (!mounted) return;
    final next = _ambient.copyWith(
      rooms: [
        for (final r in _ambient.rooms)
          if (room == null || !room.room.contains(r.point)) r,
        setting,
      ],
    );
    setState(() => _ambient = next);
    await _repo.saveAmbient(setup.id, next);
  }

  /// Abre otra planta: dentro de la pantalla de trabajo, sin apilar.
  void _openTarget(PlanTarget target) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(target);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CameraPlanEditor.shot(
          projectId: widget.projectId,
          shotId: target.id,
          shotLabel: target.label,
        ),
      ),
    );
  }

  void _onDoubleTapCanvas(TapDownDetails d) {
    if (_tool.drawsSegment) {
      // Doble toque: termina la cadena de tramos.
      setState(() {
        _segmentStart = null;
        _segmentHover = null;
      });
      return;
    }
    final picked = _selected;
    if (picked == null || !PlanMarks.supports(picked)) return;
    final canvasPos = _toCanvasCoords(d.localPosition);
    if (_elementAt(canvasPos) != null) return;
    if (CameraPlanPainter.pathPointAt(_selected!, canvasPos, scale: _scale) !=
        null) {
      return;
    }
    _addPathPointAt(canvasPos);
  }

  /// Atajos del lienzo. Solo valen con el foco en él, para no pisar lo que
  /// se escribe en los paneles.
  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
        _redo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
        _redo,
    const SingleActivator(LogicalKeyboardKey.keyD, meta: true):
        _duplicateSelection,
    const SingleActivator(LogicalKeyboardKey.keyD, control: true):
        _duplicateSelection,
    const SingleActivator(LogicalKeyboardKey.delete): _deleteSelected,
    const SingleActivator(LogicalKeyboardKey.backspace): _deleteSelected,
    const SingleActivator(LogicalKeyboardKey.escape): _cancel,
    const SingleActivator(LogicalKeyboardKey.keyV): () =>
        _setTool(PlanTool.select),
    const SingleActivator(LogicalKeyboardKey.keyW): () =>
        _setTool(PlanTool.wall),
    const SingleActivator(LogicalKeyboardKey.keyM): () =>
        _setTool(PlanTool.measure),
  };

  /// Esc: suelta lo que se esté haciendo.
  void _cancel() {
    if (_zoneEditRect != null) {
      setState(() => _zoneEditRect = null);
    } else if (_segmentStart != null || _measure != null) {
      setState(() {
        _segmentStart = null;
        _segmentHover = null;
        _measure = null;
      });
    } else if (_tool != PlanTool.select) {
      _setTool(PlanTool.select);
    } else {
      _select(null);
    }
  }

  void _zoomBy(double delta) {
    setState(() => _scale = (_scale + delta).clamp(0.2, 2.5));
  }

  void _showAddMenu() {
    final palette = context.palette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AddElementSheet(
        palette: palette,
        wallsToEnvironment: _linkedSet != null && _linkedSite != null
            ? _wallsToEnvironment
            : null,
        onWallsToEnvironment: (v) => _wallsToEnvironment = v,
        onAddCamera: () {
          Navigator.pop(ctx);
          _addCamera();
        },
        onAddActor: (color) {
          Navigator.pop(ctx);
          _addActor(color);
        },
        onAddLight: (type) {
          Navigator.pop(ctx);
          _addLight(type);
        },
        onAddProp: (type) {
          Navigator.pop(ctx);
          _addProp(type);
        },
        onAddArchitecture: (type) {
          Navigator.pop(ctx);
          _addArchitecture(type);
        },
      ),
    );
  }

  void _toggleLayer(PlanLayer layer) {
    setState(() {
      if (!_hiddenLayers.remove(layer)) _hiddenLayers.add(layer);
      if (_selected != null && _hiddenLayers.contains(_selected!.layer)) {
        _selected = null;
        _selectedPathIndex = null;
      }
    });
  }

  /// Barra de capas: qué se ve, qué esquema de luz y qué plano.
  Widget _buildLayerBar(AppPalette palette) {
    Widget chip(
      PlanLayer layer,
      String label,
      Color color, {
      VoidCallback? onMenu,
    }) => _LayerChip(
      palette: palette,
      label: label,
      color: color,
      visible: !_hiddenLayers.contains(layer),
      onToggle: () => _toggleLayer(layer),
      onMenu: onMenu,
    );

    return Material(
      color: palette.surface,
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          children: [
            if (_linkedSite != null)
              chip(PlanLayer.environment, 'Entorno', palette.textSecondary),
            if (_linkedSet != null) chip(PlanLayer.set, 'Set', _sceneColor),
            chip(
              PlanLayer.light,
              'Luz: ${_lightSetup?.name ?? 'sin esquema'}',
              _setupColor,
              onMenu: _chooseLightSetup,
            ),
            if (_navTargets.isNotEmpty)
              chip(
                PlanLayer.shot,
                'Cámara: ${_shot != null ? widget.label : 'ningún plano'}',
                palette.accent,
                onMenu: _showSceneNavigator,
              ),
            IconButton(
              tooltip: 'Ambiente: sol, cielo y rebote de paredes',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                _ambient.day
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_outlined,
                size: 18,
                color: palette.textSecondary,
              ),
              onPressed: _editAmbient,
            ),
            if (_otherCameras.isNotEmpty)
              IconButton(
                tooltip: _showOtherCameras
                    ? 'Ocultar las cámaras de los otros planos'
                    : 'Ver las cámaras de los otros planos',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.switch_video_outlined,
                  size: 18,
                  color: _showOtherCameras
                      ? palette.accent
                      : palette.textTertiary,
                ),
                onPressed: () =>
                    setState(() => _showOtherCameras = !_showOtherCameras),
              ),
            if (_linkedSet != null && _linkedSite != null && _setZone != null)
              PopupMenuButton<String>(
                tooltip: 'Zona del set',
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.crop_free,
                  size: 18,
                  color: palette.textSecondary,
                ),
                onSelected: (action) {
                  switch (action) {
                    case 'fit':
                      _fitTo(_setZone!);
                    case 'adjust':
                      _startZoneEdit();
                    case 'redraw':
                      setState(() {
                        _zoneMode = true;
                        _selected = null;
                      });
                    case 'clear':
                      _clearZone();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'fit', child: Text('Encuadrar el set')),
                  PopupMenuItem(
                    value: 'adjust',
                    child: Text('Mover o redimensionar la zona'),
                  ),
                  PopupMenuItem(
                    value: 'redraw',
                    child: Text('Volver a marcar la zona'),
                  ),
                  PopupMenuItem(value: 'clear', child: Text('Quitar la zona')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Con sitio de sobra, la paleta va fija a la izquierda y el panel de
  /// material y propiedades a la derecha.
  bool _wide = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    _wide = MediaQuery.sizeOf(context).width >= 1100;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: _isShotMode && _scene != null
            ? Row(
                children: [
                  SceneNumberBadge(
                    sceneNumber: _scene!.number,
                    color: _sceneColor,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: AppTypography.titleMedium(palette),
                        ),
                        if (_scene!.name.isNotEmpty)
                          Text(
                            _scene!.name,
                            style: AppTypography.caption(palette),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      widget.scope.title,
                      if (widget.scope == FloorPlanScope.lightSetup)
                        _linkedSet?.locationName ??
                            _linkedSite?.name ??
                            'Planta libre',
                    ].join(' · '),
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(color: palette.accent),
                  ),
                  Text(widget.label, style: AppTypography.titleMedium(palette)),
                ],
              ),
        actions: [
          IconButton(
            tooltip: _annotationMode
                ? 'Volver a editar elementos'
                : 'Anotar con Apple Pencil',
            icon: Icon(
              _annotationMode ? Icons.edit_off_outlined : Icons.draw_outlined,
              color: _annotationMode ? palette.accent : palette.textSecondary,
            ),
            onPressed: () => setState(() {
              _annotationMode = !_annotationMode;
              _selected = null;
              _selectedPathIndex = null;
            }),
          ),
          IconButton(
            tooltip: 'Deshacer',
            icon: const Icon(Icons.undo),
            color: palette.textSecondary,
            onPressed: _undoStack.isEmpty ? null : _undo,
          ),
          IconButton(
            tooltip: 'Rehacer',
            icon: const Icon(Icons.redo),
            color: palette.textSecondary,
            onPressed: _redoStack.isEmpty ? null : _redo,
          ),
          IconButton(
            tooltip: _snap ? 'Imán activado' : 'Imán desactivado',
            icon: Icon(
              Icons.grid_goldenratio,
              color: _snap ? palette.accent : palette.textTertiary,
            ),
            onPressed: () => setState(() => _snap = !_snap),
          ),
          PopupMenuButton<LightView>(
            tooltip: 'Luz: ${_lightView.label.toLowerCase()}',
            icon: Icon(
              _lightView == LightView.camera
                  ? Icons.camera_outlined
                  : Icons.visibility_outlined,
              color: palette.textSecondary,
            ),
            initialValue: _lightView,
            onSelected: (view) => setState(() => _lightView = view),
            itemBuilder: (_) => [
              for (final view in LightView.values)
                CheckedPopupMenuItem<LightView>(
                  value: view,
                  checked: view == _lightView,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(view.label),
                    subtitle: Text(switch (view) {
                      LightView.camera =>
                        'Como la ve la cámara a ${formatStop(_targetStop)}: '
                            'lo que sobra se quema y lo que falta se apaga',
                      LightView.all =>
                        'Lo más iluminado al máximo, para ver hasta dónde '
                            'llega cada luz',
                    }),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Alzado y perfil · exportar DXF y MVR',
            icon: Icon(
              Icons.view_in_ar_outlined,
              color: palette.textSecondary,
            ),
            onPressed: () => showPlanElevation(
              context,
              elements: _visibleElements,
              metersPerUnit: _metersPerUnit,
              name: _linkedSet?.locationName ?? _linkedSite?.name ?? 'planta',
            ),
          ),
          IconButton(
            tooltip: _gearLabels
                ? 'Quitar rótulos de equipo'
                : 'Rótulos de equipo: unidad, vatios, lúmenes y leyenda',
            icon: Icon(
              Icons.sell_outlined,
              color: _gearLabels ? palette.accent : palette.textSecondary,
            ),
            onPressed: () => setState(() => _gearLabels = !_gearLabels),
          ),
          IconButton(
            tooltip: _exposureMap
                ? 'Volver a los haces de luz'
                : 'Mapa de exposición',
            icon: Icon(
              Icons.gradient,
              color: _exposureMap ? palette.accent : palette.textSecondary,
            ),
            onPressed: () => setState(() => _exposureMap = !_exposureMap),
          ),
          IconButton(
            tooltip: _showReadings
                ? 'Ocultar lecturas de los actores'
                : 'Mostrar lecturas de los actores',
            icon: Icon(
              Icons.speed_outlined,
              color: _showReadings ? palette.accent : palette.textTertiary,
            ),
            onPressed: () => setState(() => _showReadings = !_showReadings),
          ),
          IconButton(
            tooltip: 'Guardar',
            icon: Icon(Icons.save_outlined, color: palette.textSecondary),
            onPressed: _saveCurrentPlan,
          ),
          IconButton(
            tooltip: 'Alejar',
            icon: Icon(Icons.remove, color: palette.textSecondary),
            onPressed: () => _zoomBy(-0.1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              '${(_scale * 100).round()}%',
              style: AppTypography.caption(palette),
            ),
          ),
          IconButton(
            tooltip: 'Acercar',
            icon: Icon(Icons.add, color: palette.textSecondary),
            onPressed: () => _zoomBy(0.1),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_wide && !_annotationMode)
                  PlanPalette(
                    tool: _tool,
                    onTool: _setTool,
                    onAddCamera: _addCamera,
                    onAddActor: () => _addActor(_nextActorColor),
                    cast: [
                      for (final c in _knownCast.values) (c.name, c.color),
                    ],
                    onAddCast: (name, color) => _addActor(color, name: name),
                    onAddLight: _addLight,
                    onAddProp: _addProp,
                    onAddMeter: _addMeter,
                    projectLights: _gear.lights,
                    onAddCatalogLight: _addCatalogLight,
                    onQuickAddLight: _quickAddLight,
                    catalogLights: _gear.catalogLights,
                    onAddArchitecture: _addArchitecture,
                    wallsToEnvironment:
                        _linkedSet != null && _linkedSite != null
                        ? _wallsToEnvironment
                        : null,
                    onWallsToEnvironment: (v) =>
                        setState(() => _wallsToEnvironment = v),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _buildLayerBar(palette),
                      if (_zoneEditRect != null)
                        _Notice(
                          palette: palette,
                          icon: Icons.crop_free,
                          text:
                              'Arrastra las esquinas para cambiar el tamaño '
                              'de la zona, o el interior para moverla.',
                          actionLabel: 'Listo',
                          onAction: _finishZoneEdit,
                        )
                      else if (_tool.drawsSegment)
                        _Notice(
                          palette: palette,
                          icon: _tool.icon,
                          text:
                              '${_tool.label}: toca punto a punto para '
                              'encadenar tramos, o arrastra para uno solo. '
                              'Doble toque o Esc para terminar.',
                          actionLabel: 'Terminar',
                          onAction: () => _setTool(PlanTool.select),
                        )
                      else if (_tool == PlanTool.measure)
                        _Notice(
                          palette: palette,
                          icon: Icons.straighten,
                          text: 'Medir: arrastra entre dos puntos.',
                          actionLabel: 'Terminar',
                          onAction: () => _setTool(PlanTool.select),
                        )
                      else if (_zoneMode)
                        _Notice(
                          palette: palette,
                          icon: Icons.crop_free,
                          text:
                              'Arrastra sobre el plano para marcar la zona de '
                              '«${_linkedSet?.locationName ?? ''}».',
                          actionLabel: 'Cancelar',
                          onAction: () => setState(() {
                            _zoneMode = false;
                            _zoneDraft = null;
                          }),
                        )
                      else if (_misplaced.isNotEmpty)
                        _Notice(
                          palette: palette,
                          icon: Icons.layers_outlined,
                          text:
                              'Hay luces o cámaras guardadas en el entorno o en el '
                              'set. Pásalas a su capa para poder compartirlas.',
                          actionLabel: 'Ordenar capas',
                          onAction: _tidyLayers,
                        )
                      else if (_linkedSet != null &&
                          _linkedSite != null &&
                          _setZone == null)
                        _Notice(
                          palette: palette,
                          icon: Icons.crop_free,
                          text:
                              'Este set aún no tiene zona en el plano de '
                              '«${_linkedSite!.name}».',
                          actionLabel: 'Marcar zona',
                          onAction: () => setState(() {
                            _zoneMode = true;
                            _selected = null;
                          }),
                        ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  _canvasSize = constraints.biggest;
                                  final fit = _pendingFit;
                                  if (fit != null) {
                                    _pendingFit = null;
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted) _fitTo(fit);
                                        });
                                  }
                                  return ClipRect(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        IgnorePointer(
                                          ignoring: _annotationMode,
                                          child: CallbackShortcuts(
                                            bindings: _shortcuts,
                                            child: Focus(
                                              focusNode: _canvasFocus,
                                              autofocus: true,
                                              child: MouseRegion(
                                                cursor: _tool == PlanTool.select
                                                    ? MouseCursor.defer
                                                    : SystemMouseCursors
                                                          .precise,
                                                onHover: (e) {
                                                  if (_tool.drawsSegment &&
                                                      _segmentStart != null) {
                                                    setState(
                                                      () => _segmentHover =
                                                          _snapSegmentPoint(
                                                            _toCanvasCoords(
                                                              e.localPosition,
                                                            ),
                                                          ),
                                                    );
                                                  }
                                                },
                                                child: GestureDetector(
                                                  // El arrastre empieza donde se tocó, no donde se
                                                  // reconoció: si no, las asas pequeñas se escapan
                                                  // en pantalla táctil.
                                                  dragStartBehavior:
                                                      DragStartBehavior.down,
                                                  onPanStart: _onPanStart,
                                                  onPanUpdate: _onPanUpdate,
                                                  onPanEnd: _onPanEnd,
                                                  onTapDown: _onTapCanvas,
                                                  onDoubleTapDown:
                                                      _onDoubleTapCanvas,
                                                  child: CustomPaint(
                                                    size: Size(
                                                      constraints.maxWidth,
                                                      constraints.maxHeight,
                                                    ),
                                                    painter: CameraPlanPainter(
                                                      elements:
                                                          _visibleElements,
                                                      inheritedElements:
                                                          _showOtherCameras
                                                          ? _otherCameras
                                                          : const [],
                                                      ambient:
                                                          _lightSetup == null
                                                          ? null
                                                          : _ambient,
                                                      zones: [
                                                        for (final zone
                                                            in _zones)
                                                          if (zone.active &&
                                                              _zoneEditRect !=
                                                                  null)
                                                            PlanZone(
                                                              rect:
                                                                  _zoneEditRect!,
                                                              color: zone.color,
                                                              label: zone.label,
                                                              active: true,
                                                            )
                                                          else
                                                            zone,
                                                        if (_zoneDraft != null)
                                                          PlanZone(
                                                            rect: _zoneDraft!,
                                                            color: _sceneColor,
                                                            label:
                                                                _linkedSet
                                                                    ?.locationName ??
                                                                '',
                                                            active: true,
                                                          ),
                                                      ],
                                                      alsoSelected: _multi,
                                                      rotating: _isRotating,
                                                      lightMap: _lightMap,
                                                      selectedRoom:
                                                          _selectedRoom,
                                                      segmentPreview:
                                                          _segmentStart !=
                                                                  null &&
                                                              _segmentHover !=
                                                                  null
                                                          ? (
                                                              from:
                                                                  _segmentStart!,
                                                              to: _segmentHover!,
                                                              kind:
                                                                  _segmentKind,
                                                            )
                                                          : null,
                                                      measure: _measure,
                                                      zoneHandles:
                                                          _zoneEditRect,
                                                      metersPerUnit:
                                                          _metersPerUnit,
                                                      exposure: _exposure,
                                                      targetStop: _targetStop,
                                                      showReadings:
                                                          _showReadings,
                                                      exposureMap: _exposureMap,
                                                      lightView: _lightView,
                                                      gearLabels: _gearLabels,
                                                      selectedElement:
                                                          _selected,
                                                      selectedPathIndex:
                                                          _selectedPathIndex,
                                                      scale: _scale,
                                                      offset: _canvasOffset,
                                                      palette: palette,
                                                      backgroundImage:
                                                          _backgroundImage,
                                                      backgroundRect:
                                                          _backgroundRect,
                                                      backgroundOpacity:
                                                          _backgroundOpacity,
                                                    ),
                                                    child: Container(
                                                      color: Colors.transparent,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        IgnorePointer(
                                          ignoring: !_annotationMode,
                                          child: AnnotationCanvas(
                                            controller: _annotationController,
                                            enabled: _annotationMode,
                                            tool: _annotationTool,
                                            color: _annotationColor,
                                            width: _annotationWidth,
                                            viewport: AnnotationViewport(
                                              documentSize:
                                                  _annotationDocumentSize,
                                              offset: _canvasOffset,
                                              scale: _scale,
                                            ),
                                            onChanged: _saveAnnotations,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (_selected != null)
                              _ElementPanel(
                                palette: palette,
                                element: _selected!,
                                scopeNotice: _scopeNotice(_selected!.layer),
                                moveTargets: [
                                  for (final layer in PlanLayer.values)
                                    if (layer != _selected!.layer &&
                                        _hasLayer(layer))
                                      layer,
                                ],
                                onMove: (layer) =>
                                    _moveToLayer(_selected!, layer),
                                selectedPathIndex: _selectedPathIndex,
                                onManageGear: _manageGear,
                                cast: _knownCast,
                                onRecolourCast: (color) =>
                                    _recolourCast(_selected!, color),
                                onAddPathPoint: _addPathPointAhead,
                                onDeletePathPoint: _deleteSelectedPathPoint,
                                onClearPath: _clearCameraPath,
                                onPreview: () => setState(() {}),
                                onUpdate: () async {
                                  final el = _selected!;
                                  await _syncCameraSensor(el);
                                  if (mounted) setState(() {});
                                  await _persistElement(el);
                                },
                                onDelete: _deleteSelected,
                                onDuplicate: _duplicateSelection,
                                selectionCount: _selection.length,
                                metersPerUnit: _metersPerUnit,
                                exposure: _exposure,
                                targetStop: _targetStop,
                                gear: _gear,
                                canOverride:
                                    _shot != null &&
                                    _selected!.layer == PlanLayer.light,
                                onOverride: (own) =>
                                    _setShotOverride(_selected!, own),
                                reading:
                                    _selected!.type == ElementType.actor ||
                                        _selected!.propType == PropType.meter
                                    ? _readingFor(_selected!)
                                    : null,
                                lengthLabel: PlanSegment.isSegment(_selected!)
                                    ? formatMeters(
                                        PlanSegment.length(_selected!),
                                        _metersPerUnit,
                                      )
                                    : null,
                              )
                            else if (_selectedRoom != null &&
                                _lightScene.roomAt(_selectedRoom!) != null)
                              Container(
                                width: 280,
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(color: palette.border),
                                  ),
                                ),
                                child: PlanRoomPanel(
                                  room: _lightScene.roomAt(_selectedRoom!)!,
                                  metersPerUnit: _metersPerUnit,
                                  anchor: _selectedRoom!,
                                  onChanged: _saveRoom,
                                  onClose: () =>
                                      setState(() => _selectedRoom = null),
                                ),
                              )
                            else if (_wide)
                              Container(
                                width: 240,
                                decoration: BoxDecoration(
                                  color: palette.surface,
                                  border: Border(
                                    left: BorderSide(color: palette.border),
                                  ),
                                ),
                                child: PlanGearListPanel(
                                  gear: _gearList,
                                  title: _gearTitle,
                                  onPick: _pickGearLine,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_annotationMode)
                        _PlanAnnotationToolbar(
                          palette: palette,
                          controller: _annotationController,
                          tool: _annotationTool,
                          color: _annotationColor,
                          width: _annotationWidth,
                          onToolChanged: (tool) =>
                              setState(() => _annotationTool = tool),
                          onColorChanged: (color) =>
                              setState(() => _annotationColor = color),
                          onWidthChanged: (width) =>
                              setState(() => _annotationWidth = width),
                        ),
                      if (!_wide)
                        _BottomToolbar(
                          palette: palette,
                          onAdd: _showAddMenu,
                          onSave: _saveCurrentPlan,
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Franja de aviso con una acción.
class _Notice extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  const _Notice({
    required this.palette,
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.accent.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: palette.accent, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: AppTypography.bodyMedium(palette)),
            ),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: AppTypography.label(
                  palette,
                ).copyWith(color: palette.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastilla de una capa: ojo para ocultarla y, si procede, un desplegable.
class _LayerChip extends StatelessWidget {
  final AppPalette palette;
  final String label;
  final Color color;
  final bool visible;
  final VoidCallback onToggle;
  final VoidCallback? onMenu;

  const _LayerChip({
    required this.palette,
    required this.label,
    required this.color,
    required this.visible,
    required this.onToggle,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final ink = visible ? palette.textPrimary : palette.textTertiary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: color.withValues(alpha: visible ? 0.16 : 0.05),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                child: Tooltip(
                  message: visible ? 'Ocultar capa' : 'Mostrar capa',
                  child: Icon(
                    visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 16,
                    color: visible ? color : palette.textTertiary,
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: onMenu ?? onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 6, 10, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTypography.label(palette).copyWith(color: ink),
                    ),
                    if (onMenu != null)
                      Icon(Icons.arrow_drop_down, size: 18, color: ink),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanAnnotationToolbar extends StatelessWidget {
  static const _colors = [
    Color(0xFF007AFF),
    Color(0xFFFF3B30),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFFAF52DE),
    Color(0xFF111111),
  ];

  final AppPalette palette;
  final AnnotationCanvasController controller;
  final AnnotationToolType tool;
  final Color color;
  final double width;
  final ValueChanged<AnnotationToolType> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onWidthChanged;

  const _PlanAnnotationToolbar({
    required this.palette,
    required this.controller,
    required this.tool,
    required this.color,
    required this.width,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onWidthChanged,
  });

  Future<void> _addNote(BuildContext context) async {
    final textController = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir post-it'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Escribe una aclaración…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text.trim()),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (text == null || text.isEmpty) return;
    controller.addNote(
      AnnotationNote(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: text,
        x: 0.36,
        y: 0.34,
        width: 0.28,
        height: 0.18,
        colorArgb: const Color(0xFFFFE082).toARGB32(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surfaceElevated,
      child: SizedBox(
        height: 64,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _annotationToolButton(
                icon: Icons.edit_outlined,
                tooltip: 'Lápiz',
                value: AnnotationToolType.pen,
              ),
              _annotationToolButton(
                icon: Icons.border_color_outlined,
                tooltip: 'Subrayador',
                value: AnnotationToolType.highlighter,
              ),
              _annotationToolButton(
                icon: Icons.north_east,
                tooltip: 'Flecha',
                value: AnnotationToolType.arrow,
              ),
              const VerticalDivider(indent: 12, endIndent: 12),
              for (final choice in _colors)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onColorChanged(choice),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: choice,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: choice == color
                              ? palette.textPrimary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: Slider(
                  value: width,
                  min: 2,
                  max: 24,
                  onChanged: onWidthChanged,
                ),
              ),
              IconButton(
                tooltip: 'Añadir post-it',
                onPressed: () => _addNote(context),
                icon: const Icon(Icons.note_add_outlined),
              ),
              IconButton(
                tooltip: 'Deshacer',
                onPressed: controller.canUndo ? controller.undo : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: 'Rehacer',
                onPressed: controller.canRedo ? controller.redo : null,
                icon: const Icon(Icons.redo),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _annotationToolButton({
    required IconData icon,
    required String tooltip,
    required AnnotationToolType value,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: () => onToolChanged(value),
    color: tool == value ? palette.accent : palette.textSecondary,
    icon: Icon(icon),
  );
}

class _BottomToolbar extends StatelessWidget {
  final AppPalette palette;
  final VoidCallback onAdd;
  final VoidCallback onSave;

  const _BottomToolbar({
    required this.palette,
    required this.onAdd,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarButton(
            palette: palette,
            icon: Icons.add_circle,
            label: 'Añadir',
            highlighted: true,
            onTap: onAdd,
          ),
          _ToolbarButton(
            palette: palette,
            icon: Icons.save_outlined,
            label: 'Guardar',
            onTap: onSave,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  const _ToolbarButton({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? palette.accent : palette.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.caption(
                palette,
              ).copyWith(color: color, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddElementSheet extends StatefulWidget {
  final AppPalette palette;
  final VoidCallback onAddCamera;
  final ValueChanged<Color> onAddActor;
  final ValueChanged<LightType> onAddLight;
  final ValueChanged<PropType> onAddProp;
  final ValueChanged<ArchitectureType> onAddArchitecture;

  /// Dónde van paredes y props: al entorno o al set. `null` si no hay
  /// elección (solo existe una de las dos capas).
  final bool? wallsToEnvironment;
  final ValueChanged<bool>? onWallsToEnvironment;

  const _AddElementSheet({
    this.wallsToEnvironment,
    this.onWallsToEnvironment,
    required this.palette,
    required this.onAddCamera,
    required this.onAddActor,
    required this.onAddLight,
    required this.onAddProp,
    required this.onAddArchitecture,
  });

  @override
  State<_AddElementSheet> createState() => _AddElementSheetState();
}

class _AddElementSheetState extends State<_AddElementSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool? _toEnvironment = widget.wallsToEnvironment;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Añadir elemento',
                    style: AppTypography.titleMedium(palette),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: palette.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (_toEnvironment != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Paredes y props se añaden a',
                        style: AppTypography.caption(palette),
                      ),
                    ),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: false, label: Text('Set')),
                        ButtonSegment(value: true, label: Text('Entorno')),
                      ],
                      selected: {_toEnvironment!},
                      onSelectionChanged: (v) {
                        setState(() => _toEnvironment = v.first);
                        widget.onWallsToEnvironment?.call(v.first);
                      },
                    ),
                  ],
                ),
              ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: palette.accent,
              unselectedLabelColor: palette.textSecondary,
              indicatorColor: palette.accent,
              tabs: const [
                Tab(text: 'Cámara'),
                Tab(text: 'Actores'),
                Tab(text: 'Luces'),
                Tab(text: 'Props'),
                Tab(text: 'Arquitectura'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _CameraTab(palette: palette, onAdd: widget.onAddCamera),
                  _ActorTab(palette: palette, onAdd: widget.onAddActor),
                  _LightTab(palette: palette, onAdd: widget.onAddLight),
                  _PropTab(palette: palette, onAdd: widget.onAddProp),
                  _ArchitectureTab(
                    palette: palette,
                    onAdd: widget.onAddArchitecture,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GridTile extends StatelessWidget {
  final AppPalette palette;
  final Widget child;
  final String label;
  final VoidCallback onTap;

  const _GridTile({
    required this.palette,
    required this.child,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            child,
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.caption(palette),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraTab extends StatelessWidget {
  final AppPalette palette;
  final VoidCallback onAdd;

  const _CameraTab({required this.palette, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 140,
        height: 120,
        child: _GridTile(
          palette: palette,
          label: 'Cámara',
          onTap: onAdd,
          child: Icon(Icons.videocam, color: palette.accent, size: 36),
        ),
      ),
    );
  }
}

class _ActorTab extends StatelessWidget {
  final AppPalette palette;
  final ValueChanged<Color> onAdd;

  const _ActorTab({required this.palette, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: kActorColors.length,
      itemBuilder: (context, i) {
        final color = kActorColors[i];
        return _GridTile(
          palette: palette,
          label: 'Actor ${i + 1}',
          onTap: () => onAdd(color),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: palette.border),
            ),
          ),
        );
      },
    );
  }
}

class _LightTab extends StatelessWidget {
  final AppPalette palette;
  final ValueChanged<LightType> onAdd;

  const _LightTab({required this.palette, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520
            ? 8
            : constraints.maxWidth >= 360
            ? 6
            : 4;

        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.72,
          ),
          itemCount: kShotDesignerLightGrid.length,
          itemBuilder: (context, i) {
            final type = kShotDesignerLightGrid[i];
            return LightGridTile(type: type, onTap: () => onAdd(type));
          },
        );
      },
    );
  }
}

class _PropTab extends StatelessWidget {
  final AppPalette palette;
  final ValueChanged<PropType> onAdd;

  const _PropTab({required this.palette, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      // El fotómetro, último de la lista, se añade desde «Medición».
      itemCount: PropType.values.length - 1,
      itemBuilder: (context, i) {
        final type = PropType.values[i];
        return _GridTile(
          palette: palette,
          label: type.label,
          onTap: () => onAdd(type),
          child: Icon(type.icon, color: palette.textSecondary, size: 28),
        );
      },
    );
  }
}

class _ArchitectureTab extends StatelessWidget {
  final AppPalette palette;
  final ValueChanged<ArchitectureType> onAdd;

  const _ArchitectureTab({required this.palette, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: ArchitectureType.values.length,
      itemBuilder: (context, i) {
        final type = ArchitectureType.values[i];
        return _GridTile(
          palette: palette,
          label: type.label,
          onTap: () => onAdd(type),
          child: Icon(type.icon, color: palette.textPrimary, size: 28),
        );
      },
    );
  }
}

class _ElementPanel extends StatefulWidget {
  final AppPalette palette;
  final PlanElement element;

  /// A qué afecta cambiar este elemento.
  final String scopeNotice;
  final List<PlanLayer> moveTargets;
  final ValueChanged<PlanLayer> onMove;

  /// Repinta mientras se arrastra un control, sin guardar todavía.
  final VoidCallback onPreview;
  final int? selectedPathIndex;

  /// Abre «Cámaras y lentes del proyecto».
  final VoidCallback? onManageGear;

  /// Personajes del proyecto y su color.
  final Map<String, ({String name, Color color})> cast;

  /// Cambia el color del personaje seleccionado en todo el proyecto.
  final ValueChanged<Color>? onRecolourCast;
  final VoidCallback? onAddPathPoint;
  final VoidCallback? onDeletePathPoint;
  final VoidCallback? onClearPath;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  /// Cuántos elementos hay seleccionados a la vez.
  final int selectionCount;

  /// Longitud en metros, si es un tramo.
  final String? lengthLabel;
  final double metersPerUnit;

  /// Ajustes con los que se lee la luz y diafragma de trabajo.
  final ExposureSettings exposure;
  final double targetStop;

  /// Lectura de fotómetro, si lo seleccionado es un fotómetro o un actor.
  final MeterReading? reading;

  /// Equipo del proyecto, para elegir cámara y lente.
  final ProjectGear gear;

  /// Con un plano abierto, una luz del esquema se puede ajustar solo en él.
  final bool canOverride;
  final ValueChanged<bool>? onOverride;

  const _ElementPanel({
    required this.palette,
    required this.element,
    required this.scopeNotice,
    required this.moveTargets,
    required this.onMove,
    required this.onPreview,
    this.selectedPathIndex,
    this.onManageGear,
    this.cast = const {},
    this.onRecolourCast,
    this.onAddPathPoint,
    this.onDeletePathPoint,
    this.onClearPath,
    required this.onUpdate,
    required this.onDelete,
    required this.onDuplicate,
    this.selectionCount = 1,
    this.lengthLabel,
    this.metersPerUnit = defaultMetersPerUnit,
    this.exposure = const ExposureSettings(),
    this.targetStop = CameraExposure.defaultStop,
    this.reading,
    this.gear = const ProjectGear(),
    this.canOverride = false,
    this.onOverride,
  });

  @override
  State<_ElementPanel> createState() => _ElementPanelState();
}

class _ElementPanelState extends State<_ElementPanel> {
  late TextEditingController _lensCtrl;
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.element.label ?? '',
  );

  /// Pone nombre al personaje. Si ya existe en el proyecto, coge su color.
  void _commitName(String value) {
    final element = widget.element;
    final name = value.trim();
    if (name.isEmpty || name == element.label) return;
    element.label = name;
    final known = widget.cast[PlanCast.key(name)];
    if (known != null) element.actorColor = known.color;
    widget.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _lensCtrl = TextEditingController(text: widget.element.lens ?? '');
  }

  @override
  void didUpdateWidget(_ElementPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.element.id != widget.element.id) {
      _lensCtrl.text = widget.element.lens ?? '';
      _nameCtrl.text = widget.element.label ?? '';
    }
  }

  @override
  void dispose() {
    _lensCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Control de una propiedad del haz: repinta al arrastrar y guarda al
  /// soltar.
  Widget _beamSlider(
    String label,
    String value,
    String key,
    double current,
    double min,
    double max, {
    double step = 1,
  }) {
    final palette = widget.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.caption(palette))),
            Text(value, style: AppTypography.caption(palette)),
          ],
        ),
        Slider(
          value: current.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) {
            widget.element.props[key] = (v / step).round() * step;
            widget.onPreview();
          },
          onChangeEnd: (_) => widget.onUpdate(),
        ),
      ],
    );
  }

  /// Foco de un aparato que enfoca: del spot al flood de su ficha. Al
  /// abrir, el mismo flujo se reparte en más ángulo y el eje baja.
  Widget _focusControl(LightOptics optics, double spread) {
    final palette = widget.palette;
    final spot = optics.spotDeg!, flood = optics.floodDeg!;
    final current = spread.clamp(spot, flood).toDouble();
    String deg(double v) =>
        '${v == v.roundToDouble() ? v.round() : v.toStringAsFixed(1)}°';
    void set(double v) {
      widget.element.props[LightBeam.spreadKey] = v;
      widget.onUpdate();
    }

    final light = PlanLight.of(widget.element);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Foco', style: AppTypography.caption(palette)),
            ),
            Text(deg(current), style: AppTypography.caption(palette)),
          ],
        ),
        Slider(
          value: current,
          min: spot,
          max: flood,
          onChanged: (v) {
            widget.element.props[LightBeam.spreadKey] = v.roundToDouble();
            widget.onPreview();
          },
          onChangeEnd: (_) => widget.onUpdate(),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => set(spot),
              child: Text('Spot ${deg(spot)}'),
            ),
            const Spacer(),
            if (light != null)
              Text(
                '${formatLux(light.source.illuminance(3))} a 3 m',
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.textTertiary),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => set(flood),
              child: Text('Flood ${deg(flood)}'),
            ),
          ],
        ),
        if (optics.estimated)
          Text(
            'Rango típico de su formato: la ficha no trae el suyo.',
            style: AppTypography.caption(
              palette,
            ).copyWith(color: palette.textTertiary, fontSize: 10),
          ),
      ],
    );
  }

  void _commitLens(String v) {
    widget.element.lens = v;
    widget.onUpdate();
  }

  /// Bloques abiertos o plegados; se recuerda mientras dure la sesión.
  static final _openSections = <String, bool>{};

  /// Un bloque plegable del panel.
  Widget _section(
    AppPalette palette,
    String title,
    String key,
    List<Widget> children, {
    bool open = true,
  }) {
    final isOpen = _openSections[key] ?? open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _openSections[key] = !isOpen),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.accent,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  isOpen ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: palette.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (isOpen) ...children,
        Divider(height: 12, color: palette.border),
      ],
    );
  }

  List<Widget> _rotationControls(AppPalette palette, PlanElement element) => [
    Text('Rotación', style: AppTypography.caption(palette)),
    Row(
      children: [
        Expanded(
          child: Slider(
            // Girar en el lienzo puede dejar la rotación
            // fuera de 0–360 (p. ej. -90).
            value: element.rotation % 360,
            min: 0,
            max: 360,
            divisions: 360,
            label: '${(element.rotation % 360).round()}°',
            onChanged: (v) {
              element.rotation = v;
              widget.onUpdate();
            },
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${(element.rotation % 360).round()}°',
            style: AppTypography.caption(palette),
          ),
        ),
        for (final step in const [-15.0, 15.0])
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: step < 0 ? 'Girar −15°' : 'Girar +15°',
            icon: Icon(
              step < 0 ? Icons.rotate_left : Icons.rotate_right,
              size: 18,
            ),
            onPressed: () {
              final turned = ((element.rotation + step) / 15).round() * 15.0;
              element.rotation = (turned % 360 + 360) % 360;
              widget.onUpdate();
            },
          ),
      ],
    ),
    Text(
      'Arrastra el asa o el anillo en el lienzo para girar; '
      'con Mayús, de 15 en 15°',
      style: AppTypography.caption(
        palette,
      ).copyWith(color: palette.textTertiary, fontSize: 10),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final element = widget.element;

    // Un Material, no un fondo de color: los controles con tinta (listas,
    // interruptores) pintan sobre él.
    return Material(
      color: palette.surface,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Propiedades', style: AppTypography.label(palette)),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      element.displayLabel,
                      style: AppTypography.titleMedium(palette),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.scopeNotice,
                        style: AppTypography.caption(palette),
                      ),
                    ),
                    if (widget.moveTargets.isNotEmpty)
                      PopupMenuButton<PlanLayer>(
                        tooltip: 'Mover a otra capa',
                        onSelected: widget.onMove,
                        itemBuilder: (_) => [
                          for (final layer in widget.moveTargets)
                            PopupMenuItem(
                              value: layer,
                              child: Text('Mover a ${layer.label}'),
                            ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Mover a otra capa…',
                            style: AppTypography.caption(
                              palette,
                            ).copyWith(color: palette.accent),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    if (element.type == ElementType.actor)
                      _section(palette, 'Personaje', 'cast', [
                        TextField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: AppTypography.bodyLarge(palette),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Nombre',
                            hintText: 'ADIL',
                          ),
                          onSubmitted: _commitName,
                          onTapOutside: (_) => _commitName(_nameCtrl.text),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final c in kActorColors)
                              GestureDetector(
                                onTap: () => widget.onRecolourCast?.call(c),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: element.actorColor == c
                                        ? Border.all(
                                            color: palette.textPrimary,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          PlanCast.isNamed(element.label)
                              ? '${element.label!.trim()} lleva este color en '
                                    'todas las plantas del proyecto.'
                              : 'Ponle nombre y su color le seguirá en todas '
                                    'las plantas.',
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: palette.textTertiary),
                        ),
                      ]),
                    if (element.type == ElementType.camera)
                      _section(palette, 'Cámara', 'camera-id', [
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final letter in const ['A', 'B', 'C', 'D'])
                              ChoiceChip(
                                visualDensity: VisualDensity.compact,
                                showCheckmark: false,
                                avatar: CircleAvatar(
                                  backgroundColor: cameraColorForLetter(letter),
                                  radius: 6,
                                ),
                                label: Text('Cám. $letter'),
                                selected: element.cameraLetter == letter,
                                onSelected: (_) {
                                  element.cameraLetter = letter;
                                  final body = widget.gear.cameraForLetter(
                                    letter,
                                  );
                                  if (body != null) {
                                    PlanEquipment.applyCamera(element, body);
                                  }
                                  widget.onUpdate();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cada letra tiene su color, el mismo en todas las '
                          'plantas, y coge el cuerpo que lleve esa letra en '
                          'el proyecto.',
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: palette.textTertiary),
                        ),
                      ]),
                    if (LightBeam.of(element) case final beam?) ...[
                      _section(palette, 'Aparato', 'fixture', [
                        PlanElementCompatPanel(
                          element: element,
                          onChanged: widget.onUpdate,
                          part: CompatPart.identity,
                        ),
                      ]),
                      _section(palette, 'Luz', 'light', [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Encendida',
                                style: AppTypography.caption(palette),
                              ),
                            ),
                            Switch(
                              value: !beam.off,
                              onChanged: (on) {
                                element.props[LightBeam.offKey] = !on;
                                widget.onUpdate();
                              },
                            ),
                          ],
                        ),
                        _beamSlider(
                          'Intensidad',
                          '${beam.intensity.round()} %',
                          LightBeam.intensityKey,
                          beam.intensity,
                          0,
                          100,
                        ),
                        _beamSlider(
                          'Temperatura de color',
                          '${beam.cct.round()} K',
                          LightBeam.cctKey,
                          beam.cct,
                          2000,
                          10000,
                          step: 100,
                        ),
                        if (PlanLight.opticsOf(element) case final optics
                            when optics.focusable)
                          _focusControl(optics, beam.spread)
                        else
                          _beamSlider(
                            'Apertura del haz',
                            '${beam.spread.round()}°',
                            LightBeam.spreadKey,
                            beam.spread,
                            5,
                            360,
                          ),
                        PlanLightControls(
                          element: element,
                          exposure: widget.exposure,
                          onUpdate: widget.onUpdate,
                          parts: const {LightControlPart.power},
                        ),
                      ]),
                      _section(palette, 'Montaje', 'mount', [
                        PlanLightControls(
                          element: element,
                          exposure: widget.exposure,
                          onUpdate: widget.onUpdate,
                          parts: const {LightControlPart.mount},
                        ),
                        ..._rotationControls(palette, element),
                      ]),
                      _section(palette, 'Filtros y difusión', 'filters', [
                        PlanLightControls(
                          element: element,
                          exposure: widget.exposure,
                          onUpdate: widget.onUpdate,
                          parts: const {LightControlPart.filters},
                        ),
                      ]),
                      _section(palette, 'Dato del fabricante', 'data', [
                        PlanLightControls(
                          element: element,
                          exposure: widget.exposure,
                          onUpdate: widget.onUpdate,
                          parts: const {LightControlPart.data},
                        ),
                      ]),
                    ],
                    if (widget.canOverride)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              element.shotOverride
                                  ? 'Ajustada solo en este plano'
                                  : 'Ajustar solo en este plano',
                              style: AppTypography.caption(palette),
                            ),
                          ),
                          Switch(
                            value: element.shotOverride,
                            onChanged: widget.onOverride,
                          ),
                        ],
                      ),
                    if (element.type == ElementType.camera)
                      PlanProjectCameraPicker(
                        gear: widget.gear,
                        camera: element,
                        onManage: widget.onManageGear,
                        onCamera: (camera) {
                          PlanEquipment.applyCamera(element, camera);
                          widget.onUpdate();
                        },
                        onLens: (lens) {
                          PlanEquipment.applyLens(element, lens);
                          _lensCtrl.text = element.lens ?? '';
                          widget.onUpdate();
                        },
                        onFocal: (focal) {
                          PlanEquipment.setFocal(element, focal);
                          _lensCtrl.text = element.lens ?? '';
                          widget.onUpdate();
                        },
                      ),
                    if (widget.reading != null)
                      PlanMeterPanel(
                        reading: widget.reading!,
                        exposure: widget.exposure,
                      ),
                    if (element.type == ElementType.camera)
                      PlanCameraExposureControls(
                        camera: element,
                        fallback: widget.exposure,
                        fallbackStop: widget.targetStop,
                        onUpdate: widget.onUpdate,
                      ),
                    if (PlanPieceControls.appliesTo(element))
                      PlanPieceControls(
                        element: element,
                        metersPerUnit: widget.metersPerUnit,
                        onPreview: widget.onPreview,
                        onUpdate: widget.onUpdate,
                      ),
                    if (widget.lengthLabel != null)
                      Text(
                        'Longitud: ${widget.lengthLabel}',
                        style: AppTypography.bodyMedium(palette),
                      )
                    else ...[
                      if (LightBeam.of(element) == null)
                        ..._rotationControls(palette, element),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    if (element.type == ElementType.camera) ...[
                      Text('Lente', style: AppTypography.caption(palette)),
                      TextField(
                        controller: _lensCtrl,
                        style: AppTypography.bodyLarge(palette),
                        decoration: const InputDecoration(hintText: '50mm'),
                        onSubmitted: _commitLens,
                        onEditingComplete: () => _commitLens(_lensCtrl.text),
                      ),
                    ],
                    if (PlanMarks.supports(element))
                      _section(palette, 'Posiciones', 'marks', [
                        Text(
                          element.pathPoints.isEmpty
                              ? 'Una sola posición'
                              : '${element.pathPoints.length + 1} posiciones',
                          style: AppTypography.caption(palette).copyWith(
                            color: palette.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        if (widget.selectedPathIndex != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Posición ${widget.selectedPathIndex! + 2} seleccionada: '
                              'arrástrala o gírala con su asa',
                              style: AppTypography.caption(
                                palette,
                              ).copyWith(color: palette.accent, fontSize: 10),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.onAddPathPoint,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Posición'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: widget.selectedPathIndex != null
                                    ? widget.onDeletePathPoint
                                    : null,
                                icon: Icon(
                                  Icons.remove,
                                  size: 16,
                                  color: palette.error,
                                ),
                                label: Text(
                                  'Quitar',
                                  style: TextStyle(color: palette.error),
                                ),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (element.pathPoints.isNotEmpty)
                          TextButton(
                            onPressed: widget.onClearPath,
                            child: Text(
                              'Dejar una sola posición',
                              style: AppTypography.caption(
                                palette,
                              ).copyWith(color: palette.textSecondary),
                            ),
                          ),
                        Text(
                          'Doble toque en el lienzo para añadir una posición. Cada '
                          'una se arrastra y se gira por separado: en la de una '
                          'cámara se ve qué encuadra desde allí.',
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: palette.textTertiary, fontSize: 10),
                        ),
                      ]),
                    if (element.type == ElementType.camera ||
                        element.type == ElementType.light ||
                        element.type == ElementType.prop ||
                        element.type == ElementType.wall ||
                        element.type == ElementType.actor) ...[
                      _section(palette, 'Exportar a 3D', 'export', [
                        Text(
                          'Enlace con ARRI Luka y Cine Tracer. Se rellena '
                          'solo al elegir un modelo de Equipo.',
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: palette.textTertiary),
                        ),
                        const SizedBox(height: 6),
                        PlanElementCompatPanel(
                          element: element,
                          onChanged: widget.onUpdate,
                          part:
                              element.type == ElementType.light &&
                                  LightBeam.of(element) != null
                              ? CompatPart.export
                              : CompatPart.all,
                        ),
                      ], open: false),
                    ],
                  ],
                ),
              ),
            ),
            if (widget.selectionCount > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${widget.selectionCount} elementos seleccionados: duplicar '
                  'y eliminar se aplican a todos.',
                  style: AppTypography.caption(palette),
                ),
              ),
            GestureDetector(
              onTap: widget.onDuplicate,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.copy_outlined, color: palette.accent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Duplicar',
                      style: AppTypography.bodyMedium(
                        palette,
                      ).copyWith(color: palette.accent),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: widget.onDelete,
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: palette.error, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Eliminar',
                    style: AppTypography.bodyMedium(
                      palette,
                    ).copyWith(color: palette.error),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
