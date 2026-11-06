import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/history/edit_history.dart';
import '../../shared/rich_text/script_markup.dart';
import '../camera_plan/shot_cover.dart';
import 'shoot_day_order.dart';
import 'shoot_day_screen.dart';
import '../export_center/export_center_screen.dart';
import '../export_center/export_selection.dart';
import 'shoot_plan.dart';

/// Lo que se arrastra por el tablero.
sealed class _BoardDrag {
  const _BoardDrag();
}

/// Bloques que ya están en una jornada.
class _BlocksDrag extends _BoardDrag {
  final List<int> blockIds;
  const _BlocksDrag(this.blockIds);
}

/// Planos o escenas que aún no tienen día.
class _ItemsDrag extends _BoardDrag {
  final List<ShootPlanItem> items;
  const _ItemsDrag(this.items);
}

/// Una jornada entera, para cambiarla de sitio.
class _DayDrag extends _BoardDrag {
  final int dayId;
  const _DayDrag(this.dayId);
}

/// Plan de rodaje: qué escenas se ruedan cada día y en qué orden.
class ShootDaysBoardScreen extends ConsumerWidget {
  final int projectId;

  const ShootDaysBoardScreen({super.key, required this.projectId});

  static Future<void> open(BuildContext context, {required int projectId}) =>
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ShootDaysBoardScreen(projectId: projectId),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final history = ref.watch(editHistoryProvider);
    final service = ShootPlanService(db, history: history);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan de rodaje'),
        actions: [
          IconButton(
            tooltip: 'Deshacer',
            icon: const Icon(Icons.undo),
            onPressed: history.canUndo ? history.undo : null,
          ),
          IconButton(
            tooltip: 'Exportar',
            icon: const Icon(Icons.ios_share),
            onPressed: () => ExportCenterScreen.open(
              context,
              projectId: projectId,
              document: ExportDocument.shootingPlan,
            ),
          ),
          TextButton.icon(
            onPressed: () => service.addDay(projectId),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Añadir jornada'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: StreamBuilder<List<ShootDocument>>(
        stream: db.watchShootDocumentsForProject(projectId),
        builder: (context, docs) => StreamBuilder<List<ShootDocumentBlock>>(
          stream: db.watchShootDayBlocks(projectId),
          builder: (context, blocks) => StreamBuilder<List<Scene>>(
            stream: db.watchScenesForProject(projectId),
            builder: (context, scenes) => StreamBuilder<List<Shot>>(
              stream: db.watchShotsForProject(projectId),
              builder: (context, shots) => StreamBuilder<List<LocationSite>>(
                stream: db.watchSitesForProject(projectId),
                builder: (context, sites) =>
                    StreamBuilder<List<LocationBasePlan>>(
                      stream: db.watchLocationsForProject(projectId),
                      builder: (context, sets) {
                        if (!docs.hasData ||
                            !blocks.hasData ||
                            !scenes.hasData ||
                            !shots.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return _Board(
                          projectId: projectId,
                          service: service,
                          plan: ShootPlan.from(
                            documents: docs.data!,
                            blocks: blocks.data!,
                            scenes: scenes.data!,
                            shots: shots.data!,
                          ),
                          scenes: {for (final s in scenes.data!) s.id: s},
                          shots: {for (final s in shots.data!) s.id: s},
                          colors: ProjectColorScheme.resolve(
                            sites: sites.data ?? const [],
                            sets: sets.data ?? const [],
                            scenes: scenes.data!,
                          ),
                        );
                      },
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  final int projectId;
  final ShootPlanService service;
  final ShootPlan plan;
  final Map<int, Scene> scenes;
  final Map<int, Shot> shots;
  final ProjectColorScheme colors;

  const _Board({
    required this.projectId,
    required this.service,
    required this.plan,
    required this.scenes,
    required this.shots,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final compact = AppLayout.isCompact(context);
    final unassigned = _UnassignedColumn(board: this, compact: compact);
    final days = [
      for (final (i, day) in plan.days.indexed)
        _DayColumn(board: this, day: day, index: i, compact: compact),
    ];

    // En el iPhone no se arrastra: cada tarjeta lleva su menú «Mover a…».
    if (compact) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (plan.unassigned.isNotEmpty) ...[
            unassigned,
            const SizedBox(height: AppSpacing.md),
          ],
          for (final day in days) ...[
            day,
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 300, child: unassigned),
        VerticalDivider(width: 1, color: context.palette.divider),
        Expanded(
          child: plan.days.isEmpty
              ? _NoDays(onAdd: () => service.addDay(projectId))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: days.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (_, i) => SizedBox(width: 320, child: days[i]),
                ),
        ),
      ],
    );
  }

  Future<void> drop(_BoardDrag data, int dayId, int? beforeBlockId) async {
    switch (data) {
      case _BlocksDrag(:final blockIds):
        await service.move(
          projectId: projectId,
          dayId: dayId,
          blockIds: blockIds,
          beforeBlockId: beforeBlockId,
        );
      case _ItemsDrag(:final items):
        await service.place(
          projectId: projectId,
          dayId: dayId,
          items: items,
          beforeBlockId: beforeBlockId,
        );
      case _DayDrag():
        break;
    }
  }

  Future<void> moveDay(int dayId, int before) async {
    final ids = [for (final d in plan.days) d.id];
    final from = ids.indexOf(dayId);
    if (from < 0) return;
    ids.removeAt(from);
    ids.insert(before > from ? before - 1 : before, dayId);
    await service.reorderDays(projectId, ids);
  }

  /// Elige jornada, sin contar [except].
  Future<int?> pickDay(BuildContext context, String title, {int? except}) {
    final palette = context.palette;
    final options = plan.days.where((d) => d.id != except).toList();
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: palette.surfaceElevated,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(title, style: AppTypography.titleMedium(palette)),
            ),
            if (options.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No hay otra jornada. Añade una primero.',
                  style: AppTypography.bodyMedium(palette),
                ),
              ),
            for (final day in options)
              ListTile(
                title: Text(day.name),
                subtitle: day.shootDate == null ? null : Text(day.shootDate!),
                onTap: () => Navigator.pop(context, day.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoDays extends StatelessWidget {
  final VoidCallback onAdd;

  const _NoDays({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Añade la primera jornada y arrastra aquí las escenas.',
            style: AppTypography.bodyMedium(context.palette),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Añadir jornada'),
          ),
        ],
      ),
    );
  }
}

/// Lo que aún no tiene día. Soltar aquí algo de una jornada lo saca de ella.
class _UnassignedColumn extends StatelessWidget {
  final _Board board;
  final bool compact;

  const _UnassignedColumn({required this.board, required this.compact});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final plan = board.plan;

    final content = [
      for (final entry in plan.unassigned)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _UnassignedScene(board: board, entry: entry, compact: compact),
        ),
    ];

    return DragTarget<_BoardDrag>(
      onWillAcceptWithDetails: (d) => d.data is _BlocksDrag,
      onAcceptWithDetails: (d) => board.service.remove(
        projectId: board.projectId,
        blockIds: (d.data as _BlocksDrag).blockIds,
      ),
      builder: (context, hovering, _) => Container(
        color: hovering.isEmpty
            ? palette.surfaceOverlay.withValues(alpha: 0.3)
            : palette.accent.withValues(alpha: 0.1),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Text('Sin asignar', style: AppTypography.titleMedium(palette)),
            const SizedBox(height: 2),
            Text(
              plan.unassigned.isEmpty
                  ? 'Todo el guion tiene su día.'
                  : compact
                  ? 'Usa el menú de cada escena para colocarla.'
                  : 'Arrastra una escena o un plano a su jornada.',
              style: AppTypography.caption(palette),
            ),
            const SizedBox(height: AppSpacing.md),
            if (compact)
              ...content
            else
              Expanded(child: ListView(children: content)),
          ],
        ),
      ),
    );
  }
}

class _UnassignedScene extends StatelessWidget {
  final _Board board;
  final UnassignedScene entry;
  final bool compact;

