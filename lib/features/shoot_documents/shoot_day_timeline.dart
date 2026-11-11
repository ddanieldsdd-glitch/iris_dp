import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import '../../core/database/shoot_block_overrides.dart';
import 'shoot_document_block_types.dart';

/// Qué es una franja del orden de rodaje.
enum ShootStripKind {
  call('Citación'),
  prelight('Prelight'),
  setup('Montaje'),
  wrap('Desmontaje'),
  meal('Comida'),
  rest('Descanso'),
  move('Cambio de localización'),
  note('Nota');

  final String label;

  const ShootStripKind(this.label);
}

/// «08:00 – 10:30», «08:00» o vacío.
String shootTimeRange(String? from, String? to) {
  if (from != null && to != null) return '$from – $to';
  return from ?? (to == null ? '' : 'hasta $to');
}

/// Lo propio de una franja. Va en `contentOverridesJson` del bloque, igual
/// que las marcas de En set: viaja con la jornada sin tocar el esquema. La
/// localización se guarda por uid, que no cambia al sincronizar.
class ShootStrip {
  static const _key = 'schedule';

  final ShootStripKind kind;
  final String? from;
  final String? to;
  final String? siteUid;

  /// Cuánto dura. Con ella, la hora se calcula sola tras lo anterior.
  final int? minutes;

  /// Empieza a su hora [from] pase lo que pase antes (la comida a las 14:00).
  final bool pinned;

  /// Guardada antes de que hubiera duraciones: ver [stripIsPinned].
  final bool legacy;

  const ShootStrip({
    this.kind = ShootStripKind.note,
    this.from,
    this.to,
    this.siteUid,
    this.minutes,
    this.pinned = false,
    this.legacy = false,
  });

  ShootStrip copyWith({
    ShootStripKind? kind,
    Value<String?>? from,
    Value<String?>? to,
    Value<String?>? siteUid,
    Value<int?>? minutes,
    bool? pinned,
  }) => ShootStrip(
    kind: kind ?? this.kind,
    from: from == null ? this.from : from.value,
    to: to == null ? this.to : to.value,
    siteUid: siteUid == null ? this.siteUid : siteUid.value,
    minutes: minutes == null ? this.minutes : minutes.value,
    pinned: pinned ?? this.pinned,
  );

  static bool isStrip(ShootDocumentBlock block) =>
      block.blockType == ShootBlockType.schedule;

  static ShootStrip of(ShootDocumentBlock block) {
    final m = decodeBlockOverrides(block.contentOverridesJson)[_key];
    if (m is! Map) return const ShootStrip();
    return ShootStrip(
      kind:
          ShootStripKind.values.where((k) => k.name == m['kind']).firstOrNull ??
          ShootStripKind.note,
      from: m['from'] as String?,
      to: m['to'] as String?,
      siteUid: m['siteUid'] as String?,
      minutes: (m['minutes'] as num?)?.toInt(),
      pinned: m['pinned'] == true,
      legacy: !m.containsKey('pinned'),
    );
  }

  /// El nombre escrito a mano o, si no hay, el de su tipo.
  static String titleOf(ShootDocumentBlock block) {
    final custom = block.customLabel?.trim() ?? '';
    return custom.isNotEmpty ? custom : of(block).kind.label;
  }

  String writeInto(String? json) {
    final all = decodeBlockOverrides(json);
    all[_key] = {
      'kind': kind.name,
      'from': ?from,
      'to': ?to,
      'siteUid': ?siteUid,
      'minutes': ?minutes,
      // Una hora antigua que se reescribe tal cual sigue siendo antigua.
      if (!legacy || pinned) 'pinned': pinned,
    };
    return jsonEncode(all);
  }
}

/// Hora y aclaración de una escena dentro de la jornada. Se guarda en el
/// primer bloque de su tramo.
class SceneSchedule {
  static const _key = 'sceneSchedule';

  final String? from;
  final String? to;
  final String note;

  /// Cuánto dura si sus planos no tienen duración.
  final int? minutes;

  /// Empieza a su hora [from] pase lo que pase antes.
  final bool pinned;

  /// Guardada antes de que hubiera duraciones: ver [sceneIsPinned].
  final bool legacy;

  const SceneSchedule({
    this.from,
    this.to,
    this.note = '',
    this.minutes,
    this.pinned = false,
    this.legacy = false,
  });

  bool get isEmpty =>
      from == null &&
      to == null &&
      note.trim().isEmpty &&
      minutes == null &&
      !pinned;

