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
import 'plan_sketch.dart';
import 'plan_target.dart';
import 'plan_thumbnail.dart';
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
  final _extraSets = <int>{};

  /// Planos marcados para arrastrarlos juntos.
  final _picked = <int>{};

  PlanProjectData get _data => widget.data;
  Scene get _scene => widget.scene;
  AppDatabase get _db => ref.read(databaseProvider);

  @override
  void didUpdateWidget(PlanSceneBoard old) {
    super.didUpdateWidget(old);
    if (old.scene.id != widget.scene.id) {
      _extraSets.clear();
      _picked.clear();
    }
  }

  /// Lleva unos planos a un set y a un esquema. Con el set de la escena no
  /// hace falta guardarlo: es el de partida.
  Future<void> _move(
    List<Shot> shots,
    LocationBasePlan? set,
    LightSetup? setup,
  ) async {
    for (final shot in shots) {
      await _db.moveShot(
        shot.id,
        setId: set == null || set.id == _scene.locationId ? null : set.id,
        lightSetupId: setup?.id,
      );
    }
    if (mounted) setState(_picked.clear);
  }

  Future<LightSetup> _newSetup(LocationBasePlan? set) =>
      FloorPlanRepository(_db).createLightSetup(
        projectId: widget.projectId,
        setId: set?.id,
        siteId: set == null ? _data.siteIdOfScene(_scene) : null,
      );

  /// Crea un boceto en el set y lo abre para dibujarlo. Con [shot], el
  /// boceto queda además a la vista en ese plano (en el guion técnico).
  Future<void> _newSketch(LocationBasePlan? set, {Shot? shot}) async {
    final created = await createPlanSketch(
      context,
      _db,
      projectId: widget.projectId,
      setId: set?.id,
      siteId: _data.siteIdOfScene(_scene),
      label: shot == null
          ? 'Esc ${_scene.number}'
          : 'Esc ${_scene.number} P${shot.number}',
    );
    if (created == null) return;
    if (shot != null) {
      await addShotPlanSketchSetup(
        db: _db,
        shot: shot,
        setupId: created.setup.id,
      );
    }
    widget.onOpen(
      PlanTarget.lightSetup(
        created.setup.id,
        created.setup.name,
        draw: created.freehand,
      ),
    );
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
    final sets = _data.boardSetsOf(_scene, extra: _extraSets);
    final addable = _data.setsToAdd(_scene, sets.map((s) => s?.id));
    final shots = _data.shotsOfScene(_scene.id);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SceneHeaderRow(
                sceneNumber: _scene.number,
                sceneColor: color,
                title: _scene.name.isNotEmpty
                    ? _scene.name
                    : formatSceneTitle(
                        number: _scene.number,
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
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          site == null
              ? 'Esta escena aún no tiene localización. Asígnale una en '
                    'Localizaciones para repartir sus planos por sets.'
              : 'Arrastra cada plano al esquema de luz con el que se rueda. '
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
        for (final set in sets) _setSection(palette, set),
        if (addable.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<int>(
              tooltip: 'Otro set de ${site?.name ?? 'la localización'}',
              onSelected: (id) => setState(() => _extraSets.add(id)),
              itemBuilder: (_) => [
                for (final set in addable)
                  PopupMenuItem(value: set.id, child: Text(set.locationName)),
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

  Widget _setSection(AppPalette palette, LocationBasePlan? set) {
    final setups = _data.boardSetupsOf(_scene, set?.id);
    final own = set?.id == _scene.locationId;
    final setColor = set == null
        ? palette.textTertiary
        : _data.colors.setColor(set);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 18, color: setColor),
              const SizedBox(width: 8),
              Text(
                set == null
                    ? 'SIN SET'
                    : 'SET ${set.locationName.toUpperCase()}',
                style: AppTypography.label(palette),
              ),
              const SizedBox(width: 8),
              if (set != null && own)
                Text(
                  'el de la escena',
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.textTertiary),
                ),
              const Spacer(),
              if (set != null)
                TextButton.icon(
                  onPressed: () =>
                      widget.onOpen(PlanTarget.set(set.id, set.locationName)),
                  icon: const Icon(Icons.grid_on_outlined, size: 15),
                  label: const Text('Planta del set'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              _column(palette, set: set, setup: null),
              for (final setup in setups)
                _column(palette, set: set, setup: setup),
              _NewSetupColumn(
                onTap: () => _newSetup(set),
                onSketch: () => _newSketch(set),
                onDrop: (shots) async =>
                    _move(shots, set, await _newSetup(set)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _column(
    AppPalette palette, {
    required LocationBasePlan? set,
    required LightSetup? setup,
  }) {
    final shots = _data.boardShots(_scene, set?.id, setup?.id);
    final color = setup == null
        ? palette.textTertiary
        : _data.setupColor(setup);
    return DragTarget<List<Shot>>(
      onWillAcceptWithDetails: (d) => d.data.any((s) => !shots.contains(s)),
      onAcceptWithDetails: (d) => _move(d.data, set, setup),
      builder: (context, candidate, _) => Container(
        key: ValueKey('col_${set?.id}_${setup?.id}'),
        width: _ShotCard.width + 20,
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
                        ..._data.ownOfSetup(setup),
                        for (final shot in shots)
                          ..._data.ownOfShot(shot, tagged: true),
                      ],
                      inherited: _data.inheritedOfSetup(setup),
                      drawings: _data.drawingsOfSetup(setup),
                      focus: _data.zoneOf(set),
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
                child: _ShotCard(
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
                  onSketch: () => _newSketch(set, shot: shot),
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
class _NewSetupColumn extends StatelessWidget {
  final VoidCallback onTap;

  /// Crear un boceto: un esquema para dibujar a mano o con elementos.
  final VoidCallback onSketch;
  final ValueChanged<List<Shot>> onDrop;

  const _NewSetupColumn({
    required this.onTap,
    required this.onSketch,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _target(palette),
        SizedBox(
          width: 120,
          child: TextButton.icon(
            onPressed: onSketch,
            icon: const Icon(Icons.draw_outlined, size: 15),
            label: const Text('Boceto nuevo'),
          ),
        ),
      ],
    );
  }

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
                'Esquema nuevo',
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
class _ShotCard extends StatelessWidget {
  final Shot shot;
  final PlanProjectData data;
  final bool picked;
  final List<Shot> Function() dragged;
  final VoidCallback onOpen;
  final VoidCallback onPick;
  final VoidCallback onSequence;

  /// Dibujar un boceto para este plano.
  final VoidCallback onSketch;

  const _ShotCard({
    required this.shot,
    required this.data,
    required this.picked,
    required this.dragged,
    required this.onOpen,
    required this.onPick,
    required this.onSequence,
    required this.onSketch,
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
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      shape: picked
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: palette.accent, width: 2),
            )
          : null,
      child: InkWell(
        onTap: () {
          final keys = HardwareKeyboard.instance;
          if (keys.isShiftPressed || keys.isMetaPressed) {
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
              child: drawn.isEmpty && drawings.isEmpty && sketches.isNotEmpty
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
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('P${shot.number}', style: AppTypography.label(palette)),
                  if (details.isNotEmpty)
                    Text(
                      details,
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                  'draw' => onSketch(),
                  _ => onSequence(),
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
                  const PopupMenuItem(
                    value: 'draw',
                    child: Text('Dibujar un boceto para este plano'),
                  ),
                  PopupMenuItem(
                    value: 'pick',
                    child: Text(picked ? 'Desmarcar' : 'Marcar para mover'),
                  ),
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
