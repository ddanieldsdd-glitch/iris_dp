import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value, OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../core/utils/scene_color.dart';
import '../../shared/annotations/annotation_canvas.dart';
import '../../shared/annotations/annotation_document.dart';
import 'camera_plan_grouping.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'camera_plan_painter.dart';
import 'camera_plan_scene_badge.dart';
import 'floor_plan_repository.dart';
import 'floor_plan_json.dart';
import 'floor_plan_scope.dart';
import 'plan_target.dart';
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
       shotId = null;

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
       shotId = null;

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
       shotId = null;

  /// Planta de cámara de un plano concreto.
  const CameraPlanEditor.shot({
    super.key,
    required this.projectId,
    required int this.shotId,
    required String shotLabel,
    this.onNavigate,
  }) : label = shotLabel,
       scope = FloorPlanScope.shot,
       siteId = null,
       setId = null,
       lightSetupId = null;

  @override
  ConsumerState<CameraPlanEditor> createState() => _CameraPlanEditorState();
}

class _CameraPlanEditorState extends ConsumerState<CameraPlanEditor> {
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
  int _setShotCount = 0;
  final AnnotationCanvasController _annotationController =
      AnnotationCanvasController();
  PlanElement? _selected;
  Offset _canvasOffset = Offset.zero;
  double _scale = 1.0;
  bool _loading = true;
  bool _isRotating = false;
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
    _annotationController.dispose();
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
        if (scene != null) {
          if (scene.locationId != null) {
            linkedSet = await db.getLocationById(scene.locationId!);
          }
          if (scene.locationSiteId != null) {
            linkedSite = await db.getSiteById(scene.locationSiteId!);
          } else if (linkedSet?.siteId != null) {
            linkedSite = await db.getSiteById(linkedSet!.siteId!);
          }
          sceneColor = colors.sceneColor(scene);
        }
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
      lightSetup = setupById(shot.lightSetupId);
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
    addLayer(PlanLayer.light, FloorPlanJson.decode(lightSetup?.planJson));
    if (shot != null) {
      addLayer(
        PlanLayer.shot,
        await _repo.loadElements(scope: FloorPlanScope.shot, shotId: shot.id),
      );
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

    final allShots = await (db.select(
      db.shots,
    )..where((s) => s.projectId.equals(widget.projectId))).get();
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
      _lightSetup = lightSetup;
      _zones = zones;
      if (_setZone == null && setZone != null) _pendingFit = setZone;
      _setZone = setZone;
      _setShotCount = setShotCount;
      _setupShotCount = setupShotCount;
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

    final db = ref.read(databaseProvider);
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
      await db.assignLightSetupToShot(shot.id, chosen?.id);
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
      await db.assignLightSetupToShot(shot.id, created.id);
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
        await _repo.saveElements(
          scope: FloorPlanScope.lightSetup,
          elements: list,
          lightSetupId: _lightSetup!.id,
        );
      case PlanLayer.shot:
        await _repo.saveElements(
          scope: FloorPlanScope.shot,
          elements: list,
          shotId: _shot!.id,
        );
    }
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

