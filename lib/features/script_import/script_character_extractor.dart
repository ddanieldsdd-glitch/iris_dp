import 'script_file_reader.dart' show isScriptPageMarker;
import 'normalized_scene.dart';
import 'script_parser.dart';
import 'script_screenplay_layout.dart';

/// Extrae los personajes de cada escena (entre sluglines consecutivas): los
/// que hablan y los que aparecen en la acción sin hablar.
class ScriptCharacterExtractor {
  static const _letters = 'A-Za-zÁÉÍÓÚÜÑáéíóúüñ';
  static const _caps = 'A-ZÁÉÍÓÚÜÑ';

  /// Presentación de un personaje en la acción: «ALI (25)» o «(DIEGO, 23)».
  static final _introducedBefore = RegExp(
    '(?<![$_letters])([$_caps]{2,}(?: [$_caps]{2,}){0,2})\\s*\\(\\s*\\d{1,3}\\s*\\)',
  );
  static final _introducedInside = RegExp(
    '\\(\\s*([$_caps]{2,}(?: [$_caps]{2,}){0,2})\\s*,\\s*\\d{1,3}\\s*\\)',
  );

  /// Palabras en mayúsculas que no son personajes.
  static const _noise = {
    'INT',
    'EXT',
    'CORTE',
    'CORTE A',
    'FUNDIDO',
    'FUNDIDO A',
    'FIN',
    'CONTINÚA',
    'CONTINUA',
    'CONTINUARÁ',
    'NEGRO',
    'TÍTULO',
    'TITULO',
    'FLASHBACK',
    'OFF',
    'DÍA',
    'DIA',
    'NOCHE',
    'AMANECER',
    'ATARDECER',
    'MÁS TARDE',
    'MAS TARDE',
    'ELIPSIS',
    'CRÉDITOS',
    'CREDITOS',
  };

  /// Mismo personaje con o sin acotación: «ALI (CONT’D)», «ALI (25)».
  static String _canonical(String name) => name
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toUpperCase();

  static Iterable<String> _introducedIn(String line) sync* {
    for (final pattern in [_introducedBefore, _introducedInside]) {
      for (final match in pattern.allMatches(line)) {
        yield _canonical(match.group(1)!);
      }
    }
  }

  /// ¿Se nombra a [name] en [text]? Por palabra completa y como nombre
  /// propio: «ALI» o «Ali», no una palabra común en minúsculas.
  static bool _mentions(String text, String name) {
    final pattern = RegExp(
      '(?<![$_letters])${RegExp.escape(name)}(?![$_letters])',
      caseSensitive: false,
      unicode: true,
    );
    for (final match in pattern.allMatches(text)) {
      final first = match.group(0)![0];
      if (first == first.toUpperCase() && first != first.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  static Map<int, List<String>> extractBySlugStartIndex(
    String scriptText,
    List<RawSlugline> sluglines,
  ) {
    if (sluglines.isEmpty) return {};

    final sorted = [...sluglines]
      ..sort((a, b) => a.startIndex.compareTo(b.startIndex));
    final normalized = scriptText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final lines = normalized.split('\n');

    final lineStarts = <int>[];
    var charIndex = 0;
    for (final line in lines) {
      lineStarts.add(charIndex);
      charIndex += line.length + 1;
    }

    final speakers = <int, Set<String>>{};
    final action = <int, StringBuffer>{};
    final cast = <String>{};
    final classifier = ScreenplayLineClassifier();

    for (var s = 0; s < sorted.length; s++) {
      final slug = sorted[s];
      final endIndex = s + 1 < sorted.length
          ? sorted[s + 1].startIndex
          : normalized.length;
      final speaking = speakers[slug.startIndex] = <String>{};
      final actionText = action[slug.startIndex] = StringBuffer();
      classifier.reset();
      var afterCue = false;

      for (var i = 0; i < lines.length; i++) {
        final lineStart = lineStarts[i];
        if (lineStart < slug.startIndex) continue;
        if (lineStart >= endIndex) break;

        final line = lines[i];
        final trimmed = line.trim();
        if (isScriptPageMarker(trimmed)) continue;
        if (trimmed.isEmpty) {
          // Una línea en blanco cierra el diálogo: lo que sigue es acción.
          classifier.reset();
          afterCue = false;
          continue;
        }

        if (lineStart == slug.startIndex) {
          classifier.reset();
          afterCue = false;
          continue;
        }

        final leadingSpaces = line.length - line.trimLeft().length;
        var kind = classifier.classifyLine(
          trimmed,
          isSlugline: false,
          leadingSpaces: leadingSpaces,
        );
        // Lo que va justo bajo el nombre de quien habla es su frase, aunque
        // por su forma parezca acción.
        if (afterCue && kind == ScreenplayLineKind.action) {
          kind = ScreenplayLineKind.dialogue;
        }
        afterCue =
            kind == ScreenplayLineKind.character ||
            kind == ScreenplayLineKind.parenthetical ||
            (afterCue && kind == ScreenplayLineKind.dialogue);
        if (kind == ScreenplayLineKind.action) {
          actionText.writeln(trimmed);
          cast.addAll(_introducedIn(trimmed));
          continue;
        }
        if (kind != ScreenplayLineKind.character) continue;

        final name = ScreenplayLineClassifier.parseCharacterName(trimmed);
        if (name == null || name.isEmpty) continue;
        final canonical = _canonical(name);
        if (canonical.isNotEmpty) speaking.add(canonical);
      }
      cast.addAll(speaking);
    }

    // Un lugar de cabecera en mayúsculas no es un personaje.
    final places = {for (final s in sorted) s.location.trim().toUpperCase()};
    cast.removeWhere(
      (name) =>
          name.length < 2 || _noise.contains(name) || places.contains(name),
    );

    final result = <int, List<String>>{};
    for (final slug in sorted) {
      final present = {...speakers[slug.startIndex]!}
        ..removeWhere((name) => !cast.contains(name));
      final text = action[slug.startIndex]!.toString();
      for (final name in cast) {
        if (!present.contains(name) && _mentions(text, name)) present.add(name);
      }
      result[slug.startIndex] = present.toList()..sort();
    }

    return result;
  }

  static List<NormalizedScene> attachToScenes(
    List<NormalizedScene> scenes,
    List<RawSlugline> sluglines,
    Map<int, List<String>> charactersByStart,
  ) {
    return [
      for (var i = 0; i < scenes.length; i++)
        scenes[i].copyWith(
          characters: i < sluglines.length
              ? charactersByStart[sluglines[i].startIndex] ??
                    scenes[i].characters
              : scenes[i].characters,
        ),
    ];
  }

  /// Todos los nombres de personaje detectados en el guion completo.
  static List<String> extractAllCharacterNames(String scriptText) {
    final normalized = scriptText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final classifier = ScreenplayLineClassifier();
    final characters = <String>{};

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || isScriptPageMarker(trimmed)) {
        classifier.reset();
        continue;
      }

      final leadingSpaces = line.length - line.trimLeft().length;
      final kind = classifier.classifyLine(
        trimmed,
        isSlugline: false,
        leadingSpaces: leadingSpaces,
      );
      if (kind != ScreenplayLineKind.character) continue;

      final name = ScreenplayLineClassifier.parseCharacterName(trimmed);
      if (name != null && name.isNotEmpty) characters.add(name);
    }

    return characters.toList()..sort();
  }
}
