import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/rental_queries.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'shoot_plan.dart';

enum ShootAgendaKind { shoot, pickup, ret }

class ShootAgendaEntry {
  final ShootAgendaKind kind;
  final String title;
  final String? detail;
  final bool done;

  const ShootAgendaEntry({
    required this.kind,
    required this.title,
    this.detail,
    this.done = false,
  });
}

/// Lo que toca en los próximos días, sacado de las jornadas y las reservas:
/// no guarda nada propio, así que no puede contradecirlas.
Map<String, List<ShootAgendaEntry>> buildShootAgenda({
  required List<ShootDocument> documents,
  required List<RentalReservation> reservations,
  required Map<String, RentalHouse> houses,
  required Map<int, LocationSite> sites,
  required DateTime now,
  int maxDays = 7,
}) {
  final today =
      '${now.year}-${now.month.toString().padLeft(2, '0')}'
      '-${now.day.toString().padLeft(2, '0')}';
  final byDate = <String, List<(int, String, ShootAgendaEntry)>>{};
  void add(String date, int rank, String time, ShootAgendaEntry e) {
    if (date.compareTo(today) < 0) return;
    byDate.putIfAbsent(date, () => []).add((rank, time, e));
  }

  for (final d in documents) {
    final date = d.shootDate;
    if (d.kind != kShootDayKind || date == null || date.isEmpty) continue;
    final from = d.shootFromTime;
    final to = d.shootToTime;
    add(
      date,
      1,
      from ?? '',
      ShootAgendaEntry(
        kind: ShootAgendaKind.shoot,
        title: d.name,
        detail: [
          if (from != null && to != null)
            '$from – $to'
          else if (from != null)
            from,
          if (sites[d.locationSiteId]?.name case final place?) place,
        ].join(' · '),
      ),
    );
  }

  String? timeOf(String? value) =>
      value != null && value.length >= 16 ? value.substring(11, 16) : null;

  void addRental(
    RentalReservation r,
    ShootAgendaKind kind,
    String? when,
    bool done,
  ) {
    if (when == null || when.length < 10) return;
    final time = timeOf(when);
    add(
      when.substring(0, 10),
      0,
      time ?? '',
      ShootAgendaEntry(
        kind: kind,
        title: r.title,
        detail: [
          if (time != null) time,
          if (houses[r.houseUid]?.name case final house?) house,
        ].join(' · '),
        done: done,
      ),
    );
  }

  for (final r in reservations) {
    addRental(r, ShootAgendaKind.pickup, r.pickupAt, r.pickedUpAt != null);
    addRental(r, ShootAgendaKind.ret, r.returnAt, r.returnedAt != null);
  }

  final dates = byDate.keys.toList()..sort();
  return {
    for (final date in dates.take(maxDays))
      date: [
        for (final item
            in byDate[date]!..sort((a, b) {
              final byTime = a.$2.compareTo(b.$2);
              return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
            }))
          item.$3,
      ],
  };
}

String _dayLabel(String date) {
  final d = DateTime.tryParse(date);
  if (d == null) return date;
  const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
}

/// El bloque «Próximos días» de Documentos de rodaje.
class ShootAgendaSection extends ConsumerStatefulWidget {
  final int projectId;

  const ShootAgendaSection({super.key, required this.projectId});

  @override
  ConsumerState<ShootAgendaSection> createState() => _ShootAgendaSectionState();
}

class _ShootAgendaSectionState extends ConsumerState<ShootAgendaSection> {
  late final AppDatabase _db = ref.read(databaseProvider);
  late final _documents = _db.watchShootDocumentsForProject(widget.projectId);
  late final _reservations = _db.watchRentalReservations(widget.projectId);
  late final _houses = _db.watchRentalHouses(widget.projectId);
  late final _sites = _db.watchSitesForProject(widget.projectId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ShootDocument>>(
      stream: _documents,
      builder: (context, docs) => StreamBuilder<List<RentalReservation>>(
        stream: _reservations,
        builder: (context, reservations) => StreamBuilder<List<RentalHouse>>(
          stream: _houses,
          builder: (context, houses) => StreamBuilder<List<LocationSite>>(
            stream: _sites,
            builder: (context, sites) {
              final agenda = buildShootAgenda(
                documents: docs.data ?? const [],
                reservations: reservations.data ?? const [],
                houses: {
                  for (final h in houses.data ?? const <RentalHouse>[])
                    h.uid: h,
                },
                sites: {
                  for (final s in sites.data ?? const <LocationSite>[])
                    s.id: s,
                },
                now: DateTime.now(),
              );
              if (agenda.isEmpty) return const SizedBox.shrink();
              return _agenda(context, agenda);
            },
          ),
        ),
      ),
    );
  }

  Widget _agenda(
    BuildContext context,
    Map<String, List<ShootAgendaEntry>> agenda,
  ) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Próximos días', style: AppTypography.label(palette)),
          const SizedBox(height: AppSpacing.sm),
          for (final e in agenda.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      _dayLabel(e.key),
                      style: AppTypography.bodyMedium(
                        palette,
                      ).copyWith(color: palette.textPrimary),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in e.value) _entry(palette, entry),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _entry(AppPalette palette, ShootAgendaEntry e) {
    final (icon, prefix) = switch (e.kind) {
      ShootAgendaKind.shoot => (Icons.videocam_outlined, 'Rodaje'),
      ShootAgendaKind.pickup => (Icons.inventory_2_outlined, 'Recoger'),
      ShootAgendaKind.ret => (Icons.assignment_return_outlined, 'Devolver'),
    };
    final detail = e.detail ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            e.done ? Icons.check : icon,
            size: 15,
            color: e.done ? palette.accent : palette.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$prefix · ${e.title}${detail.isEmpty ? '' : ' · $detail'}',
              style: AppTypography.caption(palette).copyWith(
                decoration: e.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
