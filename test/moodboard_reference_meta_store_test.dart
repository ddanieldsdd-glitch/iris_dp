import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/visual_bible/moodboard_reference_meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int projectId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Meta store migration'),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> insertImage({String path = '/tmp/moodboard_test.jpg'}) {
    return db.insertMoodboardImage(
      MoodboardImagesCompanion.insert(
        projectId: projectId,
        imagePath: path,
      ),
    );
  }

  group('MoodboardReferenceMetaStore', () {
    test('load migra lazy desde SharedPreferences a Drift', () async {
      final imageId = await insertImage();
      const legacyMeta = MoodboardReferenceMeta(
        tags: ['neon', 'night'],
        aspectRatio: '2.39:1',
        lightingLook: 'Dura',
      );
      final prefs = await SharedPreferences.getInstance();
      final legacyRaw = jsonEncode(legacyMeta.toJson());
      await prefs.setString('moodboard_ref_meta_$imageId', legacyRaw);

      final loaded = await MoodboardReferenceMetaStore.load(db, imageId);

      expect(loaded.tags, ['neon', 'night']);
      expect(loaded.aspectRatio, '2.39:1');
      expect(loaded.lightingLook, 'Dura');

      final fromDb = await db.getMoodboardImageMeta(imageId);
      expect(fromDb, isNotNull);
      expect(fromDb!['tags'], ['neon', 'night']);
      expect(fromDb['aspectRatio'], '2.39:1');

      // Backup legacy intacto (no se borra tras migrar).
      expect(prefs.getString('moodboard_ref_meta_$imageId'), legacyRaw);
    });

    test('load lee desde Drift sin depender de SharedPreferences', () async {
      final imageId = await insertImage();
      await db.saveMoodboardImageMeta(imageId, {
        'tags': ['drift-only'],
        'colorMood': 'Fría',
      });

      final loaded = await MoodboardReferenceMetaStore.load(db, imageId);

      expect(loaded.tags, ['drift-only']);
      expect(loaded.colorMood, 'Fría');
    });

    test('save escribe en Drift; vacío deja columna null', () async {
      final imageId = await insertImage();
      const meta = MoodboardReferenceMeta(
        tags: ['save-test'],
        technicalNotes: 'Nota técnica',
      );

      await MoodboardReferenceMetaStore.save(db, imageId, meta);

      final fromDb = await db.getMoodboardImageMeta(imageId);
      expect(fromDb?['tags'], ['save-test']);
      expect(fromDb?['technicalNotes'], 'Nota técnica');

      await MoodboardReferenceMetaStore.save(
        db,
        imageId,
        const MoodboardReferenceMeta(),
      );

      expect(await db.getMoodboardImageMeta(imageId), isNull);
    });

    test('loadMany migra lazy imágenes sin metaJson en Drift', () async {
      final imageWithLegacy = await insertImage(path: '/tmp/a.jpg');
      final imageWithDb = await insertImage(path: '/tmp/b.jpg');
      final imageEmpty = await insertImage(path: '/tmp/c.jpg');

      const legacyMeta = MoodboardReferenceMeta(
        tags: ['batch-legacy'],
        timeOfDay: 'NOCHE',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'moodboard_ref_meta_$imageWithLegacy',
        jsonEncode(legacyMeta.toJson()),
      );

      await db.saveMoodboardImageMeta(imageWithDb, {
        'tags': ['already-in-db'],
      });

      final map = await MoodboardReferenceMetaStore.loadMany(
        db,
        [imageWithLegacy, imageWithDb, imageEmpty],
      );

      expect(map.length, 2);
      expect(map[imageWithLegacy]?.tags, ['batch-legacy']);
      expect(map[imageWithLegacy]?.timeOfDay, 'NOCHE');
      expect(map[imageWithDb]?.tags, ['already-in-db']);
      expect(map.containsKey(imageEmpty), isFalse);

      expect(
        await db.getMoodboardImageMeta(imageWithLegacy),
        isNotNull,
      );
    });
  });
}
