import 'dart:convert';

List<String> decodeSceneCharacters(String? json) {
  if (json == null || json.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return decoded
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
}

String? encodeSceneCharacters(List<String> characters) {
  final cleaned = characters
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toList();
  if (cleaned.isEmpty) return null;
  return jsonEncode(cleaned);
}

List<String> parseCharactersInput(String input) {
  if (input.trim().isEmpty) return const [];
  return input
      .split(RegExp(r'[,;\n]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
}

String formatCharactersInput(List<String> characters) =>
    characters.join(', ');
