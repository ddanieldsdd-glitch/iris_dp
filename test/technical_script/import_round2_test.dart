import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/utils/image_fingerprint.dart';
import 'package:iris_dp/features/technical_script/import/docx_technical_script_reader.dart';
import 'package:iris_dp/features/technical_script/import/technical_script_import_history.dart';
import 'package:iris_dp/features/technical_script/import/technical_script_import_plan.dart';

class _TempDirs extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String root;
  _TempDirs(this.root);

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}

/// Una foto de prueba: un degradado con un cuadrado, a [width] de ancho.
Uint8List photo(int width, {bool other = false, int quality = 95}) {
  final h = width * 3 ~/ 4;
  final image = img.Image(width: width, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < width; x++) {
      final v = (x * 255 ~/ width);
      image.setPixelRgb(x, y, other ? 255 - v : v, (y * 255 ~/ h), 120);
    }
  }
  img.fillRect(
    image,
    x1: width ~/ 3,
    y1: h ~/ 3,
    x2: width ~/ 2,
    y2: h ~/ 2,
    color: img.ColorRgb8(250, 250, 250),
  );
  return img.encodeJpg(image, quality: quality);
}

void main() {
  test('la misma foto recomprimida y más pequeña se reconoce; otra no', () {
    final big = visualFingerprint(photo(1200))!;
    final small = visualFingerprint(photo(300, quality: 40))!;
    final different = visualFingerprint(photo(1200, other: true))!;
    expect(sameImage(big, small), isTrue);
    expect(sameImage(big, different), isFalse);

    final fromWord = ImportedImage(
      bytes: Uint8List(0),
      fileName: 'image1.jpeg',
      hash: 'otro-sha',
      visual: small,
    );
    expect(alreadyHaveImage({'sha-de-la-mia', 'v:$big'}, fromWord), isTrue);
    expect(alreadyHaveImage({'v:$different'}, fromWord), isFalse);
  });

  group('con base', () {
    late AppDatabase db;
    late int projectId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
    });

    tearDown(() => db.close());

    Future<Scene> scene(int number, String location, {String? suffix}) async {
      final id = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: number,
          numberSuffix: Value(suffix),
          name: location,
          locationCanonical: 'INT. $location - NOCHE',
          locationPureName: location,
          intExt: const Value('INT'),
          dayNight: const Value('NOCHE'),
        ),
      );
      return (await db.getSceneById(id))!;
    }

    test('13A es nuestra 13 (con letra) y 13B entra nueva, sin pegarse a '
        'otra escena del mismo sitio', () async {
      final s13 = await scene(13, 'KEBAB');
      final s15 = await scene(15, 'KEBAB');
      const doc = ImportedTechnicalScript(
        scenes: [
          ImportedScene(
            number: 13,
            suffix: 'A',
            intExt: 'INT',
            location: 'KEBAB',
            dayNight: 'NOCHE',
            shots: [],
          ),
          ImportedScene(
            number: 13,
            suffix: 'B',
            intExt: 'INT',
            location: 'KEBAB',
            dayNight: 'NOCHE',
            shots: [],
          ),
          ImportedScene(
            number: 15,
            intExt: 'INT',
            location: 'KEBAB',
            dayNight: 'NOCHE',
            shots: [],
          ),
        ],
      );
      final plan = buildTechnicalScriptImportPlan(
        document: doc,
        scenes: [s13, s15],
        shotsByScene: {s13.id: const [], s15.id: const []},
      );
      final byLabel = {
        for (final s in plan.scenes) s.imported?.label: s.existing?.id,
      };
      expect(byLabel['13A'], s13.id);
      expect(byLabel['13B'], isNull);
      expect(byLabel['15'], s15.id);
      final split = plan.scenes.first.headingDiffs.single;
      expect(split.field, 'label');
      expect(split.document, '13A');
    });

    test('quitar repetidas deja la de más calidad, y la copia vuelve atrás',
        () async {
      final dir = Directory.systemTemp.createTempSync('iris_dedupe');
      addTearDown(() => dir.deleteSync(recursive: true));
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TempDirs(dir.path);
      addTearDown(() => PathProviderPlatform.instance = previous);

      final s = await scene(4, 'BAR');
      final shotId = await db.insertShot(
        ShotsCompanion.insert(sceneId: s.id, projectId: projectId, number: 1),
      );
      String write(String name, Uint8List bytes) {
        final f = File('${dir.path}/$name')..writeAsBytesSync(bytes);
        return f.path;
      }

      final mine = write('mia.jpg', photo(1200));
      final word = write('word.jpg', photo(300, quality: 40));
      final other = write('otra.jpg', photo(800, other: true));
      for (final (path, source) in [
        (mine, 'manual'),
        (word, 'document'),
        (other, 'manual'),
      ]) {
        await db
            .into(db.shotReferences)
            .insert(
              ShotReferencesCompanion.insert(
                shotId: shotId,
                imagePath: path,
                source: Value(source),
              ),
            );
      }
      await db.updateShotFields(
        shotId,
        ShotsCompanion(referenceImagePath: Value(word)),
      );

      final before = await saveImportSnapshot(
        db,
        projectId,
        reason: 'Antes de quitar repetidas',
      );
      final removed = await removeDuplicateReferences(db, projectId);
      expect(removed, 1);
      var refs = await db.watchReferencesForShot(shotId).first;
      expect(refs.map((r) => r.imagePath).toSet(), {mine, other});
      expect((await db.getShotById(shotId))!.referenceImagePath, mine);

      await restoreImportSnapshot(db, projectId, before);
      final shot = (await db.getShotsForProject(projectId)).single;
      refs = await db.watchReferencesForShot(shot.id).first;
      expect(refs, hasLength(3));
      // Volver atrás también deja copia de lo que había.
      final copies = await listImportSnapshots(projectId);
      expect(copies.first.reason, 'Antes de volver atrás');
    });
  });
}
