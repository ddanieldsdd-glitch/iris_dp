import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_constants.dart';
import 'floor_plan_json.dart';
import 'floor_plan_repository.dart';
import 'light_setup_actions.dart';
import 'plan_data.dart';
import 'plan_target.dart';
import 'plan_thumbnail.dart';
import 'set_group_actions.dart';

/// Los sets de una localización (SG.2): Localización › Grupos › Sets ›
/// Planos. La localización es el entorno definitivo; cada set es una planta
/// de luz y cámara con varios planos, una cámara por plano. Los grupos
/// juntan sets con el mismo fondo, que comparten la luz.
///
/// El orden (por fondo, narrativo o a mano) es el de rodaje y el del PDF.
class PlanSiteSets extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.read(databaseProvider);
    final mode = SetOrderMode.of(site.setOrderMode);
    final ordered = data.orderedSets(site.id);
    final all = data.lightSetsOfSite(site.id);
    final loose = [
      for (final s in all)
        if (data.group(s.groupId) == null) s,
    ];

    Future<void> newSet() async {
      final created = await FloorPlanRepository(
        db,
      ).createLightSetup(projectId: projectId, siteId: site.id);
      onOpen(PlanTarget.lightSetup(created.id, created.name));
    }

    Future<void> groupSets() async {
      final picked = await _pickSets(context, loose);
      if (picked == null || picked.isEmpty || !context.mounted) return;
      await SetGroupActions(
        context,
        db,
      ).createWith(projectId: projectId, siteId: site.id, sets: picked);
    }

    final rows = <Widget>[];
    var number = 0;
    for (final part in ordered) {
      if (mode == SetOrderMode.group) {
        rows.add(
          part.group == null
              ? _LooseHeader(show: ordered.length > 1)
              : _GroupHeader(group: part.group!, data: data),
        );
      }
      if (mode == SetOrderMode.manual) {
        rows.add(
          _ManualList(sets: part.sets, data: data, site: site, onOpen: onOpen),
        );
        continue;
      }
      for (final s in part.sets) {
        number++;
        rows.add(
          PlanSetRow(
            key: ValueKey('set-${s.id}'),
            setup: s,
            data: data,
            site: site,
            onOpen: onOpen,
            number: mode == SetOrderMode.narrative ? number : null,
          ),
        );
      }
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
              onPressed: () => onOpen(PlanTarget.site(site.id, site.name)),
              icon: const Icon(Icons.home_work_outlined, size: 16),
              label: const Text('Entorno'),
            ),
            if (onMap != null)
              TextButton.icon(
                onPressed: onMap,
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('Mapa'),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 14, top: 2),
          child: Text(
            'El entorno de la localización es el definitivo: todos sus sets '
            'lo heredan. Cada set lleva su luz y una cámara por plano.',
            style: AppTypography.caption(
              palette,
            ).copyWith(color: palette.textTertiary),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<SetOrderMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(
                  value: SetOrderMode.group,
                  icon: Icon(Icons.folder_outlined, size: 16),
                  label: Text('Por fondo'),
                ),
                ButtonSegment(
                  value: SetOrderMode.narrative,
                  icon: Icon(Icons.menu_book_outlined, size: 16),
                  label: Text('Narrativo'),
                ),
                ButtonSegment(
                  value: SetOrderMode.manual,
                  icon: Icon(Icons.drag_indicator, size: 16),
                  label: Text('A mano'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (v) =>
                  db.setSiteSetOrderMode(site.id, v.first.name),
            ),
            FilledButton.tonalIcon(
              onPressed: newSet,
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
        if (all.isEmpty)
          Text(
            'Esta localización aún no tiene sets. Crea uno y vincula sus '
            'cámaras a los planos que se ruedan con esa luz.',
            style: AppTypography.bodyMedium(palette),
          ),
        ...rows,
      ],
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

class _GroupHeader extends ConsumerWidget {
  final SetGroup group;
  final PlanProjectData data;

  const _GroupHeader({required this.group, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final lights = groupLightCount(group);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, size: 18, color: palette.accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              group.name,
              style: AppTypography.bodyLarge(
                palette,
              ).copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _Chip(
            text: lights == 0
                ? 'luz compartida: vacía'
                : 'luz compartida · $lights luces',
            color: palette.accent,
          ),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: 'Opciones del grupo',
            icon: Icon(Icons.more_vert, color: palette.textSecondary),
            onSelected: (action) {
              final actions = SetGroupActions(
                context,
                ref.read(databaseProvider),
              );
              switch (action) {
                case 'rename':
                  actions.rename(group);
                case 'delete':
                  actions.delete(group);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Renombrar')),
              PopupMenuItem(value: 'delete', child: Text('Deshacer el grupo')),
            ],
          ),
        ],
      ),
    );
  }
}

class _LooseHeader extends StatelessWidget {
  final bool show;

