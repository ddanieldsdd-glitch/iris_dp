import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/artemis_import/artemis_importer.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';

class _TempDocs extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String root;
  _TempDocs(this.root);

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

// PNG de 1 × 1.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Destinos de una foto de Artemis: plano, moodboard o localización (su
/// galería y su moodboard). La pantalla, en `artemis_import_screen_test`.
void main() {
  late AppDatabase db;
  late Directory docs;
  late int projectId;
  late int sceneId;
  late List<int> shotIds;
  late LocationSite site;
  late List<String> photos;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    docs = Directory.systemTemp.createTempSync('iris_artemis');
    PathProviderPlatform.instance = _TempDocs(docs.path);
    photos = [
      for (var i = 0; i < 3; i++)
        (File('${docs.path}/artemis_$i.png')..writeAsBytesSync(_png)).path,
    ];

    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Artemis'),
    );
    final siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'BOSQUE'),
    );
    site = (await db.watchSitesForProject(projectId).first)
        .firstWhere((s) => s.id == siteId);
    sceneId = await db.insertScene(ScenesCompanion.insert(
      projectId: projectId,
      number: 1,
      name: 'Claro',
      locationCanonical: 'EXT. BOSQUE - DÍA',
      locationPureName: 'BOSQUE',
    ));
    shotIds = [
      for (var n = 1; n <= 2; n++)
        await db.insertShot(ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: n,
          lens: Value('${n * 25}mm'),
          sortOrder: Value(n),
        )),
    ];
  });

  tearDown(() async {
    await db.close();
    docs.deleteSync(recursive: true);
  });

  group('destinos', () {
    test('plano: referencia de Artemis y principal si no tenía', () async {
      final shot = (await db.getShotById(shotIds.first))!;
      await ArtemisToShot(shot).apply(db, projectId, photos.first);
      final refs = await db.watchReferencesForShot(shot.id).first;
      expect(refs, hasLength(1));
      expect(refs.single.source, 'artemis_capture');
      expect((await db.getShotById(shot.id))!.referenceImagePath, isNotNull);
    });

    test('moodboard: con su categoría y marcada como Artemis', () async {
      await const ArtemisToMoodboard(category: MoodboardCategory.lighting)
          .apply(db, projectId, photos.first);
      final images = await db.watchMoodboardImages(projectId).first;
      expect(images, hasLength(1));
      expect(images.single.source, MoodboardSource.artemisCapture);
      expect(images.single.category, MoodboardCategory.lighting);
    });

    test('localización: galería y su moodboard', () async {
      await ArtemisToSite(site).apply(db, projectId, photos.first);
      expect(await db.watchImagesForSite(site.id).first, hasLength(1));
      final images = await db.watchMoodboardImages(projectId).first;
      expect(images.single.linkedLocationName, 'BOSQUE');
      expect(images.single.category, MoodboardCategory.location);

      await ArtemisToSite(site, alsoMoodboard: false)
          .apply(db, projectId, photos[1]);
      expect(await db.watchImagesForSite(site.id).first, hasLength(2));
      expect(await db.watchMoodboardImages(projectId).first, hasLength(1));
    });
  });
}
