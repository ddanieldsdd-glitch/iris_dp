import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/rental_queries.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../shared/history/edit_history.dart';
import '../equipment/rentals/rentals_tab.dart';
import 'shoot_calendar.dart';
import 'shoot_calendar_edit.dart';
import 'shoot_calendar_editor.dart';
import 'shoot_calendar_grid.dart';
import 'shoot_day_screen.dart';
import 'shoot_day_timeline.dart';
import 'shoot_day_widgets.dart';

DateTime _mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Las reservas de material, como pantalla propia.
Future<void> openShootRentals(BuildContext context, {required int projectId}) =>
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Reservas de material')),
          body: RentalsTab(projectId: projectId),
        ),
      ),
    );

enum _View { agenda, day, week, month }

/// Calendario de rodaje: jornadas, escenas, franjas, recogidas y
/// devoluciones. Se edita arrastrando, como un calendario de Google: mover,
/// estirar por los bordes y dibujar en un hueco para crear.
class ShootCalendarScreen extends ConsumerStatefulWidget {
  final int projectId;

  const ShootCalendarScreen({super.key, required this.projectId});

  static Future<void> open(BuildContext context, {required int projectId}) =>
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ShootCalendarScreen(projectId: projectId),
        ),
      );

  @override
  ConsumerState<ShootCalendarScreen> createState() =>
      _ShootCalendarScreenState();
}

class _ShootCalendarScreenState extends ConsumerState<ShootCalendarScreen> {
  late final AppDatabase _db = ref.read(databaseProvider);
  late final _editor = ShootCalendarEditor(_db, widget.projectId);
  late final _documents = _db.watchShootDocumentsForProject(widget.projectId);
  late final _blocks = _db.watchShootDayBlocks(widget.projectId);
  late final _reservations = _db.watchRentalReservations(widget.projectId);
  late final _houses = _db.watchRentalHouses(widget.projectId);
  late final _sites = _db.watchSitesForProject(widget.projectId);
  late final _scenes = _db.watchScenesForProject(widget.projectId);
  late final _shots = _db.watchShotsForProject(widget.projectId);

  /// Propio de la pantalla: se vacía al salir.
  final _history = EditHistory();

  _View? _view;
  bool _showPast = false;
  DateTime? _anchor;

  @override
  void dispose() {
    _history.dispose();
    super.dispose();
  }

  /// Sin elegir nada, lo próximo que haya.
  DateTime _anchorFor(List<ShootCalendarEntry> entries) {
    if (_anchor != null) return _anchor!;
    final today = shootCalendarDate(DateTime.now());
    final next = entries.where((e) => e.date.compareTo(today) >= 0).firstOrNull;
    return next == null ? DateTime.now() : DateTime.parse(next.date);
  }

