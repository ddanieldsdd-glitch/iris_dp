/// Resolución determinista blob canónico vs columnas legacy (Fase 3).
abstract final class BibleSectionValueResolve {
  BibleSectionValueResolve._();

  /// Si [blob] contiene [canonicalKey], devuelve su valor (incluso vacío).
  /// Si no, usa [legacy] y luego [legacyFallbacks] en orden.
  static String? resolveSectionString(
    Map<String, dynamic> blob,
    String canonicalKey, {
    String? legacy,
    List<String?> legacyFallbacks = const [],
  }) {
    if (blob.containsKey(canonicalKey)) {
      final value = blob[canonicalKey];
      if (value == null) return null;
      return value.toString();
    }
    if (legacy != null && legacy.isNotEmpty) return legacy;
    for (final fallback in legacyFallbacks) {
      if (fallback != null && fallback.isNotEmpty) return fallback;
    }
    return null;
  }
}
