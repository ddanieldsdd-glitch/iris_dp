import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_duration.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_timeline.dart';
import 'package:iris_dp/features/shoot_documents/shoot_plan.dart';

/// El orden de rodaje por duraciones: cada cosa empieza cuando acaba la
/// anterior, la comida puede ir fijada a su hora y al arrastrar todo se
/// recalcula solo.
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

  Future<int> addShot(int shotId, int sceneId, int order, {int? minutes}) =>
      db.insertShootDocumentBlock(
        ShootDocumentBlocksCompanion.insert(
          documentId: dayId,
          sortOrder: Value(order),
          blockType: 'shot',
          sceneId: Value(sceneId),
          shotId: Value(shotId),
          contentOverridesJson: Value(
            minutes == null ? null : ShotTime(minutes: minutes).writeInto(null),
          ),
        ),
      );

  Future<int> addStrip(ShootStrip strip, int order) =>
      db.insertShootDocumentBlock(
        ShootDocumentBlocksCompanion.insert(
          documentId: dayId,
          sortOrder: Value(order),
          blockType: 'schedule',
          contentOverridesJson: Value(strip.writeInto(null)),
        ),
      );

  Future<List<ShootDocumentBlock>> blocks() =>
      db.getBlocksForShootDocument(dayId);

  Future<Map<int, Shot>> shots() async => {
    for (final s in await db.getShotsForProject(projectId)) s.id: s,
  };

  Future<ShootDaySchedule> plan({String? start = '08:00', String? end}) async {
    final s = await shots();
    return scheduleShootDay(
      buildShootDayEntries(await blocks(), s),
      s,
      dayStart: start,
      dayEnd: end,
    );
  }

  String range(ShootSpan? s) =>
      s == null ? '—' : '${formatClock(s.start)}-${formatClock(s.end)}';

  test('cada cosa empieza cuando acaba la anterior', () async {
    final setup = await addStrip(
      const ShootStrip(kind: ShootStripKind.setup, minutes: 90),
      0,
    );
    final a1 = await addShot(shotIds[0], sceneA, 1, minutes: 20);
    final a2 = await addShot(shotIds[1], sceneA, 2, minutes: 30);
    final b1 = await addShot(shotIds[2], sceneB, 3, minutes: 15);
    final p = await plan();
    expect(range(p.spans[setup]), '08:00-09:30');
    // La escena dura lo que suman sus planos, y cada plano va seguido.
    expect(range(p.spans[a1]), '09:30-09:50');
    expect(range(p.spans[a2]), '09:50-10:20');
    expect(p.sceneMinutes[a1], 50);
    expect(range(p.spans[b1]), '10:20-10:35');
    expect(p.end, 10 * 60 + 35);
    expect(p.warnings, isEmpty);
  });

  test('la comida fijada empieza a su hora y avisa si se pisa', () async {
    // La escena acaba a las 12:10: diez minutos dentro de la comida.
    await addShot(shotIds[0], sceneA, 0, minutes: 250);
    final meal = await addStrip(
      const ShootStrip(
        kind: ShootStripKind.meal,
        from: '12:00',
        minutes: 60,
        pinned: true,
      ),
      1,
    );
    final b1 = await addShot(shotIds[2], sceneB, 2, minutes: 30);
    final p = await plan();
    expect(range(p.spans[meal]), '12:00-13:00');
    expect(range(p.spans[b1]), '13:00-13:30');
    expect(p.warningOf(meal), contains('12:10'));
  });

  test('lo que acaba justo a la hora de la comida no avisa', () async {
    await addShot(shotIds[0], sceneA, 0, minutes: 240);
    final meal = await addStrip(
      const ShootStrip(
        kind: ShootStripKind.meal,
        from: '12:00',
        minutes: 60,
        pinned: true,
      ),
      1,
    );
    expect((await plan()).warningOf(meal), isNull);
  });

  test('sin duración no se inventa una hora', () async {
    final a1 = await addShot(shotIds[0], sceneA, 0);
    final note = await addStrip(const ShootStrip(), 1);
    final b1 = await addShot(shotIds[2], sceneB, 2, minutes: 10);
    final p = await plan();
    expect(p.spans[a1], isNull);
    expect(p.spans[note], isNull);
    expect(range(p.spans[b1]), '08:00-08:10');
  });

  test('avisa si la jornada se pasa de «Se rueda hasta»', () async {
    final a1 = await addShot(shotIds[0], sceneA, 0, minutes: 600);
    final p = await plan(end: '17:00');
    expect(p.warningOf(a1), contains('17:00'));
  });

  test('sin hora de inicio arranca en la primera hora escrita', () async {
    final call = await addStrip(
      const ShootStrip(kind: ShootStripKind.call, from: '07:30', to: '10:00'),
      0,
    );
    final a1 = await addShot(shotIds[0], sceneA, 1, minutes: 30);
    final p = await plan(start: null);
    // Una franja con horas escritas a mano dura lo que va de una a otra.
    expect(range(p.spans[call]), '07:30-10:00');
    expect(range(p.spans[a1]), '10:00-10:30');
  });

  test('las horas de un plan importado conservan sus huecos', () async {
    // Como el plan del kebab: Esc 6 de 10:15 a 10:45 y la preparación de
    // la Esc 8 a las 12:15, escritas antes de que hubiera duraciones.
    final a = await addShot(shotIds[0], sceneA, 0);
    final first = (await blocks()).single;
    await db.updateShootDocumentBlock(
      first.copyWith(
        contentOverridesJson: const Value(
          '{"sceneSchedule":{"from":"10:15","to":"10:45"}}',
        ),
      ),
    );
    final prep = await db.insertShootDocumentBlock(
      ShootDocumentBlocksCompanion.insert(
        documentId: dayId,
        sortOrder: const Value(1),
        blockType: 'schedule',
        contentOverridesJson: const Value(
          '{"schedule":{"kind":"setup","from":"12:15","to":"13:15"}}',
        ),
      ),
    );
    final p = await plan(start: '07:30');
    expect(range(p.sceneSpans[a]), '10:15-10:45');
    expect(range(p.spans[prep]), '12:15-13:15');
    expect(p.warnings, isEmpty);
    // Guardar el horario no las convierte en encadenadas.
    final s = await shots();
    await ShootDayScheduleService(
      db,
    ).edit(dayId, await blocks(), s, dayStart: '07:30');
    final again = await plan(start: '07:30');
    expect(range(again.spans[prep]), '12:15-13:15');
  });

  test('al arrastrar se recalcula y se guarda en cada bloque', () async {
    final a1 = await addShot(shotIds[0], sceneA, 0, minutes: 30);
    final a2 = await addShot(shotIds[1], sceneA, 1, minutes: 30);
    final b1 = await addShot(shotIds[2], sceneB, 2, minutes: 45);
    final s = await shots();
    // La escena B pasa delante.
    final undo = await ShootDayScheduleService(
      db,
    ).applyOrder(dayId, await blocks(), [b1, a1, a2], s, dayStart: '09:00');
    final after = {for (final b in await blocks()) b.id: b};
    expect(ShotTime.of(after[b1]!).from, '09:00');
    expect(ShotTime.of(after[b1]!).to, '09:45');
    expect(ShotTime.of(after[a1]!).from, '09:45');
    expect(ShotTime.of(after[a2]!).to, '10:45');
    expect(SceneSchedule.of(after[a1]!).from, '09:45');
    expect(SceneSchedule.of(after[a1]!).to, '10:45');
    // Y se deshace del todo.
    await undo();
    final back = await blocks();
    expect([for (final b in back) b.id], [a1, a2, b1]);
    expect(ShotTime.of(back.first).from, isNull);
  });

  test('cambiar una duración mueve todo lo de después', () async {
    final a1 = await addShot(shotIds[0], sceneA, 0, minutes: 30);
    final b1 = await addShot(shotIds[2], sceneB, 1, minutes: 30);
    final s = await shots();
    final current = await blocks();
    final first = current.firstWhere((b) => b.id == a1);
    await ShootDayScheduleService(db).edit(
      dayId,
      current,
      s,
      edits: {
        a1: ShotTime.of(first)
            .copyWith(minutes: const Value(60))
            .writeInto(first.contentOverridesJson),
      },
      dayStart: '08:00',
    );
    final after = {for (final b in await blocks()) b.id: b};
    expect(ShotTime.of(after[b1]!).from, '09:00');
  });

  test('las horas viejas sin duración pasan a guardar su duración', () {
    const old = SceneSchedule(from: '10:15', to: '10:45');
    expect(clockSpan(old.from, old.to), 30);
    expect(clockSpan('23:30', '00:15'), 45);
  });

  group('lo que se escribe a mano', () {
    test('entiende minutos y horas', () {
      expect(parseDurationText('40'), 40);
      expect(parseDurationText('40 min'), 40);
      expect(parseDurationText('1:30'), 90);
      expect(parseDurationText('1h30'), 90);
      expect(parseDurationText('2h'), 120);
      expect(parseDurationText('nada'), isNull);
    });

    test('formatea duraciones y horas', () {
      expect(formatDuration(45), '45 min');
      expect(formatDuration(60), '1 h');
      expect(formatDuration(95), '1 h 35');
      expect(formatClock(25 * 60 + 5), '01:05');
      expect(parseClock('7:05'), 7 * 60 + 5);
    });
  });
}
