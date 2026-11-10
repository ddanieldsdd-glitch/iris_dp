import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_constants.dart';
import 'floor_plan_json.dart';
import 'light_setup_actions.dart';
import 'plan_data.dart';
import 'plan_scene_board.dart' show PlanBoardShotCard, PlanNewSetColumn;
import 'plan_set_summary.dart';
import 'plan_target.dart';
import 'plan_thumbnail.dart';
import 'set_group_actions.dart';
import 'plan_start_from.dart' show createSetupAsked;
import 'project_focus.dart';

/// Los sets de una localización como tablero (SV.1): cada columna es un
/// set con su planta arriba y sus planos debajo (imagen, número y tipo).
/// Los planos se arrastran entre sets, a «Set nuevo» o a «Sin set»; los
/// sets se arrastran por su asa para cambiar el orden de rodaje, que es el
/// del PDF.
class PlanSiteSets extends ConsumerStatefulWidget {
  final int projectId;
  final LocationSite site;
  final PlanProjectData data;
  final void Function(PlanTarget target) onOpen;

  /// Mapa de la localización, que se enseña con el botón «Mapa».
  final VoidCallback? onMap;

  const PlanSiteSets({
    super.key,
    required this.projectId,
    required this.site,
    required this.data,
    required this.onOpen,
    this.onMap,
  });

  @override
  ConsumerState<PlanSiteSets> createState() => _PlanSiteSetsState();
}

class _PlanSiteSetsState extends ConsumerState<PlanSiteSets> {
  /// Planos marcados para arrastrarlos juntos.
  final _picked = <int>{};

  PlanProjectData get data => widget.data;
  LocationSite get site => widget.site;
  AppDatabase get _db => ref.read(databaseProvider);

  /// Los sets en el orden de rodaje.
  List<LightSetup> get _ordered => [
    for (final part in data.orderedSets(site.id)) ...part.sets,
  ];

  Future<void> _move(List<Shot> shots, LightSetup? setup) async {
    for (final shot in shots) {
      await _db.moveShot(shot.id, setId: null, lightSetupId: setup?.id);
    }
    if (mounted) setState(_picked.clear);
  }

  /// El set que se estaba editando si es de aquí; si no, el último.
  LightSetup? get _previousSet {
    final focused = ref.read(projectFocusProvider(widget.projectId)).setupId;
    return _ordered.where((s) => s.id == focused).firstOrNull ??
        _ordered.lastOrNull;
  }

  Future<LightSetup?> _newSet() => createSetupAsked(
    context,
    _db,
    projectId: widget.projectId,
    siteId: site.id,
    previous: _previousSet,
  );

  /// Pone [moved] en el sitio de [target]: el orden pasa a ser «a mano».
  Future<void> _reorder(LightSetup moved, LightSetup target) async {
    final list = [..._ordered];
    final from = list.indexWhere((s) => s.id == moved.id);
    final to = list.indexWhere((s) => s.id == target.id);
    if (from < 0 || to < 0 || from == to) return;
    list.insert(to, list.removeAt(from));
    for (final (i, s) in list.indexed) {
      if (s.shootOrder != i) await _db.setLightSetupShootOrder(s.id, i);
    }
    if (site.setOrderMode != SetOrderMode.manual.name) {
      await _db.setSiteSetOrderMode(site.id, SetOrderMode.manual.name);
    }
  }

  List<Shot> _dragged(Shot shot, List<Shot> column) => _picked.contains(shot.id)
      ? [
          for (final s in data.shots)
            if (_picked.contains(s.id)) s,
        ]
      : [shot];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ordered = _ordered;
    final loose = [
      for (final s in ordered)
        if (data.group(s.groupId) == null) s,
    ];
    final withoutSet = data.shotsWithoutSetOfSite(site.id);

