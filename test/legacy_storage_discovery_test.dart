import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/storage/legacy_storage_discovery.dart';

void main() {
  group('StorageLocationSnapshot', () {
    test('richnessScore prioriza más proyectos e imágenes', () {
      const rich = StorageLocationSnapshot(
        label: 'rich',
        databasePath: '/a.db',
        documentsPath: '/docs',
        projectCount: 2,
        assetFileCount: 50,
        moodboardCount: 30,
        projectNames: ['A', 'B'],
      );
      const poor = StorageLocationSnapshot(
        label: 'poor',
        databasePath: '/b.db',
        documentsPath: '/docs2',
        projectCount: 1,
        assetFileCount: 0,
        moodboardCount: 0,
        projectNames: ['A'],
      );

      expect(rich.richnessScore, greaterThan(poor.richnessScore));
    });
  });
}
