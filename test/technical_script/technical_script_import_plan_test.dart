import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/technical_script/import/docx_technical_script_reader.dart';
import 'package:iris_dp/features/technical_script/import/technical_script_import_plan.dart';

ImportedImage image(String hash) =>
    ImportedImage(bytes: Uint8List(0), fileName: '$hash.png', hash: hash);

void main() {
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
        locationCanonical: 'EXT. $location - NOCHE',
        locationPureName: location,
        intExt: const Value('EXT'),
        dayNight: const Value('NOCHE'),
      ),
    );
    return (await db.getSceneById(id))!;
  }

  Future<Shot> shot(
    Scene scene,
    int number, {
    String? lens,
    String? notes,
  }) async {
    final id = await db.insertShot(
      ShotsCompanion.insert(
        sceneId: scene.id,
        projectId: projectId,
        number: number,
        lens: Value(lens),
        notes: Value(notes),
      ),
    );
    return (await db.getShotById(id))!;
  }

  test(
    'empareja por número y letra; separa nuevo, cambios y solo en la app',
    () async {
      final s1 = await scene(1, 'CALLE RAVAL');
      final s1p1 = await shot(s1, 1, lens: '35mm');
      await shot(s1, 2, lens: '50mm');
      final s16 = await scene(16, 'AZOTEA');
      const doc = ImportedTechnicalScript(
        scenes: [
          ImportedScene(
            number: 1,
            intExt: 'EXT',
            location: 'CALLE RAVAL',
            dayNight: 'NOCHE',
            shots: [
              ImportedShot(number: 1, lens: '50mm', notes: 'CAMERA CAR'),
              ImportedShot(number: 3, framing: 'PD'),
            ],
          ),
          ImportedScene(
            number: 13,
            suffix: 'A',
            intExt: 'INT',
            location: 'KEBAB',
            dayNight: 'NOCHE',
            shots: [ImportedShot(number: 1)],
          ),
        ],
      );

      final plan = buildTechnicalScriptImportPlan(
        document: doc,
        scenes: [s1, s16],
        shotsByScene: {
          s1.id: await db.watchShotsForScene(s1.id).first,
          s16.id: const [],
        },
      );

      expect([for (final s in plan.scenes) s.label], ['1', '13A', '16']);
      expect(
        [for (final s in plan.scenes) s.status],
        [MatchStatus.changed, MatchStatus.added, MatchStatus.onlyInApp],
      );
      final shots = plan.scenes.first.shots;
      expect(
        [for (final s in shots) s.status],
        [MatchStatus.changed, MatchStatus.onlyInApp, MatchStatus.added],
      );
      final diffs = {for (final d in shots.first.diffs) d.field: d};
      expect(diffs['lens']!.ours, '35mm');
      expect(diffs['lens']!.document, '50mm');
      expect(diffs['lens']!.fillsEmpty, isFalse);
      expect(diffs['notes']!.fillsEmpty, isTrue);
      expect(shots.first.existing!.id, s1p1.id);

      expect(plan.newScenes, 1);
      expect(plan.newShots, 1);
      expect(plan.changedShots, 1);
      expect(plan.onlyInAppShots, 1);
      expect(plan.onlyInAppScenes, 1);
      expect(plan.isFresh, isFalse);
    },
  );

  test('sin número que coincida, empareja por la cabecera', () async {
    final s5 = await scene(5, 'RAMBLA DEL RAVAL');
    final plan = buildTechnicalScriptImportPlan(
      document: const ImportedTechnicalScript(
        scenes: [
          ImportedScene(
            number: 7,
            intExt: 'EXT',
            location: 'Rambla del Raval',
            dayNight: 'NOCHE',
            shots: [],
          ),
        ],
      ),
      scenes: [s5],
      shotsByScene: {s5.id: const []},
    );
    expect(plan.scenes.single.existing?.id, s5.id);
  });

  test('las imágenes que el plano ya tiene no se cuentan de nuevo', () async {
    final s1 = await scene(1, 'CALLE');
    final p1 = await shot(s1, 1);
    final doc = ImportedTechnicalScript(
      scenes: [
        ImportedScene(
          number: 1,
          intExt: 'EXT',
          location: 'CALLE',
          dayNight: 'NOCHE',
          shots: [
            ImportedShot(
              number: 1,
              references: [image('a'), image('b')],
              plans: [image('p')],
            ),
          ],
        ),
      ],
    );
    final plan = buildTechnicalScriptImportPlan(
      document: doc,
      scenes: [s1],
      shotsByScene: {
        s1.id: [p1],
      },
      referenceHashes: {
        p1.id: {'a'},
      },
      planHashes: {
        p1.id: {'p'},
      },
    );
    final match = plan.scenes.single.shots.single;
    expect([for (final r in match.newReferences) r.hash], ['b']);
    expect(match.newPlan, isNull);
  });

  test('las decisiones se heredan: todo → escena → plano', () {
    final d = ImportDecisions();
    expect(d.forShot('s', 'p').text, TextChoice.ours);
    expect(d.forShot('s', 'p').deleteOnlyInApp, isFalse);

    d.mode = ImportMode.overwrite;
    expect(d.forShot('s', 'p').text, TextChoice.document);
    expect(d.forShot('s', 'p').references, ReferenceMode.front);
    expect(d.forShot('s', 'p').deleteOnlyInApp, isTrue);

    d.setGeneral((c) => c.copyWith(references: ReferenceMode.back));
    d.setScene('s', (c) => c.copyWith(planView: PlanView.ours));
    d.setShot('p', (c) => c.copyWith(text: TextChoice.ours));
    final r = d.forShot('s', 'p');
    expect(r.references, ReferenceMode.back);
    expect(r.planView, PlanView.ours);
    expect(r.text, TextChoice.ours);
    expect(d.forShot('otra', 'q').planView, PlanView.both);

    final img = image('x');
    expect(d.includesReference('p', img), isTrue);
    d.toggleReference('p', img);
    expect(d.includesReference('p', img), isFalse);
  });
}
