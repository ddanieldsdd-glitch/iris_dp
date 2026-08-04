import 'script_parser.dart';

enum ScreenplayLineKind {
  slugline,
  action,
  character,
  parenthetical,
  dialogue,
  transition,
  pageNumber,
  blank,
}

/// Clasifica líneas de guion para aplicar márgenes tipo Final Draft.
class ScreenplayLineClassifier {
  bool _inDialogueBlock = false;

  static final _transition = RegExp(
    r'^(CUT TO:|CUT TO BLACK|FADE IN:|FADE OUT\.|FADE TO:|DISSOLVE TO:|'
    r'MATCH CUT TO:|SMASH CUT TO:|TIME CUT:|INTERCUT:)',
    caseSensitive: false,
  );

  static final _characterSuffix = RegExp(
    r"^([A-ZÁÉÍÓÚÜÑ0-9][A-ZÁÉÍÓÚÜÑ0-9 '.-]{0,40}?)(\s*\([^)]+\))?\s*$",
  );

  void reset() => _inDialogueBlock = false;

  ScreenplayLineKind classifyLine(
    String line, {
    required bool isSlugline,
    int leadingSpaces = 0,
  }) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      _inDialogueBlock = false;
      return ScreenplayLineKind.blank;
    }

    if (isSlugline) {
      _inDialogueBlock = false;
      return ScreenplayLineKind.slugline;
    }

    if (RegExp(r'^\d+\.?\s*$').hasMatch(trimmed)) {
      return ScreenplayLineKind.pageNumber;
    }

    if (_transition.hasMatch(trimmed)) {
      _inDialogueBlock = false;
      return ScreenplayLineKind.transition;
    }

    if (leadingSpaces >= 16 && _isCharacterLine(trimmed)) {
      _inDialogueBlock = true;
      return ScreenplayLineKind.character;
    }

    if (trimmed.startsWith('(') && trimmed.endsWith(')')) {
      if (_inDialogueBlock || (leadingSpaces >= 10 && leadingSpaces < 20)) {
        return ScreenplayLineKind.parenthetical;
      }
      return ScreenplayLineKind.action;
    }

    if (leadingSpaces >= 10 && leadingSpaces < 16) {
      if (_inDialogueBlock || !_looksLikeAction(trimmed)) {
        return ScreenplayLineKind.dialogue;
      }
    }

    if (_isCharacterLine(trimmed)) {
      _inDialogueBlock = true;
      return ScreenplayLineKind.character;
    }

    if (_inDialogueBlock && _looksLikeAction(trimmed)) {
      _inDialogueBlock = false;
      return ScreenplayLineKind.action;
    }

    if (_inDialogueBlock) {
      return ScreenplayLineKind.dialogue;
    }

    return ScreenplayLineKind.action;
  }

  static bool _isCharacterLine(String line) {
    return parseCharacterName(line) != null;
  }

  /// Nombre del personaje en una línea de diálogo (sin extensión V.O., etc.).
  static String? parseCharacterName(String line) {
    if (ScriptParser.tryParseSlugline(line, startIndex: 0) != null) {
      return null;
    }

    final match = _characterSuffix.firstMatch(line.trim());
    if (match == null) return null;

    final name = match.group(1)?.trim() ?? '';
    final letters = name.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÜÑ]'), '');
    if (letters.length < 2 || letters.length > 35) return null;
    if (letters != letters.toUpperCase()) return null;
    if (name.length > 32) return null;
    if (RegExp(r'^(INT|EXT|INT\/EXT|I\/E)\b', caseSensitive: false).hasMatch(name)) {
      return null;
    }

    return name;
  }

  static bool _looksLikeAction(String line) {
    if (line.length > 95) return true;
    final trimmed = line.trim();
    final letters = trimmed.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÜÑ]'), '');
    if (letters.isEmpty) return false;
    if (letters == letters.toUpperCase() && letters.length > 12) {
      return true;
    }

    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      final first = words.first.replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), '');
      final firstLower = first.toLowerCase();
      const dialogueStarters = {
        'no', 'sí', 'si', 'yo', 'me', 'te', 'lo', 'la', 'el', 'un', 'una',
        'es', 'ya', 'oh', 'ay', 'qué', 'que', 'cómo', 'como', 'por', 'pero',
      };
      if (!dialogueStarters.contains(firstLower) &&
          RegExp(r'^[A-ZÁÉÍÓÚÜÑ][a-záéíóúüñ]+$').hasMatch(first)) {
        final second = words[1].toLowerCase();
        const actionVerbs = {
          'se', 'camina', 'corre', 'entra', 'sale', 'mira', 'gira', 'sostiene',
          'toma', 'coge', 'repasa', 'acerca', 'aleja', 'susurra', 'grita',
          'asiente', 'cruza', 'sube', 'baja', 'abre', 'cierra', 'llega',
        };
        if (words.length >= 4 || actionVerbs.contains(second)) {
          return true;
        }
      }
    }

    return letters[0] == letters[0].toLowerCase();
  }
}

/// Márgenes proporcionales (página US Letter ~ ancho útil del guion).
class ScreenplayMargins {
  const ScreenplayMargins._();

  static EdgeInsetsMetrics forKind(ScreenplayLineKind kind, double innerWidth) {
    return switch (kind) {
      ScreenplayLineKind.action => EdgeInsetsMetrics(left: 0, right: innerWidth * 0.06),
      ScreenplayLineKind.character => EdgeInsetsMetrics(
          left: innerWidth * 0.26,
          right: innerWidth * 0.22,
        ),
      ScreenplayLineKind.dialogue => EdgeInsetsMetrics(
          left: innerWidth * 0.14,
          right: innerWidth * 0.14,
        ),
      ScreenplayLineKind.parenthetical => EdgeInsetsMetrics(
          left: innerWidth * 0.19,
          right: innerWidth * 0.25,
        ),
      ScreenplayLineKind.transition => EdgeInsetsMetrics(
          left: innerWidth * 0.45,
          right: 0,
        ),
      ScreenplayLineKind.pageNumber => EdgeInsetsMetrics(
          left: innerWidth * 0.82,
          right: 0,
        ),
      _ => EdgeInsetsMetrics.zero,
    };
  }
}

class EdgeInsetsMetrics {
  final double left;
  final double right;

  const EdgeInsetsMetrics({this.left = 0, this.right = 0});

  static const zero = EdgeInsetsMetrics();
}
