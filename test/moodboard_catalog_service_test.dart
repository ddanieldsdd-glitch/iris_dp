import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/visual_bible/moodboard_catalog_service.dart';
import 'package:iris_dp/features/visual_bible/moodboard_reference_meta.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int projectId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'lala'));
  });

  group('MoodboardCatalogService', () {
    test('options merges defaults with custom without duplicates', () async {
      await MoodboardCatalogService.addCustomOption(
        db: db,
        projectId: projectId,
        key: MoodboardCatalogKey.lightingLook,
        value: 'Neón urbano',
      );
      await MoodboardCatalogService.addCustomOption(
        db: db,
        projectId: projectId,
        key: MoodboardCatalogKey.lightingLook,
        value: 'Suave',
      );

      final catalog = await MoodboardCatalogService.loadForProject(
        db,
        projectId,
      );
      final options = MoodboardCatalogService.options(
        MoodboardCatalogKey.lightingLook,
        catalog,
      );

      expect(options, contains('Suave'));
      expect(options, contains('Neón urbano'));
      expect(options.where((o) => o.toLowerCase() == 'suave').length, 1);
    });

    test('el catálogo guardado en las preferencias pasa a la base', () async {
      SharedPreferences.setMockInitialValues({
        'iris_moodboard_catalog_$projectId': '{"lightingLook":["Neón urbano"]}',
      });

      final catalog = await MoodboardCatalogService.loadForProject(
        db,
        projectId,
      );

      expect(catalog.customFor(MoodboardCatalogKey.lightingLook), [
        'Neón urbano',
      ]);
      expect((await db.getProject(projectId))!.moodboardCatalogJson, isNotNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('iris_moodboard_catalog_$projectId'), isNull);
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