    Future<void> groupSets() async {
      final picked = await _pickSets(context, loose);
      if (picked == null || picked.isEmpty || !context.mounted) return;
      await SetGroupActions(
        context,
        _db,
      ).createWith(projectId: widget.projectId, siteId: site.id, sets: picked);
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 22,
              color: data.colors.siteColor(site.id),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                site.name,
                style: AppTypography.titleMedium(palette),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  widget.onOpen(PlanTarget.site(site.id, site.name)),
              icon: const Icon(Icons.home_work_outlined, size: 16),
              label: const Text('Entorno'),
            ),
            if (widget.onMap != null)
              TextButton.icon(
                onPressed: widget.onMap,
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('Mapa'),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 14, top: 2),
          child: Text(
            'Arrastra cada plano al set con el que se rueda (Mayús o Cmd '
            'marcan varios). Arrastra un set por su asa para cambiar el '
            'orden de rodaje: es el del PDF.',
            style: AppTypography.caption(
              palette,
            ).copyWith(color: palette.textTertiary),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () async {
                final created = await _newSet();
                if (created == null) return;
                widget.onOpen(PlanTarget.lightSetup(created.id, created.name));
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nuevo set'),
            ),
            if (loose.isNotEmpty)
              OutlinedButton.icon(
                onPressed: groupSets,
                icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                label: const Text('Agrupar sets…'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            if (withoutSet.isNotEmpty) _withoutSetColumn(palette, withoutSet),
            for (final (i, s) in ordered.indexed)
              _SetColumn(
                key: ValueKey('set-${s.id}'),
                setup: s,
                order: i + 1,
                data: data,
                site: site,
                picked: _picked,
                onOpen: widget.onOpen,
                onDrop: (shots) => _move(shots, s),
                onReorder: (moved) => _reorder(moved, s),
                onPick: (shot) => setState(() {
                  if (!_picked.remove(shot.id)) _picked.add(shot.id);
                }),
                dragged: (shot) => _dragged(shot, const []),
              ),
            PlanNewSetColumn(
              key: const ValueKey('site-new-set'),
              onTap: () async {
                final created = await _newSet();
                if (created == null) return;
                widget.onOpen(PlanTarget.lightSetup(created.id, created.name));
              },
              onDrop: (shots) async {
                final created = await _newSet();
                if (created != null) await _move(shots, created);
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Los planos de la localización que aún no tienen set.
  Widget _withoutSetColumn(AppPalette palette, List<Shot> shots) {
    return DragTarget<List<Shot>>(
      onWillAcceptWithDetails: (d) => d.data.any((s) => !shots.contains(s)),
      onAcceptWithDetails: (d) => _move(d.data, null),
      builder: (context, candidate, _) => Container(
        key: const ValueKey('site-without-set'),
        width: PlanBoardShotCard.width + 20,
        padding: const EdgeInsets.all(10),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Planos sin set',
              style: AppTypography.label(
                palette,
              ).copyWith(color: palette.textSecondary),
            ),
            Text(
              '${shots.length} plano${shots.length == 1 ? '' : 's'}',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary, fontSize: 10),
            ),
            const SizedBox(height: 8),
            for (final shot in shots)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PlanBoardShotCard(
                  key: ValueKey('site-shot-${shot.id}'),
                  shot: shot,
                  data: data,
                  sceneTag: true,
                  picked: _picked.contains(shot.id),
                  dragged: () => _dragged(shot, shots),
                  onOpen: () => widget.onOpen(
                    PlanTarget.shot(shot.id, data.shotLabel(shot)),
                  ),
                  onPick: () => setState(() {
                    if (!_picked.remove(shot.id)) _picked.add(shot.id);
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Elige sets para agruparlos.
  Future<List<LightSetup>?> _pickSets(
    BuildContext context,
    List<LightSetup> options,
  ) {
    final palette = context.palette;
    final picked = <LightSetup>{};
    return showDialog<List<LightSetup>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: palette.surfaceElevated,
          title: Text(
            '¿Qué sets van juntos?',
            style: AppTypography.titleMedium(palette),
          ),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  'Por ejemplo, los que tienen el mismo fondo. Compartirán '
                  'la luz.',
                  style: AppTypography.caption(palette),
                ),
                for (final s in options)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: picked.contains(s),
                    onChanged: (v) => setState(
                      () => v == true ? picked.add(s) : picked.remove(s),
                    ),
                    title: Text(s.name),
                    subtitle: Text(_scenesLabel(data, s)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: picked.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, [
                      for (final s in options)
                        if (picked.contains(s)) s,
                    ]),
              child: const Text('Siguiente'),
            ),
          ],
        ),
      ),
    );
  }
}

String _scenesLabel(PlanProjectData data, LightSetup setup) {
  final scenes = data.scenesOfSetup(setup.id);
  if (scenes.isEmpty) return 'Sin planos';
  return 'Esc ${scenes.map((s) => s.label).join(', ')}';
}

/// Luces de la luz compartida de un grupo.
int groupLightCount(SetGroup group) => FloorPlanJson.decode(
  group.planJson,
).where((e) => e.type == ElementType.light).length;

class _Chip extends StatelessWidget {
  final String text;
  final Color color;

  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: AppTypography.caption(
          palette,
        ).copyWith(color: palette.textPrimary, fontSize: 11),
      ),
    );
  }
}

/// Un set en el tablero de la localización: asa para reordenarlo, nombre,
/// grupo, resumen (cuándo, luz y cámaras), su planta y sus planos.
class _SetColumn extends ConsumerWidget {
  final LightSetup setup;
  final int order;
  final PlanProjectData data;
  final LocationSite site;
  final Set<int> picked;
  final void Function(PlanTarget target) onOpen;
  final ValueChanged<List<Shot>> onDrop;
  final ValueChanged<LightSetup> onReorder;
  final ValueChanged<Shot> onPick;
  final List<Shot> Function(Shot shot) dragged;

