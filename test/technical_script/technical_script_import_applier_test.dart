import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/utils/shot_reference_import.dart';
import 'package:iris_dp/features/technical_script/import/docx_technical_script_reader.dart';
import 'package:iris_dp/features/technical_script/import/technical_script_import_applier.dart';
import 'package:iris_dp/features/technical_script/import/technical_script_import_plan.dart';
import 'package:iris_dp/features/technical_script/technical_script_settings.dart';

ImportedImage image(String name) {
  final bytes = Uint8List.fromList(utf8.encode('imagen $name'));
  return ImportedImage(
    bytes: bytes,
    fileName: '$name.png',
    hash: sha1.convert(bytes).toString(),
  );
}

ImportedTechnicalScript kebab() => ImportedTechnicalScript(
  scenes: [
    ImportedScene(
      number: 7,
      intExt: 'EXT',
      location: 'RAMBLA DEL RAVAL',
      dayNight: 'NOCHE',
      shots: [
        ImportedShot(
          number: 1,
          framing: 'PA conjunto',
          lens: '35mm',
          characters: const ['ALI', 'SIMO'],
          references: [image('r1'), image('r2')],
          plans: [image('planta7')],
        ),
        ImportedShot(
          number: 2,
          framing: 'PMC de ALI',
          lens: '50mm',
          notes: 'comenzar desenfocado',
          plans: [image('planta7')],
        ),
      ],
    ),
    const ImportedScene(
      number: 13,
      suffix: 'B',
      intExt: 'INT',
      location: 'KEBAB KHALED',
      dayNight: 'NOCHE',
      shots: [ImportedShot(number: 1, framing: 'PD')],
    ),
    const ImportedScene(
      number: 13,
      suffix: 'A',
      intExt: 'INT',
      location: 'KEBAB KHALED',
      dayNight: 'NOCHE',
      shots: [ImportedShot(number: 1, framing: 'PG')],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late int projectId;
  late Directory docs;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('iris_import_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await db.close();
    docs.deleteSync(recursive: true);
  });

  Future<TechnicalScriptImportResult> run(
    ImportedTechnicalScript doc,
    ImportDecisions decisions,
  ) async {
    final plan = await prepareTechnicalScriptImport(
      db: db,
      projectId: projectId,
      document: doc,
    );
    return applyTechnicalScriptImport(
      db: db,
      projectId: projectId,
      plan: plan,
      decisions: decisions,
    );
  }

  Future<List<Scene>> scenes() => db.watchScenesForProject(projectId).first;
  Future<List<Shot>> shotsOf(Scene s) => db.watchShotsForScene(s.id).first;

  test('en un proyecto vacío lo crea todo, con 13A antes de 13B', () async {
    final result = await run(kebab(), ImportDecisions());
    expect(result.scenesAdded, 3);
    expect(result.shotsAdded, 4);
    expect(result.referencesAdded, 2);
    expect(result.plansAdded, 1);

    final all = await scenes();
    expect([for (final s in all) s.label], ['7', '13A', '13B']);
    expect(all.first.locationCanonical, 'EXT. RAMBLA DEL RAVAL - NOCHE');

    final seven = await shotsOf(all.first);
    expect(seven.first.lens, '35mm');
    final refs = await db.watchReferencesForShot(seven.first.id).first;
    expect(refs, hasLength(2));
    expect(seven.first.referenceImagePath, refs.first.imagePath);
    expect(refs.first.source, ShotReferenceSource.document);
    // La planta de la escena se guarda una vez y la comparten sus planos.
    expect(planSketchesOf(seven[0]), hasLength(1));
    expect(planSketchesOf(seven[0]), planSketchesOf(seven[1]));
  });

  test(
    'fusionar: rellena lo vacío, respeta lo nuestro y conserva lo demás',
    () async {
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 7,
          name: 'EXT. RAMBLA DEL RAVAL - NOCHE',
          locationCanonical: 'EXT. RAMBLA DEL RAVAL - NOCHE',
          locationPureName: 'RAMBLA DEL RAVAL',
          dayNight: const Value('NOCHE'),
        ),
      );
      final p1 = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: 1,
          lens: const Value('85mm'),
        ),
      );
      final p6 = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: 6,
        ),
      );
      final ours = await importShotReferenceImage(
        db: db,
        shot: (await db.getShotById(p1))!,
        sourceBytes: Uint8List.fromList([1, 2, 3]),
        source: ShotReferenceSource.manual,
      );

      await run(kebab(), ImportDecisions());

      final shot1 = (await db.getShotById(p1))!;
      expect(shot1.lens, '85mm', reason: 'en conflicto gana lo nuestro');
      expect(shot1.framing, 'PA conjunto', reason: 'lo vacío se rellena');
      expect(shot1.referenceImagePath, ours, reason: 'referencias detrás');
      expect(await db.watchReferencesForShot(p1).first, hasLength(3));
      expect(await db.getShotById(p6), isNotNull);
    },
  );

  test(
    'sobrescribir: el documento manda, sus referencias delante y borra lo que sobra',
    () async {
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 7,
          name: 'x',
          locationCanonical: 'EXT. RAMBLA DEL RAVAL - NOCHE',
          locationPureName: 'RAMBLA DEL RAVAL',
          dayNight: const Value('NOCHE'),
        ),
      );
      final p1 = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: 1,
          lens: const Value('85mm'),
        ),
      );
      final p6 = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: 6,
        ),
      );
      final orphanScene = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 16,
          name: 'AZOTEA',
          locationCanonical: 'EXT. AZOTEA - DÍA',
          locationPureName: 'AZOTEA',
        ),
      );
      final ours = await importShotReferenceImage(
        db: db,
        shot: (await db.getShotById(p1))!,
        sourceBytes: Uint8List.fromList([1, 2, 3]),
        source: ShotReferenceSource.manual,
      );

      final decisions = ImportDecisions(mode: ImportMode.overwrite);
      final result = await run(kebab(), decisions);

      final shot1 = (await db.getShotById(p1))!;
      expect(shot1.lens, '35mm');
      final refs = await db.watchReferencesForShot(p1).first;
      expect(refs.last.imagePath, ours, reason: 'la nuestra pasa a 2º plano');
      expect(shot1.referenceImagePath, refs.first.imagePath);
      expect(shot1.referenceImagePath, isNot(ours));
      expect(await db.getShotById(p6), isNull);
      expect(await db.getSceneById(orphanScene), isNull);
      expect(result.shotsDeleted, 1);
      expect(result.scenesDeleted, 1);
    },
  );

  test('reimportar el mismo documento no duplica imágenes', () async {
    await run(kebab(), ImportDecisions());
    final again = await run(kebab(), ImportDecisions());
    expect(again.referencesAdded, 0);
    expect(again.plansAdded, 0);
    expect(again.shotsAdded, 0);
    expect(again.scenesAdded, 0);
  });

  test('planta como boceto suelto y vista elegida por escena', () async {
    final decisions = ImportDecisions()
      ..setGeneral(
        (c) => c.copyWith(
          planDestination: PlanDestination.looseSketch,
          planView: PlanView.document,
        ),
      );
    final result = await run(kebab(), decisions);
    expect(result.looseSketches, 1);
    final setups = await db.getLightSetupsForProject(projectId);
    final sketch = setups.single;
    expect(sketch.status, 'boceto');
    expect(sketch.origin, 'documento');
    expect(File(sketch.sketchImagePath!).existsSync(), isTrue);

    final seven = await shotsOf((await scenes()).first);
    expect(planSketchesOf(seven.first), isEmpty);
    expect(
      ScriptPlanView.of(seven.first.cellStylesJson, ScriptPlanView.both),
      ScriptPlanView.sketch,
    );

    final again = await run(kebab(), decisions);
    expect(again.looseSketches, 0);
    expect(await db.getLightSetupsForProject(projectId), hasLength(1));
  });
}
