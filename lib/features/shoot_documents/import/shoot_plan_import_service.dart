import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/database/shoot_block_overrides.dart';
import '../shoot_day_timeline.dart';
import '../shoot_document_block_types.dart';
import '../shoot_plan.dart';
import 'shoot_plan_text_parser.dart';

/// Un día del plan leído y la jornada del proyecto a la que va.
class ShootPlanImportDay {
  final ParsedShootDay parsed;

  /// La jornada que ya existe con esa fecha o ese número; `null` si se crea.
  final ShootDocument? existing;

  /// Planos del día que el proyecto tiene.
  final int shots;

  const ShootPlanImportDay(this.parsed, this.existing, this.shots);
}

/// Lo que pasará al importar, para enseñarlo antes de tocar nada.
class ShootPlanImportPreview {
  final ParsedShootPlan plan;
  final List<ShootPlanImportDay> days;

  /// Escenas del plan que el proyecto no tiene: «99».
  final List<String> missingScenes;

  /// Planos del plan que el proyecto no tiene: «7.9».
  final List<String> missingShots;

  const ShootPlanImportPreview({
    required this.plan,
    required this.days,
    required this.missingScenes,
    required this.missingShots,
  });

  int get shots => days.fold(0, (a, d) => a + d.shots);
}

String _sceneKey(Scene s) =>
    '${s.number}${(s.numberSuffix ?? '').toUpperCase()}';

class _Draft {
  final String type;
  final int? sceneId;
  final int? shotId;
  final String? label;
  final String? note;
  final String? from;
  final String? to;
  final ShootStripKind? kind;

  /// Solo aporta hora y nota a su escena: no se guarda como bloque si la
  /// escena tiene planos al lado.
  final bool ghost;

  const _Draft({
    required this.type,
    this.sceneId,
    this.shotId,
    this.label,
    this.note,
    this.from,
    this.to,
    this.kind,
    this.ghost = false,
  });
}

/// Cómo estaban las jornadas antes de importar, para «Deshacer».
class ShootPlanImportUndo {
  final List<ShootDocument> days;
  final List<ShootDocumentBlock> blocks;

  const ShootPlanImportUndo(this.days, this.blocks);
}

/// Lleva un plan de rodaje leído a las jornadas del proyecto.
class ShootPlanImportService {
  final AppDatabase db;

  const ShootPlanImportService(this.db);

  Future<ShootPlanImportUndo> snapshot(int projectId) async =>
      ShootPlanImportUndo([
        for (final d in await db.getShootDocumentsForProject(projectId))
          if (d.kind == kShootDayKind) d,
      ], await db.getShootDayBlocks(projectId));

  /// Vuelve las jornadas a [before]: quita las creadas al importar y
  /// devuelve fechas, horas y orden. Las marcas de En set apuntadas después
  /// se quedan.
  Future<void> undo(int projectId, ShootPlanImportUndo before) async {
    final keep = {for (final d in before.days) d.id};
    await db.transaction(() async {
      for (final d in await db.getShootDocumentsForProject(projectId)) {
        if (d.kind == kShootDayKind && !keep.contains(d.id)) {
          await db.deleteShootDocument(d.id);
        }
      }
      for (final d in before.days) {
        if (await db.getShootDocument(d.id) != null) {
          await db.updateShootDocument(d);
        }
      }
      await db.restoreShootDayBlocks(projectId, before.blocks);
    });
  }

