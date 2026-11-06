import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_editor.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/env_overrides.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/light_beam.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_data.dart';
import 'package:iris_dp/features/camera_plan/plan_palette.dart';
import 'package:iris_dp/features/camera_plan/plan_repair.dart';
import 'package:iris_dp/features/camera_plan/plan_set_summary.dart';
import 'package:iris_dp/features/camera_plan/light/street_lamp.dart';

/// EN: las luces de la localización son del entorno; cada set o plano las
/// puede apagar para sí.
void main() {
  late AppDatabase db;
  late FloorPlanRepository repo;
  late int projectId;
  late int siteId;

  PlanElement light(double x) => PlanElement(
    id: 0,
    type: ElementType.light,
    position: Offset(x, 100),
    lightType: LightType.fresnelMedium,
    props: {'intensity': 100},
  )..layer = PlanLayer.light;
  PlanElement camera() => PlanElement(
    id: 0,
    type: ElementType.camera,
    position: const Offset(10, 10),
  )..layer = PlanLayer.light;

  Future<PlanProjectData> loadData() async => PlanProjectData(
    sites: await db.select(db.locationSites).get(),
    sets: await db.select(db.locationBasePlans).get(),
    setups: await db.getLightSetupsForProject(projectId),
    scenes: await db.select(db.scenes).get(),
    shots: await db.getShotsForProject(projectId),
  );

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FloorPlanRepository(db);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'KK'));
    siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Bar'),
    );
  });
  tearDown(() => db.close());

  test('pasar las luces de un esquema sin planos al entorno', () async {
    final setup = await repo.createLightSetup(
      projectId: projectId,
      siteId: siteId,
    );
    await repo.saveElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setup.id,
      elements: [light(1), light(2), camera()],
    );

    final report = await PlanRepair(db).analyze(projectId);
    expect(report.envLights.single.lights, 2);

    await PlanRepair(db).moveLightsToEnvironment(setup.id);
    final env = await repo.loadElements(
      scope: FloorPlanScope.site,
      siteId: siteId,
    );
    expect(env.where((e) => e.type == ElementType.light), hasLength(2));
    final rest = await repo.loadElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setup.id,
    );
    expect(rest.map((e) => e.type), [ElementType.camera]);
    // La cámara sigue en su set: no va a la papelera.
    expect(await db.getLightSetupById(setup.id), isNotNull);
    expect((await PlanRepair(db).analyze(projectId)).envLights, isEmpty);
  });

  test('un esquema que solo tenía luces y sin planos va a la papelera', () async {
    final setup = await repo.createLightSetup(
      projectId: projectId,
      siteId: siteId,
    );
    await repo.saveElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setup.id,
      elements: [light(1)],
    );
    await PlanRepair(db).moveLightsToEnvironment(setup.id);
    final live = await db.getLightSetupsForProject(projectId);
    expect(live.where((s) => s.id == setup.id), isEmpty);
  });

  test('un esquema con planos no se propone', () async {
    final setup = await repo.createLightSetup(
      projectId: projectId,
      siteId: siteId,
    );
    await repo.saveElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setup.id,
      elements: [light(1)],
    );
    final scene = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'E1',
        locationCanonical: 'INT. BAR',
        locationPureName: 'BAR',
        locationSiteId: Value(siteId),
      ),
    );
    final shot = await db.insertShot(
      ShotsCompanion.insert(sceneId: scene, projectId: projectId, number: 1),
    );
    await db.assignLightSetupToShot(shot, setup.id);
    expect((await PlanRepair(db).analyze(projectId)).envLights, isEmpty);
  });

  test('el set ve las luces del entorno, apagadas para él, y el plano las '
      'puede apagar solo para sí', () async {
    final a = await repo.createLightSetup(projectId: projectId, siteId: siteId);
    final b = await repo.createLightSetup(projectId: projectId, siteId: siteId);
    final env = [light(1), light(2)];
    LightOverrides.ensureUids(env);
    await repo.saveElements(
      scope: FloorPlanScope.site,
      siteId: siteId,
      elements: env,
    );
    final uid = LightOverrides.uidOf(env.first)!;

    // El set B la apaga para él.
    final off = LightOverrides.clone(env.first)
      ..props[LightBeam.offKey] = true;
    await db.setLightSetupEnvOverrides(b.id, EnvOverrides.encode({uid: off}));

    // Un plano del set A la apaga solo para él.
    final scene = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'E1',
        locationCanonical: 'INT. BAR',
        locationPureName: 'BAR',
        locationSiteId: Value(siteId),
      ),
    );
    final shot = await db.insertShot(
      ShotsCompanion.insert(sceneId: scene, projectId: projectId, number: 1),
    );
    final other = await db.insertShot(
      ShotsCompanion.insert(sceneId: scene, projectId: projectId, number: 2),
    );
    await db.assignLightSetupToShot(shot, a.id);
    await db.assignLightSetupToShot(other, a.id);
    await repo.saveLightOverrides(shot, {uid: off});

    final data = await loadData();
    final setupA = data.setup(a.id)!;
    final setupB = data.setup(b.id)!;

    expect(SetSummary.of(data, setupA).lights, 2);
    expect(SetSummary.of(data, setupA).environmentLights, 2);
    expect(SetSummary.of(data, setupA).lightText, startsWith('2 luces del entorno'));
    // En B una está apagada.
    expect(SetSummary.of(data, setupB).lights, 1);

    bool isOff(List<PlanElement> list) => LightBeam.of(
      list.firstWhere((e) => LightOverrides.uidOf(e) == uid),
    )!.off;
    final shots = data.shotsOfSetup(a.id);
    final one = shots.firstWhere((s) => s.id == shot);
    final two = shots.firstWhere((s) => s.id == other);
    expect(isOff(data.baseOfShot(one)), isTrue);
    expect(isOff(data.baseOfShot(two)), isFalse);
    expect(FloorPlanJson.decode((await db.getSiteById(siteId))!.floorPlanJson), hasLength(2));
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Widget host(Widget child) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('poner una luz en la localización la guarda en el entorno, '
      'sin crear ningún set', (tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      host(
        CameraPlanEditor.site(
          projectId: projectId,
          siteId: siteId,
          siteName: 'Bar',
        ),
      ),
    );
    await settle(tester);
    // Una farola: la luz más propia del entorno, y sin leer el catálogo.
    tester
        .widget<PlanLightBrowser>(find.byType(PlanLightBrowser).first)
        .onAddStreetLamp!(StreetLamp.styleArm);
    await settle(tester);

    final site = await tester.runAsync(() => db.getSiteById(siteId));
    final env = FloorPlanJson.decode(site!.floorPlanJson);
    expect(env.where((e) => e.type == ElementType.light), hasLength(1));
    final setups = await tester.runAsync(
      () => db.getLightSetupsForProject(projectId),
    );
    expect(setups, isEmpty);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('apagar una luz del entorno solo en un plano no cambia el '
      'entorno ni los demás planos', (tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late int shotId;
    late LightSetup setup;
    await tester.runAsync(() async {
      await db.updateSite(
        (await db.getSiteById(siteId))!.copyWith(
          floorPlanJson: const Value(
            '{"version":2,"elements":['
            '{"type":"light","x":300,"y":300,"rotation":90,'
            '"lightType":"hmi","cameraLetter":"A","cameraNumber":1,'
            '"pathPoints":[],"props":{"intensity":100,"uid":"key"}}]}',
          ),
        ),
      );
      setup = await repo.createLightSetup(projectId: projectId, siteId: siteId);
      // Otro set: si el cambio se colara, preguntaría a quién afecta.
      await repo.createLightSetup(projectId: projectId, siteId: siteId);
      final scene = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 1,
          name: 'E1',
          locationCanonical: 'INT. BAR',
          locationPureName: 'BAR',
          locationSiteId: Value(siteId),
        ),
      );
      shotId = await db.insertShot(
        ShotsCompanion.insert(sceneId: scene, projectId: projectId, number: 1),
      );
      await db.assignLightSetupToShot(shotId, setup.id);
    });
    await tester.pumpWidget(
      host(
        CameraPlanEditor.shot(
          projectId: projectId,
          shotId: shotId,
          shotLabel: 'Esc 1 · Plano 1',
        ),
      ),
    );
    await settle(tester);

    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is CameraPlanPainter,
    );
    await tester.tapAt(tester.getTopLeft(canvas.first) + const Offset(300, 300));
    await settle(tester);

    Finder switchOf(String label) => find.descendant(
      of: find
          .ancestor(of: find.text(label), matching: find.byType(Row))
          .first,
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(switchOf('Ajustar solo en este plano'));
    await tester.tap(switchOf('Ajustar solo en este plano'));
    await settle(tester);
    await tester.ensureVisible(switchOf('Encendida'));
    await tester.tap(switchOf('Encendida'));
    await settle(tester);

    // Sin preguntar: el entorno sigue encendido y el set no lo cambia.
    expect(find.byType(AlertDialog), findsNothing);
    final site = await tester.runAsync(() => db.getSiteById(siteId));
    expect(
      FloorPlanJson.decode(site!.floorPlanJson).single.props['off'],
      isNot(true),
    );
    final saved = await tester.runAsync(() => db.getLightSetupById(setup.id));
    expect(saved!.envOverridesJson, isNull);
    final shot = await tester.runAsync(
      () =>
          (db.select(db.shots)..where((s) => s.id.equals(shotId))).getSingle(),
    );
    expect(LightOverrides.decode(shot!.lightOverridesJson)['key']!.props['off'],
        isTrue);
    // Y así llega a quien pinta el plano.
    final layers = await tester.runAsync(() => repo.layersForShot(shot));
    expect(layers!.environment.single.props['off'], isTrue);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
