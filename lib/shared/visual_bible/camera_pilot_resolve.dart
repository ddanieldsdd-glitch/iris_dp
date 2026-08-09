import '../../features/visual_bible/export/bible_section_export_reader.dart';
import '../../features/visual_bible/visual_bible_model.dart';
import 'bible_section_value_resolve.dart';

/// Lectura canónica del piloto Camera (Fase 3): resolución de captura en blob.
///
/// Contrato: blob canónico → columna legacy → default (vía [BibleSectionValueResolve]).
abstract final class CameraPilotResolve {
  CameraPilotResolve._();

  static const pilotBlobKeys = {'captureResolution'};

  static Map<String, dynamic> parseBlob(String? contentJson) =>
      BibleSectionExportReader.parseCustomBlob(
        contentJson,
        BibleSectionId.camera,
      );

  static String? captureResolution(
    Map<String, dynamic> blob,
    VisualBibleData data,
  ) =>
      BibleSectionValueResolve.resolveSectionString(
        blob,
        'captureResolution',
        legacy: data.captureResolution,
      );

  /// Slots fijos del PDF clásico (columnas legacy + blob piloto).
  static List<(String, String?)> fixedSlotsForPdf(
    VisualBibleData data,
    Map<String, dynamic> blob, {
    String? primaryCameraLabel,
  }) =>
      [
        ('Intención narrativa', data.cameraNarrativeIntent),
        ('Cámara principal (A-CAM)', primaryCameraLabel),
        ('ISO nativo', data.nativeIso?.toString()),
        ('Resolución de captura', captureResolution(blob, data)),
        ('Codec', data.codec ?? data.recordingFormat),
        ('Frame rate', data.frameRateNotes),
        ('Espacio de color', data.colorScienceNotes),
        ('Filosofía de cámara', data.cameraPhilosophy),
        ('Estilo de movimiento', data.movementStyle),
        ('Show LUT', data.creativeLutName),
      ];

  /// Filas custom de export sin repetir campos ya mostrados en slots fijos.
  static List<(String, String?)> customRowsForPdf(Map<String, dynamic> blob) {
    if (blob.isEmpty) return const [];
    final filtered = Map<String, dynamic>.from(blob)
      ..removeWhere((key, _) => pilotBlobKeys.contains(key));
    return BibleSectionExportReader.rowsForSection(
      BibleSectionId.camera,
      filtered,
    ).map((row) => (row.label, row.value)).toList();
  }

  static bool hasExportablePilotContent(
    VisualBibleData data,
    Map<String, dynamic> blob, {
    String? primaryCameraLabel,
  }) =>
      fixedSlotsForPdf(
        data,
        blob,
        primaryCameraLabel: primaryCameraLabel,
      ).any((slot) => _filled(slot.$2)) ||
      BibleSectionExportReader.hasExportableContent(
        BibleSectionId.camera,
        Map<String, dynamic>.from(blob)
          ..removeWhere((key, _) => pilotBlobKeys.contains(key)),
      );

  static bool _filled(String? value) => value?.trim().isNotEmpty == true;
}
