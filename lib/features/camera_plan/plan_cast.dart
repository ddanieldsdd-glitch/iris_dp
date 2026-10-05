import 'dart:ui';

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import 'camera_plan_constants.dart';
import '../../core/utils/scene_color.dart';

/// El reparto de un proyecto en las plantas: cada personaje, con su color.
/// El mismo nombre lleva siempre el mismo color, en todos los planos.
class PlanCast {
  PlanCast._();

  /// «Adil», «ADIL» y « adil » son el mismo personaje.
  static String key(String? name) => (name ?? '').trim().toUpperCase();

  /// Nombres genéricos («Actor 1») no son personajes: no fijan color.
  static bool isNamed(String? name) =>
      key(name).isNotEmpty && !RegExp(r'^ACTOR( \d+)?$').hasMatch(key(name));

  static Future<List<CameraPlanElement>> _actorRows(
    AppDatabase db,
    int projectId,
  ) async {
    final query =
        db.select(db.cameraPlanElements).join([
            innerJoin(
              db.shots,
              db.shots.id.equalsExp(db.cameraPlanElements.shotId),
            ),
          ])
          ..where(
            db.shots.projectId.equals(projectId) &
                db.cameraPlanElements.type.equals('actor'),
          )
          ..orderBy([OrderingTerm.asc(db.cameraPlanElements.id)]);
    final rows = await query.get();
    return [for (final r in rows) r.readTable(db.cameraPlanElements)];
  }

  /// Los personajes que ya salen en alguna planta del proyecto, con el
  /// nombre tal como se escribió la primera vez y su color.
  static Future<Map<String, ({String name, Color color})>> load(
    AppDatabase db,
    int projectId,
  ) async {
    final cast = <String, ({String name, Color color})>{};
    for (final row in await _actorRows(db, projectId)) {
      if (!isNamed(row.label)) continue;
      cast.putIfAbsent(
        key(row.label),
        () => (
          name: row.label!.trim(),
          color: colorFromHex(row.color) ?? kActorColors.first,
        ),
      );
    }
    return cast;
  }

  /// Cambia el color de un personaje en todas las plantas del proyecto.
  static Future<void> recolour(
    AppDatabase db,
    int projectId,
    String name,
    Color color,
  ) async {
    if (!isNamed(name)) return;
    final ids = [
      for (final row in await _actorRows(db, projectId))
        if (key(row.label) == key(name)) row.id,
    ];
    if (ids.isEmpty) return;
    await (db.update(db.cameraPlanElements)..where((e) => e.id.isIn(ids)))
        .write(CameraPlanElementsCompanion(color: Value(hexFromColor(color))));
    await db.touchProjectContent(projectId);
  }

  /// Un color que todavía no lleva nadie del reparto.
  static Color freeColor(Iterable<Color> taken) {
    final used = {for (final c in taken) c.toARGB32()};
    for (final c in kActorColors) {
      if (!used.contains(c.toARGB32())) return c;
    }
    return kActorColors[used.length % kActorColors.length];
  }
}
