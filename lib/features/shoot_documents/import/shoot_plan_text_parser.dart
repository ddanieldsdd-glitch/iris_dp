import '../shoot_day_timeline.dart';

/// Un plan de rodaje leído de un texto, antes de emparejarlo con el proyecto.
class ParsedShootPlan {
  final String? title;
  final List<ParsedShootDay> days;

  const ParsedShootPlan({this.title, this.days = const []});

  bool get isEmpty => days.every((d) => d.lines.isEmpty);
}

class ParsedShootDay {
  /// El número escrito en el plan: «DÍA 3».
  final int number;

  /// `yyyy-MM-dd`, si el plan lo dice.
  final String? date;
  final String? from;
  final String? to;

  /// Lo escrito bajo la cabecera, antes de la primera hora.
  final String note;
  final List<ParsedPlanLine> lines;

  const ParsedShootDay({
    required this.number,
    this.date,
    this.from,
    this.to,
    this.note = '',
    this.lines = const [],
  });
}

/// Una línea del día. [from] y [to] son `HH:mm`.
sealed class ParsedPlanLine {
  final String? from;
  final String? to;

  const ParsedPlanLine({this.from, this.to});
}

class ParsedPlanStrip extends ParsedPlanLine {
  final ShootStripKind kind;
  final String label;
  final String note;

  const ParsedPlanStrip({
    required this.kind,
    required this.label,
    this.note = '',
    super.from,
    super.to,
  });
}

/// «Escena 13B (…) ALI - SIMO»: abre una escena y deja su nota.
class ParsedPlanScene extends ParsedPlanLine {
  /// «13B», en mayúsculas.
  final String scene;
  final String note;

  const ParsedPlanScene({
    required this.scene,
    this.note = '',
    super.from,
    super.to,
  });
}

/// «13b.5 PM frontal de Ali (25 min)».
class ParsedPlanShot extends ParsedPlanLine {
  final String scene;
  final int shot;
  final String text;

  const ParsedPlanShot({
    required this.scene,
    required this.shot,
    this.text = '',
    super.from,
    super.to,
  });
}

const _months = {
  'enero': 1,
  'febrero': 2,
  'marzo': 3,
  'abril': 4,
  'mayo': 5,
  'junio': 6,
  'julio': 7,
  'agosto': 8,
  'septiembre': 9,
  'setiembre': 9,
  'octubre': 10,
  'noviembre': 11,
  'diciembre': 12,
};

final _dayHeader = RegExp(
  r'^\s*(?:d[ií]a|jornada)\s+(\d{1,2})\b(.*)$',
  caseSensitive: false,
);
final _dateWords = RegExp(
  r'(\d{1,2})\s*(?:de\s+)?([a-záéíóú]{4,})',
  caseSensitive: false,
);
final _dateDigits = RegExp(r'(\d{1,2})[/.-](\d{1,2})(?:[/.-](\d{2,4}))?');
final _window = RegExp(
  r'(\d{1,2})[:.h](\d{2})\s*(?:[-–—]|a)\s*(\d{1,2})[:.h](\d{2})',
);
final _timed = RegExp(r'^\s*(\d{1,2}):(\d{2})\b\s*(.*)$');
final _endTime = RegExp(
  r'^(?:[-–—]|a\b|hasta\b)\s*(\d{1,2})[:.](\d{2})\b\s*(.*)$',
  caseSensitive: false,
);
final _shot = RegExp(r'^(\d{1,3})([A-Za-z])?\s*\.\s*(\d{1,2})(?!\d)\s*(.*)$');
final _scene = RegExp(
  r'^escena\s+(\d{1,3})([A-Za-z])?(?![A-Za-zÀ-ÿ])\s*(.*)$',
  caseSensitive: false,
);
final _sceneInside = RegExp(
  r'\(\s*escena\s+(\d{1,3})([A-Za-z])?\s*\)',
  caseSensitive: false,
);
final _hours = RegExp(r'(\d+)\s*h(?:oras?)?\b', caseSensitive: false);
final _minutes = RegExp(r'(\d+)\s*min', caseSensitive: false);
final _durationText = RegExp(
  r'\(?\s*(?:\d+\s*h(?:oras?)?\b\s*)?(?:\d+(?:/\d+)?\s*min(?:utos)?\.?)?\s*\)?',
  caseSensitive: false,
);

