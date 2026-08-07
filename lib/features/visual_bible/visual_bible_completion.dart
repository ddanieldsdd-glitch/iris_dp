export '../../shared/visual_bible/bible_layout.dart';

import 'visual_bible_model.dart';
import '../../shared/visual_bible/bible_section_ids.dart';

/// Porcentaje aproximado de completitud por sección (0.0–1.0).
double bibleSectionCompletion(VisualBibleData data, String sectionId) {
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
    BibleSectionId.camera => _ratio([
          data.primaryCameraId != null,
          filled(data.cameraPhilosophy),
          filled(data.movementStyle),
          filled(data.recordingFormat),
          filled(data.cameraNarrativeIntent),
        ]),
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
    BibleSectionId.format => _ratio([
          filled(data.aspectRatio),
          filled(data.aspectRatioJustification),
          filled(data.formatNarrativeIntent),
        ]),
    BibleSectionId.texture => _ratio([
          filled(data.imageTexture),
          filled(data.grainLevel),
          filled(data.diffusionNotes),
          filled(data.textureNarrativeIntent),
        ]),
    BibleSectionId.location => _ratio([
          filled(data.lightingNarrativeIntent),
          filled(data.lightSource),
        ]),
    BibleSectionId.cameraTests => filled(data.cameraNarrativeIntent) ? 0.35 : 0.0,
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
}) {
  final base = bibleSectionCompletion(data, sectionId);
  return switch (sectionId) {
    BibleSectionId.moodboard => moodboardCount <= 0
        ? 0.0
        : (0.2 + (moodboardCount.clamp(0, 12) / 12) * 0.8).clamp(0.0, 1.0),
    BibleSectionId.cameraTests => cameraTestCount <= 0
        ? base
        : (0.3 + (cameraTestCount.clamp(0, 5) / 5) * 0.7).clamp(0.0, 1.0),
    BibleSectionId.colorImage => colorBlockCount <= 0
        ? base
        : ((base + 0.35).clamp(0.0, 1.0)),
    BibleSectionId.location => locationRefCount <= 0
        ? base
        : ((base + 0.4).clamp(0.0, 1.0)),
    BibleSectionId.lighting => lightingSetupCount <= 0
        ? base
        : ((base + 0.25).clamp(0.0, 1.0)),
    _ => base,
  };
}

double _ratio(List<bool> checks) {
  if (checks.isEmpty) return 0;
  final done = checks.where((c) => c).length;
  return done / checks.length;
}
