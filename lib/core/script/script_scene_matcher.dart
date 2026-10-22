import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Empareja las escenas de una versión nueva del guion con las que ya tiene
/// el proyecto, por contenido y no por posición: una escena insertada o
/// quitada en medio no desplaza a las demás.
///
/// Código puro, sin base de datos ni pantalla.

/// Cómo ha cambiado una escena entre dos versiones del guion.
enum ScriptSceneChange {
  /// Misma cabecera y mismo texto.
  unchanged,

  /// Misma cabecera, cambia la parte narrativa.
  textChanged,

  /// Es la misma escena pero cambia de lugar, de INT/EXT o de momento.
  headingChanged,

  /// No estaba en el proyecto.
  added,
}

/// Escena que ya tiene el proyecto, tal como se guardó.
class ExistingScriptScene {
  final int id;
  final String headingKey;
  final String? textHash;

  /// Texto guardado de la escena; sirve para reconocerla si cambió su
  /// cabecera. Puede faltar en proyectos anteriores.
  final String? text;

  const ExistingScriptScene({
    required this.id,
    required this.headingKey,
    this.textHash,
    this.text,
  });
}

/// Escena detectada en la versión nueva del guion, en su orden.
class IncomingScriptScene {
  final String headingKey;
  final String? text;

  const IncomingScriptScene({required this.headingKey, this.text});

  String? get textHash => scriptTextHash(text);
}

/// Pareja de una escena nueva (por su posición en el guion) con la escena
/// del proyecto que le corresponde, si la hay.
class ScriptSceneLink {
  final int incomingIndex;
  final int? existingId;
  final ScriptSceneChange change;

  const ScriptSceneLink({
    required this.incomingIndex,
    required this.existingId,
    required this.change,
  });
}

class ScriptSceneMatch {
  /// Una por escena del guion nuevo, en su orden.
  final List<ScriptSceneLink> links;

  /// Escenas del proyecto que ya no están en el guion.
  final List<int> removedIds;

  const ScriptSceneMatch({required this.links, required this.removedIds});

  int count(ScriptSceneChange change) =>
      links.where((l) => l.change == change).length;

  /// Nada que revisar: todas siguen ahí y ninguna cambia de cabecera.
  bool get isTrivial =>
      removedIds.isEmpty &&
      links.every(
        (l) =>
            l.change == ScriptSceneChange.unchanged ||
            l.change == ScriptSceneChange.textChanged,
      );
}

/// Cabecera normalizada: sin tildes, signos ni mayúsculas, para que
/// «EXT. CALLE RAVAL - NOCHE» y «Ext calle Raval – noche» sean la misma.
String scriptHeadingKey({
  required String intExt,
  required String location,
  required String dayNight,
}) => [intExt, location, dayNight].map(_normalize).join('|');

/// Huella del texto de una escena, insensible a espacios y mayúsculas.
String? scriptTextHash(String? text) {
  if (text == null) return null;
  final normalized = _normalize(text);
  if (normalized.isEmpty) return null;
  return sha1.convert(utf8.encode(normalized)).toString();
}

const _accents = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

