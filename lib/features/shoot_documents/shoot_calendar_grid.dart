import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'shoot_calendar.dart';
import 'shoot_calendar_edit.dart';
import 'shoot_day_timeline.dart';
import 'shoot_day_widgets.dart';

const kCalendarPickupColor = Color(0xFF6FCF97);
const kCalendarReturnColor = Color(0xFFE58A6B);
const kCalendarSceneColor = Color(0xFF7FA7E0);

const kCalendarWeekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const kCalendarMonths = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

Color shootCalendarColor(ShootCalendarEntry e, AppPalette palette) =>
    switch (e.kind) {
      ShootCalendarKind.shoot => palette.accent,
      ShootCalendarKind.scene => kCalendarSceneColor,
      ShootCalendarKind.pickup => kCalendarPickupColor,
      ShootCalendarKind.ret => kCalendarReturnColor,
      ShootCalendarKind.strip => shootStripColor(e.stripKind!, palette),
    };

String shootCalendarPrefix(ShootCalendarEntry e) => switch (e.kind) {
  ShootCalendarKind.pickup => 'Recoger · ',
  ShootCalendarKind.ret => 'Devolver · ',
  _ => '',
};

/// En pantallas táctiles se arrastra tras mantener pulsado, para que el
/// dedo siga moviendo la rejilla.
bool get calendarUsesLongPress =>
    !kIsWeb && (Platform.isIOS || Platform.isAndroid);

/// Una escena sin hora que se suelta en la rejilla.
typedef CalendarSceneDrop =
    void Function(UnscheduledShootScene scene, String date, CalendarSpan span);

class _Drag {
  /// Nulo al dibujar una entrada nueva en un hueco.
  final ShootCalendarEntry? entry;
  final CalendarDragMode mode;
  final CalendarSpan original;
  final Offset origin;
  CalendarSpan current;

  _Drag(this.entry, this.mode, this.original, this.origin) : current = original;
}

/// Días con horas: cada entrada ocupa su franja y se puede mover, estirar
/// por arriba o por abajo, o dibujar en un hueco.
class ShootCalendarGrid extends StatefulWidget {
  final List<DateTime> days;
  final List<ShootCalendarEntry> entries;
  final ValueChanged<ShootCalendarEntry> onOpen;
  final Future<void> Function(
    ShootCalendarEntry entry,
    String date,
    CalendarSpan span,
  )
  onSpan;
  final Future<void> Function(String date, CalendarSpan span, Offset global)
  onCreate;
  final CalendarSceneDrop onDropScene;

  const ShootCalendarGrid({
    super.key,
    required this.days,
    required this.entries,
    required this.onOpen,
    required this.onSpan,
    required this.onCreate,
    required this.onDropScene,
  });

  @override
  State<ShootCalendarGrid> createState() => _ShootCalendarGridState();
}

