import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../moodboard_reference_meta.dart';
import '../visual_bible_model.dart';
import 'moodboard_lightbox.dart';

/// Abre en el visor del moodboard las imágenes [ids], en su orden, empezando
/// por [initialId]: ahí se comentan y se dibuja encima, y lo hecho se ve igual
/// desde el moodboard y desde la biblia.
Future<void> openMoodboardImages(
  BuildContext context,
  List<int> ids, {
  int? initialId,
  int? bibleId,
}) async {
  if (ids.isEmpty) return;
  final db = ProviderScope.containerOf(context).read(databaseProvider);
  final rows = await (db.select(
    db.moodboardImages,
  )..where((m) => m.id.isIn(ids))).get();
  final byId = {for (final r in rows) r.id: r};
  final ordered = [
    for (final id in ids)
      if (byId[id] case final MoodboardImage row)
        MoodboardImageModel.fromRow(row),
  ];
  if (ordered.isEmpty || !context.mounted) return;
  final meta = await MoodboardReferenceMetaStore.loadMany(
    db,
    ordered.map((m) => m.id),
  );
  if (!context.mounted) return;
  final index = ordered.indexWhere((m) => m.id == initialId);
  await MoodboardLightbox.show(
    context: context,
    images: ordered,
    initialIndex: index < 0 ? 0 : index,
    metaById: meta,
    bibleId: bibleId,
    projectId: ordered.first.projectId,
    onAddToProject: (_) async {},
  );
}
