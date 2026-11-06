import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/shoot_documents/shoot_plan.dart';
import 'package:iris_dp/shared/history/edit_history.dart';

void main() {
  late AppDatabase db;
  late int projectId;
  late Scene sceneA;
  late Scene sceneB;
  late List<Shot> shotsA;
  late EditHistory history;
  late ShootPlanService service;

  Future<ShootPlan> plan() async => ShootPlan.from(
    documents: await db.getShootDocumentsForProject(projectId),
    blocks: await db.getShootDayBlocks(projectId),
    scenes: await db.watchScenesForProject(projectId).first,
    shots: await db.getShotsForProject(projectId),
  );

  List<int?> shotsOfDay(ShootPlan p, int dayId) => [
    for (final b in p.blocksByDay[dayId]!) b.shotId,
  ];

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Prueba'),
    );
    Future<Scene> scene(int number) async {
      final id = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: number,
          name: 'Escena $number',
          locationCanonical: 'EXT. CALLE - NOCHE',
          locationPureName: 'CALLE',
        ),
      );
      return (await db.getSceneById(id))!;
    }

    sceneA = await scene(1);
    sceneB = await scene(2);
    for (var i = 0; i < 3; i++) {
      await db.insertShot(
        ShotsCompanion.insert(
          projectId: projectId,
          sceneId: sceneA.id,
          number: i + 1,
          sortOrder: Value(i),
        ),
      );
    }
    shotsA = await db.getShotsForScene(sceneA.id);
    history = EditHistory();
    service = ShootPlanService(db, history: history);
  });

  tearDown(() => db.close());

  test('el nombre sale del mayor número, no del recuento', () async {
    final one = await service.addDay(projectId);
    await service.addDay(projectId);
    await db.deleteShootDocument(one);
    expect(await service.addDay(projectId), isNotNull);
    final names = (await plan()).days.map((d) => d.name);
    expect(names, containsAll(['Jornada 2', 'Jornada 3']));
  });

  test('una escena se reparte entre días y queda lo que falta', () async {
    final d1 = await service.addDay(projectId);
    final d2 = await service.addDay(projectId);
    await service.place(
      projectId: projectId,
      dayId: d1,
      items: [(sceneId: sceneA.id, shotId: shotsA[0].id)],
    );
    await service.place(
      projectId: projectId,
      dayId: d2,
      items: [(sceneId: sceneA.id, shotId: shotsA[1].id)],
    );
    final p = await plan();
    final free = p.unassigned.singleWhere((u) => u.scene.id == sceneA.id);
    expect(free.shots.map((s) => s.id), [shotsA[2].id]);
    expect(free.total, 3);
    expect(p.daysOfShot.values, everyElement(1));
  });

  test('un plano repetido se marca en dos días', () async {
    final d1 = await service.addDay(projectId);
    final d2 = await service.addDay(projectId);
    for (final day in [d1, d2]) {
      await service.place(
        projectId: projectId,
        dayId: day,
        items: [(sceneId: sceneA.id, shotId: shotsA[0].id)],
      );
    }
    expect((await plan()).daysOfShot[shotsA[0].id], 2);
  });

  test('colocar antes de un bloque y mover entre días', () async {
    final d1 = await service.addDay(projectId);
    final d2 = await service.addDay(projectId);
    await service.place(
      projectId: projectId,
      dayId: d1,
      items: [
        (sceneId: sceneA.id, shotId: shotsA[0].id),
        (sceneId: sceneA.id, shotId: shotsA[1].id),
      ],
    );
    var p = await plan();
    final first = p.blocksByDay[d1]!.first;
    await service.place(
      projectId: projectId,
      dayId: d1,
      items: [(sceneId: sceneA.id, shotId: shotsA[2].id)],
      beforeBlockId: first.id,
    );
    p = await plan();
    expect(shotsOfDay(p, d1), [shotsA[2].id, shotsA[0].id, shotsA[1].id]);

    await service.move(
      projectId: projectId,
      dayId: d2,
      blockIds: [p.blocksByDay[d1]![1].id],
    );
    p = await plan();
    expect(shotsOfDay(p, d1), [shotsA[2].id, shotsA[1].id]);
    expect(shotsOfDay(p, d2), [shotsA[0].id]);
  });

  test('deshacer devuelve el plan y conserva lo marcado', () async {
    final d1 = await service.addDay(projectId);
    final d2 = await service.addDay(projectId);
    await service.place(
      projectId: projectId,
      dayId: d1,
      items: [(sceneId: sceneA.id, shotId: shotsA[0].id)],
    );
    final block = (await plan()).blocksByDay[d1]!.single;
    await db.updateShootDocumentBlock(
      block.copyWith(contentOverridesJson: const Value('{"onSet":"done"}')),
    );

    await service.move(projectId: projectId, dayId: d2, blockIds: [block.id]);
    expect(
      (await plan()).blocksByDay[d2]!.single.contentOverridesJson,
      '{"onSet":"done"}',
    );

    await history.undo();
    final p = await plan();
    expect(p.blocksByDay[d2], isEmpty);
    expect(p.blocksByDay[d1]!.single.contentOverridesJson, '{"onSet":"done"}');
  });

  test('una escena sin planos se coloca y sale de sin asignar', () async {
    final d1 = await service.addDay(projectId);
    expect(
      (await plan()).unassigned.map((u) => u.scene.id),
      contains(sceneB.id),
    );
    await service.place(
      projectId: projectId,
      dayId: d1,
      items: [(sceneId: sceneB.id, shotId: null)],
    );
    expect(
      (await plan()).unassigned.map((u) => u.scene.id),
      isNot(contains(sceneB.id)),
    );
  });

  test('el orden de las jornadas manda sobre la fecha', () async {
    final d1 = await service.addDay(projectId);
    final d2 = await service.addDay(projectId);
    expect((await plan()).days.map((d) => d.id), [d1, d2]);
    await service.reorderDays(projectId, [d2, d1]);
    expect((await plan()).days.map((d) => d.id), [d2, d1]);
  });
}
