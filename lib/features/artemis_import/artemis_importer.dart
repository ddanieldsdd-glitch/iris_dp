import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import '../../core/utils/media_storage.dart';
import '../../core/utils/shot_reference_import.dart';
import '../visual_bible/moodboard_helpers.dart';
import '../visual_bible/visual_bible_model.dart';

/// A dónde va una foto de Artemis.
sealed class ArtemisDestination {
  const ArtemisDestination();

  Future<void> apply(AppDatabase db, int projectId, String path);
}

/// Referencia de un plano del guion técnico (no le quita la principal).
class ArtemisToShot extends ArtemisDestination {
  final Shot shot;
  const ArtemisToShot(this.shot);

  @override
  Future<void> apply(AppDatabase db, int projectId, String path) async {
    // La fila puede haber cambiado (p. ej. la principal) desde que se cargó.
    final fresh = await db.getShotById(shot.id) ?? shot;
    await importShotReferenceImage(
      db: db,
      shot: fresh,
      sourcePath: path,
      source: ShotReferenceSource.artemisCapture,
      keepPrimary: true,
    );
  }
}

/// Moodboard de la biblia, con su categoría.
class ArtemisToMoodboard extends ArtemisDestination {
  final String? category;
  final String? linkedLocationName;
  const ArtemisToMoodboard({this.category, this.linkedLocationName});

  @override
  Future<void> apply(AppDatabase db, int projectId, String path) async {
    final bible = await db.ensureVisualBibleForProject(projectId);
    await MoodboardHelpers.addManualImages(
      db: db,
      projectId: projectId,
      bibleId: bible.id,
      category: category,
      linkedLocationName: linkedLocationName,
      sourcePaths: [path],
      source: MoodboardSource.artemisCapture,
    );
  }
}

/// Galería de la localización y, si se quiere, su moodboard (la sección de
/// localizaciones de la biblia agrupa por nombre).
class ArtemisToSite extends ArtemisDestination {
  final LocationSite site;
  final bool alsoMoodboard;
  const ArtemisToSite(this.site, {this.alsoMoodboard = true});

  @override
  Future<void> apply(AppDatabase db, int projectId, String path) async {
    final existing = await db.watchImagesForSite(site.id).first;
    final stored = await MediaStorage.copySiteImage(
      projectId: projectId,
      siteId: site.id,
      sourcePath: path,
    );
    await db.insertSiteImage(
      SiteImagesCompanion.insert(
        siteId: site.id,
        imagePath: stored,
        sortOrder: Value(existing.length),
      ),
    );
    if (alsoMoodboard) {
      await ArtemisToMoodboard(
        category: MoodboardCategory.location,
        linkedLocationName: site.name,
      ).apply(db, projectId, path);
    }
  }
}