  SceneSchedule copyWith({
    Value<String?>? from,
    Value<String?>? to,
    String? note,
    Value<int?>? minutes,
    bool? pinned,
  }) => SceneSchedule(
    from: from == null ? this.from : from.value,
    to: to == null ? this.to : to.value,
    note: note ?? this.note,
    minutes: minutes == null ? this.minutes : minutes.value,
    pinned: pinned ?? this.pinned,
  );

  static SceneSchedule of(ShootDocumentBlock block) {
    final m = decodeBlockOverrides(block.contentOverridesJson)[_key];
    if (m is! Map) return const SceneSchedule();
    return SceneSchedule(
      from: m['from'] as String?,
      to: m['to'] as String?,
      note: m['note'] as String? ?? '',
      minutes: (m['minutes'] as num?)?.toInt(),
      pinned: m['pinned'] == true,
      legacy: !m.containsKey('pinned'),
    );
  }

  String writeInto(String? json) {
    final all = decodeBlockOverrides(json);
    if (isEmpty) {
      all.remove(_key);
    } else {
      all[_key] = {
        'from': ?from,
        'to': ?to,
        if (note.trim().isNotEmpty) 'note': note.trim(),
        'minutes': ?minutes,
        if (!legacy || pinned) 'pinned': pinned,
      };
    }
    return jsonEncode(all);
  }
}

/// Hora y apunte de un plano dentro de la jornada, tal como viene en el plan
/// de rodaje. Va en el bloque del plano, junto a las marcas de En set.
class ShotTime {
  static const _key = 'shotTime';

  final String? from;
  final String? to;
  final String note;

  /// Cuánto dura el plano: la escena dura lo que suman sus planos.
  final int? minutes;

  const ShotTime({this.from, this.to, this.note = '', this.minutes});

  bool get isEmpty =>
      from == null && to == null && note.trim().isEmpty && minutes == null;

  ShotTime copyWith({
    Value<String?>? from,
    Value<String?>? to,
    String? note,
    Value<int?>? minutes,
  }) => ShotTime(
    from: from == null ? this.from : from.value,
    to: to == null ? this.to : to.value,
    note: note ?? this.note,
    minutes: minutes == null ? this.minutes : minutes.value,
  );

  static ShotTime of(ShootDocumentBlock block) {
    final m = decodeBlockOverrides(block.contentOverridesJson)[_key];
    if (m is! Map) return const ShotTime();
    return ShotTime(
      from: m['from'] as String?,
      to: m['to'] as String?,
      note: m['note'] as String? ?? '',
      minutes: (m['minutes'] as num?)?.toInt(),
    );
  }

  String writeInto(String? json) {
    final all = decodeBlockOverrides(json);
    if (isEmpty) {
      all.remove(_key);
    } else {
      all[_key] = {
        'from': ?from,
        'to': ?to,
        if (note.trim().isNotEmpty) 'note': note.trim(),
        'minutes': ?minutes,
      };
    }
    return jsonEncode(all);
  }
}

