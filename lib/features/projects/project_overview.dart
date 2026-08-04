import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';

/// Métrica visual de contenido en la tarjeta de proyecto.
class ProjectContentMetric {
  final String label;
  final IconData icon;
  final int value;
  final int capacity;
  final Color color;

  const ProjectContentMetric({
    required this.label,
    required this.icon,
    required this.value,
    required this.capacity,
    required this.color,
  });

  double get progress =>
      capacity <= 0 ? 0 : (value / capacity).clamp(0.0, 1.0);

  bool get hasContent => value > 0;
}

/// Resumen visual del estado de un proyecto para la pantalla de inicio.
class ProjectOverview {
  final String? directionSummary;
  final int sceneCount;
  final int planCount;
  final int moodboardCount;
  final int locationCount;
  final int bibleFillPercent;
  final int totalScore;

  const ProjectOverview({
    this.directionSummary,
    this.sceneCount = 0,
    this.planCount = 0,
    this.moodboardCount = 0,
    this.locationCount = 0,
    this.bibleFillPercent = 0,
    this.totalScore = 0,
  });

  String get stateLabel {
    if (totalScore == 0) return 'Proyecto nuevo';
    if (sceneCount == 0 && moodboardCount > 0) {
      return 'Look en desarrollo';
    }
    if (sceneCount > 0 && planCount == 0) return 'Guion cargado';
    if (planCount > 0 && bibleFillPercent < 40) {
      return 'Preproducción en marcha';
    }
    if (bibleFillPercent >= 40) return 'Biblia en progreso';
    return 'En configuración';
  }

  List<ProjectContentMetric> metricsForPalette({
    required Color accent,
    required Color success,
    required Color warning,
    required Color info,
    required Color secondary,
  }) {
    return [
      ProjectContentMetric(
        label: 'Guion',
        icon: Icons.menu_book_outlined,
        value: sceneCount,
        capacity: 40,
        color: warning,
      ),
      ProjectContentMetric(
        label: 'Planos',
        icon: Icons.grid_on_outlined,
        value: planCount,
        capacity: 30,
        color: success,
      ),
      ProjectContentMetric(
        label: 'Moodboard',
        icon: Icons.photo_library_outlined,
        value: moodboardCount,
        capacity: 24,
        color: accent,
      ),
      ProjectContentMetric(
        label: 'Locaciones',
        icon: Icons.location_city_outlined,
        value: locationCount,
        capacity: 12,
        color: info,
      ),
      ProjectContentMetric(
        label: 'Biblia',
        icon: Icons.auto_stories_outlined,
        value: bibleFillPercent,
        capacity: 100,
        color: secondary,
      ),
    ];
  }
}

/// Texto breve desde el apartado Dirección de la biblia de fotografía.
String? directionSummaryFromBible(VisualBible? bible) {
  if (bible == null) return null;
  for (final text in [
    bible.creativeIntention,
    bible.directionNarrativeIntent,
    bible.tone,
    bible.stagingApproach,
    bible.pointOfView,
  ]) {
    if (text != null && text.trim().isNotEmpty) return text.trim();
  }
  return null;
}

int _bibleFillPercent(VisualBible? bible) {
  if (bible == null) return 0;
  const fields = [
    // Dirección
    'creativeIntention',
    'directionNarrativeIntent',
    'tone',
    'stagingApproach',
    'pointOfView',
    // Concepto y técnica
    'visualConcept',
    'cameraPhilosophy',
    'lensPhilosophy',
    'lightingPhilosophy',
    'aspectRatio',
    'workingLutName',
    'highlightBehavior',
    'shadowBehavior',
  ];
  var filled = 0;
  for (final key in fields) {
    final value = switch (key) {
      'creativeIntention' => bible.creativeIntention,
      'directionNarrativeIntent' => bible.directionNarrativeIntent,
      'tone' => bible.tone,
      'stagingApproach' => bible.stagingApproach,
      'pointOfView' => bible.pointOfView,
      'visualConcept' => bible.visualConcept,
      'cameraPhilosophy' => bible.cameraPhilosophy,
      'lensPhilosophy' => bible.lensPhilosophy,
      'lightingPhilosophy' => bible.lightingPhilosophy,
      'aspectRatio' => bible.aspectRatio,
      'workingLutName' => bible.workingLutName,
      'highlightBehavior' => bible.highlightBehavior,
      'shadowBehavior' => bible.shadowBehavior,
      _ => null,
    };
    if (value != null && value.trim().isNotEmpty) filled++;
  }
  return ((filled / fields.length) * 100).round();
}

ProjectOverview buildProjectOverview({
  required VisualBible? bible,
  required int sceneCount,
  required int planCount,
  required int moodboardCount,
  required int locationCount,
}) {
  final biblePct = _bibleFillPercent(bible);
  final totalScore = sceneCount +
      planCount +
      moodboardCount +
      locationCount +
      (biblePct ~/ 10);

  return ProjectOverview(
    directionSummary: directionSummaryFromBible(bible),
    sceneCount: sceneCount,
    planCount: planCount,
    moodboardCount: moodboardCount,
    locationCount: locationCount,
    bibleFillPercent: biblePct,
    totalScore: totalScore,
  );
}

Future<ProjectOverview> loadProjectOverview(AppDatabase db, int projectId) async {
  final counts = await db.fetchProjectSummaryCounts(projectId);
  return buildProjectOverview(
    bible: counts.bible,
    sceneCount: counts.sceneCount,
    planCount: counts.planCount,
    moodboardCount: counts.moodboardCount,
    locationCount: counts.locationCount,
  );
}
