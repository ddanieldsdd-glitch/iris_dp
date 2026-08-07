import 'visual_bible_model.dart';

abstract final class BibleLayoutGroup {
  static const narrative = 'narrative';
  static const technical = 'technical';
  static const spatial = 'spatial';
  static const operational = 'operational';

  static String label(String id) => switch (id) {
        narrative => 'Narrativa y creativa',
        technical => 'Técnica de imagen',
        spatial => 'Espacial y pruebas',
        operational => 'Operativa y referencias',
        _ => id,
      };

  static const orderedGroups = [narrative, technical, spatial, operational];

  static const sectionsByGroup = {
    narrative: [BibleSectionId.direction, BibleSectionId.concept],
    technical: [
      BibleSectionId.camera,
      BibleSectionId.optics,
      BibleSectionId.exposure,
      BibleSectionId.lighting,
      BibleSectionId.colorImage,
      BibleSectionId.format,
      BibleSectionId.texture,
    ],
    spatial: [BibleSectionId.location, BibleSectionId.cameraTests],
    operational: [BibleSectionId.workflow, BibleSectionId.moodboard, BibleSectionId.settings],
  };
}

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
    BibleSectionId.exposure => filled(data.exposureNarrativeIntent) ? 0.5 : 0.0,
    BibleSectionId.lighting => _ratio([
      filled(data.lightingPhilosophy),
      filled(data.lightQuality),
      filled(data.contrastStyle),
      filled(data.lightingNarrativeIntent),
    ]),
    BibleSectionId.colorImage => _ratio([
      filled(data.workingLutName),
      filled(data.creativeLutName),
      filled(data.colorNarrativeIntent),
    ]),
    BibleSectionId.format => _ratio([
      filled(data.aspectRatio),
      filled(data.aspectRatioJustification),
      filled(data.formatNarrativeIntent),
    ]),
    BibleSectionId.texture => _ratio([
      filled(data.imageTexture),
      filled(data.grainLevel),
      filled(data.textureNarrativeIntent),
    ]),
    BibleSectionId.location => 0.0,
    BibleSectionId.cameraTests => 0.0,
    BibleSectionId.workflow => filled(data.workflowPipeline) ? 1.0 : 0.0,
    BibleSectionId.moodboard => 0.0,
    _ => 0.0,
  };
}

double _ratio(List<bool> checks) {
  if (checks.isEmpty) return 0;
  final done = checks.where((c) => c).length;
  return done / checks.length;
}
