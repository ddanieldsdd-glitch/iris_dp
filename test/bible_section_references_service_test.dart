import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/visual_bible/services/bible_section_references_service.dart';

void main() {
  test('sorted puts hero (sortOrder 0) first', () {
    final images = [
      MoodboardImage(
        id: 1,
        projectId: 1,
        imagePath: 'a.png',
        source: 'manual',
        sortOrder: 3,
      ),
      MoodboardImage(
        id: 2,
        projectId: 1,
        imagePath: 'b.png',
        source: 'manual',
        sortOrder: 0,
      ),
    ];
    final sorted = BibleSectionReferencesService.sorted(images);
    expect(sorted.first.id, 2);
  });
}
