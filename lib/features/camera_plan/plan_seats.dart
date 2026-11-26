import 'dart:math' as math;
import 'dart:ui';

import 'arch/arch_solid.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/light_scene.dart';
import 'light_overrides.dart';
import 'plan_marks.dart';
import 'plan_segment.dart';
import 'rig/plan_rig.dart';

/// Una plaza de un asiento: dónde se sienta (lienzo), hacia dónde mira
/// (grados, como un actor) y la postura que toma.
typedef SeatPlace = ({Offset at, double deg, String pose});

/// Sentarse en sillas, bancos, sofás y camas (F6.1.9b).
///
/// Un actor soltado sobre un asiento se engancha como una luz al truss:
/// toma la postura, mira hacia donde mira el mueble y queda a su nivel. Si
/// el mueble se mueve, lo sigue; si se le aparta, vuelve a estar de pie.
/// Se guarda en `props['seat'] = {uid del mueble, plaza}`.
abstract final class PlanSeats {
  static const seatKey = 'seat';

  /// Alto del asiento (m), si el mueble lo dice.
  static const seatHeightKey = 'seatH';

  /// Lo que mide de ancho una plaza en un banco o un sofá.
  static const placeWidthM = 0.55;

  static bool isSeat(PlanElement el) =>
      el.type == ElementType.prop &&
      !PlanSegment.isSegment(el) &&
      switch (el.propType) {
        PropType.chair || PropType.sofa || PropType.bed => true,
        _ => false,
      };

  static double seatHeightM(PlanElement el) =>
      (el.props[seatHeightKey] as num?)?.toDouble() ??
      switch (el.propType) {
        PropType.sofa => 0.42,
        PropType.bed => 0.55,
        _ => 0.45,
      };

  /// Las plazas de un asiento, de izquierda a derecha.
  static List<SeatPlace> places(PlanElement el, double mpu) {
    if (!isSeat(el)) return const [];
    final size = LightScene.furnitureSizeM(el);
    final rad = el.rotation * math.pi / 180;
    final c = math.cos(rad), s = math.sin(rad);
    // Local (m): x a lo ancho, y hacia atrás (el respaldo está abajo).
    Offset at(double x, double y) =>
        el.position + Offset(x * c - y * s, x * s + y * c) / mpu;
    if (el.propType == PropType.bed) {
      final n = size.width >= 1.3 ? 2 : 1;
      return [
        for (var i = 0; i < n; i++)
          (
            at: at((i - (n - 1) / 2) * size.width / n, 0),
            deg: el.rotation,
            pose: PlanMarks.poseLie,
          ),
      ];
    }
    final n = el.propType == PropType.chair
        ? 1
        : math.max(1, (size.width / placeWidthM).floor());
    return [
      for (var i = 0; i < n; i++)
        (
          at: at((i - (n - 1) / 2) * size.width / n, -size.depth * 0.05),
          deg: el.rotation,
          pose: PlanMarks.poseSit,
        ),
    ];
  }

  /// El asiento de un actor: el `uid` del mueble y la plaza.
  static ({String uid, int place})? of(PlanElement actor) {
    final raw = actor.props[seatKey];
    if (raw is! Map) return null;
    final uid = raw['uid'], i = raw['i'];
    if (uid is! String || i is! int) return null;
    return (uid: uid, place: i);
  }

  /// La plaza libre más cercana a [p], a menos de medio metro de ella.
  static ({PlanElement seat, int place})? nearest(
    List<PlanElement> elements,
    Offset p,
    double mpu, {
    PlanElement? actor,
  }) {
    final taken = <(String, int)>{
      for (final a in elements)
        if (a.type == ElementType.actor && !identical(a, actor))
          if (of(a) case final s?) (s.uid, s.place),
    };
    ({PlanElement seat, int place})? best;
    var bestD = 0.5 / mpu;
    for (final el in elements) {
      final uid = LightOverrides.uidOf(el);
      if (uid == null || !isSeat(el)) continue;
      final list = places(el, mpu);
      for (var i = 0; i < list.length; i++) {
        if (taken.contains((uid, i))) continue;
        final d = (list[i].at - p).distance;
        if (d < bestD) {
          bestD = d;
          best = (seat: el, place: i);
        }
      }
    }
    return best;
  }

