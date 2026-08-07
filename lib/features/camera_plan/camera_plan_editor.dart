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
import 'camera_plan_grouping.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'camera_plan_painter.dart';
import 'camera_plan_scene_badge.dart';
import 'floor_plan_repository.dart';
import 'floor_plan_scope.dart';
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
  final int? shotId;

  const CameraPlanEditor({
    super.key,
    required this.projectId,
    required this.label,
    this.scope = FloorPlanScope.shot,
    this.siteId,
    this.setId,
    this.shotId,
  });

  /// Plano maestro de localización.
  const CameraPlanEditor.site({
    super.key,
    required this.projectId,
    required int this.siteId,
    required String siteName,
  })  : label = siteName,
        scope = FloorPlanScope.site,
        setId = null,
        shotId = null;

  /// Plano base del set de rodaje.
  const CameraPlanEditor.set({
    super.key,
    required this.projectId,
    required int this.setId,
    required String setName,
  })  : label = setName,
        scope = FloorPlanScope.set,
        siteId = null,
        shotId = null;

  /// Planta de cámara de un plano concreto.
  const CameraPlanEditor.shot({
    super.key,
    required this.projectId,
    required int this.shotId,
    required String shotLabel,
  })  : label = shotLabel,
        scope = FloorPlanScope.shot,
        siteId = null,
        setId = null;

  @override
  ConsumerState<CameraPlanEditor> createState() => _CameraPlanEditorState();
}

class _CameraPlanEditorState extends ConsumerState<CameraPlanEditor> {
  final List<PlanElement> _elements = [];
  PlanElement? _selected;
  Offset _canvasOffset = Offset.zero;
  double _scale = 1.0;
  bool _loading = true;
  bool _isRotating = false;
  bool _isDraggingPathPoint = false;
  int? _selectedPathIndex;
  Shot? _shot;
  Scene? _scene;
  LocationBasePlan? _linkedSet;
  LocationSite? _linkedSite;
  List<CameraPlanNavTarget> _navTargets = [];
  Color _sceneColor = const Color(0xFF94A3B8);
  bool _canInheritTemplate = false;
  ui.Image? _backgroundImage;
  Rect? _backgroundRect;
  double _backgroundOpacity = 0.85;
  late FloorPlanRepository _repo;

  bool get _isShotMode => widget.scope == FloorPlanScope.shot;

  @override
  void initState() {
    super.initState();
    _repo = FloorPlanRepository(ref.read(databaseProvider));
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final elements = await _repo.loadElements(
      scope: widget.scope,
      siteId: widget.siteId,
      setId: widget.setId,
      shotId: widget.shotId,
    );

    Shot? shot;
    Scene? scene;
    LocationBasePlan? linkedSet;
    LocationSite? linkedSite;
    Color sceneColor = sceneDisplayColor(null);
    var canInherit = false;

    final sites = await db.watchSitesForProject(widget.projectId).first;
    final allSets = await db.watchLocationsForProject(widget.projectId).first;
    final allScenes = await db.watchScenesForProject(widget.projectId).first;
    final colors = ProjectColorScheme.resolve(
      sites: sites,
      sets: allSets,
      scenes: allScenes,
    );

    if (_isShotMode && widget.shotId != null) {
      shot = await (db.select(db.shots)
            ..where((s) => s.id.equals(widget.shotId!)))
          .getSingleOrNull();

      if (shot != null) {
        scene = await (db.select(db.scenes)
              ..where((s) => s.id.equals(shot!.sceneId)))
            .getSingleOrNull();
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
          if (elements.isEmpty) {
            canInherit =
                await _repo.resolveTemplateJsonForScene(scene) != null;
          }
        }
      }
    } else if (widget.scope == FloorPlanScope.set && widget.setId != null) {
      linkedSet = await db.getLocationById(widget.setId!);
      if (linkedSet?.siteId != null) {
        linkedSite = await db.getSiteById(linkedSet!.siteId!);
      }
      sceneColor = colors.setColor(linkedSet!);
    } else if (widget.scope == FloorPlanScope.site && widget.siteId != null) {
      linkedSite = await db.getSiteById(widget.siteId!);
      sceneColor = colors.siteColor(widget.siteId);
    }

