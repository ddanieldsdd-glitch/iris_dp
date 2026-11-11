/// Cuentas del calendario editable: minutos, imán y arrastres. Sin interfaz,
/// para poder probarlas.
library;

const kCalendarSnap = 15;
const kCalendarShortest = 15;
const _day = 24 * 60;

/// «07:30» → 450. Nulo si no se puede leer.
int? calendarMinutesOf(String? hm) {
  if (hm == null) return null;
  final parts = hm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

/// 450 → «07:30». Pasadas las doce vuelve a empezar: 1530 → «01:30».
String calendarHm(int minutes) {
  final m = ((minutes % _day) + _day) % _day;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

int calendarSnap(int minutes, {int step = kCalendarSnap}) =>
    (minutes / step).round() * step;

/// Un tramo en la rejilla: día (columna, desde la primera) y minutos desde
/// las 00:00 de ese día. [end] pasa de 1440 si acaba al día siguiente.
class CalendarSpan {
  final int day;
  final int start;
  final int end;

  const CalendarSpan(this.day, this.start, this.end);

  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is CalendarSpan &&
      other.day == day &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(day, start, end);

  @override
  String toString() => 'día $day ${calendarHm(start)}–${calendarHm(end)}';
}

enum CalendarDragMode { move, resizeStart, resizeEnd }

/// Dónde queda [original] tras arrastrarlo [dayDelta] columnas y
/// [minuteDelta] minutos, con imán a [step].
CalendarSpan dragCalendarSpan(
  CalendarSpan original,
  CalendarDragMode mode, {
  int dayDelta = 0,
  required int minuteDelta,
  int days = 7,
  int step = kCalendarSnap,
}) {
  switch (mode) {
    case CalendarDragMode.move:
      final length = original.length;
      final day = (original.day + dayDelta).clamp(0, days - 1);
      final start = calendarSnap(
        original.start + minuteDelta,
        step: step,
      ).clamp(0, _day - step);
      return CalendarSpan(day, start, start + length);
    case CalendarDragMode.resizeEnd:
      final end = calendarSnap(
        original.end + minuteDelta,
        step: step,
      ).clamp(original.start + kCalendarShortest, original.start + _day);
      return CalendarSpan(original.day, original.start, end);
    case CalendarDragMode.resizeStart:
      final start = calendarSnap(
        original.start + minuteDelta,
        step: step,
      ).clamp(0, original.end - kCalendarShortest);
      return CalendarSpan(original.day, start, original.end);
  }
}

/// El tramo que se dibuja arrastrando en un hueco de [from] a [to].
CalendarSpan createCalendarSpan(
  int day,
  int from,
  int to, {
  int step = kCalendarSnap,
  int shortest = 30,
}) {
  var a = calendarSnap(from < to ? from : to, step: step).clamp(0, _day - step);
  var b = calendarSnap(from < to ? to : from, step: step);
  if (b - a < shortest) b = a + shortest;
  return CalendarSpan(day, a, b.clamp(a + step, _day));
}

DateTime _utc(String date) => DateTime.parse('${date}T00:00:00Z');

/// Días de [from] a [to] (`yyyy-MM-dd`), sin que el cambio de hora cuente.
int calendarDaysBetween(String from, String to) =>
    _utc(to).difference(_utc(from)).inDays;

/// [date] más [days] días, en `yyyy-MM-dd`.
String calendarAddDays(String date, int days) =>
    _utc(date).add(Duration(days: days)).toIso8601String().substring(0, 10);

/// Desde el día de la jornada, cuántos minutos son [hm]. Lo de madrugada en
/// una jornada que empieza por la tarde va al día siguiente.
int calendarMinutesInDay(String hm, String? dayFrom) {
  final m = calendarMinutesOf(hm) ?? 0;
  final start = calendarMinutesOf(dayFrom);
  if (start == null) return m < 5 * 60 ? m + _day : m;
  return m < start - 3 * 60 ? m + _day : m;
}

/// Las horas de una franja o escena de la jornada de [dayDate] puestas en
/// [span], que está en la columna de [spanDate]. Nulo si queda fuera de la
/// jornada (más de un día de distancia).
({String from, String to})? calendarTimesInDay({
  required String dayDate,
  required String spanDate,
  required CalendarSpan span,
}) {
  final offset = calendarDaysBetween(dayDate, spanDate);
  final start = offset * _day + span.start;
  if (start < 0 || start >= 2 * _day) return null;
  return (from: calendarHm(start), to: calendarHm(start + span.length));
}
