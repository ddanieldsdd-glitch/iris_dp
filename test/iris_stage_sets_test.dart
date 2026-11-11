import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/plan_data.dart';
import 'package:iris_dp/features/iris_stage/iris_stage_sets.dart';

/// ED.4: IRIS Stage enseña los sets del proyecto por localización para
/// abrir su 3D.
void main() {
  late AppDatabase db;
  late FloorPlanRepository repo;
  late int projectId, siteId, setId;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FloorPlanRepository(db);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'KK'));
    siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Bar'),
    );
    setId = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: 'Bar',
      ),
    );
  });
  tearDown(() => db.close());

  test('sets por localización y, al final, los sueltos', () async {
    final a = await repo.createLightSetup(
      projectId: projectId,
      setId: setId,
      name: 'Barra',
    );
    final free = await repo.createLightSetup(
      projectId: projectId,
      name: 'Prueba',
    );
    final data = await PlanProjectData.load(db, projectId);
    final groups = IrisStageSets.groups(data);
    expect(groups.map((g) => g.$1), ['Bar', 'Sin localización']);
    expect(groups.first.$2.map((s) => s.id), [a.id]);
    expect(groups.last.$2.map((s) => s.id), [free.id]);
  });

  testWidgets('cada set es un botón para abrir su 3D', (tester) async {
    await repo.createLightSetup(
      projectId: projectId,
      setId: setId,
      name: 'Barra',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: IrisStageSets(projectId: projectId)),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('El 3D de cada set'), findsOneWidget);
    expect(find.text('Barra · 0 planos'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  });
}
