import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/light_crew/light_crew_screen.dart';

import '../support/snapshot.dart';
import 'package:iris_dp/core/cloud/project_role.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/light_crew/light_crew_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int projectId;
  late int sceneId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Caseta'),
    );
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 4,
        name: 'Feria',
        locationCanonical: 'EXT. FERIA - NOCHE',
        locationPureName: 'FERIA',
      ),
    );
  });

  tearDown(() => db.close());

  PlanElement light(double x, LightType type) => PlanElement(
    id: -1,
    type: ElementType.light,
    position: Offset(x, 200),
    lightType: type,
  );

  Future<LightSetup> setupWith(String name, List<PlanElement> lights) async {
    final repo = FloorPlanRepository(db);
    final setup = await repo.createLightSetup(projectId: projectId, name: name);
    await repo.saveElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setup.id,
      elements: lights,
    );
    return setup;
  }

  Future<int> shot(int number, int? setupId) => db.insertShot(
    ShotsCompanion.insert(
      sceneId: sceneId,
      projectId: projectId,
      number: number,
      sortOrder: Value(number - 1),
      lightSetupId: Value(setupId),
    ),
  );

  Future<void> day(String name, String date, List<int> shots) async {
    final id = await db.insertShootDocument(
      ShootDocumentsCompanion.insert(
        projectId: projectId,
        name: name,
        kind: const Value('technical_day'),
        shootDate: Value(date),
      ),
    );
    for (final (i, s) in shots.indexed) {
      await db.insertShootDocumentBlock(
        ShootDocumentBlocksCompanion.insert(
          documentId: id,
          blockType: 'shot',
          shotId: Value(s),
          sortOrder: Value(i),
        ),
      );
    }
  }

  test('por jornada: sus esquemas, focos, vatios y el más cargado', () async {
    final noche = await setupWith('Noche', [
      light(100, LightType.hmi),
      light(300, LightType.fresnelSmall),
    ]);
    final tarde = await setupWith('Tarde', [light(150, LightType.led1x1)]);
    final vacio = await setupWith('Vacío', []);
    final a = await shot(1, noche.id);
    final b = await shot(2, tarde.id);
    final c = await shot(3, vacio.id);
    final d = await shot(4, noche.id);
    await day('Jornada 1', '2026-12-01', [a, b, c]);
    await day('Jornada 2', '2026-12-02', [d]);

    final data = (await LightCrewData.load(db, projectId))!;
    expect(data.days.map((d) => d.title), ['Jornada 1', 'Jornada 2']);

    final first = data.days.first;
    // El esquema sin focos no sale.
    expect(first.schemes.map((s) => s.name), ['Noche', 'Tarde']);
    final night = first.schemes.first;
    expect(night.lightCount, 2);
    expect(night.watts, greaterThan(0));
    expect(night.use.scenes, ['4']);
    expect(first.heaviest!.watts, night.watts);

    expect(data.days.last.schemes.single.name, 'Noche');
  });

  test('sin jornadas, todo el guion', () async {
    final setup = await setupWith('Única', [light(0, LightType.par)]);
    await shot(1, setup.id);
    final data = (await LightCrewData.load(db, projectId))!;
    expect(data.days.single.title, 'Todo el guion');
    expect(data.days.single.schemes.single.lightCount, 1);
  });

  test('los eléctricos solo consultan', () {
    for (final r in [ProjectRole.bestBoy, ProjectRole.electrician]) {
      expect(r.canEdit, isFalse);
      expect(r.isLightCrew, isTrue);
    }
    expect(ProjectRole.gaffer.canEdit, isTrue);
    expect(ProjectRole.gaffer.isLightCrew, isFalse);
    expect(ProjectRole.viewer.isLightCrew, isFalse);
    expect(ProjectRole.shortLabel('electrician'), 'eléctrico');
  });

  testWidgets('la vista de eléctricos cabe en un iPhone', (tester) async {
    await loadSnapshotFonts();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late int a;
    LightCrewData? data;
    await tester.runAsync(() async {
      final noche = await setupWith('Noche', [
        light(100, LightType.hmi),
        light(300, LightType.fresnelSmall),
      ]);
      a = await shot(1, noche.id);
      await day('Jornada 1 · Feria de abril, caseta grande', '2026-12-01', [a]);
      await day('Jornada 2', '2026-12-02', [a]);
      data = await LightCrewData.load(db, projectId);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: LightCrewScreen(
            projectId: projectId,
            projectName: 'Caseta',
            preloaded: data,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Noche'), findsWidgets);
    expect(find.text('Alzado y perfil'), findsOneWidget);
    expect(find.text('Hoja de luz'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await saveSnapshot(tester, 'electricos_iphone');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