class _ShootCalendarGridState extends State<ShootCalendarGrid> {
  static const _hourHeight = 46.0;
  static const _rail = 46.0;
  final _scroll = ScrollController();
  final _stackKey = GlobalKey();
  bool _placed = false;
  _Drag? _drag;
  double _columnWidth = 1;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // La línea de «ahora» avanza sola.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(ShootCalendarGrid old) {
    super.didUpdateWidget(old);
    if (old.days.first != widget.days.first ||
        old.days.length != widget.days.length) {
      _placed = false;
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  List<String> get _dates => [
    for (final d in widget.days) shootCalendarDate(d),
  ];

  int _minuteAt(double y) => (y / _hourHeight * 60).round();

  CalendarSpan _spanOf(ShootCalendarSlot slot, int day) {
    final e = slot.entry;
    final from = calendarMinutesOf(e.from) ?? slot.start;
    final to = calendarMinutesOf(e.to);
    final end = to == null
        ? from + 60
        : to <= from
        ? to + 24 * 60
        : to;
    return CalendarSpan(day, from, end);
  }

  void _begin(
    ShootCalendarEntry? entry,
    CalendarDragMode mode,
    CalendarSpan span,
    Offset global,
  ) => setState(() => _drag = _Drag(entry, mode, span, global));

  void _update(Offset global) {
    final drag = _drag;
    if (drag == null) return;
    final delta = global - drag.origin;
    final minutes = (delta.dy / _hourHeight * 60).round();
    setState(() {
      if (drag.entry == null) {
        final o = drag.original;
        drag.current = createCalendarSpan(o.day, o.start, o.start + minutes);
      } else {
        drag.current = dragCalendarSpan(
          drag.original,
          drag.mode,
          dayDelta: drag.mode == CalendarDragMode.move
              ? (delta.dx / _columnWidth).round()
              : 0,
          minuteDelta: minutes,
          days: widget.days.length,
        );
      }
    });
  }

  Future<void> _end() async {
    final drag = _drag;
    if (drag == null) return;
    final date = _dates[drag.current.day];
    if (drag.entry case final entry?) {
      if (drag.current != drag.original) {
        await widget.onSpan(entry, date, drag.current);
      }
    } else {
      final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
      final at =
          box?.localToGlobal(
            Offset(
              _rail + (drag.current.day + 0.5) * _columnWidth,
              drag.current.end / 60 * _hourHeight,
            ),
          ) ??
          drag.origin;
      await widget.onCreate(date, drag.current, at);
    }
    if (mounted) setState(() => _drag = null);
  }

  void _cancel() => setState(() => _drag = null);

  /// Mover con ratón al arrastrar; con el dedo, tras mantener pulsado.
  Widget _mover({
    required Widget child,
    required void Function(Offset global) begin,
    VoidCallback? onTap,
  }) {
    if (calendarUsesLongPress) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPressStart: (d) => begin(d.globalPosition),
        onLongPressMoveUpdate: (d) => _update(d.globalPosition),
        onLongPressEnd: (_) => _end(),
        onLongPressCancel: _cancel,
        child: child,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      dragStartBehavior: DragStartBehavior.down,
      onPanStart: (d) => begin(d.globalPosition),
      onPanUpdate: (d) => _update(d.globalPosition),
      onPanEnd: (_) => _end(),
      onPanCancel: _cancel,
      child: child,
    );
  }

