import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/shoot_documents/shoot_calendar.dart';
import 'package:iris_dp/features/shoot_documents/shoot_calendar_edit.dart';
import 'package:iris_dp/features/shoot_documents/shoot_calendar_editor.dart';
import 'package:iris_dp/features/shoot_documents/shoot_calendar_grid.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_on_set.dart';
import 'package:iris_dp/features/shoot_documents/shoot_day_timeline.dart';
import 'package:iris_dp/features/shoot_documents/shoot_document_block_types.dart';
import 'package:iris_dp/features/shoot_documents/shoot_plan.dart';

void main() {
  group('cuentas del calendario', () {
    test('mover con imán a 15 minutos y a otro día', () {
      const span = CalendarSpan(1, 600, 660);
      expect(
        dragCalendarSpan(
          span,
          CalendarDragMode.move,
          dayDelta: 2,
          minuteDelta: 52,
        ),
        const CalendarSpan(3, 645, 705),
      );
      // No se sale de la semana ni del día.
      expect(
        dragCalendarSpan(
          span,
          CalendarDragMode.move,
          dayDelta: 9,
          minuteDelta: -900,
        ),
        const CalendarSpan(6, 0, 60),
      );
    });

    test(
      'estirar por abajo puede pasar de medianoche; por arriba no cruza',
      () {
        const span = CalendarSpan(0, 22 * 60, 23 * 60);
        expect(
          dragCalendarSpan(span, CalendarDragMode.resizeEnd, minuteDelta: 180),
          const CalendarSpan(0, 22 * 60, 26 * 60),
        );
        expect(
          dragCalendarSpan(
            span,
            CalendarDragMode.resizeStart,
            minuteDelta: 200,
          ),
          const CalendarSpan(0, 23 * 60 - kCalendarShortest, 23 * 60),
        );
      },
    );

    test('crear dibujando, en cualquier dirección', () {
      expect(createCalendarSpan(2, 610, 700), const CalendarSpan(2, 615, 705));
      expect(createCalendarSpan(2, 700, 610), const CalendarSpan(2, 615, 705));
      expect(createCalendarSpan(2, 600, 605), const CalendarSpan(2, 600, 630));
    });

    test('horas de una franja según la columna donde cae', () {
      const span = CalendarSpan(0, 30, 90);
      expect(
        calendarTimesInDay(
          dayDate: '2026-11-15',
          spanDate: '2026-11-16',
          span: span,
        ),
        (from: '00:30', to: '01:30'),
      );
      expect(
        calendarTimesInDay(
          dayDate: '2026-11-15',
          spanDate: '2026-11-17',
          span: span,
        ),
        isNull,
      );
      // El cambio de hora de marzo no se come un día.
      expect(calendarDaysBetween('2027-03-27', '2027-03-29'), 2);
      expect(calendarAddDays('2026-11-30', 1), '2026-12-01');
    });

    test('la madrugada de una jornada de noche es del día siguiente', () {
      expect(calendarMinutesInDay('00:45', '17:00'), 24 * 60 + 45);
      expect(calendarMinutesInDay('07:00', '08:00'), 7 * 60);
      expect(calendarMinutesInDay('02:00', null), 26 * 60);
    });
  });

  group('editar desde el calendario', () {
    late AppDatabase db;
    late int projectId;
    late int dayId;
    late int sceneId;
    late int shotId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
      dayId = await db.insertShootDocument(
        ShootDocumentsCompanion.insert(
          projectId: projectId,
          name: 'Jornada 3',
          kind: const Value(kShootDayKind),
          shootDate: const Value('2026-11-15'),
          shootFromTime: const Value('17:00'),
          shootToTime: const Value('03:00'),
        ),
      );
      sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 7,
          name: 'La Rouge',
          locationCanonical: 'EXT. LA ROUGE - NOCHE',
          locationPureName: 'LA ROUGE',
        ),
      );
      shotId = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: 1,
        ),
      );
      await db.insertShootDocumentBlock(
        ShootDocumentBlocksCompanion.insert(
          documentId: dayId,
          blockType: ShootBlockType.shot,
          sceneId: Value(sceneId),
          shotId: Value(shotId),
          sortOrder: const Value(0),
        ),
      );
      await db.insertShootDocumentBlock(
        ShootDocumentBlocksCompanion.insert(
          documentId: dayId,
          blockType: ShootBlockType.schedule,
          sortOrder: const Value(1),
          contentOverridesJson: Value(
            const ShootStrip(
              kind: ShootStripKind.wrap,
              from: '03:00',
              to: '03:40',
            ).writeInto(null),
          ),
        ),
      );
    });

    tearDown(() => db.close());

    Future<List<ShootCalendarEntry>> entries() async => buildShootCalendar(
      documents: await db.getShootDocumentsForProject(projectId),
      blocks: await db.getShootDayBlocks(projectId),
      reservations: const [],
      houses: const {},
      sites: const {},
      scenes: {
        for (final s in await db.watchScenesForProject(projectId).first)
          s.id: s,
      },
      shots: {for (final s in await db.getShotsForProject(projectId)) s.id: s},
    );

    test('la recogida de las 03:00 sale el día siguiente', () async {
      final strip = (await entries()).firstWhere(
        (e) => e.kind == ShootCalendarKind.strip,
      );
      expect(strip.date, '2026-11-16');
      expect(strip.dayDate, '2026-11-15');
    });

    test('dar hora a una escena y moverla; deshacer conserva En set', () async {
      final editor = ShootCalendarEditor(db, projectId);
      final pending = unscheduledShootScenes(
        documents: await db.getShootDocumentsForProject(projectId),
        blocks: await db.getShootDayBlocks(projectId),
        shots: {
          for (final s in await db.getShotsForProject(projectId)) s.id: s,
        },
        dates: {'2026-11-15'},
      );
      expect(pending.single.sceneId, sceneId);
      await editor.scheduleScene(
        pending.single,
        '2026-11-16',
        const CalendarSpan(1, 0, 45),
      );
      var scene = (await entries()).firstWhere(
        (e) => e.kind == ShootCalendarKind.scene,
      );
      expect(
        '${scene.date} ${scene.from}-${scene.to}',
        '2026-11-16 00:00-00:45',
      );
      expect(scene.title, 'Esc. 7');

      final step = await editor.setSpan(
        scene,
        '2026-11-15',
        const CalendarSpan(0, 23 * 60 + 30, 24 * 60 + 15),
      );
      scene = (await entries()).firstWhere(
        (e) => e.kind == ShootCalendarKind.scene,
      );
      expect(
        '${scene.date} ${scene.from}-${scene.to}',
        '2026-11-15 23:30-00:15',
      );

      // Entre medias, alguien marca el plano como hecho en el set.
      final block = (await db.getShootDayBlocks(projectId)).first;
      await db.updateShootDocumentBlock(
        block.copyWith(
          contentOverridesJson: Value(
            const OnSetMark(
              status: OnSetStatus.done,
            ).writeInto(block.contentOverridesJson),
          ),
        ),
      );
      await step!.undo();
      final after = (await db.getShootDayBlocks(projectId)).first;
      expect(SceneSchedule.of(after).from, '00:00');
      expect(OnSetMark.of(after).status, OnSetStatus.done);
    });

    test('una franja no se va a otra semana', () async {
      final editor = ShootCalendarEditor(db, projectId);
      final strip = (await entries()).firstWhere(
        (e) => e.kind == ShootCalendarKind.strip,
      );
      expect(
        await editor.setSpan(strip, '2026-11-20', const CalendarSpan(5, 0, 40)),
        isNull,
      );
    });

    test('mover la jornada, crear otra y una franja en su sitio', () async {
      final editor = ShootCalendarEditor(db, projectId);
      final day = (await entries()).firstWhere(
        (e) => e.kind == ShootCalendarKind.shoot,
      );
      final move = await editor.setSpan(
        day,
        '2026-11-14',
        const CalendarSpan(0, 18 * 60, 28 * 60),
      );
      var doc = (await db.getShootDocument(dayId))!;
      expect(
        '${doc.shootDate} ${doc.shootFromTime}-${doc.shootToTime}',
        '2026-11-14 18:00-04:00',
      );
      await move!.undo();
      doc = (await db.getShootDocument(dayId))!;
      expect(doc.shootDate, '2026-11-15');

      final created = await editor.addDay(
        '2026-11-18',
        const CalendarSpan(0, 8 * 60, 18 * 60),
      );
      var days = await db.getShootDocumentsForProject(projectId);
      expect(days.map((d) => d.name), contains('Jornada 4'));
      await created.undo();
      days = await db.getShootDocumentsForProject(projectId);
      expect(days.length, 1);

      // Una comida a las 22:00 va antes de la recogida de las 03:00.
      final meal = await editor.addStrip(
        dayId: dayId,
        dayDate: '2026-11-15',
        date: '2026-11-15',
        span: const CalendarSpan(0, 22 * 60, 23 * 60),
        kind: ShootStripKind.meal,
      );
      final order = await db.getBlocksForShootDocument(dayId);
      expect(
        [
          for (final b in order)
            if (ShootStrip.isStrip(b)) ShootStrip.of(b).kind,
        ],
        [ShootStripKind.meal, ShootStripKind.wrap],
      );
      await meal!.undo();
      expect((await db.getBlocksForShootDocument(dayId)).length, 2);
    });
  });

  testWidgets('arrastrar con el ratón mueve una hora y estirar alarga', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final changes = <(String, CalendarSpan)>[];
    final created = <CalendarSpan>[];
    const entry = ShootCalendarEntry(
      key: 'strip:1',
      date: '2026-11-13',
      dayDate: '2026-11-13',
      kind: ShootCalendarKind.strip,
      stripKind: ShootStripKind.setup,
      title: 'Montaje',
      from: '01:00',
      to: '02:00',
      dayId: 1,
      blockId: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ShootCalendarGrid(
            days: [DateTime(2026, 11, 13)],
            entries: const [entry],
            onOpen: (_) {},
            onSpan: (e, date, span) async => changes.add((date, span)),
            onCreate: (date, span, _) async => created.add(span),
            onDropScene: (_, _, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final block = find.byType(ShootCalendarBlock);
    // 46 px son una hora.
    await tester.drag(
      block,
      const Offset(0, 46),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(changes.single.$2, const CalendarSpan(0, 120, 180));

    final bottom = tester.getBottomLeft(block) + const Offset(20, -2);
    await tester.dragFrom(
      bottom,
      const Offset(0, 23),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(changes.last.$2, const CalendarSpan(0, 60, 150));

    // Dibujar en un hueco crea.
    final grid = tester.getTopLeft(find.byType(ShootCalendarGrid));
    await tester.dragFrom(
      grid + const Offset(300, 40 + 46 * 5),
      const Offset(0, 92),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(created, isNotEmpty);
    expect(created.single.length, greaterThanOrEqualTo(90));
  });
}
