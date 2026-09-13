import 'package:flutter/widgets.dart';

import '../../widgets/moodboard_section.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';

/// Host V2 mínimo: monta [MoodboardSection] sin tocar el widget legacy.
abstract final class BibleMoodboardV2Host {
  static const pageId = BibleSectionId.moodboard;

  static Widget Function(String sectionId) wrap({
    required int projectId,
    required int? bibleId,
  }) {
    return (sectionId) => sectionBuilder(
      sectionId: sectionId,
      projectId: projectId,
      bibleId: bibleId,
    );
  }

  static Widget sectionBuilder({
    required String sectionId,
    required int projectId,
    required int? bibleId,
  }) {
    if (sectionId != pageId) {
      return const SizedBox.shrink();
    }
    final resolvedBibleId = bibleId ?? 0;
    return MoodboardSection(projectId: projectId, bibleId: resolvedBibleId);
  }
}
