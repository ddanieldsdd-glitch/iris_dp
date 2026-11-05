import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_editor.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/env_overrides.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/group_light.dart';

/// SG.3: desde un set, el entorno y la luz del grupo preguntan a quién
/// afecta el cambio.
void main() {
  late AppDatabase db;
  late int projectId;
  late int siteId;
  late LightSetup setA;
  late LightSetup setB;
  late int groupId;

  String el(String type, double x, double y, String uid) =>
      '{"type":"$type","x":$x,"y":$y,"rotation":0,"label":"$type",'
      '"lightType":${type == 'light' ? '"fresnel"' : 'null'},'
      '"pathPoints":[],"props":{"uid":"$uid"}}';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> seed(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'KK'));
      siteId = await db.insertSite(
        LocationSitesCompanion.insert(
          projectId: projectId,
          name: 'Calle',
          floorPlanJson: Value(
            '{"version":2,"elements":[${el('wall', 300, 300, 'w1')}]}',
          ),
        ),
      );
      final repo = FloorPlanRepository(db);
      setA = await repo.createLightSetup(projectId: projectId, siteId: siteId);
      setB = await repo.createLightSetup(projectId: projectId, siteId: siteId);
      groupId = await db.insertSetGroup(
        SetGroupsCompanion.insert(
          projectId: projectId,
          locationSiteId: Value(siteId),
          name: 'Fondo fachada',
          planJson: Value(
            '{"version":2,"elements":[${el('light', 600, 300, 'g1')}]}',
          ),
        ),
      );
      await db.assignLightSetupToGroup(setA.id, groupId);
      await db.assignLightSetupToGroup(setB.id, groupId);
    });
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openSetA(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: CameraPlanEditor.lightSetup(
            projectId: projectId,
            lightSetupId: setA.id,
            setupName: setA.name,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> drag(WidgetTester tester, Offset at, Offset by) async {
    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is CameraPlanPainter,
    );
    await tester.dragFrom(tester.getTopLeft(canvas) + at, by);
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('mover una pared solo en este set no toca la localización', (
    tester,
  ) async {
    await seed(tester);
    await openSetA(tester);

    await drag(tester, const Offset(300, 300), const Offset(100, 50));
    expect(find.textContaining('¿A quién afecta?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('env-scope-thisSet')));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await settle(tester);

    final site = (await tester.runAsync(() => db.getSiteById(siteId)))!;
    expect(
      FloorPlanJson.decode(site.floorPlanJson).single.position,
      const Offset(300, 300),
    );
    final a = (await tester.runAsync(() => db.getLightSetupById(setA.id)))!;
    final b = (await tester.runAsync(() => db.getLightSetupById(setB.id)))!;
    final own = EnvOverrides.decode(a.envOverridesJson);
    expect(own.keys, ['w1']);
    expect(own['w1']!.position.dx, greaterThan(350));
    expect(b.envOverridesJson, isNull);

    // Las capas de A lo ven movido; las de B, no.
    final repo = FloorPlanRepository(db);
    final layersA = (await tester.runAsync(
      () => repo.inheritedLayers(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: setA.id,
      ),
    ))!;
    final layersB = (await tester.runAsync(
      () => repo.inheritedLayers(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: setB.id,
      ),
    ))!;
    expect(layersA.environment.single.position.dx, greaterThan(350));
    expect(layersB.environment.single.position, const Offset(300, 300));

    // Se recuerda: otro cambio no vuelve a preguntar.
    expect(
      find.textContaining('Entorno · solo cambia en este set'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('a toda la localización cambia el entorno definitivo', (
    tester,
  ) async {
    await seed(tester);
    await openSetA(tester);

    await drag(tester, const Offset(300, 300), const Offset(100, 50));
    await tester.tap(find.text('Aplicar'));
    await settle(tester);

    final site = (await tester.runAsync(() => db.getSiteById(siteId)))!;
    expect(
      FloorPlanJson.decode(site.floorPlanJson).single.position.dx,
      greaterThan(350),
    );
    final a = (await tester.runAsync(() => db.getLightSetupById(setA.id)))!;
    expect(a.envOverridesJson, isNull);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('deshacer el cambio lo deja como estaba', (tester) async {
    await seed(tester);
    await openSetA(tester);

    await drag(tester, const Offset(300, 300), const Offset(100, 50));
    await tester.tap(find.text('Deshacer el cambio'));
    await settle(tester);

    final site = (await tester.runAsync(() => db.getSiteById(siteId)))!;
    expect(
      FloorPlanJson.decode(site.floorPlanJson).single.position,
      const Offset(300, 300),
    );
    final a = (await tester.runAsync(() => db.getLightSetupById(setA.id)))!;
    expect(a.envOverridesJson, isNull);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('una luz del grupo: todo el grupo o solo este set', (
    tester,
  ) async {
    await seed(tester);
    await openSetA(tester);

    // Todo el grupo: la luz se mueve en el grupo, la ven A y B.
    await drag(tester, const Offset(600, 300), const Offset(0, 80));
    expect(find.textContaining('Es una luz del grupo'), findsOneWidget);
    // Que vuelva a preguntar la próxima vez.
    await tester.tap(
      find.text('No volver a preguntar mientras edito esta planta'),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('group-light-all')));
    await settle(tester);
    var group = (await tester.runAsync(
      () async => (await db.getSetGroupById(groupId))!,
    ))!;
    final moved = FloorPlanJson.decode(group.planJson).single;
    expect(moved.position.dy, greaterThan(340));

    // Solo este set: A se queda con su versión; el grupo y B, no cambian.
    await drag(tester, moved.position, const Offset(120, 0));
    expect(find.textContaining('Es una luz del grupo'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('group-light-this')));
    await settle(tester);
    group = (await tester.runAsync(
      () async => (await db.getSetGroupById(groupId))!,
    ))!;
    expect(
      FloorPlanJson.decode(group.planJson).single.position,
      moved.position,
    );
    final a = (await tester.runAsync(() => db.getLightSetupById(setA.id)))!;
    final b = (await tester.runAsync(() => db.getLightSetupById(setB.id)))!;
    final ownA = FloorPlanJson.decode(a.planJson);
    expect(ownA.single.props['uid'], 'g1');
    expect(ownA.single.position.dx, greaterThan(650));
    // A ya no ve la del grupo (lleva la suya); B, sí.
    expect(GroupLight.visible(group.planJson, a.planJson), isEmpty);
    expect(GroupLight.visible(group.planJson, b.planJson), hasLength(1));
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
