import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/scene_format.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../core/widgets/scene_meta_display.dart';
import 'camera_plan_scene_badge.dart';
import 'floor_plan_repository.dart';
import 'light_setup_actions.dart';
import 'plan_data.dart';
import 'plan_guide.dart';
import 'plan_site_sets.dart' show groupLightCount;
import 'plan_item_actions.dart';
import 'plan_sketch.dart';
import 'plan_view_picker.dart';
import 'plan_target.dart';
import 'plan_thumbnail.dart';
import 'shot_cover.dart';
import 'shot_route.dart';
import '../../shared/rich_text/script_markup.dart';
import '../../shared/shot_images/shot_image_menu.dart';

/// Tablero de una escena: sus planos repartidos por set y por esquema de
/// luz. Cada plano es una tarjeta que se arrastra a la columna que toque.
///
/// La escena tiene una localización y no se sale de ella: el tablero solo
/// ofrece sus sets. La excepción es el plano secuencia, que lleva su
/// recorrido en una fila propia y puede pasar por otras localizaciones.
class PlanSceneBoard extends ConsumerStatefulWidget {
  final int projectId;
  final Scene scene;
  final PlanProjectData data;
  final void Function(PlanTarget target) onOpen;

  const PlanSceneBoard({
    super.key,
    required this.projectId,
    required this.scene,
    required this.data,
    required this.onOpen,
  });

  @override
  ConsumerState<PlanSceneBoard> createState() => _PlanSceneBoardState();
}

class _PlanSceneBoardState extends ConsumerState<PlanSceneBoard> {
  /// Sets añadidos al tablero a mano, aún sin planos.
  final _extraSetups = <int>{};

  /// Planos marcados para arrastrarlos juntos.
  final _picked = <int>{};

  PlanProjectData get _data => widget.data;
  Scene get _scene => widget.scene;
  AppDatabase get _db => ref.read(databaseProvider);

  @override
  void didUpdateWidget(PlanSceneBoard old) {
    super.didUpdateWidget(old);
    if (old.scene.id != widget.scene.id) {
      _extraSetups.clear();
      _picked.clear();
    }
  }

  /// Lleva unos planos a un set (SG.2). El entorno es siempre el de la
  /// localización de la escena: no se cambia de zona.
  Future<void> _move(List<Shot> shots, LightSetup? setup) async {
    for (final shot in shots) {
      await _db.moveShot(shot.id, setId: null, lightSetupId: setup?.id);
    }
    if (mounted) setState(_picked.clear);
  }

  Future<LightSetup> _newSetup(LocationBasePlan? set) =>
      FloorPlanRepository(_db).createLightSetup(
        projectId: widget.projectId,
        setId: set?.id,
        siteId: set == null ? _data.siteIdOfScene(_scene) : null,
      );

  /// Crea un boceto de la escena y lo abre. Con [shot], el boceto queda
  /// además a la vista en ese plano (en el guion técnico), pero no lleva
  /// planos: es para pensar la luz.
  Future<void> _newSketch({Shot? shot, String? kind}) async {
    final setId = shot == null ? _scene.locationId : _data.setIdOfShot(shot);
    final created = await createPlanSketch(
      context,
      _db,
      projectId: widget.projectId,
      sceneId: _scene.id,
      setId: setId,
      siteId: _data.siteIdOfScene(_scene),
      kind: kind,
      label: shot == null
          ? 'Esc ${_scene.label}'
          : 'Esc ${_scene.label} P${shot.number}',
    );
    if (created == null || !mounted) return;
    if (shot != null) {
      await addShotPlanSketchSetup(db: _db, shot: shot, setupId: created.id);
      if (!mounted) return;
    }
    await _openSketch(created);
  }

  Future<void> _openSketch(LightSetup sketch) async {
    if (sketch.kind == LightSetupKind.sketchFreehand) {
      await drawFreehandSketch(context, _db, sketch);
    } else {
      widget.onOpen(PlanTarget.lightSetup(sketch.id, sketch.name));
    }
  }

  Future<void> _makeSequence(Shot shot) async {
    final setId = _data.setIdOfShot(shot);
    await _db.saveShotRoute(
      shot.id,
      ShotRoute.encode([
        ShotLeg(
          siteId: _data.set(setId)?.siteId ?? _data.siteIdOfScene(_scene),
          setId: setId,
          lightSetupId: _data.setup(shot.lightSetupId)?.id,
        ),
      ]),
    );
  }