    final navTargets =
        _isShotMode ? await _loadNavTargets(db) : <CameraPlanNavTarget>[];

    ui.Image? bgImage;
    Rect? bgRect;
    var bgOpacity = 0.85;
    final scanService = LocationScanService(db);
    final scopeKind = switch (widget.scope) {
      FloorPlanScope.site => FloorPlanScopeKind.site,
      FloorPlanScope.set => FloorPlanScopeKind.set,
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
    setState(() {
      _elements
        ..clear()
        ..addAll(elements);
      _shot = shot;
      _scene = scene;
      _linkedSet = linkedSet;
      _linkedSite = linkedSite;
      _sceneColor = sceneColor;
      _navTargets = navTargets;
      _canInheritTemplate = canInherit;
      _backgroundImage = bgImage;
      _backgroundRect = bgRect;
      _backgroundOpacity = bgOpacity;
      _loading = false;
    });

    if (_canInheritTemplate && elements.isEmpty && _isShotMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _offerInheritTemplate();
      });
    }
  }

  Future<void> _offerInheritTemplate() async {
    if (!_canInheritTemplate || _elements.isNotEmpty || !_isShotMode) return;
    final palette = context.palette;
    final inherit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text('Heredar planta', style: AppTypography.titleMedium(palette)),
        content: Text(
          'Este plano está vacío. ¿Quieres copiar la planta del set o '
          'localización vinculada como punto de partida?',
          style: AppTypography.bodyMedium(palette),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Empezar vacío', style: AppTypography.bodyMedium(palette)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Heredar',
              style: AppTypography.bodyMedium(palette)
                  .copyWith(color: palette.accent),
            ),
          ),
        ],
      ),
    );
    if (inherit == true && mounted) {
      await _inheritFromTemplate();
    }
  }

  Future<List<CameraPlanNavTarget>> _loadNavTargets(AppDatabase db) async {
    final scenes = await (db.select(db.scenes)
          ..where((s) => s.projectId.equals(widget.projectId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
        .get();
    final sets = await db.getLocationsMapForProject(widget.projectId);
    final sites = await db.watchSitesForProject(widget.projectId).first;
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
      final siteName = site?.name ??
          (scene.locationPureName.trim().isNotEmpty
              ? scene.locationPureName.trim()
              : 'Sin localización');
      final shots = await db.getShotsForScene(scene.id);
      for (final shot in shots) {
        targets.add(CameraPlanNavTarget(
          shotId: shot.id,
          sceneId: scene.id,
          sceneNumber: scene.number,
          shotNumber: shot.number,
          sceneName: scene.name,
          sceneColor: color,
          siteName: siteName,
        ));
      }
    }
    return targets;
  }

  void _jumpToShot(CameraPlanNavTarget target) {
    if (target.shotId == widget.shotId) return;
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
    await _repo.saveElements(
      scope: widget.scope,
      elements: _elements,
      siteId: widget.siteId,
      setId: widget.setId,
      shotId: widget.shotId,
    );
    if (!mounted) return;
    _showSnack('Plano guardado.');
  }

  Future<void> _inheritFromTemplate() async {
    if (!_isShotMode || _scene == null || widget.shotId == null) return;
    final ok = await _repo.seedShotFromSceneTemplate(widget.shotId!, _scene!);
    if (!mounted) return;
    if (!ok) {
      _showSnack('No hay plano de set ni maestro para heredar.');
      return;
    }
    await _load();
    _showSnack('Planta heredada del set/localización.');
  }

  Future<void> _saveAsSetPlan() async {
    if (_linkedSet == null) {
      _showSnack('Esta escena no tiene set vinculado.');
      return;
    }
    await _repo.saveElements(
      scope: FloorPlanScope.set,
      elements: _elements,
      setId: _linkedSet!.id,
    );
    if (!mounted) return;
    _showSnack('Planta guardada en set «${_linkedSet!.locationName}».');
  }

  Future<void> _saveAsSitePlan() async {
    if (_linkedSite == null) {
      _showSnack('Esta escena no tiene localización vinculada.');
      return;
    }
    await _repo.saveElements(
      scope: FloorPlanScope.site,
      elements: _elements,
      siteId: _linkedSite!.id,
    );
    if (!mounted) return;
    _showSnack('Planta guardada en localización «${_linkedSite!.name}».');
  }

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
                    Text('Escenas y planos', style: AppTypography.titleMedium(palette)),
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
                              left: BorderSide(color: group.accentColor, width: 4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.location_city_outlined,
                                  size: 16, color: palette.textSecondary),
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
                                fontWeight:
                                    selected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                            subtitle: t.sceneName.isNotEmpty
                                ? Text(t.sceneName,
                                    style: AppTypography.caption(palette))
                                : null,
                            trailing: selected
                                ? Icon(Icons.check_circle,
                                    color: palette.accent, size: 20)
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

  void _showSaveMenu() {
    if (!_isShotMode) {
      _saveCurrentPlan();
      return;
    }
    final palette = context.palette;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Guardar planta', style: AppTypography.titleMedium(palette)),
            ),
            if (_linkedSet != null)
              ListTile(
                leading: Icon(Icons.layers_outlined, color: palette.accent),
                title: Text('Planta de set', style: AppTypography.bodyLarge(palette)),
                subtitle: Text(
                  _linkedSet!.locationName,
                  style: AppTypography.caption(palette),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveAsSetPlan();
                },
              ),
            if (_linkedSite != null)
              ListTile(
                leading: Icon(Icons.location_city_outlined, color: palette.accent),
                title: Text('Planta de localización', style: AppTypography.bodyLarge(palette)),
                subtitle: Text(
                  _linkedSite!.name,
                  style: AppTypography.caption(palette),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveAsSitePlan();
                },
              ),
            if (_linkedSet == null && _linkedSite == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Vincula la escena a un set o localización para guardar la planta allí.',
                  style: AppTypography.bodyMedium(palette),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _persistElement(PlanElement el, {int? sortOrder}) async {
    if (!_isShotMode) {
      await _repo.saveElements(
        scope: widget.scope,
        elements: _elements,
        siteId: widget.siteId,
        setId: widget.setId,
      );
      return;
    }

    final db = ref.read(databaseProvider);
    final index = _elements.indexWhere((e) => e.id == el.id);
    final order = sortOrder ?? (index >= 0 ? index : _elements.length);

    if (el.id <= 0) {
      final newId = await db.insertCameraPlanElement(
        el.toCompanion(widget.shotId!, sortOrder: order),
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
          shotId: widget.shotId!,
          type: el.type.dbValue,
          x: el.position.dx,
          y: el.position.dy,
          rotation: el.rotation,
          label: el.label,
          color: el.type == ElementType.actor ? hexFromColor(el.actorColor) : null,
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
          sortOrder: order,
        ),
      );
      await db.replacePathPoints(
        el.id,
        el.pathPoints.map((p) => (x: p.dx, y: p.dy)).toList(),
      );
    }

    if (el.type == ElementType.camera && _shot != null) {
      await db.updateShot(_shot!.copyWith(
        lens: Value(el.lens ?? _shot!.lens),
        movement: Value(el.stabilization ?? _shot!.movement),
      ));
      _shot = (await (db.select(db.shots)
            ..where((s) => s.id.equals(widget.shotId!)))
          .getSingleOrNull());
    }
  }

  Future<void> _persistAllElements() async {
    if (!_isShotMode) {
      await _repo.saveElements(
        scope: widget.scope,
        elements: _elements,
        siteId: widget.siteId,
        setId: widget.setId,
      );
      return;
    }
    await _repo.saveElements(
      scope: FloorPlanScope.shot,
      elements: _elements,
      shotId: widget.shotId,
    );
  }

  Future<void> _addElement(PlanElement el) async {
    setState(() => _elements.add(el));
    await _persistElement(el);
    setState(() => _selected = el);
  }

  Future<void> _addCamera() async {
    final cameras = _elements.where((e) => e.type == ElementType.camera).length;
    final letter = String.fromCharCode(65 + cameras);
    await _addElement(PlanElement(
      id: 0,
      type: ElementType.camera,
      position: const Offset(200, 200),
      cameraLetter: letter,
      cameraNumber: cameras + 1,
      stabilization: _shot?.movement ?? 'STEADY',
      lens: _shot?.lens ?? '50mm',
    ));
  }

  Future<void> _addActor(Color color) async {
    final actorCount = _elements.where((e) => e.type == ElementType.actor).length;
    await _addElement(PlanElement(
      id: 0,
      type: ElementType.actor,
      position: Offset(150 + actorCount * 60.0, 150),
      label: 'Actor ${actorCount + 1}',
      actorColor: color,
    ));
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
    if (_selected == null) return;
    final id = _selected!.id;
    if (_isShotMode) {
      final db = ref.read(databaseProvider);
      if (id > 0) await db.deleteCameraPlanElement(id);
    }
    setState(() {
      _elements.remove(_selected);
      _selected = null;
      _selectedPathIndex = null;
    });
    if (!_isShotMode) {
      await _persistAllElements();
    }
  }

  Offset _toCanvasCoords(Offset localPos) {
    return (localPos - _canvasOffset) / _scale;
  }

  PlanElement? _elementAt(Offset canvasPos) {
    for (final el in _elements.reversed) {
      if ((el.position - canvasPos).distance < 28) return el;
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
    if (tapped != null) {
      setState(() {
        _selected = tapped;
        _selectedPathIndex = null;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final delta = d.delta / _scale;
    if (_selected != null &&
        _isDraggingPathPoint &&
        _selectedPathIndex != null) {
      setState(() {
        _selected!.pathPoints[_selectedPathIndex!] += delta;
      });
    } else if (_selected != null && _isRotating) {
      final canvasPos = _toCanvasCoords(d.localPosition);
      setState(() => _updateRotation(_selected!, canvasPos));
    } else if (_selected != null) {
      setState(() => _selected!.position += delta);
    } else {
      setState(() => _canvasOffset += d.delta);
    }
  }

  Future<void> _onPanEnd(DragEndDetails d) async {
    if (_selected != null &&
        (_isRotating || _isDraggingPathPoint || d.primaryVelocity != null)) {
      await _persistElement(_selected!);
    }
    _isRotating = false;
    _isDraggingPathPoint = false;
  }

  void _onTapCanvas(TapDownDetails d) {
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
    if (CameraPlanPainter.pathPointAt(
          _selected!,
          canvasPos,
          scale: _scale,
        ) !=
        null) {
      return;
    }
    _addPathPointAt(canvasPos);
  }

  void _zoomBy(double delta) {
    setState(() => _scale = (_scale + delta).clamp(0.4, 2.5));
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
                    widget.scope.title,
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.accent,
                    ),
                  ),
                  Text(
                    widget.label,
                    style: AppTypography.titleMedium(palette),
                  ),
                ],
              ),
        actions: [
          IconButton(
            tooltip: 'Alejar',
            icon: Icon(Icons.remove, color: palette.textSecondary),
            onPressed: () => _zoomBy(-0.1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text('${(_scale * 100).round()}%',
                style: AppTypography.caption(palette)),
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
                if (_canInheritTemplate && _elements.isEmpty)
                  Material(
                    color: palette.accent.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.layers_outlined,
                              color: palette.accent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Este plano está vacío. Hereda la planta del set o localización.',
                              style: AppTypography.bodyMedium(palette),
                            ),
                          ),
                          TextButton(
                            onPressed: _inheritFromTemplate,
                            child: Text(
                              'Heredar',
                              style: AppTypography.label(palette)
                                  .copyWith(color: palette.accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return GestureDetector(
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
                                  elements: _elements,
                                  selectedElement: _selected,
                                  selectedPathIndex: _selectedPathIndex,
                                  scale: _scale,
                                  offset: _canvasOffset,
                                  palette: palette,
                                  backgroundImage: _backgroundImage,
                                  backgroundRect: _backgroundRect,
                                  backgroundOpacity: _backgroundOpacity,
                                ),
                                child: Container(color: Colors.transparent),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_selected != null)
                        _ElementPanel(
                          palette: palette,
                          element: _selected!,
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
                _BottomToolbar(
                  palette: palette,
                  onAdd: _showAddMenu,
                  onScenes: _showSceneNavigator,
                  onSave: _showSaveMenu,
                  showScenes: _isShotMode,
                ),
              ],
            ),
    );
  }
}

class _BottomToolbar extends StatelessWidget {
  final AppPalette palette;
  final VoidCallback onAdd;
  final VoidCallback onScenes;
  final VoidCallback onSave;
  final bool showScenes;

  const _BottomToolbar({
    required this.palette,
    required this.onAdd,
    required this.onScenes,
    required this.onSave,
    this.showScenes = true,
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
          if (showScenes)
            _ToolbarButton(
              palette: palette,
              icon: Icons.view_list_outlined,
              label: 'Escenas',
              onTap: onScenes,
            )
          else
            const SizedBox(width: 72),
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
    final color = highlighted
        ? palette.accent
        : palette.textSecondary;

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
              style: AppTypography.caption(palette).copyWith(
                color: color,
                fontSize: 10,
              ),
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

  const _AddElementSheet({
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
                  Text('Añadir elemento',
                      style: AppTypography.titleMedium(palette)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: palette.textSecondary),
                    onPressed: () => Navigator.pop(context),
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
            return LightGridTile(
              type: type,
              onTap: () => onAdd(type),
            );
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
  final int? selectedPathIndex;
  final VoidCallback? onAddPathPoint;
  final VoidCallback? onDeletePathPoint;
  final VoidCallback? onClearPath;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const _ElementPanel({
    required this.palette,
    required this.element,
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
                  Text(element.displayLabel,
                      style: AppTypography.titleMedium(palette)),
                  const SizedBox(height: AppSpacing.md),
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
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.textTertiary,
                      fontSize: 10,
                    ),
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
                      style: AppTypography.caption(palette).copyWith(
                        color: palette.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    if (widget.selectedPathIndex != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Punto ${widget.selectedPathIndex! + 2} seleccionado',
                          style: AppTypography.caption(palette).copyWith(
                            color: palette.accent,
                            fontSize: 10,
                          ),
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
                            icon: Icon(Icons.remove, size: 16, color: palette.error),
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
                          style: AppTypography.caption(palette).copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    Text(
                      'Doble toque en el canvas para añadir un punto. '
                      'Arrastra los círculos numerados para mover la ruta.',
                      style: AppTypography.caption(palette).copyWith(
                        color: palette.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                  if (element.type == ElementType.camera ||
                      element.type == ElementType.light ||
                      element.type == ElementType.prop ||
                      element.type == ElementType.wall ||
                      element.type == ElementType.actor) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text('Compatibilidad 3D', style: AppTypography.caption(palette)),
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
                                          color: palette.textPrimary, width: 2)
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
                Text('Eliminar',
                    style: AppTypography.bodyMedium(palette)
                        .copyWith(color: palette.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