String _normalize(String value) {
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    final plain = _accents[ch] ?? ch;
    final code = plain.codeUnitAt(0);
    final isLetter = code >= 97 && code <= 122;
    final isDigit = code >= 48 && code <= 57;
    buffer.write(isLetter || isDigit ? plain : ' ');
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

Set<String> _words(String? text) => text == null
    ? const {}
    : _normalize(text).split(' ').where((w) => w.length > 3).toSet();

/// Parecido entre dos textos, de 0 a 1 (palabras en común sobre el total).
double scriptTextSimilarity(String? a, String? b) {
  final wa = _words(a);
  final wb = _words(b);
  if (wa.isEmpty || wb.isEmpty) return 0;
  final common = wa.intersection(wb).length;
  return common / (wa.length + wb.length - common);
}

/// A partir de este parecido, dos textos son la misma escena reescrita.
const _sameSceneSimilarity = 0.5;

ScriptSceneMatch matchScriptScenes({
  required List<ExistingScriptScene> existing,
  required List<IncomingScriptScene> incoming,
}) {
  final linked = List<int?>.filled(incoming.length, null);
  final usedOld = <int>{};

  void link(int newIndex, int oldIndex) {
    linked[newIndex] = oldIndex;
    usedOld.add(oldIndex);
  }

  // 1. Cabeceras iguales en el mismo orden relativo. Es la subsecuencia
  //    común más larga: aguanta escenas insertadas y quitadas, y empareja
  //    bien las cabeceras repetidas (la 2.ª «CALLE RAVAL» con la 2.ª).
  final n = existing.length;
  final m = incoming.length;
  final lcs = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      lcs[i][j] = existing[i].headingKey == incoming[j].headingKey
          ? lcs[i + 1][j + 1] + 1
          : (lcs[i + 1][j] >= lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
    }
  }
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (existing[i].headingKey == incoming[j].headingKey) {
      link(j, i);
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }

  List<int> freeOld() => [
    for (var k = 0; k < n; k++)
      if (!usedOld.contains(k)) k,
  ];
  List<int> freeNew() => [
    for (var k = 0; k < m; k++)
      if (linked[k] == null) k,
  ];

  // 2. La misma escena, movida de sitio en el guion: misma cabecera y mismo
  //    texto, fuera del orden anterior.
  for (final newIndex in freeNew()) {
    final hash = incoming[newIndex].textHash;
    if (hash == null) continue;
    for (final oldIndex in freeOld()) {
      if (existing[oldIndex].headingKey == incoming[newIndex].headingKey &&
          existing[oldIndex].textHash == hash) {
        link(newIndex, oldIndex);
        break;
      }
    }
  }

  // 3. Cambió la cabecera pero el texto es reconocible: se queda con la más
  //    parecida, siempre que lo sea de verdad.
  final candidates = <({int newIndex, int oldIndex, double score})>[];
  for (final newIndex in freeNew()) {
    for (final oldIndex in freeOld()) {
      final score =
          existing[oldIndex].textHash != null &&
              existing[oldIndex].textHash == incoming[newIndex].textHash
          ? 1.0
          : scriptTextSimilarity(
              existing[oldIndex].text,
              incoming[newIndex].text,
            );
      if (score >= _sameSceneSimilarity) {
        candidates.add((newIndex: newIndex, oldIndex: oldIndex, score: score));
      }
    }
  }
  candidates.sort((a, b) => b.score.compareTo(a.score));
  for (final c in candidates) {
    if (linked[c.newIndex] != null || usedOld.contains(c.oldIndex)) continue;
    link(c.newIndex, c.oldIndex);
  }

  // 4. Sin texto con el que comparar: una escena suelta entre dos ya
  //    emparejadas, donde antes había exactamente otra, es esa con la
  //    cabecera cambiada.
  var newIndex = 0;
  while (newIndex < m) {
    if (linked[newIndex] != null) {
      newIndex++;
      continue;
    }
    var end = newIndex;
    while (end < m && linked[end] == null) {
      end++;
    }
    final before = newIndex == 0 ? -1 : linked[newIndex - 1]!;
    final after = end == m ? n : linked[end]!;
    final gapOld = [
      for (var k = before + 1; k < after; k++)
        if (!usedOld.contains(k)) k,
    ];
    if (end - newIndex == 1 && gapOld.length == 1 && before < after) {
      final old = existing[gapOld.single];
      final neu = incoming[newIndex];
      // Con texto en ambos lados ya se comparó en el paso 3 y no se parecían.
      if (old.text == null || neu.text == null) link(newIndex, gapOld.single);
    }
    newIndex = end;
  }

  final links = <ScriptSceneLink>[];
  for (var k = 0; k < m; k++) {
    final oldIndex = linked[k];
    if (oldIndex == null) {
      links.add(
        ScriptSceneLink(
          incomingIndex: k,
          existingId: null,
          change: ScriptSceneChange.added,
        ),
      );
      continue;
    }
    final old = existing[oldIndex];
    final neu = incoming[k];
    final ScriptSceneChange change;
    if (old.headingKey != neu.headingKey) {
      change = ScriptSceneChange.headingChanged;
    } else if (old.textHash != null &&
        neu.textHash != null &&
        old.textHash != neu.textHash) {
      change = ScriptSceneChange.textChanged;
    } else {
      change = ScriptSceneChange.unchanged;
    }
    links.add(
      ScriptSceneLink(incomingIndex: k, existingId: old.id, change: change),
    );
  }

  return ScriptSceneMatch(
    links: links,
    removedIds: [for (final k in freeOld()) existing[k].id],
  );
}

/// Texto de cada escena dentro del guion: desde su cabecera hasta la de la
/// siguiente. [starts] son las posiciones de las cabeceras, una por escena y
/// en el orden de la lista (nulo = escena sin sitio en el texto).
List<String?> sceneTextsFromScript(String scriptText, List<int?> starts) {
  final ordered = [
    for (final s in starts)
      if (s != null && s >= 0 && s < scriptText.length) s,
  ]..sort();
  return [
    for (final start in starts)
      if (start == null || start < 0 || start >= scriptText.length)
        null
      else
        () {
          final next = ordered.where((s) => s > start);
          final end = next.isEmpty ? scriptText.length : next.first;
          final text = scriptText.substring(start, end).trim();
          return text.isEmpty ? null : text;
        }(),
  ];
}