  /// Guarda el recorrido. El primer tramo es también el set y el esquema
  /// «del plano», para lo que no sabe de tramos (PDF, listas).
  Future<void> _saveRoute(Shot shot, List<ShotLeg> legs) async {
    await _db.saveShotRoute(shot.id, ShotRoute.encode(legs));
    if (legs.isEmpty) return;
    final first = legs.first;
    await _db.moveShot(
      shot.id,
      setId: first.setId == _scene.locationId ? null : first.setId,
      lightSetupId: first.lightSetupId,
    );
  }

  List<Shot> _dragged(Shot shot) => _picked.contains(shot.id)
      ? [
          for (final s in _data.shotsOfScene(_scene.id))
            if (_picked.contains(s.id)) s,
        ]
      : [shot];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = _data.colors.sceneColor(_scene);
    final location = locationFromCanonical(_scene.locationCanonical);
    final site = _data.site(_data.siteIdOfScene(_scene));
    final parts = _data.boardGroupsOf(_scene, extra: _extraSetups);
    final addable = _data.lightSetsToAdd(_scene, [
      for (final part in parts) ...part.sets.map((s) => s.id),
    ]);
    final shots = _data.shotsOfScene(_scene.id);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SceneHeaderRow(
                sceneNumber: _scene.label,
                sceneColor: color,
                title: _scene.name.isNotEmpty
                    ? _scene.name
                    : formatSceneTitle(
                        number: _scene.label,
                        intExt: _scene.intExt,
                        dayNight: _scene.dayNight,
                        location: location,
                      ),
                subtitleWidget: SceneMetaDisplay(
                  intExt: _scene.intExt,
                  dayNight: _scene.dayNight,
                  location: location,
                  style: AppTypography.caption(palette),
                ),
                palette: palette,
              ),
            ),
            if (site != null)
              _MasterPlanChip(
                site: site,
                data: _data,
                onTap: () => widget.onOpen(PlanTarget.site(site.id, site.name)),
              ),
            IconButton(
              tooltip: site == null
                  ? 'Elegir la localización de la escena'
                  : 'Cambiar la localización de la escena',
              icon: Icon(
                site == null
                    ? Icons.add_location_alt_outlined
                    : Icons.edit_location_alt_outlined,
                color: palette.textSecondary,
              ),
              onPressed: () => site == null
                  ? pickSiteForScene(context, _db, _scene)
                  : changeSceneSite(context, _db, _scene),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          site == null
              ? 'Esta escena aún no tiene localización. Elígela con el botón '
                    'de arriba para repartir sus planos por sets.'
              : 'Arrastra cada plano al set con el que se rueda. '
                    'Con Mayús o Cmd se marcan varios para moverlos juntos.',
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textTertiary),
        ),
        if (shots.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Text(
              'Sin planos en esta escena.',
              style: AppTypography.bodyMedium(palette),
            ),
          ),
        for (final shot in _data.sequencesOf(_scene))
          _SequenceCard(
            shot: shot,
            scene: _scene,
            data: _data,
            onOpen: widget.onOpen,
            onSave: (legs) => _saveRoute(shot, legs),
            onNewSetup: (set) => _newSetup(set),
          ),
        PlanSketchStrip(
          title: 'BOCETOS DE ESTA ESCENA',
          sketches: _data.sketchesOfScene(_scene.id),
          data: _data,
          onOpen: _openSketch,
          onNewElements: () => _newSketch(kind: LightSetupKind.sketchElements),
          onNewFreehand: () => _newSketch(kind: LightSetupKind.sketchFreehand),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              _column(palette, setup: null),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlanNewSetColumn(
                    onTap: () => _newSetup(_data.set(_scene.locationId)),
                    onDrop: (shots) async => _move(
                      shots,
                      await _newSetup(_data.set(_scene.locationId)),
                    ),
                  ),
                  PlanPasteButton(
                    target: PlanPasteTarget(
                      siteId: _data.siteIdOfScene(_scene),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        for (final part in parts) _groupSection(palette, part.group, part.sets),
        if (addable.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<int>(
              tooltip: 'Otro set de ${site?.name ?? 'la localización'}',
              onSelected: (id) => setState(() => _extraSetups.add(id)),
              itemBuilder: (_) => [
                for (final s in addable)
                  PopupMenuItem(
                    value: s.id,
                    child: Text(
                      [
                        s.name,
                        if (_data.group(s.groupId) case final g?) g.name,
                      ].join(' · '),
                    ),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: palette.accent),
                    const SizedBox(width: 4),
                    Text(
                      'Otro set de ${site?.name ?? 'la localización'}',
                      style: AppTypography.bodyMedium(
                        palette,
                      ).copyWith(color: palette.accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Una fila del tablero: los sets de un grupo (que comparten la luz), o
  /// los sueltos.
  Widget _groupSection(
    AppPalette palette,
    SetGroup? group,
    List<LightSetup> sets,
  ) {
    final lights = group == null ? 0 : groupLightCount(group);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                group == null ? Icons.layers_outlined : Icons.folder_outlined,
                size: 16,
                color: group == null ? palette.textTertiary : palette.accent,
              ),
              const SizedBox(width: 8),
              Text(
                group == null ? 'SETS' : group.name.toUpperCase(),
                style: AppTypography.label(palette),
              ),
              if (group != null) ...[
                const SizedBox(width: 8),
                Text(
                  lights == 0
                      ? 'luz compartida, aún vacía'
                      : 'comparten $lights luces',
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.textTertiary),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              for (final setup in sets) _column(palette, setup: setup),
            ],
          ),
        ],
      ),
    );
  }

  Widget _column(AppPalette palette, {required LightSetup? setup}) {
    final shots = _data.boardShotsOfSet(_scene, setup?.id);
    final color = setup == null
        ? palette.textTertiary
        : _data.setupColor(setup);
    final target = DragTarget<List<Shot>>(
      onWillAcceptWithDetails: (d) => d.data.any((s) => !shots.contains(s)),
      onAcceptWithDetails: (d) => _move(d.data, setup),
      builder: (context, candidate, _) => Container(
        key: ValueKey('col_${setup?.id}'),
        width: PlanBoardShotCard.width + 20,
        constraints: const BoxConstraints(minHeight: 150),
        decoration: BoxDecoration(
          color: candidate.isNotEmpty
              ? palette.accent.withValues(alpha: 0.14)
              : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: candidate.isNotEmpty
                ? palette.accent
                : color.withValues(alpha: 0.35),
            width: candidate.isNotEmpty ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (setup == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Sin luz',
                  style: AppTypography.label(
                    palette,
                  ).copyWith(color: palette.textSecondary),
                ),
              )
            else ...[
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      setup.name,
                      style: AppTypography.label(palette),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: LightSetupMenuButton(
                      setup: setup,
                      shotCount: _data.shotsOfSetup(setup.id).length,
                    ),
                  ),
                ],
              ),
              Text(
                lightSetupStatusLabel(setup.status),
                style: AppTypography.caption(
                  palette,
                ).copyWith(color: palette.textTertiary, fontSize: 10),
              ),
              const SizedBox(height: 6),
              // La planta del esquema: se toca y se abre.
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => widget.onOpen(
                    PlanTarget.lightSetup(setup.id, setup.name),
                  ),
                  child: SizedBox(
                    height: 84,
                    width: double.infinity,
                    child: PlanThumbnail(
                      elements: [
                        ..._data.groupLightOf(setup),
                        ..._data.ownOfSetup(setup),
                        for (final shot in shots)
                          ..._data.ownOfShot(shot, tagged: true),
                      ],
                      inherited: _data.inheritedOfSetup(setup),
                      drawings: _data.drawingsOfSetup(setup),
                      focus: _data.zoneOf(_data.set(setup.locationBasePlanId)),
                      emptyIcon: Icons.wb_incandescent_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            for (final shot in shots)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PlanBoardShotCard(
                  shot: shot,
                  data: _data,
                  picked: _picked.contains(shot.id),
                  dragged: () => _dragged(shot),
                  onOpen: () => widget.onOpen(
                    PlanTarget.shot(shot.id, _data.shotLabel(shot)),
                  ),
                  onPick: () => setState(() {
                    if (!_picked.remove(shot.id)) _picked.add(shot.id);
                  }),
                  onSequence: () => _makeSequence(shot),
                  onSketch: () => _newSketch(shot: shot),
                  onSection: () =>
                      showPlanViewPicker(context, data: _data, shot: shot),
                ),
              ),
            if (shots.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Suelta planos aquí',
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.textTertiary),
                ),
              ),
          ],
        ),
      ),
    );
    if (setup == null) return target;
    final actions = LightSetupActions(
      context,
      _db,
      setup,
      _data.shotsOfSetup(setup.id).length,
    );
    return PlanItemKeys(
      onCopy: actions.copy,
      onDuplicate: actions.duplicate,
      onPaste: actions.pasteBeside,
      onDelete: actions.delete,
      child: target,
    );
  }
}

