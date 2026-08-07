import 'bible_section_ids.dart';

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
    operational: [
      BibleSectionId.workflow,
      BibleSectionId.moodboard,
      BibleSectionId.settings,
    ],
  };
}