  const _UnassignedScene({
    required this.board,
    required this.entry,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final scene = entry.scene;
    final items = entry.shots.isEmpty
        ? <ShootPlanItem>[(sceneId: scene.id, shotId: null)]
        : [for (final s in entry.shots) (sceneId: scene.id, shotId: s.id)];

    Future<void> addTo(BuildContext context) async {
      final dayId = await board.pickDay(context, 'Añadir a…');
      if (dayId != null) await board.drop(_ItemsDrag(items), dayId, null);
    }

    final count = entry.total == 0
        ? 'sin planos'
        : entry.shots.length == entry.total
        ? '${entry.total} planos'
        : '${entry.shots.length} de ${entry.total} planos';

    return _Tract(
      key: ValueKey('sin-asignar-${scene.id}'),
      scene: scene,
      color: board.colors.sceneColor(scene),
      subtitle: count,
      compact: compact,
      drag: _ItemsDrag(items),
      menu: [_MenuAction('Añadir a…', addTo)],
      children: [
        for (final shot in entry.shots)
          _ShotTile(
            shot: shot,
            days: 0,
            compact: compact,
            drag: _ItemsDrag([(sceneId: scene.id, shotId: shot.id)]),
            menu: [
              _MenuAction('Añadir a…', (context) async {
                final dayId = await board.pickDay(context, 'Añadir a…');
                if (dayId == null) return;
                await board.drop(
                  _ItemsDrag([(sceneId: scene.id, shotId: shot.id)]),
                  dayId,
                  null,
                );
              }),
            ],
          ),
      ],
    );
  }
}

/// Una jornada: cabecera y sus escenas en el orden en que se ruedan.
class _DayColumn extends StatelessWidget {
  final _Board board;
  final ShootDocument day;
  final int index;
  final bool compact;

