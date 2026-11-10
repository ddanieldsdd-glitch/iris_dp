import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/export_center/export_selection.dart';
import 'package:iris_dp/features/shoot_documents/shoot_calendar.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_timeline.dart';
import 'package:iris_dp/features/shoot_documents/shoot_plan.dart';

ShootCalendarEntry _entry(String key, String date, String? from, String? to) =>
    ShootCalendarEntry(
      key: key,
      date: date,
      kind: ShootCalendarKind.shoot,
      title: key,
      from: from,
      to: to,
    );

void main() {
  group('rejilla de horas', () {
    test('una noche se reparte entre los dos días', () {
      final night = _entry('noche', '2026-11-13', '20:00', '04:00');
      final first = shootCalendarSlots([night], '2026-11-13').single;
      expect((first.start, first.end, first.continued), (1200, 1440, false));
      final second = shootCalendarSlots([night], '2026-11-14').single;
      expect((second.start, second.end, second.continued), (0, 240, true));
      expect(shootCalendarSlots([night], '2026-11-15'), isEmpty);
    });

    test('el cambio de mes también reparte la noche', () {
      final night = _entry('noche', '2026-11-30', '22:00', '02:00');
      expect(shootCalendarSlots([night], '2026-12-01').single.end, 120);
    });

    test('lo que se pisa va en columnas y lo demás ocupa todo', () {
      final slots = shootCalendarSlots([
        _entry('a', '2026-11-13', '09:00', '11:00'),
        _entry('b', '2026-11-13', '10:00', '12:00'),
        _entry('c', '2026-11-13', '15:00', '16:00'),
      ], '2026-11-13');
      expect([for (final s in slots) s.column], [0, 1, 0]);
      expect([for (final s in slots) s.columns], [2, 2, 1]);
    });

    test('lo que no tiene hora no entra en la rejilla', () {
      expect(
        shootCalendarSlots([
          _entry('a', '2026-11-13', null, null),
        ], '2026-11-13'),
        isEmpty,
      );
    });

    test('una entrada muy corta sigue siendo tocable', () {
      final slot = shootCalendarSlots([
        _entry('a', '2026-11-13', '09:00', '09:05'),
      ], '2026-11-13').single;
      expect(slot.end - slot.start, 45);
    });
  });

  group('con datos', () {
    late AppDatabase db;
    late int projectId;
    late int dayId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
      dayId = await db.insertShootDocument(
        ShootDocumentsCompanion.insert(
          projectId: projectId,
          name: 'Jornada 1',
          kind: const Value(kShootDayKind),
          shootDate: const Value('2026-11-13'),
        ),
      );
    });
    tearDown(() => db.close());

    Future<List<ShootCalendarEntry>> calendar() async => buildShootCalendar(
      documents: await db.getShootDocumentsForProject(projectId),
      blocks: await db.getShootDayBlocks(projectId),
      reservations: const [],
      houses: const {},
      sites: const {},
    );

    test('cambiar la jornada mueve su entrada, sin segunda copia', () async {
      await ShootDayScheduleService(db).addStrip(
        dayId,
        const ShootStripDraft(
          strip: ShootStrip(kind: ShootStripKind.meal, from: '14:00'),
        ),
      );
      var entries = await calendar();
      expect(entries.map((e) => e.kind), [
        ShootCalendarKind.shoot,
        ShootCalendarKind.strip,
      ]);
      expect(entries.last.dayId, dayId);

      final day = await db.getShootDocument(dayId);
      await db.updateShootDocument(
        day!.copyWith(shootDate: const Value('2026-11-14')),
      );
      entries = await calendar();
      expect(entries.map((e) => e.date).toSet(), {'2026-11-14'});
    });

    test('una jornada sin fecha no sale en el calendario', () async {
      final day = await db.getShootDocument(dayId);
      await db.updateShootDocument(day!.copyWith(shootDate: const Value(null)));
      expect(await calendar(), isEmpty);
    });

    test('una escena sin planos sale en la jornada exportada', () async {
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
      final withShot = await scene(1);
      final empty = await scene(2);
      final shot = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: withShot,
          projectId: projectId,
          number: 1,
        ),
      );
      final shotBlock = await db.insertShootDocumentBlock(
        ShootDocumentBlocksCompanion.insert(
          documentId: dayId,
          sortOrder: const Value(0),
          blockType: 'shot',
          sceneId: Value(withShot),
          shotId: Value(shot),
        ),
      );
      await db.insertShootDocumentBlock(
        ShootDocumentBlocksCompanion.insert(
          documentId: dayId,
          sortOrder: const Value(1),
          blockType: 'scene_header',
          sceneId: Value(empty),
        ),
      );
      final source = await ExportSource.load(db, projectId);
      final sections = resolveExportSections(
        source!,
        ExportSelection(scope: ExportScope.days, blockIds: {shotBlock}),
      );
      expect(sections.single.scenes.map((s) => s.scene.id), [withShot, empty]);
      expect(sections.single.scenes.last.shots, isEmpty);
      expect(sections.single.shotCount, 1);
    });
  });
}