/// La miniatura del plano maestro de la localización, en la cabecera.
class _MasterPlanChip extends StatelessWidget {
  final LocationSite site;
  final PlanProjectData data;
  final VoidCallback onTap;

  const _MasterPlanChip({
    required this.site,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = data.colors.siteColor(site.id);
    return Material(
      color: palette.surfaceElevated,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 4, height: 44, color: color),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    site.name.toUpperCase(),
                    style: AppTypography.label(palette),
                  ),
                  Text('Plano maestro', style: AppTypography.caption(palette)),
                ],
              ),
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 96,
                  height: 56,
                  child: PlanThumbnail(
                    elements: data.environmentOf(site.id),
                    zones: data.zonesOfSite(site.id),
                    emptyIcon: Icons.map_outlined,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La columna «+ esquema»: tocarla crea uno; soltar planos encima lo crea
/// con ellos dentro.
class PlanNewSetColumn extends StatelessWidget {
  final VoidCallback onTap;
  final ValueChanged<List<Shot>> onDrop;

  const PlanNewSetColumn({
    super.key,
    required this.onTap,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) => _target(context.palette);

  Widget _target(AppPalette palette) {
    return DragTarget<List<Shot>>(
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidate, _) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 120,
          height: 150,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: candidate.isNotEmpty
                ? palette.accent.withValues(alpha: 0.14)
                : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: candidate.isNotEmpty ? palette.accent : palette.border,
              width: candidate.isNotEmpty ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: palette.textSecondary),
              const SizedBox(height: 4),
              Text(
                'Set nuevo',
                style: AppTypography.caption(palette),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un plano en el tablero. Se toca para abrir su planta y se arrastra para
/// cambiarlo de esquema o de set.
class PlanBoardShotCard extends StatelessWidget {
  final Shot shot;
  final PlanProjectData data;
  final bool picked;
  final List<Shot> Function() dragged;
  final VoidCallback onOpen;
  final VoidCallback onPick;
  final VoidCallback? onSequence;

  /// Dibujar un boceto para este plano.
  final VoidCallback? onSketch;

  /// Elegir la parte de la planta que sale en los documentos.
  final VoidCallback? onSection;

  /// Con la escena delante del número («11·P3»): en el tablero de la
  /// localización, donde se mezclan escenas.
  final bool sceneTag;

  /// Marca con las cámaras del plano (A, B…) o «sin cámara».
  final bool showCameras;

  const PlanBoardShotCard({
    super.key,
    required this.shot,
    required this.data,
    required this.picked,
    required this.dragged,
    required this.onOpen,
    required this.onPick,
    this.onSequence,
    this.onSketch,
    this.onSection,
    this.sceneTag = false,
    this.showCameras = false,
  });

  static const double width = 168;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final details = [
      if (shot.framing?.isNotEmpty == true) scriptMarkupToPlain(shot.framing),
      if (shot.lens?.isNotEmpty == true) shot.lens!,
      if (shot.movement?.isNotEmpty == true) shot.movement!,
    ].join(' · ');
    // Sin planta dibujada, el boceto (una imagen) ocupa su sitio.
    final sketches = planSketchesOf(shot);
    final entries = planSketchEntriesOf(shot);
    final drawn = [...data.lightOfShot(shot), ...data.ownOfShot(shot)];
    final drawings = data.drawingsOfShot(shot);
    void sketchMenu() => showShotImageMenu(
      context,
      shot,
      target: ShotImageTarget.planSketch,
      sketches: planSketchDelegate,
    );

    final card = Material(
      color: palette.surfaceElevated,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: picked
            ? BorderSide(color: palette.accent, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          final keys = HardwareKeyboard.instance;
          if (keys.isShiftPressed ||
              keys.isMetaPressed ||
              keys.isControlPressed) {
            onPick();
          } else {
            onOpen();
          }
        },
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 48,
              // La imagen del plano (storyboard o referencia); sin ella, su
              // planta o el boceto.
              child:
                  shotCoverThumbnail(shot, cacheWidth: 200) ??
                  (drawn.isEmpty && drawings.isEmpty && sketches.isNotEmpty
                      ? Tooltip(
                          message: 'Boceto de planta · clic para verlo',
                          child: GestureDetector(
                            onTap: sketchMenu,
                            child: Image.file(
                              File(sketches.last),
                              fit: BoxFit.cover,
                              cacheWidth: 200,
                            ),
                          ),
                        )
                      : PlanThumbnail(
                          elements: drawn,
                          drawings: drawings,
                          inherited: data.baseOfShot(shot),
                          focus: data.zoneOf(data.set(data.setIdOfShot(shot))),
                          emptyIcon: Icons.videocam_outlined,
                        )),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sceneTag
                        ? '${data.scene(shot.sceneId)?.label ?? '–'}·P${shot.number}'
                        : 'P${shot.number}',
                    style: AppTypography.label(palette),
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details,
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (showCameras)
                    PlanShotCameraBadges(cameras: data.camerasOfShot(shot)),
                ],
              ),
            ),
            SizedBox(
              width: 26,
              child: PopupMenuButton<String>(
                tooltip: 'Opciones del plano',
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: Icon(Icons.more_vert, color: palette.textTertiary),
                onSelected: (action) => switch (action) {
                  'open' => onOpen(),
                  'pick' => onPick(),
                  'sketch' => sketchMenu(),
                  'draw' => onSketch?.call(),
                  'section' => onSection?.call(),
                  _ => onSequence?.call(),
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'open',
                    child: Text('Abrir planta'),
                  ),
                  PopupMenuItem(
                    value: 'sketch',
                    child: Text(
                      entries.isEmpty
                          ? 'Añadir boceto (imagen)'
                          : 'Bocetos de planta (${entries.length})',
                    ),
                  ),
                  if (onSketch != null)
                    const PopupMenuItem(
                      value: 'draw',
                      child: Text('Dibujar un boceto para este plano'),
                    ),
                  if (onSection != null)
                    const PopupMenuItem(
                      value: 'section',
                      child: Text('Sección para documentos…'),
                    ),
                  PopupMenuItem(
                    value: 'pick',
                    child: Text(picked ? 'Desmarcar' : 'Marcar para mover'),
                  ),
                  if (onSequence != null)
                    const PopupMenuItem(
                      value: 'sequence',
                      child: Text('Es un plano secuencia'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Draggable<List<Shot>>(
      data: dragged(),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Builder(
        builder: (context) {
          final moving = dragged();
          return Material(
            color: palette.accent,
            borderRadius: BorderRadius.circular(8),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                moving.length == 1
                    ? 'P${moving.single.number}'
                    : '${moving.length} planos',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: SizedBox(width: width, child: card),
    );
  }
}

/// Un plano secuencia: su recorrido, tramo a tramo. Cada tramo tiene su
/// set, su esquema de luz y su planta. Es el único plano que puede salir
/// de la localización de su escena.
class _SequenceCard extends StatelessWidget {
  final Shot shot;
  final Scene scene;
  final PlanProjectData data;
  final void Function(PlanTarget target) onOpen;
  final Future<void> Function(List<ShotLeg> legs) onSave;
  final Future<LightSetup> Function(LocationBasePlan? set) onNewSetup;

  const _SequenceCard({
    required this.shot,
    required this.scene,
    required this.data,
    required this.onOpen,
    required this.onSave,
    required this.onNewSetup,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final legs = data.legsOf(shot);
    final homeSite = data.siteIdOfScene(scene);

    List<ShotLeg> swapped(int a, int b) {
      final next = [...legs];
      final moved = next[a];
      next[a] = next[b];
      next[b] = moved;
      return next;
    }

    Widget legTile(int index) {
      final leg = legs[index];
      final set = data.set(leg.setId);
      final site = data.site(set?.siteId ?? leg.siteId);
      final setup = data.setup(leg.lightSetupId);
      final setups = set == null
          ? const <LightSetup>[]
          : data.setupsOfSet(set.id);
      final away = site != null && site.id != homeSite;
      return SizedBox(
        width: 176,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: palette.accent,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    set?.locationName ?? site?.name ?? 'Sin set',
                    style: AppTypography.label(palette),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Fuera de la localización de la escena: se dice dónde.
            Text(
              away ? 'en ${site.name}' : ' ',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.warning, fontSize: 10),
            ),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onOpen(
                  PlanTarget.shot(
                    shot.id,
                    '${data.shotLabel(shot)} · tramo ${index + 1}',
                    leg: index,
                  ),
                ),
                child: SizedBox(
                  height: 90,
                  width: double.infinity,
                  child: PlanThumbnail(
                    elements: [
                      if (setup != null) ...data.ownOfSetup(setup),
                      ...data.ownOfLeg(shot, index),
                    ],
                    inherited: data.baseOfLeg(leg),
                    focus: data.zoneOf(set),
                    emptyIcon: Icons.videocam_outlined,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: PopupMenuButton<int>(
                    tooltip: 'Esquema de luz del tramo',
                    onSelected: (id) async {
                      final next = [...legs];
                      if (id == -2) {
                        final created = await onNewSetup(set);
                        next[index] = leg.copyWith(lightSetupId: created.id);
                      } else if (id == -1) {
                        next[index] = leg.copyWith(clearSetup: true);
                      } else {
                        next[index] = leg.copyWith(lightSetupId: id);
                      }
                      await onSave(next);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: -1, child: Text('Sin luz')),
                      for (final s in setups)
                        PopupMenuItem(value: s.id, child: Text(s.name)),
                      const PopupMenuItem(
                        value: -2,
                        child: Text('Esquema nuevo…'),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: setup == null
                                  ? palette.textTertiary
                                  : data.setupColor(setup),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              setup?.name ?? 'Sin luz',
                              style: AppTypography.caption(palette),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (index > 0)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Antes',
                    icon: const Icon(Icons.chevron_left, size: 16),
                    onPressed: () => onSave(swapped(index, index - 1)),
                  ),
                if (index < legs.length - 1)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Después',
                    icon: const Icon(Icons.chevron_right, size: 16),
                    onPressed: () => onSave(swapped(index, index + 1)),
                  ),
                if (legs.length > 1)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Quitar tramo',
                    icon: const Icon(Icons.close, size: 15),
                    onPressed: () => onSave([...legs]..removeAt(index)),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_outlined, size: 16, color: palette.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'P${shot.number} · PLANO SECUENCIA',
                  style: AppTypography.label(palette),
                ),
              ),
              TextButton(
                onPressed: () => onSave(const []),
                child: const Text('Deja de ser secuencia'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: AppSpacing.md,
            children: [
              for (var i = 0; i < legs.length; i++) ...[
                legTile(i),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    i < legs.length - 1
                        ? Icons.arrow_forward
                        : Icons.more_horiz,
                    size: 18,
                    color: palette.textTertiary,
                  ),
                ),
              ],
              // Aquí sí se puede salir de la localización de la escena.
              PopupMenuButton<int>(
                tooltip: 'Añadir un tramo',
                onSelected: (setId) {
                  final set = data.set(setId);
                  onSave([...legs, ShotLeg(siteId: set?.siteId, setId: setId)]);
                },
                itemBuilder: (_) => [
                  for (final site in data.sites) ...[
                    PopupMenuItem<int>(
                      enabled: false,
                      height: 28,
                      child: Text(
                        site.name.toUpperCase(),
                        style: AppTypography.caption(palette),
                      ),
                    ),
                    for (final set in data.setsOfSite(site.id))
                      PopupMenuItem(
                        value: set.id,
                        child: Text(set.locationName),
                      ),
                  ],
                ],
                child: Container(
                  width: 110,
                  height: 90,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: palette.textSecondary),
                      Text('Tramo', style: AppTypography.caption(palette)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Las cámaras de un plano como marcas pequeñas («CAM A»), o un aviso
/// «sin cámara» si no tiene ninguna.
class PlanShotCameraBadges extends StatelessWidget {
  final List<String> cameras;

  const PlanShotCameraBadges({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget badge(String text, Color color) => Container(
      margin: const EdgeInsets.only(top: 3, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
    return Wrap(
      children: cameras.isEmpty
          ? [badge('SIN CÁMARA', palette.warning)]
          : [for (final c in cameras) badge('CAM $c', palette.success)],
    );
  }
}