  Future<ShootPlanImportPreview> preview(
    int projectId,
    ParsedShootPlan plan,
  ) async {
    final scenes = await db.watchScenesForProject(projectId).first;
    final shots = await db.getShotsForProject(projectId);
    final sceneByKey = {for (final s in scenes) _sceneKey(s): s};
    final existing = sortShootDays(
      await db.getShootDocumentsForProject(projectId),
    );
    final taken = <int>{};
    final missingScenes = <String>{};
    final missingShots = <String>[];
    final days = <ShootPlanImportDay>[];
    for (final day in plan.days) {
      ShootDocument? match;
      if (day.date != null) {
        match = existing
            .where((d) => d.shootDate == day.date && !taken.contains(d.id))
            .firstOrNull;
      }
      match ??= existing
          .where(
            (d) =>
                d.shootDate == null &&
                !taken.contains(d.id) &&
                d.name.trim() == 'Jornada ${day.number}',
          )
          .firstOrNull;
      if (match != null) taken.add(match.id);
      var count = 0;
      for (final line in day.lines) {
        switch (line) {
          case ParsedPlanScene(:final scene):
            if (!sceneByKey.containsKey(scene)) missingScenes.add(scene);
          case ParsedPlanShot(:final scene, :final shot):
            final s = sceneByKey[scene];
            if (s == null) {
              missingScenes.add(scene);
            } else if (shots.any(
              (x) => x.sceneId == s.id && x.number == shot,
            )) {
              count++;
            } else {
              missingShots.add('$scene.$shot');
            }
          case ParsedPlanStrip():
            break;
        }
      }
      days.add(ShootPlanImportDay(day, match, count));
    }
    return ShootPlanImportPreview(
      plan: plan,
      days: days,
      missingScenes: missingScenes.toList(),
      missingShots: missingShots,
    );
  }

  /// Escribe el plan. Cada jornada emparejada cambia su orden por el del
  /// plan y conserva las marcas de En set de los planos que siguen en ella.
  /// Devuelve las jornadas escritas.
  Future<List<int>> apply(int projectId, ShootPlanImportPreview preview) async {
    final scenes = await db.watchScenesForProject(projectId).first;
    final shots = await db.getShotsForProject(projectId);
    final sceneByKey = {for (final s in scenes) _sceneKey(s): s};
    final written = <int>[];
    await db.transaction(() async {
      for (final day in preview.days) {
        final parsed = day.parsed;
        final drafts = _drafts(parsed, sceneByKey, shots);
        final sites = {
          for (final d in drafts)
            if (d.sceneId != null)
              scenes.firstWhere((s) => s.id == d.sceneId).locationSiteId,
        }..remove(null);
        final site = sites.length == 1 ? sites.first : null;

        var doc = day.existing;
        if (doc == null) {
          final all = await db.getShootDocumentsForProject(projectId);
          final id = await db.insertShootDocument(
            ShootDocumentsCompanion.insert(
              projectId: projectId,
              name: nextShootDayName(all.where((d) => d.kind == kShootDayKind)),
              kind: const Value(kShootDayKind),
            ),
          );
          doc = (await db.getShootDocument(id))!;
        }
        await db.updateShootDocument(
          doc.copyWith(
            shootDate: Value(parsed.date ?? doc.shootDate),
            shootFromTime: Value(parsed.from ?? doc.shootFromTime),
            shootToTime: Value(parsed.to ?? doc.shootToTime),
            description: Value(
              parsed.note.trim().isEmpty ? doc.description : parsed.note.trim(),
            ),
            locationSiteId: Value(doc.locationSiteId ?? site),
            updatedAt: DateTime.now(),
          ),
        );

        final old = await db.getBlocksForShootDocument(doc.id);
        final marks = <int, Object?>{
          for (final b in old)
            if (b.shotId != null)
              b.shotId!: decodeBlockOverrides(b.contentOverridesJson)['onSet'],
        }..removeWhere((_, v) => v == null);
        for (final b in old) {
          await db.deleteShootDocumentBlock(b.id);
        }

        final blocks = _withSceneSchedules(drafts);
        for (final (i, b) in blocks.indexed) {
          var json = b.json;
          final mark = marks[b.draft.shotId];
          if (mark != null) {
            json = jsonEncode(decodeBlockOverrides(json)..['onSet'] = mark);
          }
          await db.insertShootDocumentBlock(
            ShootDocumentBlocksCompanion.insert(
              documentId: doc.id,
              blockType: b.draft.type,
              sortOrder: Value(i),
              sceneId: Value(b.draft.sceneId),
              shotId: Value(b.draft.shotId),
              customLabel: Value(b.draft.label),
              noteBody: Value(b.draft.note),
              contentOverridesJson: Value(json),
            ),
          );
        }
        written.add(doc.id);
      }
    });
    await db.touchProjectContent(projectId);
    return written;
  }

