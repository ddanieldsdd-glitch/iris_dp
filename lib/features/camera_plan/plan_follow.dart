import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show listEquals;

import '../../core/database/app_database.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light_overrides.dart';
import 'plan_marks.dart';

/// Elementos que siguen a otro (PL.4).
///
/// Un plano nuevo de una escena trae los actores del plano anterior; cada
/// copia lleva `props['followOf'] = {shotUid, uid}`, con identificadores que
/// viajan entre equipos. Mientras el plano no la mueva, la copia toma el
/// sitio y el recorrido del original cada vez que este cambia, y en cadena:
/// lo que sigue a la copia también se mueve. Lo que el plano ya movió se
/// respeta. Las cámaras de set siguen a su cámara del esquema igual
/// ([samePlace], [takePlace]), desde `CameraLinks.followCameras`.
class PlanFollow {
  final AppDatabase db;
  PlanFollow(this.db);

  static const key = 'followOf';

  /// A quién sigue [el]: plano e identificador del original, o `null`.
  static ({String shotUid, String uid})? of(PlanElement el) {
    final raw = el.props[key];
    if (raw is! Map) return null;
    final shot = raw['shotUid'], uid = raw['uid'];
    if (shot is! String || uid is! String) return null;
    return (shotUid: shot, uid: uid);
  }

  static void set(PlanElement el, String shotUid, String uid) =>
      el.props[key] = <String, dynamic>{'shotUid': shotUid, 'uid': uid};

  /// «Soltar»: deja de seguir al original.
  static void release(PlanElement el) => el.props.remove(key);

  /// Está en el mismo sitio, con el mismo recorrido y las mismas marcas.
  static bool samePlace(PlanElement a, PlanElement b) =>
      a.position == b.position &&
      a.rotation == b.rotation &&
      listEquals(a.pathPoints, b.pathPoints) &&
      listEquals(_marks(a), _marks(b));

  /// [el] toma el sitio, el recorrido y las marcas de [from].
  static void takePlace(PlanElement el, PlanElement from) {
    el
      ..position = from.position
      ..rotation = from.rotation
      ..pathPoints = [...from.pathPoints];
    final marks = from.props[PlanMarks.rotKey];
    if (marks is List) {
      el.props[PlanMarks.rotKey] = [...marks];
    } else {
      el.props.remove(PlanMarks.rotKey);
    }
  }

  static List<Object?> _marks(PlanElement el) =>
      switch (el.props[PlanMarks.rotKey]) {
        final List l => l,
        _ => const [],
      };

  /// Planos de la escena por su identificador, para la insignia
  /// («sigue a 6/1»).
  static Future<Map<String, String>> sceneLabels(
    AppDatabase db,
    Scene scene,
  ) async => {
    for (final s in await db.getShotsForScene(scene.id))
      if (s.uid != null) s.uid!: '${scene.label}/${s.number}',
  };

  /// Tras guardar el plano [shotId] entero: [before] era cómo estaba.
  Future<void> shotSaved(
    int shotId,
    List<PlanElement> before,
    List<PlanElement> after,
  ) => _propagate(shotId, _changes(before, after));

  /// Tras guardar un elemento del plano [shotId]: [before] era cómo estaba.
  Future<void> elementSaved(
    int shotId,
    PlanElement before,
    PlanElement after,
  ) => _propagate(shotId, _changes([before], [after]));

  /// Cómo estaba un elemento guardado de un plano, para comparar después.
  Future<PlanElement?> loadElement(int id) async {
    final row = await (db.select(
      db.cameraPlanElements,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return PlanElement.fromDb(
      row,
      pathRows: await db.getPathPointsForElement(row.id),
    );
  }

  /// Actores que cambiaron de sitio: identificador → (antes, ahora).
  static Map<String, (PlanElement, PlanElement)> _changes(
    List<PlanElement> before,
    List<PlanElement> after,
  ) {
    Map<String, PlanElement> actors(List<PlanElement> list) => {
      for (final e in list)
        if (e.type == ElementType.actor && LightOverrides.uidOf(e) != null)
          LightOverrides.uidOf(e)!: e,
    };
    final old = actors(before);
    return {
      for (final MapEntry(key: uid, value: now) in actors(after).entries)
        if (old[uid] case final was? when !samePlace(was, now)) uid: (was, now),
    };
  }

  /// Lleva los cambios del plano [shotId] a los planos de su escena que lo
  /// siguen y, de ahí, a los que siguen a esos. Cada plano se toca una vez
  /// (sin ciclos) y todo va en una transacción.
  Future<void> _propagate(
    int shotId,
    Map<String, (PlanElement, PlanElement)> changes,
  ) async {
    if (changes.isEmpty) return;
    final origin = await db.getShotById(shotId);
    if (origin == null || origin.uid == null) return;
    final others = [
      for (final s in await db.getShotsForScene(origin.sceneId))
        if (s.id != shotId && s.uid != null) s,
    ];
    if (others.isEmpty) return;
    await db.transaction(() async {
      final visited = {shotId};
      final queue = [(origin.uid!, changes)];
      while (queue.isNotEmpty) {
        final (fromUid, moved) = queue.removeAt(0);
        for (final shot in others) {
          if (visited.contains(shot.id)) continue;
          final own = await _shotElements(shot.id);
          final next = <String, (PlanElement, PlanElement)>{};
          final touched = <PlanElement>[];
          for (final el in own) {
            final follow = of(el);
            if (follow == null || follow.shotUid != fromUid) continue;
            final change = moved[follow.uid];
            if (change == null) continue;
            final (was, now) = change;
            if (!samePlace(el, was) || samePlace(el, now)) continue;
            final before = LightOverrides.clone(el);
            takePlace(el, now);
            touched.add(el);
            final uid = LightOverrides.uidOf(el);
            if (uid != null) next[uid] = (before, el);
          }
          if (touched.isEmpty) continue;
          visited.add(shot.id);
          await _saveMoved(shot, touched);
          queue.add((shot.uid!, next));
        }
      }
    });
  }

  Future<List<PlanElement>> _shotElements(int shotId) async => [
    for (final row in await db.getCameraPlanElementsForShot(shotId))
      PlanElement.fromDb(
        row,
        pathRows: await db.getPathPointsForElement(row.id),
      ),
  ];

  /// Guarda el sitio de los elementos movidos de un plano.
  Future<void> _saveMoved(Shot shot, List<PlanElement> moved) async {
    for (final el in moved) {
      await (db.update(
        db.cameraPlanElements,
      )..where((e) => e.id.equals(el.id))).write(
        CameraPlanElementsCompanion(
          x: Value(el.position.dx),
          y: Value(el.position.dy),
          rotation: Value(el.rotation),
          propsJson: Value(el.props.isEmpty ? null : jsonEncode(el.props)),
        ),
      );
      await db.replacePathPoints(
        el.id,
        el.pathPoints.map((p) => (x: p.dx, y: p.dy)).toList(),
      );
    }
    await db.touchProjectContent(shot.projectId);
  }
}
