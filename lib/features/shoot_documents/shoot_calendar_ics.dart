import 'dart:convert';

import 'shoot_calendar.dart';
import 'shoot_calendar_edit.dart';

String _escape(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\r\n', r'\n')
    .replaceAll('\n', r'\n');

/// Las líneas de más de 75 bytes siguen en la siguiente con un espacio, como
/// pide el formato.
String _fold(String line) {
  final bytes = utf8.encode(line);
  if (bytes.length <= 75) return line;
  final out = StringBuffer();
  var count = 0;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    final size = utf8.encode(char).length;
    if (count + size > 74) {
      out.write('\r\n ');
      count = 1;
    }
    out.write(char);
    count += size;
  }
  return out.toString();
}

String _stamp(String date, String hm) =>
    '${date.replaceAll('-', '')}T${hm.replaceAll(':', '')}00';

/// Identificador que no cambia entre aparatos ni al volver a exportar: sale
/// del proyecto, del tipo y de lo que se ve, no de los ids locales.
String _uid(String project, ShootCalendarEntry e) {
  final kind = e.kind.name;
  final base = switch (e.kind) {
    ShootCalendarKind.shoot => '$kind|${e.title}',
    ShootCalendarKind.pickup ||
    ShootCalendarKind.ret => '$kind|${e.title}|${e.date}',
    _ => '$kind|${e.dayDate}|${e.title}|${e.from}',
  };
  final hash = base64Url
      .encode(utf8.encode('$project|$base'))
      .replaceAll('=', '');
  return '$hash@iris-dp';
}

String _prefix(ShootCalendarEntry e) => switch (e.kind) {
  ShootCalendarKind.pickup => 'Recoger · ',
  ShootCalendarKind.ret => 'Devolver · ',
  _ => '',
};

/// El calendario de rodaje en `.ics`, para abrirlo en Calendario, Google u
/// Outlook. Las horas van sin zona: se leen en la hora del aparato.
String buildShootCalendarIcs({
  required String projectName,
  required List<ShootCalendarEntry> entries,
  DateTime? now,
}) {
  final stamp = (now ?? DateTime.now()).toUtc();
  final dtStamp =
      '${stamp.toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//IRIS DP//Calendario de rodaje//ES',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:${_escape('Rodaje · $projectName')}',
  ];
  final seen = <String>{};
  for (final e in entries) {
    var uid = _uid(projectName, e);
    // Dos iguales (mismo título y hora) siguen siendo dos.
    for (var n = 2; !seen.add(uid); n++) {
      uid = '${_uid(projectName, e)}-$n';
    }
    lines.add('BEGIN:VEVENT');
    lines.add('UID:$uid');
    lines.add('DTSTAMP:$dtStamp');
    final from = e.from;
    if (from == null) {
      lines.add('DTSTART;VALUE=DATE:${e.date.replaceAll('-', '')}');
      lines.add(
        'DTEND;VALUE=DATE:${calendarAddDays(e.date, 1).replaceAll('-', '')}',
      );
    } else {
      final start = calendarMinutesOf(from)!;
      var end = calendarMinutesOf(e.to) ?? start + 30;
      if (end <= start) end += 24 * 60;
      final endDate = calendarAddDays(e.date, end ~/ (24 * 60));
      lines.add('DTSTART:${_stamp(e.date, from)}');
      lines.add('DTEND:${_stamp(endDate, calendarHm(end))}');
    }
    lines.add('SUMMARY:${_escape('${_prefix(e)}${e.title}')}');
    if ((e.detail ?? '').isNotEmpty) {
      lines.add('DESCRIPTION:${_escape(e.detail!)}');
    }
    lines.add(
      'CATEGORIES:${switch (e.kind) {
        ShootCalendarKind.shoot => 'Jornada',
        ShootCalendarKind.scene => 'Escena',
        ShootCalendarKind.strip => 'Franja',
        ShootCalendarKind.pickup => 'Recogida',
        ShootCalendarKind.ret => 'Devolución',
      }}',
    );
    lines.add('END:VEVENT');
  }
  lines.add('END:VCALENDAR');
  return '${lines.map(_fold).join('\r\n')}\r\n';
}