  Future<void> _persistElement(PlanElement el, {int? sortOrder}) async {
    if (el.layer != PlanLayer.shot) {
      await _saveLayer(el.layer);
      return;
    }
    final shotId = _shot?.id;
    if (shotId == null) return;

    final db = ref.read(databaseProvider);
    final shotElements = _layerElements(PlanLayer.shot);
    final index = shotElements.indexOf(el);
    final order = sortOrder ?? (index >= 0 ? index : shotElements.length);

    if (el.id <= 0) {
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
  }

  Future<void> _persistAllElements() async {
    for (final layer in PlanLayer.values) {
      await _saveLayer(layer);
    }
  }

  Future<void> _addElement(PlanElement el) async {
    final layer = await _layerForNew(el.type);
    if (!mounted) return;
    el.layer = layer;
    if (layer != PlanLayer.shot) el.id = --_tempId;
    // Lo nuevo aparece en lo que se está viendo.
    final same = _elements.where((e) => e.type == el.type).length;
    el.position = _viewCenter + Offset(same % 5 * 36.0, same % 5 * 24.0);
    _hiddenLayers.remove(layer);
    setState(() => _elements.add(el));
    await _persistElement(el);
    setState(() => _selected = el);
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
      ),
    );
  }

  Future<void> _addActor(Color color) async {
    final actorCount = _elements
        .where((e) => e.type == ElementType.actor)
        .length;
    await _addElement(
      PlanElement(
        id: 0,
        type: ElementType.actor,
        position: Offset(150 + actorCount * 60.0, 150),
        label: 'Actor ${actorCount + 1}',
        actorColor: color,
      ),
    );
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
    final el = _selected;
    if (el == null) return;
    if (el.layer == PlanLayer.shot && el.id > 0) {
      final db = ref.read(databaseProvider);
      await db.deleteCameraPlanElement(el.id);
      await db.touchProjectContent(widget.projectId);
    }
    setState(() {
      _elements.remove(el);
      _selected = null;
      _selectedPathIndex = null;
    });
    if (el.layer != PlanLayer.shot) await _saveLayer(el.layer);
  }

  Offset _toCanvasCoords(Offset localPos) {
    return (localPos - _canvasOffset) / _scale;
  }

  PlanElement? _elementAt(Offset canvasPos) {
    for (final el in _visibleElements.reversed) {
      if ((el.position - canvasPos).distance < 28 / math.min(1.0, _scale)) {
        return el;
      }
    }
    return null;
  }

  bool _hitRotationHandle(Offset canvasPos) {
    if (_selected == null) return false;
    final handle = CameraPlanPainter.rotationHandleWorld(_selected!);
    return (canvasPos - handle).distance < 14 / _scale;
  }

  void _updateRotation(PlanElement el, Offset canvasPos) {
    final angle = math.atan2(
      canvasPos.dy - el.position.dy,
      canvasPos.dx - el.position.dx,
    );
    el.rotation = ((angle * 180 / math.pi) + 90) % 360;
    if (el.rotation < 0) el.rotation += 360;
  }

  Future<void> _addPathPointAt(Offset canvasPos) async {
    final cam = _selected;
    if (cam == null || cam.type != ElementType.camera) return;
    setState(() {
      cam.pathPoints.add(canvasPos);
      _selectedPathIndex = cam.pathPoints.length - 1;
    });
    await _persistElement(cam);
  }

  Future<void> _addPathPointAhead() async {
    final cam = _selected;
    if (cam == null || cam.type != ElementType.camera) return;
    final rad = cam.rotation * math.pi / 180;
    final forward = Offset(-math.sin(rad), math.cos(rad));
    final origin = cam.pathPoints.isEmpty ? cam.position : cam.pathPoints.last;
    await _addPathPointAt(origin + forward * 80);
  }

  Future<void> _deleteSelectedPathPoint() async {
    final cam = _selected;
    final index = _selectedPathIndex;
    if (cam == null ||
        cam.type != ElementType.camera ||
        index == null ||
        index < 0 ||
        index >= cam.pathPoints.length) {
      return;
    }
    setState(() {
      cam.pathPoints.removeAt(index);
      _selectedPathIndex = null;
    });
    await _persistElement(cam);
  }

  Future<void> _clearCameraPath() async {
    final cam = _selected;
    if (cam == null || cam.type != ElementType.camera) return;
    setState(() {
      cam.pathPoints.clear();
      _selectedPathIndex = null;
    });
    await _persistElement(cam);
  }

  int? _pathPointIndexAt(PlanElement camera, Offset canvasPos) =>
      CameraPlanPainter.pathPointAt(camera, canvasPos, scale: _scale);

  void _onPanStart(DragStartDetails d) {
    final canvasPos = _toCanvasCoords(d.localPosition);
    if (_zoneMode) {
      setState(() {
        _zoneStart = canvasPos;
        _zoneDraft = Rect.fromPoints(canvasPos, canvasPos);
      });
      return;
    }
    for (final el in _elements.reversed) {
      if (el.type != ElementType.camera) continue;
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
    if (_selected != null && _hitRotationHandle(canvasPos)) {
      _isRotating = true;
      _isDraggingPathPoint = false;
      return;
    }
    _isRotating = false;
    _isDraggingPathPoint = false;
    final tapped = _elementAt(canvasPos);
    _dragging = tapped;
    if (tapped != null) {
      setState(() {
        _selected = tapped;
        _selectedPathIndex = null;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_zoneMode) {
      final start = _zoneStart;
      if (start == null) return;
      setState(() {
        _zoneDraft = Rect.fromPoints(start, _toCanvasCoords(d.localPosition));
      });
      return;
    }
    final delta = d.delta / _scale;
    if (_selected != null &&
        (_isDraggingPathPoint || _isRotating || _dragging != null)) {
      _dragDirty = true;
    }
    if (_selected != null &&
        _isDraggingPathPoint &&
        _selectedPathIndex != null) {
      setState(() {
        _selected!.pathPoints[_selectedPathIndex!] += delta;
      });
    } else if (_selected != null && _isRotating) {
      final canvasPos = _toCanvasCoords(d.localPosition);
      setState(() => _updateRotation(_selected!, canvasPos));
    } else if (_dragging != null) {
      setState(() => _dragging!.position += delta);
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
    // Se guarda siempre que algo se haya movido, se suelte como se suelte.
    final moved = _dragDirty;
    _dragDirty = false;
    _dragging = null;
    if (_selected != null && moved) {
      await _persistElement(_selected!);
    }
    _isRotating = false;
    _isDraggingPathPoint = false;
  }

  void _onTapCanvas(TapDownDetails d) {
    if (_zoneMode) return;
    final canvasPos = _toCanvasCoords(d.localPosition);
    for (final el in _elements.reversed) {
      if (el.type != ElementType.camera) continue;
      final pathIdx = _pathPointIndexAt(el, canvasPos);
      if (pathIdx != null) {
        setState(() {
          _selected = el;
          _selectedPathIndex = pathIdx;
        });
        return;
      }
    }
    final el = _elementAt(canvasPos);
    setState(() {
      _selected = el;
      _selectedPathIndex = null;
    });
  }

  void _onDoubleTapCanvas(TapDownDetails d) {
    if (_selected?.type != ElementType.camera) return;
    final canvasPos = _toCanvasCoords(d.localPosition);
    if (_elementAt(canvasPos) != null) return;
    if (CameraPlanPainter.pathPointAt(_selected!, canvasPos, scale: _scale) !=
        null) {
      return;
    }
    _addPathPointAt(canvasPos);
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
              const Color(0xFFFFB300),
              onMenu: _chooseLightSetup,
            ),
            if (_navTargets.isNotEmpty)
              chip(
                PlanLayer.shot,
                'Cámara: ${_shot != null ? widget.label : 'ningún plano'}',
                palette.accent,
                onMenu: _showSceneNavigator,
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

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
          : Column(
              children: [
                _buildLayerBar(palette),
                if (_zoneMode)
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
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) _fitTo(fit);
                              });
                            }
                            return ClipRect(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  IgnorePointer(
                                    ignoring: _annotationMode,
                                    child: GestureDetector(
                                      onPanStart: _onPanStart,
                                      onPanUpdate: _onPanUpdate,
                                      onPanEnd: _onPanEnd,
                                      onTapDown: _onTapCanvas,
                                      onDoubleTapDown: _onDoubleTapCanvas,
                                      child: CustomPaint(
                                        size: Size(
                                          constraints.maxWidth,
                                          constraints.maxHeight,
                                        ),
                                        painter: CameraPlanPainter(
                                          elements: _visibleElements,
                                          zones: [
                                            ..._zones,
                                            if (_zoneDraft != null)
                                              PlanZone(
                                                rect: _zoneDraft!,
                                                color: _sceneColor,
                                                label:
                                                    _linkedSet?.locationName ??
                                                    '',
                                                active: true,
                                              ),
                                          ],
                                          selectedElement: _selected,
                                          selectedPathIndex: _selectedPathIndex,
                                          scale: _scale,
                                          offset: _canvasOffset,
                                          palette: palette,
                                          backgroundImage: _backgroundImage,
                                          backgroundRect: _backgroundRect,
                                          backgroundOpacity: _backgroundOpacity,
                                        ),
                                        child: Container(
                                          color: Colors.transparent,
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
                                        documentSize: _annotationDocumentSize,
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
                              if (layer != _selected!.layer && _hasLayer(layer))
                                layer,
                          ],
                          onMove: (layer) => _moveToLayer(_selected!, layer),
                          selectedPathIndex: _selectedPathIndex,
                          onAddPathPoint: _addPathPointAhead,
                          onDeletePathPoint: _deleteSelectedPathPoint,
                          onClearPath: _clearCameraPath,
                          onUpdate: () async {
                            setState(() {});
                            await _persistElement(_selected!);
                          },
                          onDelete: _deleteSelected,
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
                _BottomToolbar(
                  palette: palette,
                  onAdd: _showAddMenu,
                  onSave: _saveCurrentPlan,
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
      itemCount: PropType.values.length,
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
  final int? selectedPathIndex;
  final VoidCallback? onAddPathPoint;
  final VoidCallback? onDeletePathPoint;
  final VoidCallback? onClearPath;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const _ElementPanel({
    required this.palette,
    required this.element,
    required this.scopeNotice,
    required this.moveTargets,
    required this.onMove,
    this.selectedPathIndex,
    this.onAddPathPoint,
    this.onDeletePathPoint,
    this.onClearPath,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_ElementPanel> createState() => _ElementPanelState();
}

class _ElementPanelState extends State<_ElementPanel> {
  late TextEditingController _lensCtrl;

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
    }
  }

  @override
  void dispose() {
    _lensCtrl.dispose();
    super.dispose();
  }

  void _commitLens(String v) {
    widget.element.lens = v;
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final element = widget.element;

    return Container(
      width: 240,
      color: palette.surface,
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
                  Text('Rotación', style: AppTypography.caption(palette)),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: element.rotation,
                          min: 0,
                          max: 360,
                          divisions: 360,
                          label: '${element.rotation.round()}°',
                          onChanged: (v) {
                            element.rotation = v;
                            widget.onUpdate();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${element.rotation.round()}°',
                          style: AppTypography.caption(palette),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Arrastra el asa azul en el canvas para rotar',
                    style: AppTypography.caption(
                      palette,
                    ).copyWith(color: palette.textTertiary, fontSize: 10),
                  ),
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
                    const SizedBox(height: AppSpacing.sm),
                    Text('Trayectoria', style: AppTypography.caption(palette)),
                    const SizedBox(height: 4),
                    Text(
                      '${element.pathPoints.length} punto(s) · '
                      '${element.pathPoints.length + 1} posiciones',
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(color: palette.textSecondary, fontSize: 10),
                    ),
                    if (widget.selectedPathIndex != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Punto ${widget.selectedPathIndex! + 2} seleccionado',
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
                            label: const Text('Añadir'),
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
                          'Limpiar trayectoria',
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: palette.textSecondary),
                        ),
                      ),
                    Text(
                      'Doble toque en el canvas para añadir un punto. '
                      'Arrastra los círculos numerados para mover la ruta.',
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(color: palette.textTertiary, fontSize: 10),
                    ),
                  ],
                  if (element.type == ElementType.camera ||
                      element.type == ElementType.light ||
                      element.type == ElementType.prop ||
                      element.type == ElementType.wall ||
                      element.type == ElementType.actor) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Compatibilidad 3D',
                      style: AppTypography.caption(palette),
                    ),
                    const SizedBox(height: 6),
                    PlanElementCompatPanel(
                      element: element,
                      onChanged: widget.onUpdate,
                    ),
                  ],
                  if (element.type == ElementType.actor) ...[
                    Text('Color', style: AppTypography.caption(palette)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: kActorColors
                          .map(
                            (c) => GestureDetector(
                              onTap: () {
                                element.actorColor = c;
                                widget.onUpdate();
                              },
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
                          )
                          .toList(),
                    ),
                  ],
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
    );
  }
}
