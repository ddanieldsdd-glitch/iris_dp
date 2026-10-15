import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show IconData, Icons;

import '../../core/database/app_database.dart';
import '../../core/sync/sync_plan.dart';
import '../../shared/visual_bible/bible_section_fields.dart';

/// Lo que enseña la tarjeta de un proyecto: cuánto está preparado y cómo está
/// respecto a la nube.
class ProjectCardStats {
  final int scenes;
  final int shots;
  final int shotsWithPlan;
  final int shotsWithStoryboard;
  final int shotsWithLens;
  final int bibleScreensFilled;
  final int bibleScreensTotal;
  final int references;
  final int lightSetups;
  final int sets;
  final bool contentQueued;
  final int imagesPending;
  final int imagesFailed;

  const ProjectCardStats({
    this.scenes = 0,
    this.shots = 0,
    this.shotsWithPlan = 0,
    this.shotsWithStoryboard = 0,
    this.shotsWithLens = 0,
    this.bibleScreensFilled = 0,
    this.bibleScreensTotal = 0,
    this.references = 0,
    this.lightSetups = 0,
    this.sets = 0,
    this.contentQueued = false,
    this.imagesPending = 0,
    this.imagesFailed = 0,
  });

  /// Avance medio (0–100) de los datos de avance de [metrics]: planta,
  /// storyboard, lente y biblia si no se dice otra cosa. Solo cuenta lo que
  /// tiene de qué: sin planos, el avance es el de la biblia.
  int preparationPercent([
    List<ProjectCardMetric> metrics = ProjectCardMetric.defaults,
  ]) {
    var progress = [
      for (final m in metrics)
        if (m.isProgress) m,
    ];
    if (progress.isEmpty) progress = ProjectCardMetric.defaults;
    final ratios = [
      for (final m in progress)
        if (m.total(this) > 0) m.done(this) / m.total(this),
    ];
    if (ratios.isEmpty) return 0;
    return (ratios.reduce((a, b) => a + b) / ratios.length * 100).round();
  }
}

/// Un dato que puede enseñar la tarjeta del proyecto: de avance (con barra,
/// «hechos/total») o una cifra.
enum ProjectCardMetric {
  plan('Planta', Icons.architecture_outlined),
  storyboard('Storyboard', Icons.view_carousel_outlined),
  lens('Lente', Icons.camera_outlined),
  bible('Biblia', Icons.menu_book_outlined),
  scenes('Escenas', Icons.movie_outlined),
  shots('Planos', Icons.videocam_outlined),
  lightSetups('Esquemas de luz', Icons.lightbulb_outline),
  sets('Sets', Icons.place_outlined),
  references('Referencias', Icons.photo_library_outlined);

  final String label;
  final IconData icon;
  const ProjectCardMetric(this.label, this.icon);

  static const defaults = [plan, storyboard, lens, bible];

  /// Cuántos datos caben en la tarjeta.
  static const maxShown = 5;

  bool get isProgress => switch (this) {
    plan || storyboard || lens || bible => true,
    _ => false,
  };

  int done(ProjectCardStats s) => switch (this) {
    plan => s.shotsWithPlan,
    storyboard => s.shotsWithStoryboard,
    lens => s.shotsWithLens,
    bible => s.bibleScreensFilled,
    scenes => s.scenes,
    shots => s.shots,
    lightSetups => s.lightSetups,
    sets => s.sets,
    references => s.references,
  };

  int total(ProjectCardStats s) => switch (this) {
    plan || storyboard || lens => s.shots,
    bible => s.bibleScreensTotal,
    _ => done(s),
  };

  /// Los datos elegidos para un proyecto (`Projects.cardMetricsJson`).
  static List<ProjectCardMetric> of(String? json) {
    if (json == null || json.isEmpty) return defaults;
    try {
      final names = (jsonDecode(json) as List).map((e) => '$e').toList();
      final chosen = [
        for (final name in names)
          ...values.where((m) => m.name == name),
      ];
      return chosen.isEmpty ? defaults : chosen.take(maxShown).toList();
    } catch (_) {
      return defaults;
    }
  }

  static String encode(List<ProjectCardMetric> metrics) =>
      jsonEncode([for (final m in metrics) m.name]);
}

