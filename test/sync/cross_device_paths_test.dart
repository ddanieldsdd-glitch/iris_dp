import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/media_slots.dart';
import 'package:iris_dp/core/sync/primary_reference_repair.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';

/// Rutas de otro equipo (`/Users/…` del Mac en el PC o el iPad): no deben
/// contar como cambios ni quedarse sin archivo.
void main() {
  group('referenceImages de la biblia', () {
    Map<String, dynamic> bundle(List<String> paths) => {
          'colorBlocks': [
            {
              'blockName': 'Noche',
              'dominantColors': '["#112233"]',
              'referenceImages': jsonEncode(paths),
            },
          ],
        };

    test('la misma imagen en otra ruta no cambia la huella', () {
      final mac = bundle(['/Users/d/iris/color_refs/a.png']);
      final pc = bundle([r'C:\Users\x\iris\color_refs\a.png']);
      expect(
        ProjectContentBundle.hashBundle(mac),
        ProjectContentBundle.hashBundle(pc),
      );
      // Una imagen más sí es un cambio.
      expect(
        ProjectContentBundle.hashBundle(mac),
        isNot(ProjectContentBundle.hashBundle(
          bundle(['/Users/d/a.png', '/Users/d/b.png']),
        )),
      );
    });

    test('referenceImages cuenta como ruta, como las demás', () {
      expect(ProjectContentBundle.isPathKey('referenceImages'), isTrue);
      expect(ProjectContentBundle.isPathKey('storyboardImagePath'), isTrue);
      expect(ProjectContentBundle.isPathKey('blockName'), isFalse);
    });

    test('los tres bloques tienen hueco de medios', () {
      final tables = {for (final s in kMediaSlots) s.table};
      expect(
        tables,
        containsAll([
          'visual_bible_color_blocks',
          'exposure_blocks',
          'visual_bible_location_refs',
        ]),
      );
    });
  });

  group('principal de un plano con ruta de otro equipo', () {
    late AppDatabase db;
    late int projectId;
    late int shotId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'p'));
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 1,
          name: 'INT. CASA - DÍA',
          locationCanonical: 'INT. CASA - DÍA',
          locationPureName: 'CASA',
        ),
      );
      shotId = await db.into(db.shots).insert(
            ShotsCompanion.insert(
              sceneId: sceneId,
              projectId: projectId,
              number: 1,
              referenceImagePath:
                  const Value('/Users/otro/no-existe/shot_1.jpg'),
            ),
          );
    });

    test('pasa a la primera referencia que sí está aquí', () async {
      final dir = Directory.systemTemp.createTempSync('iris_primary');
      addTearDown(() => dir.deleteSync(recursive: true));
      final second = (File('${dir.path}/b.jpg')..writeAsBytesSync([2])).path;
      final first = (File('${dir.path}/a.jpg')..writeAsBytesSync([1])).path;
      await db.into(db.shotReferences).insert(
            ShotReferencesCompanion.insert(
              shotId: shotId,
              imagePath: second,
              sortOrder: const Value(3),
            ),
          );
      await db.into(db.shotReferences).insert(
            ShotReferencesCompanion.insert(
              shotId: shotId,
              imagePath: first,
              sortOrder: const Value(0),
            ),
          );

      expect(await repairDuplicatePrimaryReferences(db, projectId), 1);
      final shot = await (db.select(db.shots)
            ..where((s) => s.id.equals(shotId)))
          .getSingle();
      expect(shot.referenceImagePath, first);
    });

    test('sin referencias aquí, no se toca', () async {
      expect(await repairDuplicatePrimaryReferences(db, projectId), 0);
      final shot = await (db.select(db.shots)
            ..where((s) => s.id.equals(shotId)))
          .getSingle();
      expect(shot.referenceImagePath, '/Users/otro/no-existe/shot_1.jpg');
    });
  });
}