  const _SetColumn({
    super.key,
    required this.setup,
    required this.order,
    required this.data,
    required this.site,
    required this.picked,
    required this.onOpen,
    required this.onDrop,
    required this.onReorder,
    required this.onPick,
    required this.dragged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.read(databaseProvider);
    final shots = data.shotsOfSetup(setup.id);
    final group = data.group(setup.groupId);
    final groups = data.groupsOfSite(site.id);
    final color = data.setupColor(setup);
    final summary = SetSummary.of(data, setup);
    final ownLights = data
        .ownOfSetup(setup)
        .where((e) => e.type == ElementType.light)
        .length;

    Widget groupMenu() => PopupMenuButton<String>(
      tooltip: 'Grupo del set',
      padding: EdgeInsets.zero,
      iconSize: 18,
      icon: Icon(
        Icons.folder_open_outlined,
        size: 18,
        color: palette.textSecondary,
      ),
      onSelected: (action) async {
        final actions = SetGroupActions(context, db);
        if (action.startsWith('group:')) {
          await actions.moveTo(setup, int.parse(action.substring(6)));
        } else if (action == 'ungroup') {
          await actions.moveTo(setup, null);
        } else if (action == 'new') {
          await actions.createWith(
            projectId: setup.projectId,
            siteId: site.id,
            sets: [setup],
          );
        } else if (action == 'share' && group != null) {
          await actions.shareLight(setup, group.id);
        } else if (action == 'rename' && group != null) {
          await actions.rename(group);
        }
      },
      itemBuilder: (_) => [
        for (final g in groups)
          if (g.id != setup.groupId)
            PopupMenuItem(
              value: 'group:${g.id}',
              child: Text('Mover a «${g.name}»'),
            ),
        const PopupMenuItem(
          value: 'new',
          child: Text('Crear grupo con este set…'),
        ),
        if (group != null) ...[
          const PopupMenuDivider(),
          if (ownLights > 0)
            PopupMenuItem(
              value: 'share',
              child: Text('Pasar sus luces a «${group.name}»'),
            ),
          PopupMenuItem(
            value: 'rename',
            child: Text('Renombrar «${group.name}»'),
          ),
          const PopupMenuItem(value: 'ungroup', child: Text('Sacar del grupo')),
        ],
      ],
    );

    final handle = Draggable<LightSetup>(
      data: setup,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            setup.name,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Tooltip(
          message: 'Arrastra para cambiar el orden de rodaje',
          child: Icon(
            Icons.drag_indicator,
            key: ValueKey('set-grip-${setup.id}'),
            size: 18,
            color: palette.textTertiary,
          ),
        ),
      ),
    );

    Widget column(bool shotOver, bool setOver) => Container(
      width: PlanBoardShotCard.width + 20,
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: shotOver || setOver
            ? palette.accent.withValues(alpha: 0.14)
            : color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: shotOver || setOver
              ? palette.accent
              : color.withValues(alpha: 0.45),
          width: shotOver || setOver ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              handle,
              const SizedBox(width: 2),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '$orderº',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 26, height: 28, child: groupMenu()),
              SizedBox(
                width: 26,
                height: 28,
                child: LightSetupMenuButton(
                  setup: setup,
                  shotCount: shots.length,
                ),
              ),
            ],
          ),
          if (group != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _Chip(
                text: '${group.name} · luz compartida',
                color: palette.accent,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 3, bottom: 6),
            child: Text(
              [
                if (summary.when != null) summary.when!,
                summary.lightText,
                summary.cameraText,
              ].join(' · '),
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary, fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // La planta del set: se toca y se abre.
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('set-open-${setup.id}'),
              onTap: () => onOpen(PlanTarget.lightSetup(setup.id, setup.name)),
              child: SizedBox(
                height: 92,
                width: double.infinity,
                child: PlanThumbnail(
                  elements: [
                    ...data.groupLightOf(setup),
                    ...data.ownOfSetup(setup),
                  ],
                  inherited: data.inheritedOfSetup(setup),
                  drawings: data.drawingsOfSetup(setup),
                  emptyIcon: Icons.wb_incandescent_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final shot in shots)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PlanBoardShotCard(
                key: ValueKey('site-shot-${shot.id}'),
                shot: shot,
                data: data,
                sceneTag: true,
                showCameras: true,
                picked: picked.contains(shot.id),
                dragged: () => dragged(shot),
                onOpen: () =>
                    onOpen(PlanTarget.shot(shot.id, data.shotLabel(shot))),
                onPick: () => onPick(shot),
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
    );

    return DragTarget<LightSetup>(
      onWillAcceptWithDetails: (d) => d.data.id != setup.id,
      onAcceptWithDetails: (d) => onReorder(d.data),
      builder: (context, setCandidates, _) => DragTarget<List<Shot>>(
        onWillAcceptWithDetails: (d) =>
            d.data.any((s) => s.lightSetupId != setup.id),
        onAcceptWithDetails: (d) => onDrop(d.data),
        builder: (context, shotCandidates, _) =>
            column(shotCandidates.isNotEmpty, setCandidates.isNotEmpty),
      ),
    );
  }
}
