import '../../core/database/app_database.dart';
import 'shoot_calendar_edit.dart';
import 'shoot_day_timeline.dart';
import 'shoot_plan.dart';

enum ShootCalendarKind { shoot, strip, scene, pickup, ret }

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

  /// Fecha de la jornada de origen: una franja de madrugada cae en [date],
  /// el día siguiente.
  final String? dayDate;

  /// Bloque de la franja, o el primero del tramo de la escena.
  final int? blockId;

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
    this.dayDate,
    this.blockId,
  });

  bool get hasTime => from != null;

  /// Se puede mover y estirar en la rejilla.
  bool get editable =>
      kind == ShootCalendarKind.shoot ||
      kind == ShootCalendarKind.strip ||
      kind == ShootCalendarKind.scene;

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
  Map<int, Scene> scenes = const {},
  Map<int, Shot> shots = const {},
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
        dayDate: date,
      ),
    );
    // La madrugada de una jornada de noche cae al día siguiente.
    String dateOf(String? hm) =>
        hm != null && calendarMinutesInDay(hm, d.shootFromTime) >= 24 * 60
        ? calendarAddDays(date, 1)
        : date;
    final dayBlocks = [
      for (final b in blocks)
        if (b.documentId == d.id) b,
    ];
    for (final entry in buildShootDayEntries(dayBlocks, shots)) {
      if (entry is! ShootSceneEntry) continue;
      final first = entry.blocks.first;
      final schedule = SceneSchedule.of(first);
      if (schedule.from == null) continue;
      final scene = scenes[entry.sceneId];
      entries.add(
        ShootCalendarEntry(
          key: 'scene:${first.id}',
          date: dateOf(schedule.from),
          kind: ShootCalendarKind.scene,
          title: scene == null ? 'Escena' : 'Esc. ${scene.label}',
          from: schedule.from,
          to: schedule.to,
          detail: [
            ?scene?.locationPureName,
            if (schedule.note.trim().isNotEmpty) schedule.note.trim(),
          ].join(' · '),
          dayId: d.id,
          dayDate: date,
          blockId: first.id,
        ),
      );
    }
    for (final b in dayBlocks) {
      if (!ShootStrip.isStrip(b)) continue;
      final strip = ShootStrip.of(b);
      entries.add(
        ShootCalendarEntry(
          key: 'strip:${b.id}',
          date: dateOf(strip.from),
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
          dayDate: date,
          blockId: b.id,
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
  final previous = calendarAddDays(date, -1);
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

/// Una escena de una jornada con fecha que aún no tiene hora.
class UnscheduledShootScene {
  final int dayId;
  final String dayName;
  final String date;
  final String? dayFrom;
  final int sceneId;

  /// Primer bloque del tramo: ahí se guarda la hora.
  final ShootDocumentBlock block;
  final int shots;

  const UnscheduledShootScene({
    required this.dayId,
    required this.dayName,
    required this.date,
    required this.dayFrom,
    required this.sceneId,
    required this.block,
    required this.shots,
  });
}

/// Las escenas sin hora de las jornadas de [dates].
List<UnscheduledShootScene> unscheduledShootScenes({
  required List<ShootDocument> documents,
  required List<ShootDocumentBlock> blocks,
  required Map<int, Shot> shots,
  required Set<String> dates,
}) {
  final out = <UnscheduledShootScene>[];
  for (final d in sortShootDays(documents)) {
    final date = d.shootDate;
    if (date == null || !dates.contains(date)) continue;
    final dayBlocks = [
      for (final b in blocks)
        if (b.documentId == d.id) b,
    ];
    for (final entry in buildShootDayEntries(dayBlocks, shots)) {
      if (entry is! ShootSceneEntry) continue;
      final first = entry.blocks.first;
      if (SceneSchedule.of(first).from != null) continue;
      out.add(
        UnscheduledShootScene(
          dayId: d.id,
          dayName: d.name,
          date: date,
          dayFrom: d.shootFromTime,
          sceneId: entry.sceneId,
          block: first,
          shots: entry.shotBlocks(shots).length,
        ),
      );
    }
  }
  return out;
}