  const _LooseHeader({required this.show});

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 4),
      child: Text(
        'SIN GRUPO',
        style: AppTypography.label(
          palette,
        ).copyWith(color: palette.textTertiary),
      ),
    );
  }
}

/// Orden de rodaje a mano: se arrastran los sets.
class _ManualList extends ConsumerWidget {
  final List<LightSetup> sets;
  final PlanProjectData data;
  final LocationSite site;
  final void Function(PlanTarget target) onOpen;

  const _ManualList({
    required this.sets,
    required this.data,
    required this.site,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: (from, to) async {
        final list = [...sets];
        final moved = list.removeAt(from);
        list.insert(to, moved);
        for (final (i, s) in list.indexed) {
          if (s.shootOrder != i) await db.setLightSetupShootOrder(s.id, i);
        }
      },
      children: [
        for (final (i, s) in sets.indexed)
          PlanSetRow(
            key: ValueKey('set-${s.id}'),
            setup: s,
            data: data,
            site: site,
            onOpen: onOpen,
            number: i + 1,
            dragIndex: i,
          ),
      ],
    );
  }
}

/// Un set: su planta en pequeño, sus escenas, sus planos (cada uno con su
/// cámara) y de dónde le viene la luz.
class PlanSetRow extends ConsumerWidget {
  final LightSetup setup;
  final PlanProjectData data;
  final LocationSite site;
  final void Function(PlanTarget target) onOpen;

  /// Número en el orden de rodaje.
  final int? number;

  /// Posición en la lista que se reordena a mano.
  final int? dragIndex;

  const PlanSetRow({
    super.key,
    required this.setup,
    required this.data,
    required this.site,
    required this.onOpen,
    this.number,
    this.dragIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.read(databaseProvider);
    final shots = data.shotsOfSetup(setup.id);
    final group = data.group(setup.groupId);
    final ownLights = data
        .ownOfSetup(setup)
        .where((e) => e.type == ElementType.light)
        .length;
    final groupLights = group == null ? 0 : groupLightCount(group);
    final light = [
      if (groupLights > 0) 'luz del grupo',
      if (ownLights > 0) group == null ? 'luz propia' : '+ $ownLights propias',
    ];
    final groups = data.groupsOfSite(site.id);
    final color = data.setupColor(setup);

    final row = InkWell(
      onTap: () => onOpen(PlanTarget.lightSetup(setup.id, setup.name)),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border, width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dragIndex != null)
              ReorderableDragStartListener(
                index: dragIndex!,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6, top: 18),
                  child: Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: palette.textTertiary,
                  ),
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 84,
                height: 60,
                child: PlanThumbnail(
                  elements: [
                    ...data.groupLightOf(setup),
                    ...data.ownOfSetup(setup),
                    for (final shot in shots)
                      ...data.ownOfShot(shot, tagged: true),
                  ],
                  inherited: data.inheritedOfSetup(setup),
                  drawings: data.drawingsOfSetup(setup),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text:
                                    '${number != null ? '$number. ' : ''}'
                                    '${setup.name}',
                                style: AppTypography.bodyMedium(
                                  palette,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(
                                text: ' · ${_scenesLabel(data, setup)}',
                                style: AppTypography.caption(palette),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final shot in shots)
                        ActionChip(
                          key: ValueKey('set-shot-${shot.id}'),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          avatar: const Icon(Icons.videocam_outlined, size: 14),
                          label: Text(_shotTag(data, shot)),
                          tooltip: data.shotLabel(shot),
                          onPressed: () => onOpen(
                            PlanTarget.shot(shot.id, data.shotLabel(shot)),
                          ),
                        ),
                      if (shots.isEmpty)
                        Text(
                          'Vincula sus cámaras a planos desde la planta.',
                          style: AppTypography.caption(
                            palette,
                          ).copyWith(color: palette.textTertiary),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Chip(
                  text: light.isEmpty ? 'sin luz' : light.join(' '),
                  color: light.isEmpty ? palette.textTertiary : color,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      tooltip: 'Grupo del set',
                      icon: Icon(
                        Icons.folder_open_outlined,
                        size: 18,
                        color: palette.textSecondary,
                      ),
                      onSelected: (action) async {
                        final actions = SetGroupActions(context, db);
                        if (action.startsWith('group:')) {
                          await actions.moveTo(
                            setup,
                            int.parse(action.substring(6)),
                          );
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
                          const PopupMenuItem(
                            value: 'ungroup',
                            child: Text('Sacar del grupo'),
                          ),
                        ],
                      ],
                    ),
                    LightSetupMenuButton(setup: setup, shotCount: shots.length),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return row;
  }
}

/// «12·3»: escena y plano.
String _shotTag(PlanProjectData data, Shot shot) {
  final scene = data.scene(shot.sceneId);
  return scene == null ? 'P${shot.number}' : '${scene.label}·${shot.number}';
}

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