  const _DayColumn({
    required this.board,
    required this.day,
    required this.index,
    required this.compact,
  });

  String _duration(List<ShootDocumentBlock> blocks) {
    var seconds = 0;
    for (final block in blocks) {
      seconds += board.shots[block.shotId]?.durationSeconds ?? 0;
    }
    if (seconds == 0) return '';
    final minutes = (seconds / 60).ceil();
    return ' · ≈ $minutes min';
  }

  Future<void> _pickDate(BuildContext context) async {
    final initial = DateTime.tryParse(day.shootDate ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final iso =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    await board.service.db.updateShootDocument(
      day.copyWith(shootDate: Value(iso)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final blocks = board.plan.blocksByDay[day.id] ?? const [];
    final byId = {for (final b in blocks) b.id: b};
    final tracts = groupShootTracts([
      for (final b in blocks) b.id,
    ], (id) => byId[id]!.sceneId ?? -1);
    final shotCount = blocks.where((b) => b.shotId != null).length;

    final header = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(day.name, style: AppTypography.titleMedium(palette)),
              InkWell(
                onTap: () => _pickDate(context),
                child: Text(
                  day.shootDate ?? 'Poner fecha',
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.accent),
                ),
              ),
              Text(
                '$shotCount plano${shotCount == 1 ? '' : 's'}'
                '${_duration(blocks)}',
                style: AppTypography.caption(palette),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Abrir jornada',
          icon: const Icon(Icons.open_in_new, size: 18),
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ShootDayScreen(
                projectId: board.projectId,
                documentId: day.id,
              ),
            ),
          ),
        ),
      ],
    );

