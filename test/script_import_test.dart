import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/script_import/normalized_scene.dart';
import 'package:iris_dp/features/script_import/script_character_extractor.dart';
import 'package:iris_dp/features/script_import/script_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScriptParser', () {
    test('detects standard sluglines', () {
      const script = '''
FADE IN:

INT. COCINA DE MARÍA - DÍA

María prepara el desayuno.

EXT. CALLE DEL PUEBLO - NOCHE

Un coche pasa a toda velocidad.

INT/EXT. COCHE - ATARDECER

Gala mira por la ventanilla.
''';

      final sluglines = ScriptParser.parse(script);

      expect(sluglines.length, 3);
      expect(sluglines[0].number, 1);
      expect(sluglines[0].intExt, 'INT');
      expect(sluglines[0].location, 'COCINA DE MARÍA');
      expect(sluglines[0].dayNight, 'DÍA');
      expect(sluglines[1].intExt, 'EXT');
      expect(sluglines[2].intExt, 'INT/EXT');
      expect(sluglines[2].dayNight, 'ATARDECER');
    });

    test('detects comma and INTERIOR formats', () {
      const script = '''
INTERIOR. SALÓN - NOCHE
EXT. CALLE, DÍA
INT - COCINA - AMANECER
''';

      final sluglines = ScriptParser.parse(script);
      expect(sluglines.length, 3);
      expect(sluglines[0].intExt, 'INT');
      expect(sluglines[1].intExt, 'EXT');
      expect(sluglines[2].location, 'COCINA');
    });

    test('detects sluglines with trailing scene numbers (Final Draft PDF)', () {
      const script = '''
EXT. POLÍGONO, PARKING CAMIONES - ATARDECER 1 1
EXT. CAMPO, MIRADOR - ATARDECER 2 2
EXT. POLÍGONO, PARKING CAMIONES - NOCHE 8 8
EXT. POLÍGONO, PARKING CAMIONES - NOCHE 9 9
EXT. POLÍGONO, PARKING CAMIONES - CONTINUOUS 13 13
INT. POLÍGONO, GARITA VIGILANTE - CONTINUOUS 18 18
''';

      final sluglines = ScriptParser.parse(script);
      expect(sluglines.length, 6);
      expect(sluglines[0].scriptNumber, 1);
      expect(sluglines[0].location, 'POLÍGONO, PARKING CAMIONES');
      expect(sluglines[2].scriptNumber, 8);
      expect(sluglines[3].scriptNumber, 9);
      expect(sluglines[4].dayNight, 'CONTINUO');
      expect(sluglines[5].intExt, 'INT');
      expect(sluglines[5].scriptNumber, 18);
    });

    test('allows repeated locations as separate scenes', () {
      const script = '''
EXT. PARKING - NOCHE 1 1
EXT. PARKING - NOCHE 2 2
EXT. PARKING - NOCHE 3 3
''';

      final sluglines = ScriptParser.parse(script);
      expect(sluglines.length, 3);
      expect(sluglines[0].scriptNumber, 1);
      expect(sluglines[2].scriptNumber, 3);
    });

    test('reads scene numbers on following lines (PDF extraction)', () {
      const script = '''
EXT. POLÍGONO, PARKING CAMIONES - ATARDECER
1
1
ADIL corre.

EXT. CAMPO, MIRADOR - ATARDECER
2
2
Karim espera.
''';

      final sluglines = ScriptParser.parse(script);
      expect(sluglines.length, 2);
      expect(sluglines[0].scriptNumber, 1);
      expect(sluglines[1].scriptNumber, 2);
    });
  });

  group('NormalizedScene merge', () {
    test('mergeWithRaw keeps all parser scenes when fewer normalized entries', () {
      final raw = [
        const RawSlugline(
          number: 1,
          intExt: 'INT',
          location: 'COCINA',
          dayNight: 'DÍA',
          rawLine: 'INT. COCINA - DÍA',
          startIndex: 0,
        ),
        const RawSlugline(
          number: 2,
          intExt: 'EXT',
          location: 'CALLE',
          dayNight: 'NOCHE',
          rawLine: 'EXT. CALLE - NOCHE',
          startIndex: 10,
        ),
      ];

      final ai = [
        const NormalizedScene(
          number: 1,
          intExt: 'INT',
          dayNight: 'DÍA',
          location: 'COCINA',
          shootSet: 'CASA',
          locationSite: 'CASA',
        ),
      ];

      final merged = NormalizedScene.mergeWithRaw(raw, ai);
      expect(merged.length, 2);
      expect(merged[0].shootSet, 'CASA');
      expect(merged[1].location, 'CALLE');
    });
  });

  group('ScriptCharacterExtractor', () {
    test('detecta personajes entre sluglines consecutivas', () {
      const script = '''
INT. COCINA DE MARÍA - DÍA

MARÍA
(preocupada)
¿Dónde está Gala?

GALA
Aquí estoy.

EXT. CALLE DEL PUEBLO - NOCHE

KARIM
Corre.
''';

      final sluglines = ScriptParser.parse(script);
      final characters = ScriptCharacterExtractor.extractBySlugStartIndex(
        script,
        sluglines,
      );

      expect(sluglines.length, 2);
      expect(characters[sluglines[0].startIndex], ['GALA', 'MARÍA']);
      expect(characters[sluglines[1].startIndex], ['KARIM']);
    });
  });

  group('Scenes and shots persistence', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('insert scene and editable shot fields persist', () async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Test'),
      );

      await db.insertScene(ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'INT SALÓN DÍA',
        locationCanonical: 'INT. SALÓN - DÍA',
        locationPureName: 'CASA DE MARÍA',
        intExt: const Value('INT'),
        dayNight: const Value('DÍA'),
        sortOrder: const Value(1),
      ));

      final scenes = await db.watchScenesForProject(projectId).first;
      expect(scenes.length, 1);
      expect(scenes.first.locationPureName, 'CASA DE MARÍA');

      final sceneId = scenes.first.id;
      await db.insertShot(ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: 1,
        sortOrder: const Value(0),
      ));

      var shots = await db.watchShotsForScene(sceneId).first;
      expect(shots.length, 1);

      await db.updateShot(shots.first.copyWith(
        framing: const Value('PD'),
        lens: const Value('50mm'),
        movement: const Value('TRÍPODE'),
        angle: const Value('Normal'),
        fStop: const Value('T2.8'),
        action: const Value('Entra por la puerta'),
        notes: const Value('Cuidado con el foco'),
      ));

      shots = await db.watchShotsForScene(sceneId).first;
      expect(shots.first.framing, 'PD');
      expect(shots.first.lens, '50mm');
      expect(shots.first.movement, 'TRÍPODE');
      expect(shots.first.angle, 'Normal');
      expect(shots.first.fStop, 'T2.8');
      expect(shots.first.action, 'Entra por la puerta');
      expect(shots.first.notes, 'Cuidado con el foco');
    });

    test('replaceScenesForProject replaces order and clears shots', () async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Order Test'),
      );

      final sceneId = await db.insertScene(ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena vieja',
        locationCanonical: 'INT. VIEJA - DÍA',
        locationPureName: 'VIEJA',
        sortOrder: const Value(1),
      ));

      await db.insertShot(ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: 1,
        sortOrder: const Value(0),
      ));

      await db.replaceScenesForProject(projectId, [
        ScenesCompanion.insert(
          projectId: projectId,
          number: 1,
          name: 'EXT CALLE NOCHE',
          locationCanonical: 'EXT. CALLE - NOCHE',
          locationPureName: 'CALLE',
          sortOrder: const Value(1),
        ),
        ScenesCompanion.insert(
          projectId: projectId,
          number: 2,
          name: 'INT CASA DÍA',
          locationCanonical: 'INT. CASA - DÍA',
          locationPureName: 'CASA',
          sortOrder: const Value(2),
        ),
      ]);

      final scenes = await db.watchScenesForProject(projectId).first;
      expect(scenes.length, 2);
      expect(scenes[0].name, 'EXT CALLE NOCHE');
      expect(scenes[0].number, 1);
      expect(scenes[0].sortOrder, 1);
      expect(scenes[1].name, 'INT CASA DÍA');
      expect(scenes[1].number, 2);

      final shots = await db.getShotsForProject(projectId);
      expect(shots, isEmpty);
    });
  });
}
