import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import '../../core/database/shoot_block_overrides.dart';
import '../../shared/history/edit_history.dart';
import '../camera_plan/camera_plan_grouping.dart';
import 'shoot_day_timeline.dart';
import 'shoot_document_block_types.dart';

/// Tipo de documento de una jornada de rodaje.
const kShootDayKind = 'technical_day';

/// Las jornadas en orden de rodaje: las ya ordenadas a mano y, detrás, las
/// demás por fecha.
List<ShootDocument> sortShootDays(Iterable<ShootDocument> docs) {
  int rank(ShootDocument d) => d.dayOrder ?? 1 << 30;
  return docs.where((d) => d.kind == kShootDayKind).toList()..sort((a, b) {
    final order = rank(a).compareTo(rank(b));
    if (order != 0) return order;
    final date = (a.shootDate ?? '9999').compareTo(b.shootDate ?? '9999');
    return date != 0 ? date : a.id.compareTo(b.id);
  });
}

/// Nombre de una jornada nueva. Sale del mayor número usado, no del recuento:
/// tras borrar una, contar repetiría un nombre.
String nextShootDayName(Iterable<ShootDocument> days) {
  final pattern = RegExp(r'^Jornada (\d+)$');
  var last = 0;
  for (final day in days) {
    final match = pattern.firstMatch(day.name.trim());
    final number = match == null ? 0 : int.parse(match.group(1)!);
    if (number > last) last = number;
  }
  return 'Jornada ${last + 1}';
}

/// Una escena en «Sin asignar»: los planos que aún no tienen día.
class UnassignedScene {
  final Scene scene;
  final List<Shot> shots;

  /// Planos de la escena en total, para enseñar «2 de 5».
  final int total;

  const UnassignedScene(this.scene, this.shots, this.total);
}

/// Foto del plan de rodaje: qué lleva cada jornada y qué falta por colocar.
class ShootPlan {
  final List<ShootDocument> days;
  final Map<int, List<ShootDocumentBlock>> blocksByDay;
  final List<UnassignedScene> unassigned;

  /// En cuántas jornadas está cada plano.
  final Map<int, int> daysOfShot;

  const ShootPlan({
    required this.days,
    required this.blocksByDay,
    required this.unassigned,
    required this.daysOfShot,
  });

  factory ShootPlan.from({
    required List<ShootDocument> documents,
    required List<ShootDocumentBlock> blocks,
    required List<Scene> scenes,
    required List<Shot> shots,
  }) {
    final days = sortShootDays(documents);
    final blocksByDay = {
      for (final day in days)
        day.id: blocks.where((b) => b.documentId == day.id).toList()
          ..sort((a, b) {
            final order = a.sortOrder.compareTo(b.sortOrder);
            return order != 0 ? order : a.id.compareTo(b.id);
          }),
    };
    final daysOfShot = <int, int>{};
    final scheduledScenes = <int>{};
    for (final dayBlocks in blocksByDay.values) {
      final inDay = <int>{};
      for (final block in dayBlocks) {
        if (block.sceneId != null) scheduledScenes.add(block.sceneId!);
        if (block.shotId != null) inDay.add(block.shotId!);
      }
      for (final id in inDay) {
        daysOfShot[id] = (daysOfShot[id] ?? 0) + 1;
      }
    }
    final unassigned = <UnassignedScene>[];
    for (final scene in scenesInScriptOrder(scenes)) {
      final ofScene = shots.where((s) => s.sceneId == scene.id).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final free = ofScene.where((s) => !daysOfShot.containsKey(s.id)).toList();
      // Una escena sin planos cuenta como colocada si ya tiene su sitio.
      final missing = ofScene.isEmpty
          ? !scheduledScenes.contains(scene.id)
          : free.isNotEmpty;
      if (missing) {
        unassigned.add(UnassignedScene(scene, free, ofScene.length));
      }
    }
    return ShootPlan(
      days: days,
      blocksByDay: blocksByDay,
      unassigned: unassigned,
      daysOfShot: daysOfShot,
    );
  }
}

/// Lo que se coloca en un día: un plano o, si la escena no tiene planos,
/// la escena.
typedef ShootPlanItem = ({int sceneId, int? shotId});

/// Cambios del plan de rodaje. Cada uno se puede deshacer.
class ShootPlanService {
  final AppDatabase db;
  final EditHistory? history;

  const ShootPlanService(this.db, {this.history});

  Future<int> addDay(int projectId) async {
    final existing = await db.getShootDocumentsForProject(projectId);
    return db.insertShootDocument(
      ShootDocumentsCompanion.insert(
        projectId: projectId,
        name: nextShootDayName(existing.where((d) => d.kind == kShootDayKind)),
        kind: const Value(kShootDayKind),
      ),
    );
  }

