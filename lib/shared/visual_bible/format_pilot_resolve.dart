import '../../features/visual_bible/export/bible_section_export_reader.dart';
import '../../features/visual_bible/visual_bible_model.dart';
import 'bible_section_value_resolve.dart';

/// Lectura canónica de los tres conceptos migrados en el piloto Format (Fase 3).
///
/// Contrato: blob canónico → columna legacy → default (vía [BibleSectionValueResolve]).
abstract final class FormatPilotResolve {
  FormatPilotResolve._();

  static const pilotBlobKeys = {'activeRatio', 'resolution', 'intentNarrative'};

  static Map<String, dynamic> parseBlob(String? contentJson) =>
      BibleSectionExportReader.parseCustomBlob(
        contentJson,
        BibleSectionId.format,
      );

  static String? activeRatio(
    Map<String, dynamic> blob,
    VisualBibleData data,
  ) =>
      BibleSectionValueResolve.resolveSectionString(
        blob,
        'activeRatio',
        legacy: data.aspectRatio,
      );

  static String? resolution(
    Map<String, dynamic> blob,
    VisualBibleData data,
  ) =>
      BibleSectionValueResolve.resolveSectionString(
        blob,
        'resolution',
        legacy: data.captureResolution,
      );

  static String? intentNarrative(
    Map<String, dynamic> blob,
    VisualBibleData data,
  ) =>
      BibleSectionValueResolve.resolveSectionString(
        blob,
        'intentNarrative',
        legacyFallbacks: [
          data.formatNarrativeIntent,
          data.aspectRatioJustification,
        ],
      );

  /// Slot PDF «Justificación»: solo cuando no hay narrativa canónica en blob y
  /// la columna legacy no está ya cubierta por [intentNarrative].
  static String? legacyJustificationForPdf(
    Map<String, dynamic> blob,
    VisualBibleData data,
  ) {
    if (blob.containsKey('intentNarrative')) return null;
    final justification = data.aspectRatioJustification?.trim();
    if (justification == null || justification.isEmpty) return null;
    final narrativeIntent = data.formatNarrativeIntent?.trim();
    if (narrativeIntent != null && narrativeIntent.isNotEmpty) return null;
    return justification;
  }

  /// Filas custom de export sin repetir campos ya mostrados en slots fijos.
  static List<(String, String?)> customRowsForPdf(Map<String, dynamic> blob) {
    if (blob.isEmpty) return const [];
    final filtered = Map<String, dynamic>.from(blob)
      ..removeWhere((key, _) => pilotBlobKeys.contains(key));
    return BibleSectionExportReader.rowsForSection(
      BibleSectionId.format,
      filtered,
    ).map((row) => (row.label, row.value)).toList();
  }

  static bool hasExportablePilotContent(
    VisualBibleData data,
    Map<String, dynamic> blob,
  ) =>
      _filled(activeRatio(blob, data)) ||
      _filled(resolution(blob, data)) ||
      _filled(intentNarrative(blob, data)) ||
      _filled(legacyJustificationForPdf(blob, data)) ||
      _filled(data.recordingFormat) ||
      _filled(data.deliveryResolution) ||
      BibleSectionExportReader.hasExportableContent(
        BibleSectionId.format,
        Map<String, dynamic>.from(blob)
          ..removeWhere((key, _) => pilotBlobKeys.contains(key)),
      );

  static bool _filled(String? value) => value?.trim().isNotEmpty == true;
}
