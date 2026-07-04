// Pasada 1: regex y heurísticas sobre sluglines de guion
import 'script_file_reader.dart' show isScriptPageMarker;

class ScriptParser {
  static const _timeOfDay =
      r'DÍA|DIA|DAY|NOCHE|NIGHT|AMANECER|DAWN|SUNRISE|ATARDECER|ANOCHECER|DUSK|SUNSET|EVENING|MORNING|CONTINUO|CONTINUOUS|CONTINUED|LATER|MÁS TARDE|MAS TARDE';

  static final _patterns = [
    RegExp(
      r'^(INT\.?\/EXT\.?|EXT\.?\/INT\.?|INT\.?|EXT\.?|I\/E\.?)\s+(.+?)\s*[-–—]\s*(' +
          _timeOfDay +
          r')\s*$',
      caseSensitive: false,
    ),
    RegExp(
      r'^(INT\.?\/EXT\.?|EXT\.?\/INT\.?|INT\.?|EXT\.?|I\/E\.?)\s+(.+?)\s*,\s*(' +
          _timeOfDay +
          r')\s*$',
      caseSensitive: false,
    ),
    RegExp(
      r'^(INT\.?\/EXT\.?|EXT\.?\/INT\.?|INT\.?|EXT\.?|I\/E\.?)\s+(.+?)\.\s*(' +
          _timeOfDay +
          r')\.?\s*$',
      caseSensitive: false,
    ),
    RegExp(
      r'^(INTERIOR\/EXTERIOR|INT\/EXT|INTERIOR|EXTERIOR)\.?\s+(.+?)\s*[-–—,]\s*(' +
          _timeOfDay +
          r')\s*$',
      caseSensitive: false,
    ),
    RegExp(
      r'^(INTERIOR\/EXTERIOR|INT\/EXT|INTERIOR|EXTERIOR)\.?\s+(.+?)\.\s*(' +
          _timeOfDay +
          r')\.?\s*$',
      caseSensitive: false,
    ),
    RegExp(
      r'^(INT|EXT|INT\/EXT)\s*[-–—]\s*(.+?)\s*[-–—]\s*(' + _timeOfDay + r')\s*$',
      caseSensitive: false,
    ),
  ];

  static final _slugPrefix = RegExp(
    r'^(INT\.?\/EXT\.?|EXT\.?\/INT\.?|INT\.?|EXT\.?|I\/E\.?|INTERIOR\/EXTERIOR|INTERIOR|EXTERIOR)',
    caseSensitive: false,
  );

  static List<RawSlugline> parse(String scriptText) {
    final lines = _normalizeLineEndings(scriptText).split('\n');
    final result = <RawSlugline>[];
    var charIndex = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty || _isNoiseLine(trimmed) || _isSceneNumberOnlyLine(trimmed)) {
        charIndex += line.length + 1;
        continue;
      }

      if (isScriptPageMarker(trimmed)) {
        charIndex += line.length + 1;
        continue;
      }

      final end = (i + 4).clamp(0, lines.length);
      final parsed = tryParseSluglineFromLines(
        lines,
        lineIndex: i,
        startIndex: charIndex,
        followingLines: lines.sublist(i + 1, end),
      );

      if (parsed != null) {
        result.add(parsed.slugline);
        i += parsed.linesConsumed - 1;
        charIndex += parsed.charactersConsumed;
        continue;
      }