  /// Una copia de [dayId] justo detrás, con su orden, horas y franjas, y sin
  /// las marcas de En set ni la fecha. Devuelve la jornada nueva.
  Future<int> duplicateDay(int projectId, int dayId) async {
    Future<int> make() async {
      final day = (await db.getShootDocument(dayId))!;
      final all = sortShootDays(await db.getShootDocumentsForProject(projectId));
      final id = await db.insertShootDocument(
        ShootDocumentsCompanion.insert(
          projectId: projectId,
          name: nextShootDayName(all),
          kind: const Value(kShootDayKind),
          description: Value(day.description),
          locationSiteId: Value(day.locationSiteId),
          shootFromTime: Value(day.shootFromTime),
          shootToTime: Value(day.shootToTime),
        ),
      );
      for (final b in await db.getBlocksForShootDocument(dayId)) {
        final json = decodeBlockOverrides(b.contentOverridesJson)
          ..remove('onSet');
        await db.insertShootDocumentBlock(
          b
              .toCompanion(true)
              .copyWith(
                id: const Value.absent(),
                documentId: Value(id),
                contentOverridesJson: Value(
                  json.isEmpty ? null : jsonEncode(json),
                ),
              ),
        );
      }
      final order = [for (final d in all) d.id];
      order.insert(order.indexOf(dayId) + 1, id);
      await reorderDays(projectId, order);
      return id;
    }

    var id = await make();
    history?.record(
      EditStep(
        label: 'duplicar jornada',
        undo: () => db.deleteShootDocument(id),
        redo: () async => id = await make(),
      ),
    );
    return id;
  }

  /// Borra la jornada; sus planos vuelven a «Sin asignar». Se puede deshacer
  /// mientras la pantalla esté abierta.
  Future<void> deleteDay(int projectId, int dayId) async {
    final day = await db.getShootDocument(dayId);
    if (day == null) return;
    final blocks = await db.getShootDayBlocks(projectId);
    final order = [
      for (final d in sortShootDays(
        await db.getShootDocumentsForProject(projectId),
      ))
        d.id,
    ];
    await db.deleteShootDocument(dayId);
    history?.record(
      EditStep(
        label: 'borrar ${day.name}',
        undo: () async {
          await db.into(db.shootDocuments).insert(day);
          await db.restoreShootDayBlocks(projectId, blocks);
          await reorderDays(projectId, order);
        },
        redo: () => db.deleteShootDocument(dayId),
      ),
    );
  }

  /// Fija el orden de las jornadas con [dayIds].
  Future<void> reorderDays(int projectId, List<int> dayIds) async {
    await db.setShootDayOrder(dayIds);
    await db.touchProjectContent(projectId);
  }

  /// Añade [items] a [dayId], antes del bloque [beforeBlockId] o al final.
  Future<void> place({
    required int projectId,
    required int dayId,
    required List<ShootPlanItem> items,
    int? beforeBlockId,
  }) => _recorded(projectId, 'añadir a la jornada', () async {
    final ids = <int>[
      for (final item in items)
        await db.insertShootDocumentBlock(
          ShootDocumentBlocksCompanion.insert(
            documentId: dayId,
            blockType: item.shotId == null
                ? ShootBlockType.sceneHeader
                : ShootBlockType.shot,
            sceneId: Value(item.sceneId),
            shotId: Value(item.shotId),
          ),
        ),
    ];
    await db.arrangeShootDayBlocks(dayId, ids, beforeBlockId);
  });

  /// Lleva [blockIds] a [dayId], con lo que ya llevaran (hecho, descartado).
  Future<void> move({
    required int projectId,
    required int dayId,
    required List<int> blockIds,
    int? beforeBlockId,
  }) => _recorded(
    projectId,
    'mover en el plan de rodaje',
    () => db.arrangeShootDayBlocks(dayId, blockIds, beforeBlockId),
  );

  /// Añade una franja a [dayId], antes de [beforeBlockId] o al final.
  Future<void> addStrip({
    required int projectId,
    required int dayId,
    required ShootStripDraft draft,
    int? beforeBlockId,
  }) => _recorded(
    projectId,
    'añadir franja',
    () => ShootDayScheduleService(
      db,
    ).addStrip(dayId, draft, beforeBlockId: beforeBlockId),
  );

  /// Saca [blockIds] de su jornada: vuelven a «Sin asignar».
  Future<void> remove({required int projectId, required List<int> blockIds}) =>
      _recorded(projectId, 'quitar de la jornada', () async {
        for (final id in blockIds) {
          await db.deleteShootDocumentBlock(id);
        }
      });

  Future<void> _recorded(
    int projectId,
    String label,
    Future<void> Function() action,
  ) async {
    final before = await db.getShootDayBlocks(projectId);
    await action();
    final after = await db.getShootDayBlocks(projectId);
    history?.record(
      EditStep(
        label: label,
        undo: () => db.restoreShootDayBlocks(projectId, before),
        redo: () => db.restoreShootDayBlocks(projectId, after),
      ),
    );
  }
}
