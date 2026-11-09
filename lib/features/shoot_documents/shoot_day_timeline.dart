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

  const ShootStrip({
    this.kind = ShootStripKind.note,
    this.from,
    this.to,
    this.siteUid,
  });

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

  const SceneSchedule({this.from, this.to, this.note = ''});

  bool get isEmpty => from == null && to == null && note.trim().isEmpty;

  static SceneSchedule of(ShootDocumentBlock block) {
    final m = decodeBlockOverrides(block.contentOverridesJson)[_key];
    if (m is! Map) return const SceneSchedule();
    return SceneSchedule(
      from: m['from'] as String?,
      to: m['to'] as String?,
      note: m['note'] as String? ?? '',
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
      };
    }
    return jsonEncode(all);
  }
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

  /// Fija el orden [nextIds] llevando con cada escena su hora. Devuelve cómo
  /// deshacerlo.
  Future<Future<void> Function()> applyOrder(
    int dayId,
    List<ShootDocumentBlock> blocks,
    List<int> nextIds,
    Map<int, Shot> shots,
  ) async {
    final changes = carrySceneSchedule(blocks, nextIds, shots);
    final before = [for (final b in blocks) b.id];
    final undoJson = {
      for (final b in blocks)
        if (changes.containsKey(b.id)) b.id: b.contentOverridesJson,
    };
    await db.applyShootDayOrder(dayId, nextIds, changes);
    return () => db.applyShootDayOrder(dayId, before, undoJson);
  }
}
