import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/database/rental_queries.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'shoot_calendar.dart';

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
  final today = shootCalendarDate(now);
  final calendar = buildShootCalendar(
    documents: documents,
    blocks: const [],
    reservations: reservations,
    houses: houses,
    sites: sites,
  );
  final byDate = <String, List<ShootAgendaEntry>>{};
  for (final e in calendar) {
    if (e.date.compareTo(today) < 0) continue;
    byDate
        .putIfAbsent(e.date, () => [])
        .add(
          ShootAgendaEntry(
            kind: switch (e.kind) {
              ShootCalendarKind.pickup => ShootAgendaKind.pickup,
              ShootCalendarKind.ret => ShootAgendaKind.ret,
              _ => ShootAgendaKind.shoot,
            },
            title: e.title,
            detail: e.detail,
            done: e.done,
          ),
        );
  }
  final dates = byDate.keys.toList()..sort();
  return {for (final date in dates.take(maxDays)) date: byDate[date]!};
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
                  for (final s in sites.data ?? const <LocationSite>[]) s.id: s,
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
                    width: 100,
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
