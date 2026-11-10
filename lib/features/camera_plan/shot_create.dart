import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import '../../core/settings/app_prefs.dart';
import 'camera_links.dart';
import 'plan_prefs.dart';

/// Añade un plano al final de [scene]; [shots] son los que ya tiene. Salvo
/// que Ajustes diga lo contrario, nace como el anterior: mismo set, misma
/// lente y movimiento, y su cámara en el mismo sitio.
Future<int> createShotInScene(
  AppDatabase db,
  Scene scene,
  List<Shot> shots, {
  String? title,
}) async {
  Shot? last;
  for (final shot in shots) {
    if (last == null || shot.sortOrder >= last.sortOrder) last = shot;
  }
  final previous =
      AppPrefs.instance.get(
        PlanPrefs.newShotLikePrevious,
        projectId: scene.projectId,
      )
      ? last
      : null;
  final id = await db.insertShot(
    ShotsCompanion.insert(
      sceneId: scene.id,
      projectId: scene.projectId,
      number: shots.length + 1,
      sortOrder: Value((last?.sortOrder ?? -1) + 1),
      framing: Value(title == null || title.trim().isEmpty ? null : title),
      lens: Value(previous?.lens),
      movement: Value(previous?.movement),
      lightSetupId: Value(previous?.lightSetupId),
      locationBasePlanId: Value(previous?.locationBasePlanId),
    ),
  );
  if (previous != null) await CameraLinks(db).copyCameras(previous.id, id);
  return id;
}