  List<_Draft> _drafts(
    ParsedShootDay day,
    Map<String, Scene> sceneByKey,
    List<Shot> shots,
  ) {
    final out = <_Draft>[];
    for (final line in day.lines) {
      switch (line) {
        case ParsedPlanStrip():
          out.add(
            _Draft(
              type: ShootBlockType.schedule,
              kind: line.kind,
              label: line.label.isEmpty || line.label == line.kind.label
                  ? null
                  : line.label,
              note: line.note.isEmpty ? null : line.note,
              from: line.from,
              to: line.to,
            ),
          );
        case ParsedPlanScene():
          final scene = sceneByKey[line.scene];
          out.add(
            scene == null
                ? _Draft(
                    type: ShootBlockType.schedule,
                    kind: ShootStripKind.note,
                    label: 'Escena ${line.scene}',
                    note: line.note.isEmpty ? null : line.note,
                    from: line.from,
                    to: line.to,
                  )
                : _Draft(
                    type: ShootBlockType.sceneHeader,
                    sceneId: scene.id,
                    note: line.note,
                    from: line.from,
                    to: line.to,
                    ghost: true,
                  ),
          );
        case ParsedPlanShot():
          final scene = sceneByKey[line.scene];
          final shot = scene == null
              ? null
              : shots
                    .where(
                      (s) => s.sceneId == scene.id && s.number == line.shot,
                    )
                    .firstOrNull;
          final name = '${line.scene}.${line.shot}';
          if (scene == null) {
            out.add(
              _Draft(
                type: ShootBlockType.schedule,
                kind: ShootStripKind.note,
                label: 'Plano $name',
                note: line.text.isEmpty ? null : line.text,
                from: line.from,
                to: line.to,
              ),
            );
          } else if (shot == null) {
            out.add(
              _Draft(
                type: ShootBlockType.sceneHeader,
                sceneId: scene.id,
                note: 'Plano $name (no está en el guion): ${line.text}'.trim(),
                from: line.from,
                to: line.to,
                ghost: true,
              ),
            );
          } else {
            out.add(
              _Draft(
                type: ShootBlockType.shot,
                sceneId: scene.id,
                shotId: shot.id,
                note: line.text,
                from: line.from,
                to: line.to,
              ),
            );
          }
      }
    }
    return out;
  }
}

class _Block {
  final _Draft draft;
  final String? json;

  const _Block(this.draft, this.json);
}

int? _min(String? hm) {
  if (hm == null) return null;
  final p = hm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// Junta cada escena seguida en un tramo: la primera fila guarda su hora y
/// su nota, y las líneas que solo las aportaban desaparecen.
List<_Block> _withSceneSchedules(List<_Draft> drafts) {
  final out = <_Block>[];
  var i = 0;
  while (i < drafts.length) {
    final d = drafts[i];
    if (d.sceneId == null) {
      out.add(
        _Block(
          d,
          ShootStrip(
            kind: d.kind ?? ShootStripKind.note,
            from: d.from,
            to: d.to,
          ).writeInto(null),
        ),
      );
      i++;
      continue;
    }
    var j = i;
    while (j < drafts.length && drafts[j].sceneId == d.sceneId) {
      j++;
    }
    final tract = drafts.sublist(i, j);
    final real = tract.where((t) => !t.ghost).toList();
    final notes = [
      for (final t in tract)
        if (t.ghost && (t.note ?? '').trim().isNotEmpty) t.note!.trim(),
    ];
    final from = tract.map((t) => t.from).whereType<String>().firstOrNull;
    String? to;
    for (final t in tract) {
      final end = t.to;
      if (end == null) continue;
      // Pasada la medianoche, la hora mayor ya no es la última.
      if (to == null || _min(end)! >= _min(to)! || _min(end)! < 6 * 60) {
        to = end;
      }
    }
    final schedule = SceneSchedule(from: from, to: to, note: notes.join(' · '));
    final rows = real.isEmpty
        ? [_Draft(type: ShootBlockType.sceneHeader, sceneId: d.sceneId)]
        : real;
    for (final (k, row) in rows.indexed) {
      String? json;
      if (row.shotId != null) {
        json = ShotTime(
          from: row.from,
          to: row.to,
          note: row.note ?? '',
        ).writeInto(json);
      }
      if (k == 0 && !schedule.isEmpty) json = schedule.writeInto(json);
      out.add(
        _Block(
          _Draft(type: row.type, sceneId: row.sceneId, shotId: row.shotId),
          json,
        ),
      );
    }
    i = j;
  }
  return out;
}
