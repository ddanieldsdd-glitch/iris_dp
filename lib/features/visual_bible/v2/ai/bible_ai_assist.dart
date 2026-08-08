/// Capa IA opcional (Fase 12) — stubs sin dependencia de red.
///
/// La IA no forma parte del motor; solo sugiere sobre un [BibleDocument] estable.
abstract final class BibleAiAssist {
  /// Detecta huecos evidentes (sin bloquear).
  static List<String> analyzeGaps({
    required bool hasPrimaryCamera,
    required bool hasPrimaryLens,
    required bool hasMoodboardRefs,
    required bool hasLightingSetup,
    required bool hasColorPalette,
  }) {
    final gaps = <String>[];
    if (!hasPrimaryCamera) gaps.add('No hay cámara principal.');
    if (!hasPrimaryLens) gaps.add('No hay lente principal.');
    if (!hasMoodboardRefs) gaps.add('No hay referencias visuales.');
    if (!hasLightingSetup) gaps.add('Lighting no tiene setup.');
    if (!hasColorPalette) gaps.add('Color no tiene palette.');
    return gaps;
  }

  /// Sugerencia simple de widgets según densidad técnica del texto.
  static List<String> suggestWidgets(String pageText) {
    final lower = pageText.toLowerCase();
    final out = <String>[];
    if (lower.contains('iso') || lower.contains('codec')) {
      out.add('specsTable');
    }
    if (lower.contains('kelvin') || lower.contains('contrast')) {
      out.add('telemetry');
    }
    if (lower.contains('workflow') || lower.contains('pipeline')) {
      out.add('workflowPipeline');
    }
    if (out.isEmpty) out.add('narrative');
    return out;
  }
}
