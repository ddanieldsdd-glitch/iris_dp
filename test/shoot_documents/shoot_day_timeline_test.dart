import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_on_set.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_timeline.dart';
import 'package:iris_dp/features/shoot_documents/shoot_plan.dart';

void main() {
  late AppDatabase db;
  late int projectId;
  late int dayId;
  late int sceneA;
  late int sceneB;
  late List<int> shotIds;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
    Future<int> scene(int n) => db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: n,
        name: 'E$n',
        locationCanonical: 'INT. E$n - NOCHE',
        locationPureName: 'E$n',
        sortOrder: Value(n),
      ),
    );
    sceneA = await scene(1);
    sceneB = await scene(2);
    shotIds = [
      for (final (s, n) in [(sceneA, 1), (sceneA, 2), (sceneB, 1)])
        await db.insertShot(
          ShotsCompanion.insert(
            sceneId: s,
            projectId: projectId,
            number: n,
            sortOrder: Value(n),
          ),
        ),
    ];
    dayId = await db.insertShootDocument(
      ShootDocumentsCompanion.insert(
        projectId: projectId,
        name: 'Jornada 1',
        kind: const Value(kShootDayKind),
      ),
    );
  });
  tearDown(() => db.close());

  Future<int> addShot(int shotId, int sceneId, int order) =>
      db.insertShootDocumentBlock(
        ShootDocumentBlocksCompanion.insert(
          documentId: dayId,
          sortOrder: Value(order),
          blockType: 'shot',
          sceneId: Value(sceneId),
          shotId: Value(shotId),
        ),
      );

  Future<List<ShootDocumentBlock>> blocks() =>
      db.getBlocksForShootDocument(dayId);

  Future<Map<int, Shot>> shots() async => {
    for (final s in await db.getShotsForProject(projectId)) s.id: s,
  };

  ShootDayScheduleService service() => ShootDayScheduleService(db);

  test('escenas y franjas salen en una sola lectura, en orden', () async {
    await addShot(shotIds[0], sceneA, 0);
    await addShot(shotIds[1], sceneA, 1);
    await service().addStrip(
      dayId,
      const ShootStripDraft(
        strip: ShootStrip(kind: ShootStripKind.meal, from: '14:00'),
      ),
    );
    await addShot(shotIds[2], sceneB, 3);

    final entries = buildShootDayEntries(await blocks(), await shots());
    expect(entries.map((e) => e.runtimeType.toString()), [
      'ShootSceneEntry',
      'ShootStripEntry',
      'ShootSceneEntry',
    ]);
    final strip = (entries[1] as ShootStripEntry).strip;
    expect(strip.kind, ShootStripKind.meal);
    expect(strip.from, '14:00');
  });

  test('la escena es la del plano, no la que quedó en el bloque', () async {
    await addShot(shotIds[2], sceneA, 0);
    final entries = buildShootDayEntries(await blocks(), await shots());
    expect((entries.single as ShootSceneEntry).sceneId, sceneB);
  });

  test('una escena sin planos ocupa su sitio en el orden', () async {
    await db.insertShootDocumentBlock(
      ShootDocumentBlocksCompanion.insert(
        documentId: dayId,
        blockType: 'scene_header',
        sceneId: Value(sceneB),
      ),
    );
    final entries = buildShootDayEntries(await blocks(), await shots());
    expect((entries.single as ShootSceneEntry).sceneId, sceneB);
  });

  test('un empate de orden se resuelve siempre igual', () async {
    final first = await addShot(shotIds[0], sceneA, 0);
    final second = await addShot(shotIds[1], sceneA, 0);
    expect([for (final b in await blocks()) b.id], [first, second]);
  });

  test('mover una escena lleva todas las filas y deja numerado', () async {
    await addShot(shotIds[0], sceneA, 0);
    await addShot(shotIds[1], sceneA, 1);
    final strip = await service().addStrip(
      dayId,
      const ShootStripDraft(strip: ShootStrip(kind: ShootStripKind.setup)),
    );
    final third = await addShot(shotIds[2], sceneB, 5);
    final current = await blocks();
    final map = await shots();
    final entries = buildShootDayEntries(current, map);
    await service().applyOrder(
      dayId,
      current,
      shootDayOrderOf(moveShootDayEntry(entries, 2, 0), current),
      map,
    );
    final after = await blocks();
    expect(after.first.id, third);
    expect(after[1].shotId, shotIds[0]);
    expect(after.last.id, strip);
    expect([for (final b in after) b.sortOrder], [0, 1, 2, 3]);
  });

  test('la hora de la escena sigue a su escena al reordenar planos', () async {
    final a1 = await addShot(shotIds[0], sceneA, 0);
    final a2 = await addShot(shotIds[1], sceneA, 1);
    await service().setSceneSchedule(
      (await blocks()).first,
      const SceneSchedule(from: '09:00', note: 'con niebla'),
    );
    final current = await blocks();
    final map = await shots();
    final undo = await service().applyOrder(dayId, current, [a2, a1], map);

    var after = await blocks();
    expect(after.first.id, a2);
    expect(SceneSchedule.of(after.first).from, '09:00');
    expect(SceneSchedule.of(after.first).note, 'con niebla');
    expect(SceneSchedule.of(after.last).isEmpty, isTrue);

    await undo();
    after = await blocks();
    expect(after.first.id, a1);
    expect(SceneSchedule.of(after.first).from, '09:00');
    expect(SceneSchedule.of(after.last).isEmpty, isTrue);
  });

  test('deshacer el plan no borra un «Hecho» apuntado después', () async {
    await addShot(shotIds[0], sceneA, 0);
    final second = await addShot(shotIds[1], sceneA, 1);
    final before = await db.getShootDayBlocks(projectId);

    final block = (await blocks()).last;
    await db.updateShootDocumentBlock(
      block.copyWith(
        contentOverridesJson: Value(
          const OnSetMark(status: OnSetStatus.done).writeInto(null),
        ),
      ),
    );
    await db.reorderShootDocumentBlocks(dayId, [second]);

    await db.restoreShootDayBlocks(projectId, before);
    final restored = (await blocks()).firstWhere((b) => b.id == second);
    expect(restored.sortOrder, 1);
    expect(OnSetMark.of(restored).status, OnSetStatus.done);
  });

  test('las franjas viajan con su hora y su localización', () async {
    await addShot(shotIds[0], sceneA, 0);
    final siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'BOSQUE'),
    );
    final site = (await db.watchSitesForProject(
      projectId,
    ).first).firstWhere((s) => s.id == siteId);
    await service().addStrip(
      dayId,
      ShootStripDraft(
        strip: ShootStrip(
          kind: ShootStripKind.move,
          from: '13:00',
          to: '14:00',
          siteUid: site.uid,
        ),
        label: 'Al bosque',
        note: 'Furgo 2',
      ),
    );
    await service().setSceneSchedule(
      (await blocks()).first,
      const SceneSchedule(from: '09:00'),
    );

    final bundle = await ProjectContentBundle.export(db, projectId);
    await ProjectContentBundle.importBundle(db, projectId, bundle);

    final day = (await db.getShootDocumentsForProject(projectId)).single;
    final after = await db.getBlocksForShootDocument(day.id);
    expect(after, hasLength(2));
    expect(SceneSchedule.of(after.first).from, '09:00');
    final strip = ShootStrip.of(after.last);
    expect(strip.kind, ShootStripKind.move);
    expect(strip.to, '14:00');
    expect(strip.siteUid, site.uid);
    expect(ShootStrip.titleOf(after.last), 'Al bosque');
    expect(after.last.noteBody, 'Furgo 2');
  });

  test('el horario del documento sigue el orden de rodaje', () async {
    await addShot(shotIds[0], sceneA, 0);
    expect(
      shootDayScheduleLine(await blocks(), await shots(), const {}),
      isNull,
    );
    await service().addStrip(
      dayId,
      const ShootStripDraft(
        strip: ShootStrip(kind: ShootStripKind.meal, from: '14:00'),
      ),
    );
    final scenes = {
      for (final s in await db.watchScenesForProject(projectId).first) s.id: s,
    };
    expect(
      shootDayScheduleLine(await blocks(), await shots(), scenes),
      'Esc ${scenes[sceneA]!.label} · 14:00 Comida',
    );
  });
}
