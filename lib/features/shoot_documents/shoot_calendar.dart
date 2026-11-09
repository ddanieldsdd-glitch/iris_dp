import '../../core/database/app_database.dart';
import 'shoot_day_timeline.dart';
import 'shoot_plan.dart';

enum ShootCalendarKind { shoot, strip, pickup, ret }

/// Una entrada del calendario de rodaje. Sale de las jornadas, sus franjas y
/// las reservas: el calendario no guarda nada propio, así que no puede
/// contradecirlas.
class ShootCalendarEntry {
  /// Clave estable, pensada para enlazar calendarios externos más adelante.
  final String key;

  /// `yyyy-MM-dd`.
  final String date;
  final String? from;
  final String? to;
  final ShootCalendarKind kind;
  final ShootStripKind? stripKind;
  final String title;
  final String? detail;
  final bool done;

  /// Jornada de origen, si la tiene.
  final int? dayId;

  const ShootCalendarEntry({
    required this.key,
    required this.date,
    required this.kind,
    required this.title,
    this.from,
    this.to,
    this.stripKind,
    this.detail,
    this.done = false,
    this.dayId,
  });

  bool get hasTime => from != null;

  /// Termina al día siguiente: rodaje de noche.
  bool get crossesMidnight =>
      from != null && to != null && to!.compareTo(from!) < 0;
}

String? _timeOf(String? value) =>
    value != null && value.length >= 16 ? value.substring(11, 16) : null;

/// Las entradas de todo el rodaje, ordenadas por fecha y hora.
List<ShootCalendarEntry> buildShootCalendar({
  required List<ShootDocument> documents,
  required List<ShootDocumentBlock> blocks,
  required List<RentalReservation> reservations,
  required Map<String, RentalHouse> houses,
  required Map<int, LocationSite> sites,
}) {
  final entries = <ShootCalendarEntry>[];
  final sitesByUid = {
    for (final s in sites.values)
      if (s.uid != null) s.uid!: s,
  };
  for (final d in sortShootDays(documents)) {
    final date = d.shootDate;
    if (date == null || date.isEmpty) continue;
    final place = sites[d.locationSiteId]?.name;
    entries.add(
      ShootCalendarEntry(
        key: 'shoot:${d.id}',
        date: date,
        kind: ShootCalendarKind.shoot,
        title: d.name,
        from: d.shootFromTime,
        to: d.shootToTime,
        detail: [
          if (d.shootFromTime != null && d.shootToTime != null)
            '${d.shootFromTime} – ${d.shootToTime}'
          else if (d.shootFromTime != null)
            d.shootFromTime!,
          ?place,
        ].join(' · '),
        dayId: d.id,
      ),
    );
    for (final b in blocks) {
      if (b.documentId != d.id || !ShootStrip.isStrip(b)) continue;
      final strip = ShootStrip.of(b);
      entries.add(
        ShootCalendarEntry(
          key: 'strip:${b.id}',
          date: date,
          kind: ShootCalendarKind.strip,
          stripKind: strip.kind,
          title: ShootStrip.titleOf(b),
          from: strip.from,
          to: strip.to,
          detail: [
            ?sitesByUid[strip.siteUid]?.name,
            if (b.noteBody?.trim().isNotEmpty ?? false) b.noteBody!.trim(),
          ].join(' · '),
          dayId: d.id,
        ),
      );
    }
  }

  void addRental(
    RentalReservation r,
    ShootCalendarKind kind,
    String? when,
    bool done,
  ) {
    if (when == null || when.length < 10) return;
    final time = _timeOf(when);
    final house = houses[r.houseUid]?.name;
    entries.add(
      ShootCalendarEntry(
        key:
            '${kind == ShootCalendarKind.pickup ? 'pickup' : 'return'}:${r.uid}',
        date: when.substring(0, 10),
        kind: kind,
        title: r.title,
        from: time,
        detail: [?time, ?house].join(' · '),
        done: done,
      ),
    );
  }

  for (final r in reservations) {
    addRental(r, ShootCalendarKind.pickup, r.pickupAt, r.pickedUpAt != null);
    addRental(r, ShootCalendarKind.ret, r.returnAt, r.returnedAt != null);
  }

  int rank(ShootCalendarEntry e) => e.kind == ShootCalendarKind.shoot ? 1 : 0;
  final indexed = entries.indexed.toList()
    ..sort((a, b) {
      final date = a.$2.date.compareTo(b.$2.date);
      if (date != 0) return date;
      final time = (a.$2.from ?? '').compareTo(b.$2.from ?? '');
      if (time != 0) return time;
      final byRank = rank(a.$2).compareTo(rank(b.$2));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
  return [for (final (_, e) in indexed) e];
}

/// Un trozo de entrada dentro de un día de la semana, en minutos.
class ShootCalendarSlot {
  final ShootCalendarEntry entry;
  final int start;
  final int end;

  /// Es la continuación de la noche anterior.
  final bool continued;

  /// Columna dentro del día y columnas en total, si se solapan.
  int column = 0;
  int columns = 1;

  ShootCalendarSlot(this.entry, this.start, this.end, {this.continued = false});
}

int _minutes(String hhmm) {
  final parts = hhmm.split(':');
  return (int.tryParse(parts.first) ?? 0) * 60 +
      (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
}

/// `yyyy-MM-dd` de [day].
String shootCalendarDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Lo que ocupa [date] en la rejilla de horas. Una noche que pasa de las doce
/// se reparte entre los dos días.
List<ShootCalendarSlot> shootCalendarSlots(
  List<ShootCalendarEntry> entries,
  String date,
) {
  const shortest = 45;
  final previous = shootCalendarDate(
    DateTime.parse(date).subtract(const Duration(days: 1)),
  );
  final slots = <ShootCalendarSlot>[];
  for (final e in entries) {
    if (!e.hasTime) continue;
    if (e.date == date) {
      final start = _minutes(e.from!);
      final end = e.to == null
          ? start + shortest
          : e.crossesMidnight
          ? 24 * 60
          : _minutes(e.to!);
      slots.add(
        ShootCalendarSlot(
          e,
          start,
          (end < start + shortest ? start + shortest : end).clamp(0, 24 * 60),
        ),
      );
    } else if (e.date == previous && e.crossesMidnight) {
      slots.add(ShootCalendarSlot(e, 0, _minutes(e.to!), continued: true));
    }
  }
  slots.sort((a, b) => a.start.compareTo(b.start));
  // Reparte en columnas los que se pisan.
  var group = <ShootCalendarSlot>[];
  var groupEnd = -1;
  void close() {
    final ends = <int>[];
    for (final slot in group) {
      final free = ends.indexWhere((end) => end <= slot.start);
      if (free >= 0) {
        slot.column = free;
        ends[free] = slot.end;
      } else {
        slot.column = ends.length;
        ends.add(slot.end);
      }
    }
    for (final slot in group) {
      slot.columns = ends.length;
    }
    group = [];
  }

  for (final slot in slots) {
    if (slot.start >= groupEnd) {
      close();
      groupEnd = slot.end;
    } else if (slot.end > groupEnd) {
      groupEnd = slot.end;
    }
    group.add(slot);
  }
  close();
  return slots;
}