/// «08:30» en minutos desde medianoche; nulo si no se entiende.
int? parseClock(String? text) {
  final m = RegExp(r'^\s*(\d{1,2})[:.h](\d{2})\s*$').firstMatch(text ?? '');
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/// Minutos desde medianoche en «HH:mm»; pasada la medianoche vuelve a 00.
String formatClock(int minutes) {
  final m = minutes % (24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

/// «45 min», «1 h», «1 h 30».
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

/// Lo que va de [from] a [to], también si pasa la medianoche.
int? clockSpan(String? from, String? to) {
  final a = parseClock(from);
  final b = parseClock(to);
  if (a == null || b == null) return null;
  final span = b - a;
  return span >= 0 ? span : span + 24 * 60;
}

/// Inicio y fin de algo del orden, en minutos desde la medianoche del día
/// (pueden pasar de 24 h).
typedef ShootSpan = ({int start, int end});

/// Un aviso del horario sobre un bloque: «Se solapa con lo anterior».
class ShootScheduleWarning {
  final int blockId;
  final String text;

  const ShootScheduleWarning(this.blockId, this.text);
}

/// Las horas de la jornada calculadas en cadena.
class ShootDaySchedule {
  /// Por bloque: cada franja y cada plano.
  final Map<int, ShootSpan> spans;

  /// Cada escena entera, por su primer bloque (que suele ser también su
  /// primer plano: por eso va aparte).
  final Map<int, ShootSpan> sceneSpans;

  /// Duración de cada escena, por su primer bloque.
  final Map<int, int> sceneMinutes;
  final List<ShootScheduleWarning> warnings;

  /// Cuándo acaba lo último con hora.
  final int? end;

  const ShootDaySchedule(
    this.spans,
    this.sceneSpans,
    this.sceneMinutes,
    this.warnings,
    this.end,
  );

  String? warningOf(int blockId) =>
      warnings.where((w) => w.blockId == blockId).firstOrNull?.text;
}

/// Una hora escrita antes de que hubiera duraciones (a mano o al importar
/// el plan) se respeta como fijada: encadenarla se comería los huecos del
/// plan. Al soltarla, o al darle una duración, pasa a encadenarse.
bool _legacyPinned(String? from, bool legacy, bool pinned) =>
    pinned || (legacy && parseClock(from) != null);

bool stripIsPinned(ShootStrip s) => _legacyPinned(s.from, s.legacy, s.pinned);

bool sceneIsPinned(SceneSchedule s) =>
    _legacyPinned(s.from, s.legacy, s.pinned);

/// Duración de cada plano de [entry] (nula si no tiene).
List<int?> _shotMinutes(ShootSceneEntry entry, Map<int, Shot> shots) => [
  for (final b in entry.shotBlocks(shots))
    ShotTime.of(b).minutes ??
        clockSpan(ShotTime.of(b).from, ShotTime.of(b).to),
];

/// Duración de la escena: lo que suman sus planos si alguno tiene, si no
/// la suya.
int? sceneDurationOf(ShootSceneEntry entry, Map<int, Shot> shots) {
  final perShot = _shotMinutes(entry, shots).nonNulls.toList();
  if (perShot.isNotEmpty) return perShot.fold<int>(0, (a, b) => a + b);
  final s = SceneSchedule.of(entry.blocks.first);
  return s.minutes ?? clockSpan(s.from, s.to);
}

/// Calcula las horas de [entries] en cadena: cada cosa empieza cuando acaba
/// la anterior, salvo las fijadas, que empiezan a su hora. El día arranca en
/// [dayStart] o, sin él, en la primera hora que haya escrita.
ShootDaySchedule scheduleShootDay(
  List<ShootDayEntry> entries,
  Map<int, Shot> shots, {
  String? dayStart,
  String? dayEnd,
}) {
  final spans = <int, ShootSpan>{};
  final sceneSpans = <int, ShootSpan>{};
  final sceneMinutes = <int, int>{};
  final warnings = <ShootScheduleWarning>[];

  ({String? from, bool pinned, int? minutes, int blockId}) head(
    ShootDayEntry entry,
  ) => switch (entry) {
    ShootStripEntry(:final block, :final strip) => (
      from: strip.from,
      pinned: stripIsPinned(strip),
      minutes: strip.minutes ?? clockSpan(strip.from, strip.to),
      blockId: block.id,
    ),
    final ShootSceneEntry scene => (
      from: SceneSchedule.of(scene.blocks.first).from,
      pinned: sceneIsPinned(SceneSchedule.of(scene.blocks.first)),
      minutes: sceneDurationOf(scene, shots),
      blockId: scene.blocks.first.id,
    ),
  };

  int? cursor = parseClock(dayStart);
  if (cursor == null) {
    for (final e in entries) {
      final from = parseClock(head(e).from);
      if (from != null) {
        cursor = from;
        break;
      }
    }
  }
  int? lastEnd;
  for (final entry in entries) {
    final h = head(entry);
    final from = parseClock(h.from);
    // Sin duración ni hora fijada no tiene hora: no se inventa una.
    if (h.minutes == null && !h.pinned) continue;
    int? start;
    if (h.pinned && from != null) {
      var pinnedAt = from;
      // Lo de antes puede pasar de medianoche: la hora fijada es la del
      // mismo día o la del siguiente, lo que quede después.
      while (cursor != null && pinnedAt + 12 * 60 < cursor) {
        pinnedAt += 24 * 60;
      }
      start = pinnedAt;
      if (cursor != null && cursor > pinnedAt) {
        warnings.add(
          ShootScheduleWarning(
            h.blockId,
            'Lo anterior acaba a las ${formatClock(cursor)}',
          ),
        );
      }
    } else {
      start = cursor;
    }
    if (start == null) continue;
    final minutes = h.minutes ?? 0;
    final end = start + minutes;
    if (entry is ShootStripEntry) spans[h.blockId] = (start: start, end: end);
    if (entry is ShootSceneEntry) {
      sceneSpans[h.blockId] = (start: start, end: end);
      sceneMinutes[h.blockId] = minutes;
      var at = start;
      final perShot = _shotMinutes(entry, shots);
      for (final (i, b) in entry.shotBlocks(shots).indexed) {
        final m = perShot[i];
        if (m == null) continue;
        spans[b.id] = (start: at, end: at + m);
        at += m;
      }
    }
    cursor = end;
    lastEnd = end;
  }
  final limit = parseClock(dayEnd);
  if (limit != null && lastEnd != null && entries.isNotEmpty) {
    var until = limit;
    final origin = parseClock(dayStart);
    if (origin != null && until < origin) until += 24 * 60;
    if (lastEnd > until) {
      final lastId = head(entries.last).blockId;
      warnings.add(
        ShootScheduleWarning(
          lastId,
          'La jornada acaba a las ${formatClock(until)}; esto llega a las '
          '${formatClock(lastEnd)}',
        ),
      );
    }
  }
  return ShootDaySchedule(spans, sceneSpans, sceneMinutes, warnings, lastEnd);
}

/// Cambios de `contentOverridesJson` para guardar las horas de [schedule]
/// en cada bloque: así el PDF, el calendario y En set las leen sin calcular.
/// Lo que ya tenía horas escritas a mano pasa a guardar su duración.
Map<int, String> scheduleChanges(
  List<ShootDayEntry> entries,
  Map<int, Shot> shots,
  ShootDaySchedule schedule,
) {
  final changes = <int, String>{};
  void put(ShootDocumentBlock block, String json) {
    if (json != (block.contentOverridesJson ?? '')) changes[block.id] = json;
  }

  for (final entry in entries) {
    switch (entry) {
      case ShootStripEntry(:final block, :final strip):
        final span = schedule.spans[block.id];
        if (span == null) continue;
        final timed = strip.minutes != null || clockSpan(strip.from, strip.to) != null;
        put(
          block,
          strip
              .copyWith(
                from: Value(formatClock(span.start)),
                to: Value(timed ? formatClock(span.end) : null),
                minutes: Value(timed ? span.end - span.start : null),
                pinned: stripIsPinned(strip),
              )
              .writeInto(block.contentOverridesJson),
        );
      case final ShootSceneEntry scene:
        final first = scene.blocks.first;
        final span = schedule.sceneSpans[first.id];
        if (span == null) continue;
        final own = SceneSchedule.of(first);
        final shotsHaveTime = _shotMinutes(scene, shots).any((m) => m != null);
        final timed = sceneDurationOf(scene, shots) != null;
        final sceneJson = own
            .copyWith(
              from: Value(formatClock(span.start)),
              to: Value(timed ? formatClock(span.end) : null),
              minutes: shotsHaveTime || !timed
                  ? null
                  : Value(own.minutes ?? (span.end - span.start)),
              pinned: sceneIsPinned(own),
            )
            .writeInto(first.contentOverridesJson);
        final written = <int, String>{first.id: sceneJson};
        for (final b in scene.shotBlocks(shots)) {
          final s = schedule.spans[b.id];
          if (s == null) continue;
          final base = written[b.id] ?? b.contentOverridesJson;
          final time = ShotTime.of(b);
          written[b.id] = time
              .copyWith(
                from: Value(formatClock(s.start)),
                to: Value(formatClock(s.end)),
                minutes: Value(s.end - s.start),
              )
              .writeInto(base);
        }
        for (final b in scene.blocks) {
          if (written[b.id] case final json?) put(b, json);
        }
    }
  }
  return changes;
}

/// La escena de un bloque. Manda la del plano: un plano que cambia de escena
/// se ve igual en el tablero, en la jornada y en el set.
int? shootBlockSceneId(ShootDocumentBlock block, Map<int, Shot> shots) =>
    shots[block.shotId]?.sceneId ?? block.sceneId;

/// Una línea del orden de rodaje: una escena o una franja.
sealed class ShootDayEntry {
  const ShootDayEntry();

  List<int> get blockIds;
}

class ShootSceneEntry extends ShootDayEntry {
  final int sceneId;

  /// Los bloques seguidos de la escena, con sus planos y, si los hay, la
  /// fila de escena sin planos.
  final List<ShootDocumentBlock> blocks;

  const ShootSceneEntry(this.sceneId, this.blocks);

  @override
  List<int> get blockIds => [for (final b in blocks) b.id];

  List<ShootDocumentBlock> shotBlocks(Map<int, Shot> shots) => [
    for (final b in blocks)
      if (shots.containsKey(b.shotId)) b,
  ];
}

class ShootStripEntry extends ShootDayEntry {
  final ShootDocumentBlock block;

  const ShootStripEntry(this.block);

  ShootStrip get strip => ShootStrip.of(block);

  @override
  List<int> get blockIds => [block.id];
}

/// El orden de rodaje de una jornada, en líneas. Una sola lectura para el
/// tablero, la jornada y los documentos, para que siempre coincidan.
List<ShootDayEntry> buildShootDayEntries(
  List<ShootDocumentBlock> blocks,
  Map<int, Shot> shots,
) {
  final entries = <ShootDayEntry>[];
  for (final block in blocks) {
    if (ShootStrip.isStrip(block)) {
      entries.add(ShootStripEntry(block));
      continue;
    }
    final isScene =
        block.blockType == ShootBlockType.sceneHeader ||
        (block.blockType == ShootBlockType.shot &&
            shots.containsKey(block.shotId));
    final sceneId = isScene ? shootBlockSceneId(block, shots) : null;
    if (sceneId == null) continue;
    final last = entries.lastOrNull;
    if (last is ShootSceneEntry && last.sceneId == sceneId) {
      last.blocks.add(block);
    } else {
      entries.add(ShootSceneEntry(sceneId, [block]));
    }
  }
  return entries;
}

/// Todos los bloques en el orden de [entries]; lo que no sale en ellas va al
/// final, para que renumerar no deje empates.
List<int> shootDayOrderOf(
  List<ShootDayEntry> entries,
  List<ShootDocumentBlock> blocks,
) {
  final ordered = [for (final e in entries) ...e.blockIds];
  final seen = ordered.toSet();
  return [
    ...ordered,
    for (final b in blocks)
      if (!seen.contains(b.id)) b.id,
  ];
}

/// [entries] tras llevar la línea [from] al puesto [to], ya el definitivo.
List<ShootDayEntry> moveShootDayEntry(
  List<ShootDayEntry> entries,
  int from,
  int to,
) {
  final next = [...entries];
  next.insert(to, next.removeAt(from));
  return next;
}

/// Cambios de `contentOverridesJson` para que la hora de cada escena siga
/// en el primer bloque de su tramo con el orden [nextIds]. Si dos tramos con
/// hora se juntan, la del segundo queda guardada sin mostrarse.
Map<int, String> carrySceneSchedule(
  List<ShootDocumentBlock> blocks,
  List<int> nextIds,
  Map<int, Shot> shots,
) {
  final byId = {for (final b in blocks) b.id: b};
  final ordered = [
    for (final id in nextIds)
      if (byId[id] case final block?) block,
  ];
  final changes = <int, String>{};
  for (final entry in buildShootDayEntries(ordered, shots)) {
    if (entry is! ShootSceneEntry) continue;
    final first = entry.blocks.first;
    if (!SceneSchedule.of(first).isEmpty) continue;
    final holder = entry.blocks
        .where((b) => !SceneSchedule.of(b).isEmpty)
        .firstOrNull;
    if (holder == null) continue;
    changes[first.id] = SceneSchedule.of(
      holder,
    ).writeInto(first.contentOverridesJson);
    changes[holder.id] = const SceneSchedule().writeInto(
      holder.contentOverridesJson,
    );
  }
  return changes;
}

/// Una línea para los documentos: «08:00 Montaje · Esc 8 · 14:00 Comida».
/// `null` si la jornada no tiene franjas ni horas de escena.
String? shootDayScheduleLine(
  List<ShootDocumentBlock> blocks,
  Map<int, Shot> shots,
  Map<int, Scene> scenes,
) {
  final entries = buildShootDayEntries(blocks, shots);
  var anySchedule = false;
  final parts = <String>[];
  for (final entry in entries) {
    switch (entry) {
      case ShootStripEntry(:final block, :final strip):
        anySchedule = true;
        parts.add(
          [
            shootTimeRange(strip.from, strip.to),
            ShootStrip.titleOf(block),
          ].where((s) => s.isNotEmpty).join(' '),
        );
      case ShootSceneEntry(:final sceneId, :final blocks):
        final schedule = SceneSchedule.of(blocks.first);
        final label = scenes[sceneId]?.label;
        if (schedule.from != null || schedule.to != null) anySchedule = true;
        parts.add(
          [
            shootTimeRange(schedule.from, schedule.to),
            'Esc ${label ?? '—'}',
          ].where((s) => s.isNotEmpty).join(' '),
        );
    }
  }
  return anySchedule ? parts.join(' · ') : null;
}

/// Lo que se escribe al crear o editar una franja.
class ShootStripDraft {
  final ShootStrip strip;
  final String label;
  final String note;

  const ShootStripDraft({required this.strip, this.label = '', this.note = ''});

  Value<String?> get labelValue =>
      Value(label.trim().isEmpty ? null : label.trim());
  Value<String?> get noteValue =>
      Value(note.trim().isEmpty ? null : note.trim());
}

/// Cambios del orden y las franjas de una jornada.
class ShootDayScheduleService {
  final AppDatabase db;

  const ShootDayScheduleService(this.db);

  Future<int> addStrip(
    int dayId,
    ShootStripDraft draft, {
    int? beforeBlockId,
  }) async {
    final id = await db.insertShootDocumentBlock(
      ShootDocumentBlocksCompanion.insert(
        documentId: dayId,
        blockType: ShootBlockType.schedule,
        customLabel: draft.labelValue,
        noteBody: draft.noteValue,
        contentOverridesJson: Value(draft.strip.writeInto(null)),
      ),
    );
    await db.arrangeShootDayBlocks(dayId, [id], beforeBlockId);
    return id;
  }

  Future<void> updateStrip(ShootDocumentBlock block, ShootStripDraft draft) =>
      db.updateShootDocumentBlock(
        block.copyWith(
          customLabel: draft.labelValue,
          noteBody: draft.noteValue,
          contentOverridesJson: Value(
            draft.strip.writeInto(block.contentOverridesJson),
          ),
        ),
      );

  Future<void> setSceneSchedule(
    ShootDocumentBlock block,
    SceneSchedule schedule,
  ) => db.updateShootDocumentBlock(
    block.copyWith(
      contentOverridesJson: Value(
        schedule.writeInto(block.contentOverridesJson),
      ),
    ),
  );

  /// Fija el orden [nextIds] llevando con cada escena su hora y vuelve a
  /// calcular las horas en cadena desde [dayStart]. Devuelve cómo
  /// deshacerlo.
  Future<Future<void> Function()> applyOrder(
    int dayId,
    List<ShootDocumentBlock> blocks,
    List<int> nextIds,
    Map<int, Shot> shots, {
    String? dayStart,
    String? dayEnd,
  }) => edit(
    dayId,
    blocks,
    shots,
    order: nextIds,
    carry: true,
    dayStart: dayStart,
    dayEnd: dayEnd,
  );

  /// Escribe [edits] (json por bloque), pone el orden [order] si lo hay y
  /// recalcula las horas de toda la jornada. Devuelve cómo deshacerlo.
  Future<Future<void> Function()> edit(
    int dayId,
    List<ShootDocumentBlock> blocks,
    Map<int, Shot> shots, {
    Map<int, String> edits = const {},
    List<int>? order,
    bool carry = false,
    String? dayStart,
    String? dayEnd,
  }) async {
    final nextIds = order ?? [for (final b in blocks) b.id];
    List<ShootDocumentBlock> apply(
      List<ShootDocumentBlock> list,
      Map<int, String> json,
    ) => [
      for (final b in list)
        json.containsKey(b.id)
            ? b.copyWith(contentOverridesJson: Value(json[b.id]))
            : b,
    ];
    final changes = <int, String>{...edits};
    var current = apply(blocks, changes);
    if (carry) {
      changes.addAll(carrySceneSchedule(current, nextIds, shots));
      current = apply(blocks, changes);
    }
    final byId = {for (final b in current) b.id: b};
    final ordered = [
      for (final id in nextIds)
        if (byId[id] case final b?) b,
    ];
    final entries = buildShootDayEntries(ordered, shots);
    changes.addAll(
      scheduleChanges(
        entries,
        shots,
        scheduleShootDay(entries, shots, dayStart: dayStart, dayEnd: dayEnd),
      ),
    );
    final before = [for (final b in blocks) b.id];
    final undoJson = {
      for (final b in blocks)
        if (changes.containsKey(b.id)) b.id: b.contentOverridesJson,
    };
    await db.applyShootDayOrder(dayId, nextIds, changes);
    return () => db.applyShootDayOrder(dayId, before, undoJson);
  }
}
