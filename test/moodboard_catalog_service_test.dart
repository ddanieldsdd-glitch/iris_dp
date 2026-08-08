import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/moodboard_catalog_service.dart';
import 'package:iris_dp/features/visual_bible/moodboard_reference_meta.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MoodboardCatalogService', () {
    test('options merges defaults with custom without duplicates', () async {
      await MoodboardCatalogService.addCustomOption(
        projectId: 1,
        key: MoodboardCatalogKey.lightingLook,
        value: 'Neón urbano',
      );
      await MoodboardCatalogService.addCustomOption(
        projectId: 1,
        key: MoodboardCatalogKey.lightingLook,
        value: 'Suave',
      );

      final catalog = await MoodboardCatalogService.loadForProject(1);
      final options = MoodboardCatalogService.options(
        MoodboardCatalogKey.lightingLook,
        catalog,
      );

      expect(options, contains('Suave'));
      expect(options, contains('Neón urbano'));
      expect(options.where((o) => o.toLowerCase() == 'suave').length, 1);
    });

    test('suggestSections maps catalog meta to bible screens', () {
      const meta = MoodboardReferenceMeta(
        lightingLook: 'Dura',
        composition: 'Centrado',
        colorMood: 'Fría',
        locationKind: 'INT',
      );

      final suggested = MoodboardCatalogService.suggestSections(
        meta: meta,
        linkedLocationName: 'Apartamento',
      );

      expect(suggested, contains(BibleSectionId.location));
      expect(suggested, contains(BibleSectionId.lighting));
      expect(suggested, contains(BibleSectionId.concept));
      expect(suggested, contains(BibleSectionId.colorImage));
    });
  });
}