  /// Sienta a [actor] en la plaza [i] de [seat].
  static void sit(PlanElement actor, PlanElement seat, int i, double mpu) {
    final list = places(seat, mpu);
    final uid = LightOverrides.uidOf(seat);
    if (uid == null || list.isEmpty) return;
    final place = list[i.clamp(0, list.length - 1)];
    actor
      ..position = place.at
      ..rotation = place.deg
      ..props[seatKey] = {'uid': uid, 'i': i.clamp(0, list.length - 1)}
      ..props[PlanMarks.poseKey] = place.pose;
    PlanLevel.set(actor, PlanLevel.of(seat));
  }

  /// Lo levanta del asiento.
  static void stand(PlanElement actor) {
    actor.props
      ..remove(seatKey)
      ..[PlanMarks.poseKey] = PlanMarks.poseStand;
  }

  /// Al soltar a [actor] en [p]: se sienta si cae sobre una plaza libre;
  /// si estaba sentado y se le aparta, se levanta. Dice si ha cambiado.
  static bool settle(
    List<PlanElement> elements,
    PlanElement actor,
    double mpu,
  ) {
    if (actor.type != ElementType.actor) return false;
    final hit = nearest(elements, actor.position, mpu, actor: actor);
    if (hit != null) {
      sit(actor, hit.seat, hit.place, mpu);
      return true;
    }
    if (of(actor) != null) {
      stand(actor);
      return true;
    }
    return false;
  }

  /// Los actores sentados en [seats] los siguen (los que ya no tienen su
  /// asiento se levantan). Devuelve los que han cambiado.
  static List<PlanElement> follow(List<PlanElement> elements, double mpu) {
    final byUid = <String, PlanElement>{
      for (final el in elements)
        if (isSeat(el))
          if (LightOverrides.uidOf(el) case final uid?) uid: el,
    };
    final changed = <PlanElement>[];
    for (final a in elements) {
      final s = of(a);
      if (s == null) continue;
      final seat = byUid[s.uid];
      final before = (a.position, a.rotation, PlanLevel.of(a));
      if (seat == null) {
        stand(a);
        changed.add(a);
        continue;
      }
      sit(a, seat, s.place, mpu);
      if ((a.position, a.rotation, PlanLevel.of(a)) != before) changed.add(a);
    }
    return changed;
  }
}

/// El suelo que pisa quien se suelta en un sitio: un forjado o una tarima
/// (un volumen bajo) suben a quien está encima, como el suelo de un vagón
/// o un andén.
abstract final class PlanFloors {
  /// Lo que se sube de un paso (m): una tarima o un andén, no un techo.
  static const stepUpM = 1.3;

  /// Marca de que el nivel lo puso el suelo (y se quita al salir de él).
  static const autoKey = 'floorAuto';

  /// La cota del suelo en [p] para quien está a [levelM], o `null` si no
  /// hay forjado ni tarima.
  static double? groundAt(
    List<PlanElement> elements,
    Offset p,
    double levelM,
    double mpu, {
    PlanElement? except,
  }) {
    double? best;
    for (final el in elements) {
      if (identical(el, except) || !ArchSolid.isSolid(el)) continue;
      // Un volumen alto (una caseta, un tejado) no se pisa.
      if (ArchSolid.isVolume(el) &&
          (ArchSolid.heightM(el) > stepUpM || ArchSolid.roof(el) != null)) {
        continue;
      }
      if (!ArchSolid.contains(el, p, mpu)) continue;
      final top = PlanLevel.of(el) + ArchSolid.topM(el);
      if (top > levelM + stepUpM) continue;
      if (best == null || top > best) best = top;
    }
    return best;
  }

  /// Al soltar a un actor o una cámara: sube o baja al suelo que pisa.
  /// Dice si ha cambiado.
  static bool settle(List<PlanElement> elements, PlanElement el, double mpu) {
    if (el.type != ElementType.actor && el.type != ElementType.camera) {
      return false;
    }
    if (PlanSeats.of(el) != null) return false;
    final level = PlanLevel.of(el);
    final auto = el.props[autoKey] == true;
    // Desde el suelo de antes (si lo puso un forjado, desde la calle).
    final ground = groundAt(elements, el.position, auto ? 0 : level, mpu);
    if (ground != null) {
      if ((ground - level).abs() < 1e-3 && auto) return false;
      PlanLevel.set(el, (ground * 1000).round() / 1000);
      el.props[autoKey] = true;
      return true;
    }
    if (auto) {
      PlanLevel.set(el, 0);
      el.props.remove(autoKey);
      return true;
    }
    return false;
  }
}
