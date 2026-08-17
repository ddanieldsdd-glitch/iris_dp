import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../moodboard_association.dart';
import '../visual_bible_model.dart';

/// Acciones de navegación compartidas dentro de la biblia visual.
class BibleNavigationScope extends InheritedWidget {
  final void Function({String? sectionId, String? moodboardFilter}) openMoodboard;
  final void Function({int? siteId, int? setId}) openLocations;
  /// Navega a una sección de la biblia (y opcionalmente un set).
  final void Function(String sectionId, {int? planId, String? focus})?
      openSection;
  /// Abre la sección Location de la biblia (no el módulo externo).
  final void Function({int? planId})? openBibleLocation;

  const BibleNavigationScope({
    super.key,
    required this.openMoodboard,
    required this.openLocations,
    this.openSection,
    this.openBibleLocation,
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
    final scope = maybeOf(context);
    if (scope == null) return;
    if (scope.openBibleLocation != null && setId != null) {
      scope.openBibleLocation!(planId: setId);
      return;
    }
    if (scope.openSection != null) {
      scope.openSection!(
        BibleSectionId.location,
        planId: setId,
      );
      return;
    }
    scope.openLocations(siteId: siteId, setId: setId);
  }

  static void goToSection(
    BuildContext context,
    String sectionId, {
    int? planId,
    String? focus,
  }) {
    maybeOf(context)?.openSection?.call(
          sectionId,
          planId: planId,
          focus: focus,
        );
  }

  /// Abre Iluminación centrada en una carta narrativa.
  static void openLightingCard(
    BuildContext context, {
    required int cardId,
    int? planId,
  }) {
    goToSection(
      context,
      BibleSectionId.lighting,
      planId: planId,
      focus: 'card:$cardId',
    );
  }

  @override
  bool updateShouldNotify(BibleNavigationScope oldWidget) =>
      openSection != oldWidget.openSection ||
      openBibleLocation != oldWidget.openBibleLocation;
}

/// Chips de navegación cruzada entre pantallas técnicas.
class BibleCrossNavChips extends StatelessWidget {
  final List<(String sectionId, String label)> targets;

  const BibleCrossNavChips({super.key, required this.targets});

  factory BibleCrossNavChips.techTriplet({String? current}) {
    final all = <(String, String)>[
      (BibleSectionId.lighting, 'Iluminación'),
      (BibleSectionId.exposure, 'Exposición'),
      (BibleSectionId.colorImage, 'Color'),
    ];
    return BibleCrossNavChips(
      targets: all.where((e) => e.$1 != current).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in targets)
          ActionChip(
            avatar: Icon(Icons.arrow_forward, size: 14, color: palette.accent),
            label: Text(
              'Ver en ${t.$2}',
              style: TextStyle(color: palette.textPrimary, fontSize: 12),
            ),
            onPressed: () => BibleNavigationScope.goToSection(context, t.$1),
            backgroundColor: palette.surfaceElevated,
            side: BorderSide(color: palette.border),
          ),
      ],
    );
  }
}

IconData bibleIconFromKey(String key) => switch (key) {
      'theater' => Icons.theater_comedy_outlined,
      'auto_stories' => Icons.auto_stories_outlined,
      'videocam' => Icons.videocam_outlined,
      'camera' => Icons.camera_outlined,
      'movie' => Icons.movie_filter_outlined,
      'notes' => Icons.notes_outlined,
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
