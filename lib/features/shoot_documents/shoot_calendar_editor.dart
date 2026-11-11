import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import '../../core/database/shoot_block_overrides.dart';
import '../../shared/history/edit_history.dart';
import 'shoot_calendar.dart';
import 'shoot_calendar_edit.dart';
import 'shoot_day_timeline.dart';
import 'shoot_plan.dart';

/// Lo que se cambia desde el calendario. Cada cambio devuelve su paso para
/// el historial de la pantalla (⌘Z).
class ShootCalendarEditor {
  final AppDatabase db;
  final int projectId;

  const ShootCalendarEditor(this.db, this.projectId);

  /// Pone [entry] en [span], dentro de la columna de [date]. Nulo si no se
  /// puede: una franja no sale de su jornada.
  Future<EditStep?> setSpan(
    ShootCalendarEntry entry,
    String date,
    CalendarSpan span,
  ) async {
    switch (entry.kind) {
      case ShootCalendarKind.shoot:
        final id = entry.dayId;
        if (id == null) return null;
        return _setDay(
          id,
          date: date,
          from: calendarHm(span.start),
          to: calendarHm(span.end),
          label: 'hora de ${entry.title}',
        );
      case ShootCalendarKind.strip || ShootCalendarKind.scene:
        final blockId = entry.blockId;
        final dayDate = entry.dayDate;
        if (blockId == null || dayDate == null) return null;
        final times = calendarTimesInDay(
          dayDate: dayDate,
          spanDate: date,
          span: span,
        );
        if (times == null) return null;
        final block = await db.getShootDocumentBlock(blockId);
        if (block == null) return null;
        // Lo que se suelta a una hora en el calendario queda fijado a ella,
        // y su largo pasa a ser su duración en el orden de rodaje.
        final json = entry.kind == ShootCalendarKind.strip
            ? _stripWith(block, times.from, times.to)
            : _sceneWith(block, times.from, times.to);
        return _setJson(block, json, 'hora de ${entry.title}');
      case ShootCalendarKind.pickup || ShootCalendarKind.ret:
        return null;
    }
  }

  /// Lleva la jornada a [date] sin tocar sus horas.
  Future<EditStep?> moveDayTo(int dayId, String date) async {
    final doc = await db.getShootDocument(dayId);
    if (doc == null || doc.shootDate == date) return null;
    return _setDay(
      dayId,
      date: date,
      from: doc.shootFromTime,
      to: doc.shootToTime,
      label: 'fecha de ${doc.name}',
    );
  }

  /// Da hora a una escena que no la tenía.
  Future<EditStep?> scheduleScene(
    UnscheduledShootScene scene,
    String date,
    CalendarSpan span,
  ) async {
    final times = calendarTimesInDay(
      dayDate: scene.date,
      spanDate: date,
      span: span,
    );
    if (times == null) return null;
    final block = await db.getShootDocumentBlock(scene.block.id);
    if (block == null) return null;
    return _setJson(
      block,
      _sceneWith(block, times.from, times.to),
      'hora de la escena',
    );
  }

  /// Una franja nueva en la jornada [dayId], colocada en el orden según su
  /// hora.
  Future<EditStep?> addStrip({
    required int dayId,
    required String dayDate,
    required String date,
    required CalendarSpan span,
    required ShootStripKind kind,
  }) async {
    final times = calendarTimesInDay(
      dayDate: dayDate,
      spanDate: date,
      span: span,
    );
    if (times == null) return null;
    final doc = await db.getShootDocument(dayId);
    final draft = ShootStripDraft(
      strip: ShootStrip(
        kind: kind,
        from: times.from,
        to: times.to,
        minutes: clockSpan(times.from, times.to),
        pinned: true,
      ),
    );
    Future<int> add() async {
      final blocks = await db.getBlocksForShootDocument(dayId);
      final at = calendarMinutesInDay(times.from, doc?.shootFromTime);
      final before = blocks
          .where((b) {
            final start = _startOf(b);
            return start != null &&
                calendarMinutesInDay(start, doc?.shootFromTime) > at;
          })
          .firstOrNull
          ?.id;
      return ShootDayScheduleService(
        db,
      ).addStrip(dayId, draft, beforeBlockId: before);
    }

    var id = await add();
    return EditStep(
      label: 'nueva franja',
      undo: () => db.deleteShootDocumentBlock(id),
      redo: () async => id = await add(),
    );
  }

  /// Una jornada nueva el día [date] de [from] a [to].
  Future<EditStep> addDay(String date, CalendarSpan span) async {
    Future<int> add() async {
      final id = await ShootPlanService(db).addDay(projectId);
      final doc = (await db.getShootDocument(id))!;
      await db.updateShootDocument(
        doc.copyWith(
          shootDate: Value(date),
          shootFromTime: Value(calendarHm(span.start)),
          shootToTime: Value(calendarHm(span.end)),
          updatedAt: DateTime.now(),
        ),
      );
      return id;
    }

    var id = await add();
    return EditStep(
      label: 'nueva jornada',
      undo: () => db.deleteShootDocument(id),
      redo: () async => id = await add(),
    );
  }

  static String? _startOf(ShootDocumentBlock b) {
    if (ShootStrip.isStrip(b)) return ShootStrip.of(b).from;
    return SceneSchedule.of(b).from ?? ShotTime.of(b).from;
  }

  static String _stripWith(ShootDocumentBlock block, String from, String to) {
    final old = ShootStrip.of(block);
    return ShootStrip(
      kind: old.kind,
      from: from,
      to: to,
      siteUid: old.siteUid,
      minutes: clockSpan(from, to),
      pinned: true,
    ).writeInto(block.contentOverridesJson);
  }

  static String _sceneWith(ShootDocumentBlock block, String from, String to) {
    final old = SceneSchedule.of(block);
    return SceneSchedule(
      from: from,
      to: to,
      note: old.note,
      minutes: clockSpan(from, to),
      pinned: true,
    ).writeInto(block.contentOverridesJson);
  }

  Future<EditStep?> _setDay(
    int id, {
    required String date,
    required String? from,
    required String? to,
    required String label,
  }) async {
    final before = await db.getShootDocument(id);
    if (before == null) return null;
    Future<void> write(String? d, String? f, String? t) async {
      final now = await db.getShootDocument(id);
      if (now == null) return;
      await db.updateShootDocument(
        now.copyWith(
          shootDate: Value(d),
          shootFromTime: Value(f),
          shootToTime: Value(t),
          updatedAt: DateTime.now(),
        ),
      );
    }

    await write(date, from, to);
    return EditStep(
      label: label,
      undo: () =>
          write(before.shootDate, before.shootFromTime, before.shootToTime),
      redo: () => write(date, from, to),
    );
  }

  /// Cambia el JSON del bloque; deshacer no quita las marcas de En set
  /// apuntadas entre medias.
  Future<EditStep> _setJson(
    ShootDocumentBlock block,
    String json,
    String label,
  ) async {
    final id = block.id;
    final before = block.contentOverridesJson;
    Future<void> write(String? value) async {
      final now = await db.getShootDocumentBlock(id);
      if (now == null) return;
      await db.updateShootDocumentBlock(
        now.copyWith(
          contentOverridesJson: Value(
            keepOnSetMark(value, now.contentOverridesJson),
          ),
        ),
      );
    }

    await write(json);
    return EditStep(
      label: label,
      undo: () => write(before),
      redo: () => write(json),
    );
  }
}
