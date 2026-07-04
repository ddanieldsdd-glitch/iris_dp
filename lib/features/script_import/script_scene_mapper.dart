import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import '../../core/utils/scene_format.dart';
import 'claude_script_service.dart';

/// Convierte una escena persistida al modelo del espacio de trabajo de importación.
NormalizedScene normalizedSceneFromDb(
  Scene scene, {
  String? locationSiteName,
}) {
  return NormalizedScene(
    number: scene.number,
    intExt: scene.intExt,
    dayNight: scene.dayNight,
    location: locationFromCanonical(scene.locationCanonical),
    shootSet: scene.locationPureName,
    locationSite: locationSiteName ?? scene.locationPureName,
    description: scene.description,
    locationColor: scene.locationColor,
  );
}

ScenesCompanion workspaceSceneToCompanion({
  required int projectId,
  required NormalizedScene scene,
  required int sortOrder,
  int? sourceStartIndex,
}) {
  return ScenesCompanion.insert(
    projectId: projectId,
    number: sortOrder,
    name: formatSceneDefaultName(
      intExt: scene.intExt,
      dayNight: scene.dayNight,
      location: scene.location,
    ),
    locationCanonical: '${scene.intExt}. ${scene.location} - ${scene.dayNight}',
    locationPureName: scene.shootSet,
    intExt: Value(scene.intExt),
    dayNight: Value(scene.dayNight),
    locationColor: Value(scene.locationColor),
    description: Value(scene.description),
    sourceStartIndex: Value(sourceStartIndex),
    sortOrder: Value(sortOrder),
  );
}