    final tractWidgets = <Widget>[];
    for (final tract in tracts) {
      final first = byId[tract.blockIds.first]!;
      final scene = board.scenes[first.sceneId];
      if (!compact) {
        tractWidgets.add(_DropSlot(board: board, dayId: day.id, before: first));
      }
      if (scene == null) continue;
      tractWidgets.add(
        _Tract(
          key: ValueKey('tramo-${first.id}'),
          scene: scene,
          color: board.colors.sceneColor(scene),
          subtitle: first.shotId == null
              ? 'sin planos'
              : '${tract.blockIds.length} '
                    'plano${tract.blockIds.length == 1 ? '' : 's'}',
          compact: compact,
          drag: _BlocksDrag(tract.blockIds),
          menu: _blockMenu(tract.blockIds),
          children: [
            for (final id in tract.blockIds)
              if (board.shots[byId[id]!.shotId] case final shot?) ...[
                _ShotTile(
                  shot: shot,
                  days: board.plan.daysOfShot[shot.id] ?? 0,
                  compact: compact,
                  drag: _BlocksDrag([id]),
                  menu: [
                    ..._blockMenu([id]),
                    _MenuAction('Repetir en…', (context) async {
                      final dayId = await board.pickDay(
                        context,
                        'Repetir en…',
                        except: day.id,
                      );
                      if (dayId == null) return;
                      await board.drop(
                        _ItemsDrag([(sceneId: scene.id, shotId: shot.id)]),
                        dayId,
                        null,
                      );
                      if (context.mounted) {
                        AppSnackBar.show(
                          context,
                          'El plano ${shot.number} está ahora en dos jornadas.',
                        );
                      }
                    }),
                  ],
                ),
              ],
          ],
        ),
      );
    }

    final body = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: tractWidgets,
          )
        : Expanded(
            child: ListView(
              children: [
                ...tractWidgets,
                _DropSlot(
                  board: board,
                  dayId: day.id,
                  before: null,
                  tail: true,
                ),
              ],
            ),
          );

    final column = Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (compact)
            header
          else
            Draggable<_BoardDrag>(
              data: _DayDrag(day.id),
              feedback: Material(
                color: Colors.transparent,
                child: _Feedback(label: day.name),
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: header,
              ),
            ),
          Divider(height: AppSpacing.md, color: palette.divider),
          body,
        ],
      ),
    );

    if (compact) return column;
    // Toda la columna acepta: lo que se suelta fuera de un hueco va al final.
    return DragTarget<_BoardDrag>(
      onWillAcceptWithDetails: (d) =>
          d.data is! _DayDrag || (d.data as _DayDrag).dayId != day.id,
      onAcceptWithDetails: (d) => d.data is _DayDrag
          ? board.moveDay((d.data as _DayDrag).dayId, index)
          : board.drop(d.data, day.id, null),
      builder: (context, hovering, _) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: hovering.isEmpty
              ? null
              : hovering.first is _DayDrag
              ? Border(left: BorderSide(color: palette.accent, width: 3))
              : Border.all(color: palette.accent, width: 1.5),
        ),
        child: column,
      ),
    );
  }

  List<_MenuAction> _blockMenu(List<int> blockIds) => [
    _MenuAction('Mover a…', (context) async {
      final dayId = await board.pickDay(context, 'Mover a…', except: day.id);
      if (dayId != null) await board.drop(_BlocksDrag(blockIds), dayId, null);
    }),
    _MenuAction(
      'Quitar de la jornada',
      (_) =>
          board.service.remove(projectId: board.projectId, blockIds: blockIds),
    ),
  ];
}

/// Hueco entre escenas: se abre al pasar por encima algo que se suelta.
class _DropSlot extends StatelessWidget {
  final _Board board;
  final int dayId;
  final ShootDocumentBlock? before;
  final bool tail;

