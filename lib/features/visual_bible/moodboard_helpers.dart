import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/utils/clipboard_image_reader.dart';
import '../../core/utils/media_storage.dart';
import 'moodboard_association.dart';
import 'widgets/moodboard_drag.dart';
import 'visual_bible_model.dart';

/// Operaciones del moodboard (añadir, scouting, refs del guion).
abstract final class MoodboardHelpers {
  static Future<void> addImageFromBytes({
    required AppDatabase db,
    required int projectId,
    int? bibleId,
    required Uint8List bytes,
    String? category,
    String extension = '.png',
  }) async {
    final copied = await MediaStorage.writeProjectFileBytes(
      projectId: projectId,
      subfolder: 'visual_bible/moodboard',
      bytes: bytes,
      fileName: 'paste_${DateTime.now().millisecondsSinceEpoch}$extension',
    );
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

  static Future<void> addImageFromBytesAssigned({
    required AppDatabase db,
    required int projectId,
    int? bibleId,
    required Uint8List bytes,
    required List<String> assignedSections,
    String? linkedLocationName,
    int? linkedLocationBasePlanId,
    String extension = '.png',
  }) async {
    final copied = await MediaStorage.writeProjectFileBytes(
      projectId: projectId,
      subfolder: 'visual_bible/moodboard',
      bytes: bytes,
      fileName: 'paste_${DateTime.now().millisecondsSinceEpoch}$extension',
    );
    final category =
        MoodboardAssociation.deriveCategoryFromSections(assignedSections);
    await db.insertMoodboardImage(
      MoodboardImagesCompanion.insert(
        projectId: projectId,
        bibleId: Value(bibleId),
        imagePath: copied,
        source: const Value(MoodboardSource.manual),
        category: Value(category),
        assignedSections: assignedSections.isEmpty
            ? const Value(null)
            : Value(jsonEncode(assignedSections)),
        linkedLocationName: Value(linkedLocationName),
        linkedLocationBasePlanId: Value(linkedLocationBasePlanId),
      ),
    );
  }

  static Future<ClipboardImageReadStatus> addFromClipboard({
    required AppDatabase db,
    required int projectId,
    int? bibleId,
    String? category,
  }) async {
    final result = await ClipboardImageReader.read();
    final payload = result.payload;
    if (result.status != ClipboardImageReadStatus.success || payload == null) {
      return result.status;
    }
    await addImageFromBytes(
      db: db,
      projectId: projectId,
      bibleId: bibleId,
      bytes: payload.bytes,
      category: category,
      extension: payload.extension,
    );
    return ClipboardImageReadStatus.success;
  }

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

  static Future<void> linkMoodboardToSection({
    required AppDatabase db,
    required int projectId,
    required MoodboardDragPayload payload,
    required String sectionId,
    String? locationName,
    int? locationBasePlanId,
  }) async {
    final sections = <String>[sectionId];
    if (locationName != null) sections.add(BibleSectionId.location);

    if (payload.moodboardImageId != null) {
      final rows = await db.watchMoodboardImages(projectId).first;
      MoodboardImage? row;
      for (final candidate in rows) {
        if (candidate.id == payload.moodboardImageId) {
          row = candidate;
          break;
        }
      }
      if (row != null) {
        final current =
            MoodboardAssociation.decodeSections(row.assignedSections);
        final merged = {...current, ...sections}.toList();
        await db.updateMoodboardImage(
          row.copyWith(
            assignedSections: Value(jsonEncode(merged)),
            category: Value(
              MoodboardAssociation.deriveCategoryFromSections(merged),
            ),
            linkedLocationName: locationName != null
                ? Value(locationName)
                : const Value.absent(),
            linkedLocationBasePlanId: locationBasePlanId != null
                ? Value(locationBasePlanId)
                : const Value.absent(),
          ),
        );
        return;
      }
    }

    await db.insertMoodboardImage(
      MoodboardImagesCompanion.insert(
        projectId: projectId,
        imagePath: payload.imagePath,
        source: const Value(MoodboardSource.manual),
        category: Value(
          MoodboardAssociation.deriveCategoryFromSections(sections),
        ),
        assignedSections: Value(jsonEncode(sections)),
        linkedLocationName: Value(locationName),
        linkedLocationBasePlanId: Value(locationBasePlanId),
      ),
    );
  }
}
