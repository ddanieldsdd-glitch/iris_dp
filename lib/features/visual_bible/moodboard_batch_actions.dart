import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/utils/media_storage.dart';
import 'moodboard_association.dart';
import 'visual_bible_model.dart';

/// Operaciones en lote sobre imágenes del moodboard.
abstract final class MoodboardBatchActions {
  static Future<int> assignSections({
    required AppDatabase db,
    required List<MoodboardImage> images,
    required List<String> sections,
    bool mergeWithExisting = false,
  }) async {
    var count = 0;
    for (final img in images) {
      final current = MoodboardAssociation.decodeSections(img.assignedSections);
      final next = mergeWithExisting
          ? {...current, ...sections}.toList()
          : List<String>.from(sections);
      final category =
          MoodboardAssociation.deriveCategoryFromSections(next);
      var linkedPlanId = img.linkedLocationBasePlanId;
      var linkedName = img.linkedLocationName;
      if (!next.contains(BibleSectionId.location)) {
        linkedPlanId = null;
        linkedName = null;
      }
      await db.updateMoodboardImage(
        img.copyWith(
          assignedSections:
              next.isEmpty ? const Value(null) : Value(jsonEncode(next)),
          category: Value(category),
          linkedLocationBasePlanId: Value(linkedPlanId),
          linkedLocationName: Value(linkedName),
        ),
      );
      count++;
    }
    return count;
  }

  static Future<int> assignLocation({
    required AppDatabase db,
    required List<MoodboardImage> images,
    required LocationBasePlan? set,
  }) async {
    var count = 0;
    for (final img in images) {
      final current = MoodboardAssociation.decodeSections(img.assignedSections);
      final next = current.contains(BibleSectionId.location)
          ? current
          : [...current, BibleSectionId.location];
      final category =
          MoodboardAssociation.deriveCategoryFromSections(next);
      await db.updateMoodboardImage(
        img.copyWith(
          assignedSections: Value(jsonEncode(next)),
          category: Value(category),
          linkedLocationBasePlanId: Value(set?.id),
          linkedLocationName: Value(set?.locationName),
        ),
      );
      count++;
    }
    return count;
  }

  static Future<int> assignGroup({
    required AppDatabase db,
    required List<MoodboardImage> images,
    required int? groupId,
  }) async {
    var count = 0;
    for (final img in images) {
      await db.updateMoodboardImage(
        img.copyWith(groupId: Value(groupId)),
      );
      count++;
    }
    return count;
  }

  static Future<MoodboardGroup?> createGroupAndAssign({
    required AppDatabase db,
    required int projectId,
    required String category,
    required String name,
    required List<MoodboardImage> images,
  }) async {
    final groupId = await db.insertMoodboardGroup(
      MoodboardGroupsCompanion.insert(
        projectId: projectId,
        category: category,
        name: name,
      ),
    );
    await assignGroup(db: db, images: images, groupId: groupId);
    return db
        .watchMoodboardGroups(projectId, category: category)
        .first
        .then((groups) => groups.where((g) => g.id == groupId).firstOrNull);
  }

  static Future<int> deleteImages({
    required AppDatabase db,
    required List<MoodboardImage> images,
  }) async {
    for (final img in images) {
      await db.deleteMoodboardImage(img.id);
    }
    return images.length;
  }

  static String? resolveGroupCategory({
    required List<MoodboardImage> images,
    String? activeCategoryFilter,
  }) {
    if (activeCategoryFilter != null &&
        activeCategoryFilter != MoodboardAssociation.technicalFilter &&
        activeCategoryFilter != '__unassigned__') {
      return activeCategoryFilter;
    }
    for (final img in images) {
      final sections =
          MoodboardAssociation.decodeSections(img.assignedSections);
      final derived =
          MoodboardAssociation.deriveCategoryFromSections(sections);
      if (derived != null) return derived;
    }
    return imgCategoryFallback(images);
  }

  static String? imgCategoryFallback(List<MoodboardImage> images) {
    for (final img in images) {
      if (img.category != null) return img.category;
    }
    return null;
  }

  static Future<bool> setProjectCover({
    required AppDatabase db,
    required int projectId,
    required String sourceImagePath,
  }) async {
    final project = await db.getProject(projectId);
    if (project == null) return false;

    final ext = p.extension(sourceImagePath).isEmpty
        ? '.jpg'
        : p.extension(sourceImagePath);
    final copied = await MediaStorage.copyFileIntoProject(
      projectId: projectId,
      sourcePath: sourceImagePath,
      subfolder: 'cover',
      fileName: 'cover_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    if (copied == null) return false;

    await db.updateProject(
      project.copyWith(
        coverImagePath: Value(copied),
        updatedAt: DateTime.now(),
      ),
    );
    return true;
  }
}
