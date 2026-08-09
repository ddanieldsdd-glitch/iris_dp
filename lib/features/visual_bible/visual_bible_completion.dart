export '../../shared/visual_bible/bible_layout.dart';

import '../../shared/visual_bible/camera_pilot_resolve.dart';
import '../../shared/visual_bible/format_pilot_resolve.dart';
import 'visual_bible_model.dart';

/// Porcentaje aproximado de completitud por sección (0.0–1.0).
double bibleSectionCompletion(
  VisualBibleData data,
  String sectionId, {
  String? formatSectionContentJson,
  String? cameraSectionContentJson,
}) {
  bool filled(String? v) => v != null && v.trim().isNotEmpty;

  return switch (sectionId) {
    BibleSectionId.direction => _ratio([
      filled(data.tone),
      filled(data.creativeIntention),
      filled(data.stagingApproach),
      filled(data.pointOfView),
      filled(data.directionNarrativeIntent),
    ]),
    BibleSectionId.concept => _ratio([
      filled(data.visualConcept),
      data.narrativeReferences.isNotEmpty,
      data.actVisualNotes.any((a) => filled(a['intent'])),
      filled(data.conceptNarrativeIntent),
    ]),
    BibleSectionId.camera => () {
        final blob = CameraPilotResolve.parseBlob(cameraSectionContentJson);
        return _ratio([
          data.primaryCameraId != null,
          filled(data.cameraPhilosophy),
          filled(data.movementStyle),
          filled(data.recordingFormat),
          filled(data.cameraNarrativeIntent),
          filled(CameraPilotResolve.captureResolution(blob, data)),
        ]);
      }(),
    BibleSectionId.optics => _ratio([
      filled(data.lensPhilosophy),
      filled(data.opticType),
      data.primaryFocalLengths.isNotEmpty,
      filled(data.depthOfFieldNotes),
      filled(data.opticsNarrativeIntent),
    ]),
    BibleSectionId.exposure => _ratio([
      filled(data.exposureNarrativeIntent),
      filled(data.highlightBehavior),
      filled(data.shadowBehavior),
      data.nativeIso != null,
      filled(data.defaultTStop),
    ]),
    BibleSectionId.lighting => _ratio([
      filled(data.lightingPhilosophy),
      filled(data.lightQuality),
      filled(data.contrastStyle),
      filled(data.lightSource),
      filled(data.lightingNarrativeIntent),
    ]),
    BibleSectionId.colorImage => _ratio([
      filled(data.workingLutName),
      filled(data.creativeLutName),
      filled(data.colorNarrativeIntent),
      filled(data.lightSource),
    ]),
    BibleSectionId.format => () {
        final blob = FormatPilotResolve.parseBlob(formatSectionContentJson);
        return _ratio([
          filled(FormatPilotResolve.activeRatio(blob, data)),
          filled(FormatPilotResolve.resolution(blob, data)),
          filled(FormatPilotResolve.intentNarrative(blob, data)),
        ]);
      }(),
    BibleSectionId.texture => _ratio([
      filled(data.imageTexture),
      filled(data.grainLevel),
      filled(data.diffusionNotes),
      filled(data.textureNarrativeIntent),
    ]),
    // Localización se completa con sus referencias jerárquicas; no debe
    // reutilizar campos globales de iluminación.
    BibleSectionId.location => 0.0,
    BibleSectionId.cameraTests =>
      filled(data.cameraNarrativeIntent) ? 0.35 : 0.0,
    BibleSectionId.workflow => filled(data.workflowPipeline) ? 1.0 : 0.0,
    BibleSectionId.moodboard => filled(data.visualConcept) ? 0.25 : 0.0,
    _ => 0.0,
  };
}

/// Completitud con conteos de tablas hijas (moodboard, tests, color blocks).
double bibleSectionCompletionExtended({
  required VisualBibleData data,
  required String sectionId,
  int moodboardCount = 0,
  int cameraTestCount = 0,
  int colorBlockCount = 0,
  int locationRefCount = 0,
  int lightingSetupCount = 0,
  int sectionRefsCount = 0,
  String? formatSectionContentJson,
  String? cameraSectionContentJson,
}) {
  final base = bibleSectionCompletion(
    data,
    sectionId,
    formatSectionContentJson: formatSectionContentJson,
    cameraSectionContentJson: cameraSectionContentJson,
  );
  final withRefs = sectionRefsCount > 0
      ? (base + (sectionRefsCount.clamp(0, 6) / 6) * 0.35).clamp(0.0, 1.0)
      : base;
  return switch (sectionId) {
    BibleSectionId.moodboard =>
      moodboardCount <= 0
          ? withRefs
          : (0.2 + (moodboardCount.clamp(0, 12) / 12) * 0.8).clamp(0.0, 1.0),
    BibleSectionId.cameraTests =>
      cameraTestCount <= 0
          ? withRefs
          : (0.3 + (cameraTestCount.clamp(0, 5) / 5) * 0.7).clamp(0.0, 1.0),
    BibleSectionId.colorImage =>
      colorBlockCount <= 0 ? withRefs : ((withRefs + 0.35).clamp(0.0, 1.0)),
    BibleSectionId.location =>
      locationRefCount <= 0 ? withRefs : ((withRefs + 0.4).clamp(0.0, 1.0)),
    BibleSectionId.lighting =>
      lightingSetupCount <= 0 ? withRefs : ((withRefs + 0.25).clamp(0.0, 1.0)),
    _ => withRefs,
  };
}

/// Progreso medio de las pantallas activas, incluyendo sus tablas hijas.
///
/// Ignora IDs desconocidos (por ejemplo, pantallas freeform) para no
/// presentarlos erróneamente como trabajo pendiente.
double bibleOverallCompletion({
  required VisualBibleData data,
  required Iterable<String> sectionIds,
  int moodboardCount = 0,
  int cameraTestCount = 0,
  int colorBlockCount = 0,
  int locationRefCount = 0,
  int lightingSetupCount = 0,
  int Function(String sectionId)? sectionRefsCount,
  String? formatSectionContentJson,
  String? cameraSectionContentJson,
}) {
  final knownIds = sectionIds.where(BibleSectionId.all.contains).toSet();
  if (knownIds.isEmpty) return 0;
  final total = knownIds.fold<double>(
    0,
    (sum, sectionId) =>
        sum +
        bibleSectionCompletionExtended(
          data: data,
          sectionId: sectionId,
          moodboardCount: moodboardCount,
          cameraTestCount: cameraTestCount,
          colorBlockCount: colorBlockCount,
          locationRefCount: locationRefCount,
          lightingSetupCount: lightingSetupCount,
          sectionRefsCount: sectionRefsCount?.call(sectionId) ?? 0,
          formatSectionContentJson: formatSectionContentJson,
          cameraSectionContentJson: cameraSectionContentJson,
        ),
  );
  return total / knownIds.length;
}

double _ratio(List<bool> checks) {
  if (checks.isEmpty) return 0;
  final done = checks.where((c) => c).length;
  return done / checks.length;
}
