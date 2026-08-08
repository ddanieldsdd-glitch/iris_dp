import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../shared/visual_bible/moodboard_association.dart';

/// Operaciones sobre referencias moodboard asignadas a una sección de la biblia.
abstract final class BibleSectionReferencesService {
  static List<MoodboardImage> sorted(List<MoodboardImage> images) {
    final copy = List<MoodboardImage>.from(images);
    copy.sort((a, b) {
      final heroA = _isHero(a) ? 0 : 1;
      final heroB = _isHero(b) ? 0 : 1;
      if (heroA != heroB) return heroA.compareTo(heroB);
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return copy;
  }

  static bool _isHero(MoodboardImage image) => image.sortOrder <= 0;

  static Future<void> reorder(
    AppDatabase db,
    List<MoodboardImage> images,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) return;
    final sorted = sortedImages(images);
    final item = sorted.removeAt(oldIndex);
    sorted.insert(newIndex.clamp(0, sorted.length), item);
    for (var i = 0; i < sorted.length; i++) {
      final hero = _isHero(sorted[i]);
      await db.updateMoodboardImage(
        sorted[i].copyWith(sortOrder: hero ? 0 : i + 1),
      );
    }
  }

  static List<MoodboardImage> sortedImages(List<MoodboardImage> images) =>
      sorted(images);

  static Future<void> setHero(AppDatabase db, MoodboardImage image) async {
    final rows = await db.watchMoodboardImages(image.projectId).first;
    final sections = MoodboardAssociation.decodeSections(image.assignedSections);
    final peers = rows.where((row) {
      if (row.id == image.id) return false;
      final assigned = MoodboardAssociation.decodeSections(row.assignedSections);
      return sections.any(assigned.contains);
    });
    for (final peer in peers) {
      if (_isHero(peer)) {
        await db.updateMoodboardImage(peer.copyWith(sortOrder: peer.sortOrder + 1));
      }
    }
    await db.updateMoodboardImage(image.copyWith(sortOrder: 0));
  }

  static Future<void> removeFromSection(
    AppDatabase db,
    MoodboardImage image,
    String sectionId,
  ) async {
    final sections = MoodboardAssociation.decodeSections(image.assignedSections);
    if (!sections.contains(sectionId)) return;
    final next = sections.where((s) => s != sectionId).toList();
    if (next.isEmpty && image.bibleId == null) {
      await db.deleteMoodboardImage(image.id);
      return;
    }
    await db.updateMoodboardImage(
      image.copyWith(
        assignedSections: next.isEmpty
            ? const Value(null)
            : Value(jsonEncode(next)),
        category: Value(MoodboardAssociation.deriveCategoryFromSections(next)),
      ),
    );
  }

  static Future<void> deleteImage(AppDatabase db, MoodboardImage image) async {
    await db.deleteMoodboardImage(image.id);
  }
}