  void _openEntry(ShootCalendarEntry e) {
    if (e.dayId case final dayId?) {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              ShootDayScreen(projectId: widget.projectId, documentId: dayId),
        ),
      );
      return;
    }
    openShootRentals(context, projectId: widget.projectId);
  }

  void _step(DateTime anchor, _View view, int direction) => setState(() {
    _anchor = switch (view) {
      _View.month => DateTime(anchor.year, anchor.month + direction, 1),
      _View.week => DateTime(
        anchor.year,
        anchor.month,
        anchor.day + 7 * direction,
      ),
      _ => DateTime(anchor.year, anchor.month, anchor.day + direction),
    };
  });

  Future<void> _run(Future<EditStep?> Function() change, String refused) async {
    try {
      final step = await change();
      if (!mounted) return;
      if (step == null) {
        AppSnackBar.show(context, refused);
        return;
      }
      _history.record(step);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, '$e', isError: true);
    }
  }

  Future<void> _undo() async {
    final label = await _history.undo();
    if (label != null && mounted) {
      AppSnackBar.show(context, 'Deshecho: $label');
    }
  }

  Future<void> _redo() async {
    final label = await _history.redo();
    if (label != null && mounted) {
      AppSnackBar.show(context, 'Rehecho: $label');
    }
  }

  Future<void> _onSpan(
    ShootCalendarEntry entry,
    String date,
    CalendarSpan span,
  ) => _run(
    () => _editor.setSpan(entry, date, span),
    'Las franjas y escenas se mueven dentro de su jornada.',
  );

  /// La jornada que cubre [span] en [date]: la de ese día o la noche que
  /// viene del anterior.
  ShootDocument? _dayAt(
    List<ShootDocument> docs,
    String date,
    CalendarSpan span,
  ) {
    final days = docs.where((d) => d.kind == kShootDayKind).toList();
    final previous = calendarAddDays(date, -1);
    for (final d in days) {
      if (d.shootDate != previous) continue;
      final from = calendarMinutesOf(d.shootFromTime);
      final to = calendarMinutesOf(d.shootToTime);
      if (from != null && to != null && to < from && span.start < to) {
        return d;
      }
    }
    return days.where((d) => d.shootDate == date).firstOrNull;
  }

  Future<void> _onCreate(
    List<ShootDocument> docs,
    String date,
    CalendarSpan span,
    Offset at,
  ) async {
    final day = _dayAt(docs, date, span);
    final range = '${calendarHm(span.start)} – ${calendarHm(span.end)}';
    if (day == null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nueva jornada'),
          content: Text('${_longDate(date)}, de $range.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Crear'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await _run(() => _editor.addDay(date, span), '');
      return;
    }
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final kind = await showMenu<ShootStripKind>(
      context: context,
      position: RelativeRect.fromRect(
        at & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(enabled: false, child: Text('${day.name} · $range')),
        for (final k in ShootStripKind.values)
          PopupMenuItem(value: k, child: Text(k.label)),
      ],
    );
    if (kind == null) return;
    await _run(
      () => _editor.addStrip(
        dayId: day.id,
        dayDate: day.shootDate!,
        date: date,
        span: span,
        kind: kind,
      ),
      'Esa hora queda fuera de ${day.name}.',
    );
  }

  void _onDropScene(
    UnscheduledShootScene scene,
    String date,
    CalendarSpan span,
  ) => _run(
    () => _editor.scheduleScene(scene, date, span),
    'La escena es de ${scene.dayName}: suéltala en su día.',
  );

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            _redo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): _redo,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Calendario de rodaje'),
            actions: [
              ListenableBuilder(
                listenable: _history,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Deshacer',
                      icon: const Icon(Icons.undo),
                      onPressed: _history.canUndo ? _undo : null,
                    ),
                    IconButton(
                      tooltip: 'Rehacer',
                      icon: const Icon(Icons.redo),
                      onPressed: _history.canRedo ? _redo : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: _streams(),
        ),
      ),
    );
  }

  Widget _streams() => StreamBuilder<List<ShootDocument>>(
    stream: _documents,
    builder: (context, docs) => StreamBuilder<List<ShootDocumentBlock>>(
      stream: _blocks,
      builder: (context, blocks) => StreamBuilder<List<RentalReservation>>(
        stream: _reservations,
        builder: (context, reservations) => StreamBuilder<List<RentalHouse>>(
          stream: _houses,
          builder: (context, houses) => StreamBuilder<List<LocationSite>>(
            stream: _sites,
            builder: (context, sites) => StreamBuilder<List<Scene>>(
              stream: _scenes,
              builder: (context, scenes) => StreamBuilder<List<Shot>>(
                stream: _shots,
                builder: (context, shots) {
                  if (!docs.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final shotMap = {
                    for (final s in shots.data ?? const <Shot>[]) s.id: s,
                  };
                  final data = _Data(
                    docs: docs.data!,
                    blocks: blocks.data ?? const [],
                    shots: shotMap,
                    entries: buildShootCalendar(
                      documents: docs.data!,
                      blocks: blocks.data ?? const [],
                      reservations: reservations.data ?? const [],
                      houses: {
                        for (final h in houses.data ?? const <RentalHouse>[])
                          h.uid: h,
                      },
                      sites: {
                        for (final s in sites.data ?? const <LocationSite>[])
                          s.id: s,
                      },
                      scenes: {
                        for (final s in scenes.data ?? const <Scene>[]) s.id: s,
                      },
                      shots: shotMap,
                    ),
                    scenes: {
                      for (final s in scenes.data ?? const <Scene>[]) s.id: s,
                    },
                  );
                  return LayoutBuilder(
                    builder: (context, constraints) =>
                        _body(data, constraints.maxWidth < 720),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );

  static String _longDate(String date) {
    final d = DateTime.parse(date);
    return '${kCalendarWeekdays[d.weekday - 1]} ${d.day} de '
        '${kCalendarMonths[d.month - 1]}';
  }

  Widget _body(_Data data, bool phone) {
    final palette = context.palette;
    var view = _view ?? (phone ? _View.agenda : _View.week);
    if (phone && view != _View.agenda && view != _View.day) view = _View.day;
    if (view == _View.agenda) return _agenda(data.entries);

    final anchor = _anchorFor(data.entries);
    final monday = _mondayOf(anchor);
    final sunday = monday.add(const Duration(days: 6));
    final day = DateTime(anchor.year, anchor.month, anchor.day);
    final title = switch (view) {
      _View.month => '${kCalendarMonths[anchor.month - 1]} ${anchor.year}',
      _View.day => _longDate(shootCalendarDate(day)),
      _ =>
        monday.month == sunday.month
            ? '${monday.day} – ${sunday.day} de '
                  '${kCalendarMonths[monday.month - 1]}'
            : '${monday.day} de ${kCalendarMonths[monday.month - 1]} – '
                  '${sunday.day} de ${kCalendarMonths[sunday.month - 1]}',
    };
    final days = view == _View.day
        ? [day]
        : [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
    final unscheduled = view == _View.month
        ? const <UnscheduledShootScene>[]
        : unscheduledShootScenes(
            documents: data.docs,
            blocks: data.blocks,
            shots: data.shots,
            dates: {for (final d in days) shootCalendarDate(d)},
          );

    final grid = view == _View.month
        ? _MonthGrid(
            month: anchor,
            entries: data.entries,
            onOpen: _openEntry,
            onPickDay: (d) => setState(() {
              _anchor = d;
              _view = _View.day;
            }),
            onMoveDay: (dayId, date) => _run(
              () => _editor.moveDayTo(dayId, date),
              'La jornada ya está en ese día.',
            ),
          )
        : ShootCalendarGrid(
            days: days,
            entries: data.entries,
            onOpen: _openEntry,
            onSpan: _onSpan,
            onCreate: (date, span, at) => _onCreate(data.docs, date, span, at),
            onDropScene: _onDropScene,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              IconButton(
                tooltip: 'Anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _step(anchor, view, -1),
              ),
              IconButton(
                tooltip: 'Siguiente',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _step(anchor, view, 1),
              ),
              TextButton(
                onPressed: () => setState(() => _anchor = DateTime.now()),
                child: const Text('Hoy'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(title, style: AppTypography.titleMedium(palette)),
              ),
              const SizedBox(width: AppSpacing.sm),
              _viewPicker(view, phone),
              if (!phone) ...[
                const SizedBox(width: AppSpacing.sm),
                const _Legend(),
              ],
            ],
          ),
        ),
        if (phone && unscheduled.isNotEmpty)
          _UnscheduledStrip(scenes: unscheduled, sceneMap: data.scenes),
        Divider(height: 1, color: palette.divider),
        Expanded(
          child: !phone && unscheduled.isNotEmpty
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: grid),
                    VerticalDivider(width: 1, color: palette.divider),
                    SizedBox(
                      width: 210,
                      child: _UnscheduledPanel(
                        scenes: unscheduled,
                        sceneMap: data.scenes,
                      ),
                    ),
                  ],
                )
              : grid,
        ),
      ],
    );
  }

  Widget _viewPicker(_View view, bool phone) => SegmentedButton<_View>(
    showSelectedIcon: false,
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
    segments: [
      if (phone) const ButtonSegment(value: _View.agenda, label: Text('Lista')),
      const ButtonSegment(value: _View.day, label: Text('Día')),
      if (!phone) ...const [
        ButtonSegment(value: _View.week, label: Text('Semana')),
        ButtonSegment(value: _View.month, label: Text('Mes')),
      ],
    ],
    selected: {view},
    onSelectionChanged: (v) => setState(() => _view = v.first),
  );

  Widget _agenda(List<ShootCalendarEntry> entries) {
    final palette = context.palette;
    final today = shootCalendarDate(DateTime.now());
    final hasPast = entries.any((e) => e.date.compareTo(today) < 0);
    final shown = _showPast
        ? entries
        : entries.where((e) => e.date.compareTo(today) >= 0).toList();
    final dates = {for (final e in shown) e.date}.toList()..sort();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          children: [
            const Expanded(child: _Legend()),
            _viewPicker(_View.agenda, true),
          ],
        ),
        if (hasPast)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showPast = !_showPast),
              child: Text(
                _showPast ? 'Ocultar días pasados' : 'Ver días pasados',
              ),
            ),
          ),
        if (dates.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'Aún no hay jornadas con fecha ni reservas. En «Día» puedes '
              'crear una manteniendo pulsado en una hora.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(palette),
            ),
          ),
        for (final date in dates) ...[
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: () => setState(() {
              _anchor = DateTime.parse(date);
              _view = _View.day;
            }),
            child: Row(
              children: [
                Text(_longDate(date), style: AppTypography.label(palette)),
                const SizedBox(width: 6),
                Icon(
                  Icons.view_day_outlined,
                  size: 14,
                  color: palette.textTertiary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          for (final e in shown.where((e) => e.date == date))
            _AgendaTile(entry: e, onTap: () => _openEntry(e)),
        ],
      ],
    );
  }
}

