/// Partes en las que se puede elegir o cortar el texto de una escena.
///
/// El texto del guion llega con los saltos de línea de la página: se reúne y
/// se separa por frases, que es lo que se elige en el guion técnico.
List<String> sceneTextSentences(String? text) {
  if (text == null || text.trim().isEmpty) return const [];
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return [
    for (final part in flat.split(RegExp(r'(?<=[.!?…])\s+(?=[^a-záéíóúüñ])')))
      if (part.trim().isNotEmpty) part.trim(),
  ];
}

/// Une [picked] a la acción ya escrita, sin borrar nada.
String appendActionText(String? current, String picked) {
  final before = current?.trimRight() ?? '';
  return before.isEmpty ? picked : '$before\n$picked';
}

/// Letras tras dividir una escena. Sin letra pasa a ser A y la nueva B; con
/// letra, conserva la suya y la nueva toma la primera libre detrás de la más
/// alta del número.
({String first, String second}) splitSceneSuffixes(
  String? current,
  Iterable<String?> taken,
) {
  final first = current ?? 'A';
  final used = {
    first,
    for (final s in taken)
      if (s != null) s,
  };
  var code = 'A'.codeUnitAt(0);
  for (final s in used) {
    if (s.isNotEmpty && s.codeUnitAt(0) > code) code = s.codeUnitAt(0);
  }
  return (first: first, second: String.fromCharCode(code + 1));
}
