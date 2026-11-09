import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/rental_queries.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../equipment/rentals/rentals_tab.dart';
import 'shoot_calendar.dart';
import 'shoot_day_screen.dart';
import 'shoot_day_timeline.dart';
import 'shoot_day_widgets.dart';

const _pickupColor = Color(0xFF6FCF97);
const _returnColor = Color(0xFFE58A6B);

const _weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _months = [
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

Color _colorOf(ShootCalendarEntry e, AppPalette palette) => switch (e.kind) {
  ShootCalendarKind.shoot => palette.accent,
  ShootCalendarKind.pickup => _pickupColor,
  ShootCalendarKind.ret => _returnColor,
  ShootCalendarKind.strip => shootStripColor(e.stripKind!, palette),
};

String _prefix(ShootCalendarEntry e) => switch (e.kind) {
  ShootCalendarKind.pickup => 'Recoger · ',
  ShootCalendarKind.ret => 'Devolver · ',
  _ => '',
};

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

/// Calendario de rodaje: jornadas, franjas, recogidas y devoluciones.
/// Semana con horas o mes en pantallas anchas; agenda en el iPhone.
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
  late final _documents = _db.watchShootDocumentsForProject(widget.projectId);
  late final _blocks = _db.watchShootDayBlocks(widget.projectId);
  late final _reservations = _db.watchRentalReservations(widget.projectId);
  late final _houses = _db.watchRentalHouses(widget.projectId);
  late final _sites = _db.watchSitesForProject(widget.projectId);

  bool _month = false;
  bool _showPast = false;
  DateTime? _anchor;

  /// Sin elegir nada, la semana de lo próximo que haya.
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

  void _step(DateTime anchor, int direction) => setState(() {
    _anchor = _month
        ? DateTime(anchor.year, anchor.month + direction, 1)
        : anchor.add(Duration(days: 7 * direction));
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario de rodaje')),
      body: StreamBuilder<List<ShootDocument>>(
        stream: _documents,
        builder: (context, docs) => StreamBuilder<List<ShootDocumentBlock>>(
          stream: _blocks,
          builder: (context, blocks) => StreamBuilder<List<RentalReservation>>(
            stream: _reservations,
            builder: (context, reservations) =>
                StreamBuilder<List<RentalHouse>>(
                  stream: _houses,
                  builder: (context, houses) =>
                      StreamBuilder<List<LocationSite>>(
                        stream: _sites,
                        builder: (context, sites) {
                          if (!docs.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final entries = buildShootCalendar(
                            documents: docs.data!,
                            blocks: blocks.data ?? const [],
                            reservations: reservations.data ?? const [],
                            houses: {
                              for (final h
                                  in houses.data ?? const <RentalHouse>[])
                                h.uid: h,
                            },
                            sites: {
                              for (final s
                                  in sites.data ?? const <LocationSite>[])
                                s.id: s,
                            },
                          );
                          return LayoutBuilder(
                            builder: (context, constraints) =>
                                constraints.maxWidth < 720
                                ? _agenda(entries)
                                : _wide(entries),
                          );
                        },
                      ),
                ),
          ),
        ),
      ),
    );
  }

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
        const _Legend(),
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
              'Aún no hay jornadas con fecha ni reservas.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(palette),
            ),
          ),
        for (final date in dates) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_longDate(date), style: AppTypography.label(palette)),
          const SizedBox(height: 6),
          for (final e in shown.where((e) => e.date == date))
            _AgendaTile(entry: e, onTap: () => _openEntry(e)),
        ],
      ],
    );
  }

  static String _longDate(String date) {
    final d = DateTime.parse(date);
    return '${_weekdays[d.weekday - 1]} ${d.day} de ${_months[d.month - 1]}';
  }

  Widget _wide(List<ShootCalendarEntry> entries) {
    final palette = context.palette;
    final anchor = _anchorFor(entries);
    final monday = _mondayOf(anchor);
    final sunday = monday.add(const Duration(days: 6));
    final title = _month
        ? '${_months[anchor.month - 1]} ${anchor.year}'
        : monday.month == sunday.month
        ? '${monday.day} – ${sunday.day} de ${_months[monday.month - 1]}'
        : '${monday.day} de ${_months[monday.month - 1]} – '
              '${sunday.day} de ${_months[sunday.month - 1]}';
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
                onPressed: () => _step(anchor, -1),
              ),
              IconButton(
                tooltip: 'Siguiente',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _step(anchor, 1),
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
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: false, label: Text('Semana')),
                  ButtonSegment(value: true, label: Text('Mes')),
                ],
                selected: {_month},
                onSelectionChanged: (v) => setState(() => _month = v.first),
              ),
              const SizedBox(width: AppSpacing.sm),
              const _Legend(),
            ],
          ),
        ),
        Divider(height: 1, color: palette.divider),
        Expanded(
          child: _month
              ? _MonthGrid(
                  month: anchor,
                  entries: entries,
                  onOpen: _openEntry,
                  onPickDay: (day) => setState(() {
                    _anchor = day;
                    _month = false;
                  }),
                )
              : _WeekGrid(monday: monday, entries: entries, onOpen: _openEntry),
        ),
      ],
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
        const _LegendDot(_pickupColor, 'Recogida'),
        const _LegendDot(_returnColor, 'Devolución'),
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
    final color = _colorOf(entry, palette);
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
                    '${_prefix(entry)}${entry.title}',
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