Future<ProjectCardStats> loadProjectCardStats(
  AppDatabase db,
  int projectId,
) async {
  Future<int> count(String sql) async {
    final row = await db
        .customSelect(sql, variables: [Variable.withInt(projectId)])
        .getSingle();
    return row.read<int>('n');
  }

  final shotsRow = await db
      .customSelect(
        'SELECT COUNT(*) AS n, '
        'SUM(CASE WHEN light_setup_id IS NOT NULL OR EXISTS '
        '(SELECT 1 FROM camera_plan_elements e WHERE e.shot_id = s.id) '
        'THEN 1 ELSE 0 END) AS plan, '
        "SUM(CASE WHEN COALESCE(storyboard_image_path, '') <> '' "
        'THEN 1 ELSE 0 END) AS storyboard, '
        "SUM(CASE WHEN TRIM(COALESCE(lens, '')) <> '' THEN 1 ELSE 0 END) "
        'AS lens '
        'FROM shots s WHERE s.project_id = ?',
        variables: [Variable.withInt(projectId)],
      )
      .getSingle();

  final screens = await db
      .customSelect(
        'SELECT d.content_json FROM bible_section_definitions d '
        'JOIN visual_bibles b ON b.id = d.bible_id '
        'WHERE b.project_id = ? AND d.is_hidden = 0',
        variables: [Variable.withInt(projectId)],
      )
      .get();
  final filled = screens.where((row) {
    final values = BibleSectionFieldsConfig.parseValues(
      row.read<String?>('content_json'),
    );
    return values.values.any((v) => v.trim().isNotEmpty);
  }).length;

  final queueRows = await db
      .customSelect(
        "SELECT status, COUNT(*) AS n FROM pending_media_uploads "
        'WHERE project_id = ? GROUP BY status',
        variables: [Variable.withInt(projectId)],
      )
      .get();
  final byStatus = {
    for (final r in queueRows) r.read<String>('status'): r.read<int>('n'),
  };

  return ProjectCardStats(
    scenes: await count(
      'SELECT COUNT(*) AS n FROM scenes WHERE project_id = ?',
    ),
    shots: shotsRow.read<int>('n'),
    shotsWithPlan: shotsRow.read<int?>('plan') ?? 0,
    shotsWithStoryboard: shotsRow.read<int?>('storyboard') ?? 0,
    shotsWithLens: shotsRow.read<int?>('lens') ?? 0,
    bibleScreensFilled: filled,
    bibleScreensTotal: screens.length,
    lightSetups: await count(
      'SELECT COUNT(*) AS n FROM light_setups WHERE project_id = ?',
    ),
    sets: await count(
      'SELECT COUNT(*) AS n FROM location_base_plans WHERE project_id = ?',
    ),
    references:
        await count(
          'SELECT COUNT(*) AS n FROM moodboard_images WHERE project_id = ?',
        ) +
        await count(
          'SELECT COUNT(*) AS n FROM shot_references r '
          'JOIN shots s ON s.id = r.shot_id WHERE s.project_id = ?',
        ),
    contentQueued:
        await count(
          'SELECT COUNT(*) AS n FROM cloud_sync_queue '
          "WHERE entity_type = 'project_content' AND processed = 0 "
          "AND local_entity_id = CAST(? AS TEXT)",
        ) >
        0,
    imagesPending: (byStatus['pending'] ?? 0) + (byStatus['processing'] ?? 0),
    imagesFailed: byStatus['failed'] ?? 0,
  );
}

/// Cómo está un proyecto respecto a la nube, de lo más urgente a lo menos.
enum ProjectSyncState {
  conflict('Elegir versión'),
  toDownload('Cambios en la nube'),
  toUpload('Cambios por subir'),
  imagesFailed('Imágenes fallidas'),
  imagesPending('Imágenes en cola'),
  upToDate('Al día'),
  localOnly('Solo en este equipo');

  final String label;
  const ProjectSyncState(this.label);
}

/// El estado de [project]. Lo que solo se sabe mirando la nube (conflicto,
/// cambios allí) sale del plan de la última comprobación, [pendingPlan].
ProjectSyncState projectSyncState({
  required Project project,
  required ProjectCardStats stats,
  SyncPlan? pendingPlan,
}) {
  if (project.cloudId == null) return ProjectSyncState.localOnly;
  final items = [
    for (final item in pendingPlan?.items ?? const <SyncPlanItem>[])
      if (item.localProjectId == project.id) item,
  ];
  bool has(SyncPlanAction a) => items.any((i) => i.action == a);
  if (has(SyncPlanAction.contentConflict) || has(SyncPlanAction.conflict)) {
    return ProjectSyncState.conflict;
  }
  if (has(SyncPlanAction.pullContentCloud) ||
      has(SyncPlanAction.updateLocalFromCloud)) {
    return ProjectSyncState.toDownload;
  }
  if (stats.contentQueued ||
      has(SyncPlanAction.pushContentLocal) ||
      has(SyncPlanAction.updateCloudFromLocal)) {
    return ProjectSyncState.toUpload;
  }
  if (stats.imagesFailed > 0) return ProjectSyncState.imagesFailed;
  if (stats.imagesPending > 0) return ProjectSyncState.imagesPending;
  return ProjectSyncState.upToDate;
}