  Widget _handle(void Function(Offset global) begin) => MouseRegion(
    cursor: SystemMouseCursors.resizeRow,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragStart: (d) => begin(d.globalPosition),
      onVerticalDragUpdate: (d) => _update(d.globalPosition),
      onVerticalDragEnd: (_) => _end(),
      onVerticalDragCancel: _cancel,
    ),
  );

  void _acceptScene(DragTargetDetails<UnscheduledShootScene> details) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.offset + const Offset(12, 12));
    final day = ((local.dx - _rail) / _columnWidth).floor().clamp(
      0,
      widget.days.length - 1,
    );
    final start = calendarSnap(_minuteAt(local.dy)).clamp(0, 23 * 60);
    widget.onDropScene(
      details.data,
      _dates[day],
      CalendarSpan(day, start, start + 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dates = _dates;
    final slots = {
      for (final date in dates) date: shootCalendarSlots(widget.entries, date),
    };
    final today = shootCalendarDate(DateTime.now());
    final untimed = {
      for (final date in dates)
        date: widget.entries
            .where((e) => e.date == date && !e.hasTime)
            .toList(),
    };
    final firstMinute = slots.values
        .expand((s) => s)
        .fold<int>(8 * 60, (m, s) => s.start < m ? s.start : m);
    if (!_placed) {
      _placed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.jumpTo(
          (firstMinute / 60 * _hourHeight - 12).clamp(
            0,
            _scroll.position.maxScrollExtent,
          ),
        );
      });
    }
    final maxUntimed = untimed.values.fold<int>(
      0,
      (m, l) => l.length > m ? l.length : m,
    );
    final single = widget.days.length == 1;
    final now = DateTime.now();
    final nowMinute = now.hour * 60 + now.minute;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth - _rail) / widget.days.length;
        _columnWidth = columnWidth;
        final drag = _drag;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: _rail),
                for (final (i, day) in widget.days.indexed)
                  SizedBox(
                    width: columnWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        single
                            ? '${kCalendarWeekdays[day.weekday - 1]} ${day.day} '
                                  'de ${kCalendarMonths[day.month - 1]}'
                            : '${kCalendarWeekdays[day.weekday - 1]} ${day.day}',
                        textAlign: TextAlign.center,
                        style: AppTypography.label(palette).copyWith(
                          color: dates[i] == today
                              ? palette.accent
                              : palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (maxUntimed > 0)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: _rail),
                  for (final date in dates)
                    SizedBox(
                      width: columnWidth,
                      height: maxUntimed * 26.0 + 4,
                      child: Column(
                        children: [
                          for (final e in untimed[date]!)
                            ShootCalendarChip(
                              entry: e,
                              onTap: () => widget.onOpen(e),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            Divider(height: 1, color: palette.divider),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                // Mientras se arrastra, la rejilla no se mueve con el dedo.
                physics: drag != null
                    ? const NeverScrollableScrollPhysics()
                    : null,
                child: DragTarget<UnscheduledShootScene>(
                  onAcceptWithDetails: _acceptScene,
                  builder: (context, candidates, _) => SizedBox(
                    key: _stackKey,
                    height: 24 * _hourHeight,
                    child: Stack(
                      children: [
                        for (var h = 0; h < 24; h++) ...[
                          Positioned(
                            top: h * _hourHeight,
                            left: _rail,
                            right: 0,
                            child: Container(height: 1, color: palette.divider),
                          ),
                          Positioned(
                            top: h * _hourHeight - 7,
                            left: 0,
                            width: _rail - 6,
                            child: Text(
                              h == 0
                                  ? ''
                                  : '${h.toString().padLeft(2, '0')}:00',
                              textAlign: TextAlign.right,
                              style: AppTypography.caption(
                                palette,
                              ).copyWith(fontSize: 10),
                            ),
                          ),
                        ],
                        for (final (i, date) in dates.indexed) ...[
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: _rail + i * columnWidth,
                            width: columnWidth,
                            child: _mover(
                              begin: (global) {
                                final box =
                                    _stackKey.currentContext?.findRenderObject()
                                        as RenderBox?;
                                if (box == null) return;
                                final y = box.globalToLocal(global).dy;
                                final start = calendarSnap(_minuteAt(y));
                                _begin(
                                  null,
                                  CalendarDragMode.resizeEnd,
                                  createCalendarSpan(i, start, start + 30),
                                  global,
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: candidates.isNotEmpty
                                      ? palette.accent.withValues(alpha: 0.04)
                                      : null,
                                  border: Border(
                                    left: BorderSide(color: palette.divider),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (date == today)
                            Positioned(
                              top: nowMinute / 60 * _hourHeight - 1,
                              left: _rail + i * columnWidth,
                              width: columnWidth,
                              child: IgnorePointer(
                                child: Container(
                                  height: 2,
                                  color: palette.error,
                                ),
                              ),
                            ),
                          for (final slot in slots[date]!)
                            Positioned(
                              top: slot.start / 60 * _hourHeight + 1,
                              height:
                                  (slot.end - slot.start) / 60 * _hourHeight -
                                  2,
                              left:
                                  _rail +
                                  i * columnWidth +
                                  2 +
                                  slot.column *
                                      (columnWidth - 4) /
                                      slot.columns,
                              width: (columnWidth - 4) / slot.columns - 1,
                              child: Opacity(
                                opacity:
                                    drag?.entry?.key == slot.entry.key &&
                                        drag?.current != drag?.original
                                    ? 0.35
                                    : 1,
                                child: _slot(slot, i),
                              ),
                            ),
                        ],
                        if (drag != null) _preview(drag, palette, columnWidth),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _slot(ShootCalendarSlot slot, int day) {
    final entry = slot.entry;
    final block = ShootCalendarBlock(slot: slot);
    if (!entry.editable || slot.continued) {
      return GestureDetector(onTap: () => widget.onOpen(entry), child: block);
    }
    final span = _spanOf(slot, day);
    // El final de una noche está en la columna siguiente.
    final endsHere = span.end <= 24 * 60;
    return Stack(
      fit: StackFit.expand,
      children: [
        _mover(
          onTap: () => widget.onOpen(entry),
          begin: (g) => _begin(entry, CalendarDragMode.move, span, g),
          child: block,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 6,
          child: _handle(
            (g) => _begin(entry, CalendarDragMode.resizeStart, span, g),
          ),
        ),
        if (endsHere)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 6,
            child: _handle(
              (g) => _begin(entry, CalendarDragMode.resizeEnd, span, g),
            ),
          ),
      ],
    );
  }

  Widget _preview(_Drag drag, AppPalette palette, double columnWidth) {
    final span = drag.current;
    final color = drag.entry == null
        ? palette.accent
        : shootCalendarColor(drag.entry!, palette);
    final end = span.end > 24 * 60 ? 24 * 60 : span.end;
    return Positioned(
      top: span.start / 60 * _hourHeight + 1,
      height: ((end - span.start) / 60 * _hourHeight - 2).clamp(
        10,
        double.infinity,
      ),
      left: _rail + span.day * columnWidth + 2,
      width: columnWidth - 5,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 2, 2, 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            '${calendarHm(span.start)} – ${calendarHm(span.end)}'
            '${drag.entry == null ? '' : '\n${drag.entry!.title}'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption(palette).copyWith(
              color: palette.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class ShootCalendarBlock extends StatelessWidget {
  final ShootCalendarSlot slot;

  const ShootCalendarBlock({super.key, required this.slot});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entry = slot.entry;
    final color = shootCalendarColor(entry, palette);
    return Tooltip(
      message: [
        '${shootCalendarPrefix(entry)}${entry.title}',
        if (entry.from != null) shootTimeRange(entry.from, entry.to),
        if (entry.detail?.isNotEmpty ?? false) entry.detail!,
      ].join('\n'),
      waitDuration: const Duration(milliseconds: 600),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 2, 2, 2),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            color.withValues(
              alpha: entry.kind == ShootCalendarKind.shoot ? 0.16 : 0.32,
            ),
            palette.surface,
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        // Si se pisan muchas, la columna no da para leer: queda el color,
        // y el nombre sale al pasar por encima o al tocar.
        child: LayoutBuilder(
          builder: (context, box) => box.maxWidth < 44
              ? const SizedBox.expand()
              : Text(
                  '${slot.continued ? '(sigue) ' : ''}'
                  '${shootCalendarPrefix(entry)}${entry.title}'
                  '${(slot.end - slot.start) >= 60 && entry.from != null ? '\n${shootTimeRange(entry.from, entry.to)}' : ''}',
                  maxLines: (slot.end - slot.start) >= 60 ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(palette).copyWith(
                    color: palette.textPrimary,
                    fontSize: 11,
                    height: 1.15,
                    decoration: entry.done ? TextDecoration.lineThrough : null,
                  ),
                ),
        ),
      ),
    );
  }
}

class ShootCalendarChip extends StatelessWidget {
  final ShootCalendarEntry entry;
  final VoidCallback onTap;

  const ShootCalendarChip({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = shootCalendarColor(entry, palette);
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 22,
        margin: const EdgeInsets.fromLTRB(2, 0, 2, 4),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${shootCalendarPrefix(entry)}${entry.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textPrimary, fontSize: 11),
        ),
      ),
    );
  }
}