class _Data {
  final List<ShootDocument> docs;
  final List<ShootDocumentBlock> blocks;
  final Map<int, Shot> shots;
  final Map<int, Scene> scenes;
  final List<ShootCalendarEntry> entries;

  const _Data({
    required this.docs,
    required this.blocks,
    required this.shots,
    required this.scenes,
    required this.entries,
  });
}

String _unscheduledTitle(UnscheduledShootScene s, Map<int, Scene> scenes) {
  final scene = scenes[s.sceneId];
  return scene == null
      ? 'Escena'
      : 'Esc. ${scene.label} · ${scene.locationPureName}';
}

/// Escenas de las jornadas a la vista que aún no tienen hora: se arrastran
/// a la rejilla.
class _UnscheduledPanel extends StatelessWidget {
  final List<UnscheduledShootScene> scenes;
  final Map<int, Scene> sceneMap;

  const _UnscheduledPanel({required this.scenes, required this.sceneMap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      children: [
        Text('Sin hora', style: AppTypography.label(palette)),
        const SizedBox(height: 2),
        Text(
          'Arrástralas a su día para darles hora.',
          style: AppTypography.caption(palette),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final s in scenes)
          _UnscheduledChip(scene: s, title: _unscheduledTitle(s, sceneMap)),
      ],
    );
  }
}