/// Semana con horas: cada entrada ocupa su franja, como en un calendario.
class _WeekGrid extends StatefulWidget {
  final DateTime monday;
  final List<ShootCalendarEntry> entries;
  final ValueChanged<ShootCalendarEntry> onOpen;

  const _WeekGrid({
    required this.monday,
    required this.entries,
    required this.onOpen,
  });

  @override
  State<_WeekGrid> createState() => _WeekGridState();
}

class _WeekGridState extends State<_WeekGrid> {
  static const _hourHeight = 46.0;
  static const _rail = 46.0;
  final _scroll = ScrollController();
  bool _placed = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final days = [
      for (var i = 0; i < 7; i++) widget.monday.add(Duration(days: i)),
    ];
    final dates = [for (final d in days) shootCalendarDate(d)];
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth - _rail) / 7;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: _rail),
                for (final (i, day) in days.indexed)
                  SizedBox(
                    width: columnWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${_weekdays[i]} ${day.day}',
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
                            _EventChip(entry: e, onTap: () => widget.onOpen(e)),
                        ],
                      ),
                    ),
                ],
              ),
            Divider(height: 1, color: palette.divider),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                child: SizedBox(
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
                            h == 0 ? '' : '${h.toString().padLeft(2, '0')}:00',
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
                          child: Container(width: 1, color: palette.divider),
                        ),
                        for (final slot in slots[date]!)
                          Positioned(
                            top: slot.start / 60 * _hourHeight + 1,
                            height:
                                (slot.end - slot.start) / 60 * _hourHeight - 2,
                            left:
                                _rail +
                                i * columnWidth +
                                2 +
                                slot.column * (columnWidth - 4) / slot.columns,
                            width: (columnWidth - 4) / slot.columns - 1,
                            child: _EventBlock(
                              slot: slot,
                              onTap: () => widget.onOpen(slot.entry),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EventBlock extends StatelessWidget {
  final ShootCalendarSlot slot;
  final VoidCallback onTap;

  const _EventBlock({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entry = slot.entry;
    final color = _colorOf(entry, palette);
    return Tooltip(
      message: [
        '${_prefix(entry)}${entry.title}',
        if (entry.detail?.isNotEmpty ?? false) entry.detail!,
      ].join('\n'),
      child: InkWell(
        onTap: onTap,
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
                    '${_prefix(entry)}${entry.title}',
                    maxLines: (slot.end - slot.start) >= 60 ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(palette).copyWith(
                      color: palette.textPrimary,
                      fontSize: 11,
                      height: 1.15,
                      decoration: entry.done
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  final ShootCalendarEntry entry;
  final VoidCallback onTap;

  const _EventChip({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = _colorOf(entry, palette);
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
          '${_prefix(entry)}${entry.title}',
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

/// El mes entero. Tocar un día lleva a su semana.
class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final List<ShootCalendarEntry> entries;
  final ValueChanged<ShootCalendarEntry> onOpen;
  final ValueChanged<DateTime> onPickDay;

  const _MonthGrid({
    required this.month,
    required this.entries,
    required this.onOpen,
    required this.onPickDay,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final start = _mondayOf(firstOfMonth);
    final today = shootCalendarDate(DateTime.now());
    final byDate = <String, List<ShootCalendarEntry>>{};
    for (final e in entries) {
      byDate.putIfAbsent(e.date, () => []).add(e);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final name in _weekdays)
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
                        return InkWell(
                          onTap: () => onPickDay(day),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
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
    final color = _colorOf(entry, palette);
    return InkWell(
      onTap: () => onOpen(entry),
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
          '${_prefix(entry)}${entry.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.textPrimary, fontSize: 10),
        ),
      ),
    );
  }
}
