import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/features/camera_plan/plan_data.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  /// Deja que Drift responda y la pantalla se repinte.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('una escritura reconstruye una sola vez', (tester) async {
    late int projectId;
    late int shotId;
    await tester.runAsync(() async {
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 1,
          name: 'E',
          locationCanonical: 'Casa',
          locationPureName: 'Casa',
        ),
      );
      shotId = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: 1,
        ),
      );
    });

    var builds = 0;
    PlanProjectData? last;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: PlanDataBuilder(
            projectId: projectId,
            builder: (context, data) {
              builds++;
              last = data;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await settle(tester);
    final initial = builds;
    expect(initial, greaterThan(0));

    builds = 0;
    await tester.runAsync(
      () => (db.update(db.shots)..where((s) => s.id.equals(shotId))).write(
        const ShotsCompanion(framing: Value('PM')),
      ),
    );
    await settle(tester);
    expect(last!.shots.single.framing, 'PM');
    expect(builds, 1);

    // Un aviso de la tabla sin datos nuevos no reconstruye nada.
    builds = 0;
    await tester.runAsync(
      () async => db.markTablesUpdated({db.locationSites, db.shots}),
    );
    await settle(tester);
    expect(builds, 0);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