      charIndex += line.length + 1;
    }

    if (result.length < 3) {
      final normalized = _normalizeForEmbeddedSearch(scriptText);
      final seenStarts = result.map((s) => s.startIndex).toSet();
      result.addAll(_findEmbeddedSluglines(normalized, seenStarts));
    }

    result.sort((a, b) => a.startIndex.compareTo(b.startIndex));
    for (var i = 0; i < result.length; i++) {
      final s = result[i];
      result[i] = s.copyWith(number: s.scriptNumber ?? (i + 1));
    }
    return result;
  }

  static _ParseAttempt? tryParseSluglineFromLines(
    List<String> lines, {
    required int lineIndex,
    required int startIndex,
    List<String> followingLines = const [],
  }) {
    final line = lines[lineIndex];
    final trimmed = line.trim();

    final single = tryParseSlugline(
      trimmed,
      startIndex: startIndex,
      followingLines: followingLines,
    );
    if (single != null) {
      return _ParseAttempt(
        slugline: single,
        linesConsumed: 1,
        charactersConsumed: line.length + 1,
      );
    }

    if (!_slugPrefix.hasMatch(trimmed)) return null;

    final merged = _mergeMultilineSlugline(lines, lineIndex);
    if (merged == null) return null;

    final slug = tryParseSlugline(
      merged.text,
      startIndex: startIndex,
      followingLines: followingLines,
    );
    if (slug == null) return null;

    return _ParseAttempt(
      slugline: slug,
      linesConsumed: merged.linesConsumed,
      charactersConsumed: merged.charactersConsumed,
    );
  }

  static RawSlugline? tryParseSlugline(
    String line, {
    required int startIndex,
    List<String> followingLines = const [],
  }) {
    final cleaned = _cleanLineForParsing(line);
    final parsed = _parseCleanedLine(cleaned.text);
    if (parsed == null) return null;

    final scriptNumber =
        cleaned.scriptNumber ?? _readFollowingSceneNumber(followingLines);

    return RawSlugline(
      number: scriptNumber ?? 0,
      scriptNumber: scriptNumber,
      intExt: parsed.intExt,
      location: parsed.location,
      dayNight: parsed.dayNight,
      rawLine: cleaned.text,
      startIndex: startIndex,
    );
  }

  static _MergedLines? _mergeMultilineSlugline(List<String> lines, int start) {
    final parts = <String>[];
    var charactersConsumed = 0;

    for (var j = start; j < lines.length && j < start + 6; j++) {
      final raw = lines[j];
      charactersConsumed += raw.length + 1;
      final trimmed = raw.trim();

      if (trimmed.isEmpty) {
        if (parts.isNotEmpty) parts.add(' ');
        continue;
      }

      if (j > start && _looksLikeActionLine(trimmed)) break;

      parts.add(trimmed);
      final merged = _collapseSluglineParts(parts.join(' '));
      final cleaned = _cleanLineForParsing(merged);
      if (_parseCleanedLine(cleaned.text) != null) {
        return _MergedLines(
          text: cleaned.text,
          linesConsumed: j - start + 1,
          charactersConsumed: charactersConsumed,
        );
      }
    }
    return null;
  }

  static bool _looksLikeActionLine(String line) {
    if (_slugPrefix.hasMatch(line)) return false;
    if (line.length > 90) return true;
    final letters = line.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÜÑ]'), '');
    if (letters.isEmpty) return false;
    final upper = letters.replaceAll(RegExp(r'[^A-ZÁÉÍÓÚÜÑ]'), '').length;
    if (upper / letters.length > 0.85 && letters.length > 12) return false;
    return letters[0] == letters[0].toLowerCase();
  }

  static String _collapseSluglineParts(String raw) {
    return raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' – ', ' - ')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .trim();
  }

  static int? _readFollowingSceneNumber(List<String> followingLines) {
    for (final next in followingLines) {
      final trimmed = next.trim();
      if (trimmed.isEmpty) continue;
      if (_isSceneNumberOnlyLine(trimmed)) {
        return int.tryParse(trimmed.replaceAll('.', ''));
      }
      break;
    }
    return null;
  }

  static String _normalizeLineEndings(String text) {
    return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  static String _normalizeForEmbeddedSearch(String text) {
    return _normalizeLineEndings(text)
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  static bool _isSceneNumberOnlyLine(String line) {
    return RegExp(r'^\d+\.?$').hasMatch(line);
  }

  static bool _isNoiseLine(String line) {
    if (isScriptPageMarker(line)) return true;
    if (RegExp(r'^--\s*\d+\s+of\s+\d+\s*--$', caseSensitive: false).hasMatch(line)) {
      return true;
    }
    if (RegExp(r'^\d+\.\s*$').hasMatch(line)) return true;
    final upper = line.toUpperCase();
    if (upper == 'FIN' ||
        upper == 'FADE IN:' ||
        upper == 'CORTE A NEGRO' ||
        upper == 'CORTE A: NEGRO') {
      return true;
    }
    return false;
  }

  static _CleanedLine _cleanLineForParsing(String line) {
    var cleaned = line.trim();
    int? scriptNumber;

    cleaned = cleaned.replaceFirst(RegExp(r'^\.+\s*'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'^\*\s*'), '');

    final leading = RegExp(r'^(\d+)\.?\s+');
    final leadingMatch = leading.firstMatch(cleaned);
    if (leadingMatch != null) {
      final after = cleaned.substring(leadingMatch.end);
      if (_slugPrefix.hasMatch(after)) {
        scriptNumber = int.tryParse(leadingMatch.group(1)!);
        cleaned = after;
      }
    }

    final trailingPair = RegExp(r'[\t ]+(\d+)\s+\d+\s*$');
    final trailingPairMatch = trailingPair.firstMatch(cleaned);
    if (trailingPairMatch != null) {
      scriptNumber ??= int.tryParse(trailingPairMatch.group(1)!);
      cleaned = cleaned.substring(0, trailingPairMatch.start).trim();
    } else {
      final trailingSingle = RegExp(r'[\t ]+(\d+)\s*$');
      final trailingSingleMatch = trailingSingle.firstMatch(cleaned);
      if (trailingSingleMatch != null) {
        final candidate =
            cleaned.substring(0, trailingSingleMatch.start).trim();
        if (RegExp(
          r'[-–—\.]\s*(' + _timeOfDay + r')\.?\s*$',
          caseSensitive: false,
        ).hasMatch(candidate)) {
          scriptNumber ??= int.tryParse(trailingSingleMatch.group(1)!);
          cleaned = candidate;
        }
      }
    }

    return _CleanedLine(text: cleaned, scriptNumber: scriptNumber);
  }

  static _ParsedLine? _parseCleanedLine(String line) {
    for (final pattern in _patterns) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        return _ParsedLine(
          intExt: _normalizeIntExt(match.group(1) ?? ''),
          location: _cleanLocation((match.group(2) ?? '').trim()),
          dayNight: _normalizeDayNight(match.group(3) ?? ''),
          rawLine: line,
        );
      }
    }
    return null;
  }

  static List<RawSlugline> _findEmbeddedSluglines(
    String text,
    Set<int> seenStarts,
  ) {
    final embeddedPattern = RegExp(
      r'(INT\.?\/EXT\.?|EXT\.?\/INT\.?|INT\.?|EXT\.?|I\/E\.?|INTERIOR\/EXTERIOR|INTERIOR|EXTERIOR)\s+'
      r"([A-ZÁÉÍÓÚÜÑ0-9][A-ZÁÉÍÓÚÜÑ0-9 '.\-]{2,60}?)\s*"
      r'(?:[-–—,]|\.)\s*(' +
          _timeOfDay +
          r')',
      caseSensitive: false,
    );

    final result = <RawSlugline>[];
    for (final match in embeddedPattern.allMatches(text)) {
      if (seenStarts.contains(match.start)) continue;
      seenStarts.add(match.start);

      final rawLine = match.group(0)!.trim();
      result.add(RawSlugline(
        number: 0,
        intExt: _normalizeIntExt(match.group(1) ?? ''),
        location: _cleanLocation((match.group(2) ?? '').trim()),
        dayNight: _normalizeDayNight(match.group(3) ?? ''),
        rawLine: rawLine,
        startIndex: match.start,
      ));
    }
    return result;
  }

  static String _cleanLocation(String loc) {
    return loc.replaceFirst(RegExp(r'^[-–—\s]+'), '').trim();
  }

  static String _normalizeIntExt(String raw) {
    final upper =
        raw.toUpperCase().replaceAll('.', '').replaceAll(' ', '').trim();
    if (upper.contains('/') || upper == 'IE') return 'INT/EXT';
    if (upper.startsWith('INT') || upper == 'INTERIOR') return 'INT';
    if (upper.startsWith('EXT') || upper == 'EXTERIOR') return 'EXT';
    return 'EXT';
  }

  static String _normalizeDayNight(String raw) {
    final upper = raw.toUpperCase().trim();
    return switch (upper) {
      'DIA' || 'DÍA' || 'DAY' || 'MORNING' => 'DÍA',
      'NOCHE' || 'NIGHT' => 'NOCHE',
      'AMANECER' || 'DAWN' || 'SUNRISE' => 'AMANECER',
      'ATARDECER' ||
      'ANOCHECER' ||
      'DUSK' ||
      'SUNSET' ||
      'EVENING' =>
        'ATARDECER',
      'CONTINUO' ||
      'CONTINUOUS' ||
      'CONTINUED' ||
      'LATER' ||
      'MÁS TARDE' ||
      'MAS TARDE' =>
        'CONTINUO',
      _ => raw,
    };
  }
}