String _hm(int minutes) {
  final m = minutes % (24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

int? _minutesOf(String? hm) {
  if (hm == null) return null;
  final parts = hm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// Minutos que dice un texto: «(25 min)», «1h 30 min», «1 hora».
int? shootPlanDuration(String text) {
  final h = _hours.firstMatch(text);
  final m = _minutes.firstMatch(text);
  if (h == null && m == null) return null;
  return (h == null ? 0 : int.parse(h.group(1)!) * 60) +
      (m == null ? 0 : int.parse(m.group(1)!));
}

String _clean(String text) {
  var out = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  out = out.replaceAll(RegExp(r'^[-–—·\s]+|[-–—·\s]+$'), '');
  return out;
}

String _withoutDuration(String text) => _clean(
  text.replaceAllMapped(_durationText, (m) {
    final s = m.group(0)!;
    return RegExp(r'\d').hasMatch(s) ? ' ' : s;
  }),
);

/// El rótulo de una franja: sin la duración ni paréntesis sueltos.
String _label(String text) {
  var s = _withoutDuration(text);
  if (s.startsWith('(') && s.endsWith(')') && !s.substring(1).contains('(')) {
    s = s.substring(1, s.length - 1);
  }
  if ('('.allMatches(s).length != ')'.allMatches(s).length) {
    s = s.replaceAll(RegExp(r'[()]'), ' ');
  }
  s = _clean(s).replaceFirst(RegExp(r'^de\s+', caseSensitive: false), '');
  return _capital(s);
}

String _capital(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

ShootStripKind _kindOf(String text) {
  final t = text.toLowerCase();
  bool has(String pattern) => RegExp(pattern).hasMatch(t);
  if (has(r'comida|cena|desayuno|merienda|almuerzo|catering')) {
    return ShootStripKind.meal;
  }
  if (has(r'recogida|wrap|desmontaje|fin de rodaje')) {
    return ShootStripKind.wrap;
  }
  if (has(r'prelight|preiluminaci')) return ShootStripKind.prelight;
  if (has(r'preparaci|montaje|\bprep\b')) return ShootStripKind.setup;
  if (has(r'citaci|llegada|convocatoria')) return ShootStripKind.call;
  if (has(r'descanso|pausa')) return ShootStripKind.rest;
  if (has(r'traslado|desplazamiento|cambio de loc')) {
    return ShootStripKind.move;
  }
  return ShootStripKind.note;
}

class _Raw {
  final String? time;

  /// Hora de final escrita: «7:30 - 8:30 Llegada».
  final String? end;
  String text;
  final List<String> extra = [];

  _Raw(this.time, this.text, [this.end]);

  String get all => [text, ...extra].join(' ');
}

String? _dateOf(String header, DateTime today) {
  int? day;
  int? month;
  int? year;
  final words = _dateWords
      .allMatches(header)
      .where((m) => _months.containsKey(m.group(2)!.toLowerCase()));
  if (words.isNotEmpty) {
    day = int.parse(words.first.group(1)!);
    month = _months[words.first.group(2)!.toLowerCase()];
  } else {
    final head = header.replaceAll(_window, ' ');
    final digits = _dateDigits.firstMatch(head);
    if (digits != null) {
      day = int.parse(digits.group(1)!);
      month = int.parse(digits.group(2)!);
      final y = digits.group(3);
      if (y != null) year = y.length == 2 ? 2000 + int.parse(y) : int.parse(y);
    }
  }
  if (day == null || month == null || month > 12 || day > 31) return null;
  if (year == null) {
    // Sin año, el más cercano: un plan de enero leído en diciembre es del
    // año siguiente.
    year = today.year;
    final guess = DateTime(year, month, day);
    if (guess.isBefore(today.subtract(const Duration(days: 120)))) year++;
  }
  return '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

/// Lee un plan de rodaje escrito a mano: días con «DÍA 1 - 13 noviembre
/// (7:30 - 17:00)», líneas con hora, escenas («Escena 6»), planos («6.1»)
/// y duraciones («(25 min)»). Lo que no entiende se queda como nota de la
/// línea anterior, para no perder nada.
ParsedShootPlan parseShootPlanText(String source, {DateTime? today}) {
  final now = today ?? DateTime.now();
  String? title;
  final days = <ParsedShootDay>[];

  int? number;
  String? date;
  String? dayFrom;
  String? dayTo;
  var notes = <String>[];
  var raws = <_Raw>[];

  void closeDay() {
    if (number == null) return;
    days.add(
      ParsedShootDay(
        number: number,
        date: date,
        from: dayFrom,
        to: dayTo,
        note: notes.join('\n'),
        lines: _linesOf(raws, dayFrom),
      ),
    );
  }

  for (final rawLine in source.replaceAll('\r', '').split('\n')) {
    final line = rawLine.replaceAll('\t', ' ').trimRight();
    if (line.trim().isEmpty) continue;
    final header = _dayHeader.firstMatch(line);
    if (header != null) {
      closeDay();
      number = int.parse(header.group(1)!);
      final rest = header.group(2)!;
      date = _dateOf(rest, now);
      final window = _window.firstMatch(rest);
      dayFrom = window == null
          ? null
          : _hm(int.parse(window.group(1)!) * 60 + int.parse(window.group(2)!));
      dayTo = window == null
          ? null
          : _hm(int.parse(window.group(3)!) * 60 + int.parse(window.group(4)!));
      notes = [];
      raws = [];
      continue;
    }
    if (number == null) {
      title ??= _clean(line);
      continue;
    }
    final timed = _timed.firstMatch(line);
    if (timed != null) {
      final time = _hm(
        int.parse(timed.group(1)!) * 60 + int.parse(timed.group(2)!),
      );
      var rest = timed.group(3)!.trim();
      String? end;
      final range = _endTime.firstMatch(rest);
      if (range != null) {
        end = _hm(int.parse(range.group(1)!) * 60 + int.parse(range.group(2)!));
        rest = range.group(3)!.trim();
      }
      raws.add(_Raw(time, rest, end));
      continue;
    }
    final text = line.trim();
    if (raws.isEmpty) {
      notes.add(text);
      continue;
    }
    final startsItem =
        _shot.hasMatch(text) ||
        _scene.hasMatch(text) ||
        (RegExp(r'^\d').hasMatch(text) &&
            shootPlanDuration(text) != null &&
            _kindOf(text) == ShootStripKind.wrap);
    if (startsItem) {
      raws.add(_Raw(null, text));
    } else {
      raws.last.extra.add(text);
    }
  }
  closeDay();
  return ParsedShootPlan(title: title, days: days);
}

List<ParsedPlanLine> _linesOf(List<_Raw> raws, String? dayFrom) {
  // Primera pasada: qué es cada línea y cuándo empieza. El reloj avanza con
  // las duraciones para dar hora a lo que no la trae.
  final items =
      <({_Raw raw, String kind, int? from, int? minutes, int? end})>[];
  int? clock = _minutesOf(dayFrom);
  final marks = <int>[];
  for (final raw in raws) {
    final all = raw.all;
    final lower = raw.text.toLowerCase();
    var from = _minutesOf(raw.time);
    // Tras medianoche el reloj sigue: 00:45 va después de 23:40.
    if (from != null && clock != null && from < clock - 12 * 60) {
      from += 24 * 60;
    }
    final isMotorOnly = RegExp(r'^motor\.?$').hasMatch(lower.trim());
    if (from != null && raw.time != null) marks.add(from);
    if (isMotorOnly) {
      clock = from ?? clock;
      continue;
    }
    final String kind;
    if (_shot.hasMatch(raw.text)) {
      kind = 'shot';
    } else if (_scene.hasMatch(raw.text) ||
        (lower.startsWith('motor') && _sceneInside.hasMatch(raw.text))) {
      kind = 'scene';
    } else {
      kind = 'strip';
    }
    from ??= clock;
    var end = _minutesOf(raw.end);
    if (end != null && from != null) {
      while (end! <= from) {
        end += 24 * 60;
      }
    }
    final minutes = shootPlanDuration(all);
    items.add((raw: raw, kind: kind, from: from, minutes: minutes, end: end));
    if (from != null) clock = from + (kind == 'scene' ? 0 : (minutes ?? 0));
    if (end != null) clock = end;
    if (kind == 'scene' &&
        raw.time == null &&
        minutes != null &&
        from != null) {
      clock = from + minutes;
    }
  }

  final lines = <ParsedPlanLine>[];
  for (final item in items) {
    final from = item.from;
    int? to =
        item.end ??
        (from != null && item.minutes != null ? from + item.minutes! : null);
    if (to == null && from != null && item.kind != 'scene') {
      // Sin duración, hasta la siguiente hora escrita.
      final next = marks.where((m) => m > from).firstOrNull;
      if (next != null) to = next;
    }
    final fromText = from == null ? null : _hm(from);
    final toText = to == null ? null : _hm(to);
    final raw = item.raw;
    switch (item.kind) {
      case 'shot':
        final m = _shot.firstMatch(raw.text)!;
        lines.add(
          ParsedPlanShot(
            scene: '${m.group(1)}${(m.group(2) ?? '').toUpperCase()}',
            shot: int.parse(m.group(3)!),
            text: _withoutDuration([m.group(4)!, ...raw.extra].join(' ')),
            from: fromText,
            to: toText,
          ),
        );
      case 'scene':
        final m = _scene.firstMatch(raw.text);
        final inside = _sceneInside.firstMatch(raw.text);
        final label = m != null
            ? '${m.group(1)}${(m.group(2) ?? '').toUpperCase()}'
            : '${inside!.group(1)}${(inside.group(2) ?? '').toUpperCase()}';
        final rest = m != null
            ? m.group(3)!
            : raw.text
                  .replaceFirst(_sceneInside, ' ')
                  .replaceFirst(RegExp(r'^motor', caseSensitive: false), '');
        lines.add(
          ParsedPlanScene(
            scene: label,
            note: _clean([rest, ...raw.extra].join(' ')),
            from: fromText,
            to: toText,
          ),
        );
      default:
        final kind = _kindOf(raw.text);
        final label = _label(raw.text);
        lines.add(
          ParsedPlanStrip(
            kind: kind,
            label: label,
            note: _clean(raw.extra.join('\n')),
            from: fromText,
            to: toText,
          ),
        );
    }
  }
  return lines;
}
