import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/utils/media_storage.dart';
import 'visual_bible_model.dart';

/// Operaciones del moodboard (añadir, scouting, refs del guion).
abstract final class MoodboardHelpers {
  static Future<void> addManualImages({
    required AppDatabase db,
    required int projectId,
    int? bibleId,
    String? category,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;

    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      final ext = p.extension(path);
      final copied = await MediaStorage.copyFileIntoProject(
        projectId: projectId,
        sourcePath: path,
        subfolder: 'visual_bible/moodboard',
        fileName: 'mb_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      if (copied == null) continue;
      await db.insertMoodboardImage(
        MoodboardImagesCompanion.insert(
          projectId: projectId,
          bibleId: Value(bibleId),
          imagePath: copied,
          category: Value(category),
          source: const Value(MoodboardSource.manual),
        ),
      );
    }
  }

  static Future<int> importScoutingImages({
    required AppDatabase db,
    required int projectId,
    required int bibleId,
    required List<String> imagePaths,
    String? locationName,
  }) async {
    var count = 0;
    for (final path in imagePaths) {
      if (!File(path).existsSync()) continue;
      final ext = p.extension(path);
      final copied = await MediaStorage.copyFileIntoProject(
        projectId: projectId,
        sourcePath: path,
        subfolder: 'visual_bible/moodboard',
        fileName: 'scout_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      if (copied == null) continue;
      await db.insertMoodboardImage(
        MoodboardImagesCompanion.insert(
          projectId: projectId,
          bibleId: Value(bibleId),
          imagePath: copied,
          source: const Value(MoodboardSource.scouting),
          category: const Value(MoodboardCategory.location),
          linkedLocationName: Value(locationName),
        ),
      );
      count++;
    }
    return count;
  }

  static Future<int> syncScriptReferences({
    required AppDatabase db,
    required int projectId,
    int? bibleId,
  }) async {
    final shots = await db.getShotsWithReferencesForProject(projectId);
    final existing = await db.watchMoodboardImages(projectId).first;
    final existingPaths = existing.map((e) => e.imagePath).toSet();
    var count = 0;

    for (final shot in shots) {
      final path = shot.referenceImagePath;
      if (path == null || existingPaths.contains(path)) continue;
      if (!File(path).existsSync()) continue;
      await db.insertMoodboardImage(
        MoodboardImagesCompanion.insert(
          projectId: projectId,
          bibleId: Value(bibleId),
          imagePath: path,
          source: const Value(MoodboardSource.scriptReference),
          category: const Value(MoodboardCategory.reference),
          caption: Value('Plano ${shot.number}'),
        ),
      );
      count++;
    }
    return count;
  }

  static Future<List<({String path, String label})>> listScoutingCandidates(
    AppDatabase db,
    int projectId,
  ) async {
    final out = <({String path, String label})>[];

    final sets = await db.watchLocationsForProject(projectId).first;
    for (final set in sets) {
      final images = await db.watchImagesForLocation(set.id).first;
      for (final img in images) {
        if (File(img.imagePath).existsSync()) {
          out.add((path: img.imagePath, label: '${set.locationName} · scout'));
        }
      }
    }

    final sites = await db.watchSitesForProject(projectId).first;
    for (final site in sites) {
      final images = await db.watchImagesForSite(site.id).first;
      for (final img in images) {
        if (File(img.imagePath).existsSync()) {
          out.add((path: img.imagePath, label: '${site.name} · sitio'));
        }
      }
    }
    return out;
  }
}