class _ParseAttempt {
  final RawSlugline slugline;
  final int linesConsumed;
  final int charactersConsumed;

  const _ParseAttempt({
    required this.slugline,
    required this.linesConsumed,
    required this.charactersConsumed,
  });
}

class _MergedLines {
  final String text;
  final int linesConsumed;
  final int charactersConsumed;

  const _MergedLines({
    required this.text,
    this.linesConsumed = 1,
    required this.charactersConsumed,
  });
}

class _CleanedLine {
  final String text;
  final int? scriptNumber;

  const _CleanedLine({required this.text, this.scriptNumber});
}

class _ParsedLine {
  final String intExt;
  final String location;
  final String dayNight;
  final String rawLine;

  const _ParsedLine({
    required this.intExt,
    required this.location,
    required this.dayNight,
    required this.rawLine,
  });
}

class RawSlugline {
  final int number;
  final int? scriptNumber;
  final String intExt;
  final String location;
  final String dayNight;
  final String rawLine;
  final int startIndex;

  const RawSlugline({
    required this.number,
    this.scriptNumber,
    required this.intExt,
    required this.location,
    required this.dayNight,
    required this.rawLine,
    required this.startIndex,
  });

  RawSlugline copyWith({
    int? number,
    int? scriptNumber,
    String? intExt,
    String? location,
    String? dayNight,
    String? rawLine,
    int? startIndex,
  }) =>
      RawSlugline(
        number: number ?? this.number,
        scriptNumber: scriptNumber ?? this.scriptNumber,
        intExt: intExt ?? this.intExt,
        location: location ?? this.location,
        dayNight: dayNight ?? this.dayNight,
        rawLine: rawLine ?? this.rawLine,
        startIndex: startIndex ?? this.startIndex,
      );

  Map<String, dynamic> toJson() => {
        'number': number,
        'intExt': intExt,
        'location': location,
        'dayNight': dayNight,
      };
}
