import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import 'edit_history.dart';

/// Escribe columnas de un plano y lo apunta en el historial, para poder
/// deshacerlo.
Future<void> writeShotFields(
  AppDatabase db,
  EditHistory history,
  int shotId,
  ShotsCompanion fields, {
  String label = 'cambio en el plano',
}) async {
  final before = await db.shotFieldsBefore(shotId, fields);
  await db.updateShotFields(shotId, fields);
  if (before == null) return;
  history.record(
    EditStep(
      label: label,
      undo: () => db.updateShotFields(shotId, before),
      redo: () => db.updateShotFields(shotId, fields),
    ),
  );
}

/// Las imágenes de un plano en un momento dado: referencias, storyboard y
/// bocetos de planta. Los archivos no se borran del disco al quitarlos, así
/// que volver a una foto anterior es volver a enlazarlos.
class ShotImagesSnapshot {
  final int shotId;
  final String? reference;
  final String? storyboard;
  final String? planSketches;
  final List<ShotReference> references;

  const ShotImagesSnapshot({
    required this.shotId,
    required this.reference,
    required this.storyboard,
    required this.planSketches,
    required this.references,
  });

  static Future<ShotImagesSnapshot?> take(AppDatabase db, int shotId) async {
    final shot = await db.getShotById(shotId);
    if (shot == null) return null;
    return ShotImagesSnapshot(
      shotId: shotId,
      reference: shot.referenceImagePath,
      storyboard: shot.storyboardImagePath,
      planSketches: shot.cameraPlanImagePath,
      references: await db.watchReferencesForShot(shotId).first,
    );
  }

  bool sameAs(ShotImagesSnapshot other) =>
      reference == other.reference &&
      storyboard == other.storyboard &&
      planSketches == other.planSketches &&
      references.length == other.references.length &&
      [
        for (final (i, r) in references.indexed)
          r.id == other.references[i].id &&
              r.sortOrder == other.references[i].sortOrder,
      ].every((same) => same);

  Future<void> restore(AppDatabase db) async {
    await db.replaceShotReferences(shotId, references);
    await db.updateShotFields(
      shotId,
      ShotsCompanion(
        referenceImagePath: Value(reference),
        storyboardImagePath: Value(storyboard),
        cameraPlanImagePath: Value(planSketches),
      ),
    );
  }
}

/// Ejecuta [action] sobre las imágenes de un plano y apunta en el historial
/// el antes y el después.
Future<T> recordShotImages<T>(
  AppDatabase db,
  EditHistory history,
  int shotId,
  Future<T> Function() action, {
  String label = 'imágenes del plano',
}) async {
  final before = await ShotImagesSnapshot.take(db, shotId);
  final result = await action();
  final after = await ShotImagesSnapshot.take(db, shotId);
  if (before != null && after != null && !before.sameAs(after)) {
    history.record(
      EditStep(
        label: label,
        undo: () => before.restore(db),
        redo: () => after.restore(db),
      ),
    );
  }
  return result;
}