class _UnscheduledStrip extends StatelessWidget {
  final List<UnscheduledShootScene> scenes;
  final Map<int, Scene> sceneMap;

  const _UnscheduledStrip({required this.scenes, required this.sceneMap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        children: [
          for (final s in scenes)
            SizedBox(
              width: 180,
              child: _UnscheduledChip(
                scene: s,
                title: _unscheduledTitle(s, sceneMap),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnscheduledChip extends StatelessWidget {
  final UnscheduledShootScene scene;
  final String title;

  const _UnscheduledChip({required this.scene, required this.title});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget card({double opacity = 1}) => Opacity(
      opacity: opacity,
      child: Container(
        width: 190,
        margin: const EdgeInsets.only(bottom: 6, right: 6),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: kCalendarSceneColor.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(6),
          border: const Border(
            left: BorderSide(color: kCalendarSceneColor, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textPrimary, fontSize: 11),
            ),
            Text(
              '${scene.dayName} · ${scene.shots} '
              '${scene.shots == 1 ? 'plano' : 'planos'}',
              maxLines: 1,
              style: AppTypography.caption(palette).copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
    final feedback = Material(color: Colors.transparent, child: card());
    return calendarUsesLongPress
        ? LongPressDraggable<UnscheduledShootScene>(
            data: scene,
            feedback: feedback,
            childWhenDragging: card(opacity: 0.4),
            child: card(),
          )
        : Draggable<UnscheduledShootScene>(
            data: scene,
            feedback: feedback,
            childWhenDragging: card(opacity: 0.4),
            child: MouseRegion(cursor: SystemMouseCursors.grab, child: card()),
          );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.caption(context.palette)),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        _LegendDot(palette.accent, 'Rodaje'),
        const _LegendDot(kCalendarSceneColor, 'Escena'),
        const _LegendDot(kCalendarPickupColor, 'Recogida'),
        const _LegendDot(kCalendarReturnColor, 'Devolución'),
        _LegendDot(shootStripColor(ShootStripKind.setup, palette), 'Montaje'),
        _LegendDot(shootStripColor(ShootStripKind.meal, palette), 'Comida'),
      ],
    );
  }
}

class _AgendaTile extends StatelessWidget {
  final ShootCalendarEntry entry;
  final VoidCallback onTap;

  const _AgendaTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = shootCalendarColor(entry, palette);
    final detail = entry.detail ?? '';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Text(
                entry.from ?? '—',
                style: AppTypography.mono(palette).copyWith(color: color),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${shootCalendarPrefix(entry)}${entry.title}',
                    style: AppTypography.bodyMedium(palette).copyWith(
                      color: palette.textPrimary,
                      decoration: entry.done
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (detail.isNotEmpty)
                    Text(detail, style: AppTypography.caption(palette)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El mes entero. Tocar un día lleva a ese día; arrastrar una jornada a
/// otro día le cambia la fecha.
class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final List<ShootCalendarEntry> entries;
  final ValueChanged<ShootCalendarEntry> onOpen;
  final ValueChanged<DateTime> onPickDay;
  final void Function(int dayId, String date) onMoveDay;

  const _MonthGrid({
    required this.month,
    required this.entries,
    required this.onOpen,
    required this.onPickDay,
    required this.onMoveDay,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final start = _mondayOf(firstOfMonth);
    final today = shootCalendarDate(DateTime.now());
    final byDate = <String, List<ShootCalendarEntry>>{};
    for (final e in entries) {
      // En el mes, la jornada con sus recogidas; franjas y escenas, dentro.
      if (e.kind == ShootCalendarKind.strip ||
          e.kind == ShootCalendarKind.scene) {
        continue;
      }
      byDate.putIfAbsent(e.date, () => []).add(e);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final name in kCalendarWeekdays)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: AppTypography.label(palette),
                  ),
                ),
              ),
          ],
        ),
        for (var week = 0; week < 6; week++)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final day = DateTime(
                          start.year,
                          start.month,
                          start.day + week * 7 + i,
                        );
                        final date = shootCalendarDate(day);
                        final inMonth = day.month == month.month;
                        final list = byDate[date] ?? const [];
                        return DragTarget<ShootCalendarEntry>(
                          onWillAcceptWithDetails: (d) =>
                              d.data.dayId != null && d.data.date != date,
                          onAcceptWithDetails: (d) =>
                              onMoveDay(d.data.dayId!, date),
                          builder: (context, candidates, _) => InkWell(
                            onTap: () => onPickDay(day),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              clipBehavior: Clip.hardEdge,
                              decoration: BoxDecoration(
                                color: candidates.isNotEmpty
                                    ? palette.accent.withValues(alpha: 0.12)
                                    : null,
                                border: Border.all(
                                  color: palette.divider,
                                  width: 0.5,
                                ),
                              ),
                              child: LayoutBuilder(
                                builder: (context, box) {
                                  final fit = ((box.maxHeight - 18) / 20)
                                      .floor()
                                      .clamp(0, 6);
                                  final shown = list.length > fit
                                      ? (fit - 1).clamp(0, 6)
                                      : list.length;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        '${day.day}',
                                        style: AppTypography.caption(palette)
                                            .copyWith(
                                              color: date == today
                                                  ? palette.accent
                                                  : inMonth
                                                  ? palette.textPrimary
                                                  : palette.textTertiary,
                                            ),
                                      ),
                                      for (final e in list.take(shown))
                                        _MonthLine(entry: e, onOpen: onOpen),
                                      if (list.length > shown)
                                        Text(
                                          '+${list.length - shown} más',
                                          style: AppTypography.caption(
                                            palette,
                                          ).copyWith(fontSize: 10),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MonthLine extends StatelessWidget {
  final ShootCalendarEntry entry;
  final ValueChanged<ShootCalendarEntry> onOpen;

  const _MonthLine({required this.entry, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = shootCalendarColor(entry, palette);
    Widget line({double opacity = 1}) => Opacity(
      opacity: opacity,
      child: Container(
        height: 18,
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.26),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          '${entry.from == null ? '' : '${entry.from} '}'
          '${shootCalendarPrefix(entry)}${entry.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textPrimary, fontSize: 10),
        ),
      ),
    );
    final tappable = InkWell(onTap: () => onOpen(entry), child: line());
    if (entry.kind != ShootCalendarKind.shoot) return tappable;
    final feedback = Material(
      color: Colors.transparent,
      child: SizedBox(width: 140, child: line()),
    );
    return calendarUsesLongPress
        ? LongPressDraggable<ShootCalendarEntry>(
            data: entry,
            feedback: feedback,
            childWhenDragging: line(opacity: 0.4),
            child: tappable,
          )
        : Draggable<ShootCalendarEntry>(
            data: entry,
            feedback: feedback,
            childWhenDragging: line(opacity: 0.4),
            child: tappable,
          );
  }
}
