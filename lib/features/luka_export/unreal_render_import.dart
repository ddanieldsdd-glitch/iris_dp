import '../../core/database/app_database.dart';
import '../../core/utils/shot_reference_import.dart';

/// Resultado de importar renders Unreal en lote.
class UnrealRenderImportResult {
  final int imported;
  final int skipped;
  final List<String> errors;

  const UnrealRenderImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
  });
}

final _filenamePattern = RegExp(r'iris_dp_s(\d+)_p(\d+)', caseSensitive: false);

/// Importa frames PNG nombrados como `iris_dp_s{sceneId}_p{shotNumber}.png`.
Future<UnrealRenderImportResult> importUnrealRenderBatch({
  required AppDatabase db,
  required int projectId,
  required List<String> filePaths,
}) async {
  var imported = 0;
  var skipped = 0;
  final errors = <String>[];

  for (final path in filePaths) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final match = _filenamePattern.firstMatch(name);
    if (match == null) {
      skipped++;
      errors.add('$name: nombre no reconocido (usa iris_dp_s{id}_p{n}.png)');
      continue;
    }

    final sceneId = int.tryParse(match.group(1)!);
    final shotNumber = int.tryParse(match.group(2)!);
    if (sceneId == null || shotNumber == null) {
      skipped++;
      continue;
    }

    final scene = await db.getSceneById(sceneId);
    if (scene == null || scene.projectId != projectId) {
      skipped++;
      errors.add('$name: escena $sceneId no pertenece al proyecto');
      continue;
    }

    final shot = await db.getShotBySceneAndNumber(sceneId, shotNumber);
    if (shot == null) {
      skipped++;
      errors.add('$name: plano $shotNumber no encontrado en escena $sceneId');
      continue;
    }

    try {
      await importShotReferenceImage(
        db: db,
        shot: shot,
        sourcePath: path,
        source: ShotReferenceSource.unrealRender,
      );
      imported++;
    } catch (e) {
      skipped++;
      errors.add('$name: $e');
    }
  }

  return UnrealRenderImportResult(
    imported: imported,
    skipped: skipped,
    errors: errors,
  );
}
