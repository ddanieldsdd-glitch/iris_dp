import 'script_file_reader.dart' show isScriptPageMarker;
import 'normalized_scene.dart';
import 'script_parser.dart';
import 'script_screenplay_layout.dart';

/// Extrae personajes que hablan en cada escena (entre sluglines consecutivas).
class ScriptCharacterExtractor {
  static Map<int, List<String>> extractBySlugStartIndex(
    String scriptText,
    List<RawSlugline> sluglines,
  ) {
    if (sluglines.isEmpty) return {};

    final sorted = [...sluglines]..sort((a, b) => a.startIndex.compareTo(b.startIndex));
    final normalized = scriptText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');

    final lineStarts = <int>[];
    var charIndex = 0;
    for (final line in lines) {
      lineStarts.add(charIndex);
      charIndex += line.length + 1;
    }

    final result = <int, List<String>>{};
    final classifier = ScreenplayLineClassifier();

    for (var s = 0; s < sorted.length; s++) {
      final slug = sorted[s];
      final endIndex =
          s + 1 < sorted.length ? sorted[s + 1].startIndex : normalized.length;
      final characters = <String>{};
      classifier.reset();

      for (var i = 0; i < lines.length; i++) {
        final lineStart = lineStarts[i];
        if (lineStart < slug.startIndex) continue;
        if (lineStart >= endIndex) break;

        final line = lines[i];
        final trimmed = line.trim();
        if (trimmed.isEmpty || isScriptPageMarker(trimmed)) continue;

        if (lineStart == slug.startIndex) {
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

      result[slug.startIndex] = characters.toList()..sort();
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
              ? charactersByStart[sluglines[i].startIndex] ?? scenes[i].characters
              : scenes[i].characters,
        ),
    ];
  }

  /// Todos los nombres de personaje detectados en el guion completo.
  static List<String> extractAllCharacterNames(String scriptText) {
    final normalized = scriptText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
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
