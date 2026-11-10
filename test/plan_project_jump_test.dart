import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/plan_data.dart';
import 'package:iris_dp/features/camera_plan/plan_target.dart';
import 'package:iris_dp/features/camera_plan/project_jump.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late int projectId;

  Future<int> scene(int number, String name) => db.insertScene(
    ScenesCompanion.insert(
      projectId: projectId,
      number: number,
      name: name,
      locationCanonical: name,
      locationPureName: name,
      intExt: const Value('INT'),
      dayNight: const Value('DÍA'),
    ),
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
  });

  tearDown(() => db.close());

  test('busca sin acentos y pone primero lo que empieza igual', () async {
    await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Almacén'),
    );
    await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Gran almacén'),
    );
    final data = await PlanProjectData.load(db, projectId);
    final hits = projectJumpHits(data, 'ALMACEN');
    expect(hits.map((h) => h.title), ['Almacén', 'Gran almacén']);
    expect(hits.first.target.scope, FloorPlanScope.site);
  });

  test('una escena salta a su primer plano; sin planos no sale', () async {
    final withShots = await scene(1, 'Cocina');
    await scene(2, 'Patio');
    final shotId = await db.insertShot(
      ShotsCompanion.insert(projectId: projectId, sceneId: withShots, number: 1),
    );
    final data = await PlanProjectData.load(db, projectId);
    final scenes = projectJumpHits(
      data,
      'Escena',
    ).where((h) => h.icon == Icons.movie_outlined);
    expect(scenes.single.title, 'Escena 1');
    expect(scenes.single.target, PlanTarget.shot(shotId, ''));
  });

  testWidgets('⌘K abre la búsqueda y Enter salta al primer resultado', (
    tester,
  ) async {
    await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Bosque'),
    );
    PlanTarget? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: ProjectJumpShortcut(
            projectId: projectId,
            onPick: (t) => picked = t,
            child: const Scaffold(body: Text('pantalla')),
          ),
        ),
      ),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('project-jump-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('project-jump-field')),
      'bos',
    );
    await tester.pump();
    expect(find.text('Bosque'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(picked?.scope, FloorPlanScope.site);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
