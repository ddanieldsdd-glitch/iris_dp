import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/sync/live_editing.dart';
import 'package:iris_dp/core/sync/realtime_hub.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_editor.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/technical_script/technical_script_screen.dart';

/// El bloqueo de edición compartida fuera del guion técnico: la planta (en
/// cualquiera de sus niveles) y la ficha de escena.
void main() {
  late AppDatabase db;
  late LiveEditing live;
  late List<String?> published;
  late int projectId;
  late int setId;
  late int sceneId;
  late int shotId;
  late LightSetup setup;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    published = [];
    live = LiveEditing(
      installId: 'mac',
      publishEditing: (key, _) => published.add(key),
      publishTyping: (_, _, _) {},
    );
  });

  tearDown(() => db.close());

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
    final siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Casa'),
    );
    setId = await db.insertSetUnderSite(
      projectId: projectId,
      siteId: siteId,
      name: 'Cocina',
    );
    setup = await FloorPlanRepository(
      db,
    ).createLightSetup(projectId: projectId, setId: setId);
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 2,
        name: 'Escena 2',
        locationCanonical: 'INT. COCINA - NOCHE',
        locationPureName: 'COCINA',
        locationSiteId: Value(siteId),
        locationId: Value(setId),
      ),
    );
    shotId = await db.insertShot(
      ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: 1,
        lightSetupId: Value(setup.id),
      ),
    );
  });

  Widget host(Widget child) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      liveEditingProvider.overrideWith((ref) => live),
    ],
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  PeerEditing ipad(String key) => PeerEditing(
    installId: 'ipad',
    device: 'iPad',
    shotUid: key,
    since: DateTime.utc(2026, 10, 18),
  );

  testWidgets('una planta de esquema que edita el iPad no se toca aquí, y al '
      'soltarla se vuelve a poder', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(tester);

    await tester.pumpWidget(
      host(
        CameraPlanEditor.lightSetup(
          projectId: projectId,
          lightSetupId: setup.id,
          setupName: setup.name,
        ),
      ),
    );
    await settle(tester);
    // Aquí se anuncia que se edita el esquema.
    expect(published.last, LiveKey.lightSetup(setup.uid!));
    expect(find.textContaining('Lo está editando'), findsNothing);

    live.setPeers([ipad(LiveKey.lightSetup(setup.uid!))]);
    await tester.pump();
    expect(find.textContaining('Lo está editando iPad'), findsOneWidget);

    live.setPeers(const []);
    await tester.pump();
    expect(find.textContaining('Lo está editando'), findsNothing);

    // Al salir de la planta se suelta al momento.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
    expect(live.myShotUid, isNull);
    expect(published.last, isNull);
  });

  testWidgets('desde un plano, el esquema que el iPad edita desde antes '
      'también lo bloquea', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(tester);

    await tester.pumpWidget(
      host(
        CameraPlanEditor.shot(
          projectId: projectId,
          shotId: shotId,
          shotLabel: 'Esc 2 · Plano 1',
        ),
      ),
    );
    await settle(tester);
    live.setPeers([ipad(LiveKey.lightSetup(setup.uid!))]);
    await tester.pump();
    expect(find.textContaining('Lo está editando iPad'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('al salir del guion técnico el plano queda libre al momento', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await seed(tester);

    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);
    live.focusShot('algo');
    expect(live.myShotUid, 'algo');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
    expect(live.myShotUid, isNull);
  });
}