  const _DropSlot({
    required this.board,
    required this.dayId,
    required this.before,
    this.tail = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DragTarget<_BoardDrag>(
      onWillAcceptWithDetails: (d) => d.data is! _DayDrag,
      onAcceptWithDetails: (d) => board.drop(d.data, dayId, before?.id),
      builder: (context, hovering, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: hovering.isNotEmpty ? 40 : (tail ? 72 : 10),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: hovering.isNotEmpty
              ? palette.accent.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

class _MenuAction {
  final String label;
  final Future<void> Function(BuildContext context) run;

  const _MenuAction(this.label, this.run);
}

class _ActionsMenu extends StatelessWidget {
  final List<_MenuAction> actions;

  const _ActionsMenu({required this.actions});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MenuAction>(
      tooltip: 'Acciones',
      padding: EdgeInsets.zero,
      iconSize: 18,
      onSelected: (action) => action.run(context),
      itemBuilder: (_) => [
        for (final action in actions)
          PopupMenuItem(value: action, child: Text(action.label)),
      ],
    );
  }
}

class _Feedback extends StatelessWidget {
  final String label;

  const _Feedback({required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.accent),
      ),
      child: Text(label, style: AppTypography.bodyMedium(palette)),
    );
  }
}

/// Arrastrable en el Mac y el iPad; en el iPhone se usa el menú.
Widget _draggable(bool compact, _BoardDrag data, String label, Widget child) {
  if (compact) return child;
  return Draggable<_BoardDrag>(
    data: data,
    feedback: Material(
      color: Colors.transparent,
      child: _Feedback(label: label),
    ),
    childWhenDragging: Opacity(opacity: 0.4, child: child),
    child: MouseRegion(cursor: SystemMouseCursors.grab, child: child),
  );
}

/// Escena dentro de una columna, con sus planos debajo.
class _Tract extends StatefulWidget {
  final Scene scene;
  final Color color;
  final String subtitle;
  final bool compact;
  final _BoardDrag drag;
  final List<_MenuAction> menu;
  final List<Widget> children;

  const _Tract({
    super.key,
    required this.scene,
    required this.color,
    required this.subtitle,
    required this.compact,
    required this.drag,
    required this.menu,
    required this.children,
  });

  @override
  State<_Tract> createState() => _TractState();
}

class _TractState extends State<_Tract> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scene = widget.scene;
    final title = 'Esc ${scene.label}';
    final header = Row(
      children: [
        Container(width: 4, height: 34, color: widget.color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title · ${scene.locationPureName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium(
                  palette,
                ).copyWith(color: palette.textPrimary),
              ),
              Text(widget.subtitle, style: AppTypography.caption(palette)),
            ],
          ),
        ),
        if (widget.children.isNotEmpty)
          IconButton(
            tooltip: _open ? 'Plegar' : 'Ver planos',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
            onPressed: () => setState(() => _open = !_open),
          ),
        _ActionsMenu(actions: widget.menu),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _draggable(widget.compact, widget.drag, title, header),
          if (_open) ...widget.children,
        ],
      ),
    );
  }
}

class _ShotTile extends StatelessWidget {
  final Shot shot;
  final int days;
  final bool compact;
  final _BoardDrag drag;
  final List<_MenuAction> menu;

  const _ShotTile({
    required this.shot,
    required this.days,
    required this.compact,
    required this.drag,
    required this.menu,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final framing = scriptMarkupToPlain(shot.framing).trim();
    final title = framing.isEmpty ? 'Plano ${shot.number}' : framing;
    final tile = Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 64,
              height: 36,
              child:
                  shotCoverThumbnail(shot, cacheWidth: 160) ??
                  ColoredBox(color: palette.surfaceOverlay),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${shot.number} · $title',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textPrimary),
            ),
          ),
          if (days > 1)
            Tooltip(
              message: 'Este plano está en $days jornadas',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$days días',
                  style: AppTypography.caption(
                    palette,
                  ).copyWith(color: palette.accent, fontSize: 10),
                ),
              ),
            ),
          _ActionsMenu(actions: menu),
        ],
      ),
    );
    return _draggable(compact, drag, 'Plano ${shot.number}', tile);
  }
}
