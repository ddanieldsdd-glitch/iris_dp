import 'package:flutter/material.dart';

import '../moodboard_association.dart';
import '../visual_bible_model.dart';

/// Acciones de navegación compartidas dentro de la biblia visual.
class BibleNavigationScope extends InheritedWidget {
  final void Function({String? sectionId, String? moodboardFilter}) openMoodboard;
  final void Function({int? siteId, int? setId}) openLocations;

  const BibleNavigationScope({
    super.key,
    required this.openMoodboard,
    required this.openLocations,
    required super.child,
  });

  static BibleNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BibleNavigationScope>();

  static void openMoodboardForSection(BuildContext context, String sectionId) {
    final scope = maybeOf(context);
    if (scope == null) return;
    final category = MoodboardAssociation.categoryForSection(sectionId);
    scope.openMoodboard(sectionId: sectionId, moodboardFilter: category);
  }

  static void openMoodboardFilter(BuildContext context, String? filter) {
    maybeOf(context)?.openMoodboard(moodboardFilter: filter);
  }

  static void openLocationSet(
    BuildContext context, {
    int? siteId,
    int? setId,
  }) {
    maybeOf(context)?.openLocations(siteId: siteId, setId: setId);
  }

  @override
  bool updateShouldNotify(BibleNavigationScope oldWidget) => false;
}

IconData bibleIconFromKey(String key) => switch (key) {
      'theater' => Icons.theater_comedy_outlined,
      'auto_stories' => Icons.auto_stories_outlined,
      'videocam' => Icons.videocam_outlined,
      'camera' => Icons.camera_outlined,
      'exposure' => Icons.exposure_outlined,
      'wb_sunny' => Icons.wb_sunny_outlined,
      'palette' => Icons.palette_outlined,
      'aspect_ratio' => Icons.aspect_ratio_outlined,
      'grain' => Icons.grain_outlined,
      'location_on' => Icons.location_on_outlined,
      'science' => Icons.science_outlined,
      'account_tree' => Icons.account_tree_outlined,
      'photo_library' => Icons.photo_library_outlined,
      _ => Icons.article_outlined,
    };

String bibleSectionLabel(String id, String fallback) =>
    BibleSectionId.label(id) == id ? fallback : BibleSectionId.label(id);
