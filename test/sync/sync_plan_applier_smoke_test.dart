import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/sync_plan.dart';
import 'package:iris_dp/core/sync/sync_plan_applier.dart';
import 'package:supabase/supabase.dart';

void main() {
  late AppDatabase db;
  late SupabaseClient client;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    client = SupabaseClient(
      'http://127.0.0.1:9',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSJ9.test',
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('apply ignora ítems marcados como skip', () async {
    final applier = SyncPlanApplier(db, client);
    final plan = SyncPlan(
      items: [
        SyncPlanItem(
          action: SyncPlanAction.deleteLocal,
          title: 'Omitido',
          description: 'No debe borrarse',
          localProjectId: 999,
          choice: SyncResolutionChoice.skip,
        ),
      ],
    );

    final result = await applier.apply(plan, 'workspace-smoke');

    expect(result.pushed, 0);
    expect(result.pulled, 0);
    expect(result.deleted, 0);
  });

  test('apply deleteLocal borra el proyecto sin llamar a la nube', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Borrar local'),
    );
    final applier = SyncPlanApplier(db, client);
    final plan = SyncPlan(
      items: [
        SyncPlanItem(
          action: SyncPlanAction.deleteLocal,
          title: 'Borrar local',
          description: 'Eliminar solo en SQLite',
          localProjectId: projectId,
        ),
      ],
    );

    final result = await applier.apply(plan, 'workspace-smoke');
    final remaining = await db.getProject(projectId);

    expect(result.deleted, 1);
    expect(result.pushed, 0);
    expect(result.pulled, 0);
    expect(remaining, isNull);
  });
}
