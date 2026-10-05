import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'camera_plan_constants.dart';
import 'light/ambient.dart';
import 'light/light_scene.dart';
import 'light_beam.dart';

/// El sol sobre la planta: el baño de luz al aire libre, las sombras que
/// dan las cosas según su altura y la mancha que entra por cada hueco de
/// un recinto con techo.
class PlanSunPainter {
  PlanSunPainter._();

  /// Con el sol muy bajo las sombras miden decenas de metros: se dibujan
  /// hasta aquí.
  static const double maxShadowM = 30;

  static Offset _cast(PlanAmbient env, double heightM, double mpu) =>
      env.towardSun * (-math.min(env.shadowLength(heightM), maxShadowM) / mpu);

  /// Sombra en el suelo de algo que tapa, de su base a su altura.
  static Path? floorShadow(LightBlocker blocker, PlanAmbient env, double mpu) {
    final far = _cast(env, blocker.heightM, mpu);
    if (far.distance < 0.5) return null;
    final dome = blocker.domeRadius;
    if (dome != null) {
      // Una loma: sombra en punta, de la base a donde cae su cima.
      final tip = blocker.a + far;
      final path = Path();
      if (far.distance <= dome) return null;
      final toTip = far / far.distance;
      final spread = math.acos(dome / far.distance);
      Offset onBase(double sign) {
        final c = math.cos(spread * sign);
        final s = math.sin(spread * sign);
        return blocker.a +
            Offset(toTip.dx * c - toTip.dy * s, toTip.dx * s + toTip.dy * c) *
                dome;
      }

      path.addPolygon([onBase(1), tip, onBase(-1)], true);
      return path;
    }
    if (blocker.isCircle) {
      final r = blocker.radius;
      final away = far / far.distance;
      final side = Offset(-away.dy, away.dx) * r;
      return Path()
        ..addPolygon([
          blocker.a + side,
          blocker.a - side,
          blocker.a - side + far,
          blocker.a + side + far,
        ], true)
        ..addOval(Rect.fromCircle(center: blocker.a, radius: r))
        ..addOval(Rect.fromCircle(center: blocker.a + far, radius: r));
    }
    final near = _cast(env, blocker.baseM, mpu);
    return Path()..addPolygon([
      blocker.a + near,
      blocker.b + near,
      blocker.b + far,
      blocker.a + far,
    ], true);
  }

  /// El lado de dentro de un hueco y su recinto, si da a uno con techo.
  static (SceneRoom, Offset)? _inside(LightScene scene, LightAperture gap) {
    final span = gap.b - gap.a;
    if (span.distance < 1) return null;
    final normal = Offset(-span.dy, span.dx) / span.distance;
    for (final side in [normal, normal * -1]) {
      final room = scene.roomAt(gap.centre + side * 10);
      if (room != null && room.roofed) return (room, side);
    }
    return null;
  }

  /// Si una pared está dentro de un recinto y no en su borde.
  static bool _interiorWall(LightBlocker wall, SceneRoom room) {
    final span = wall.b - wall.a;
    if (span.distance < 1) return false;
    final normal = Offset(-span.dy, span.dx) / span.distance;
    final mid = (wall.a + wall.b) / 2;
    return room.room.contains(mid + normal * 8) &&
        room.room.contains(mid - normal * 8);
  }

  /// La mancha de sol que deja un hueco en el suelo de su recinto: lo que
  /// proyecta entre el alféizar y el dintel, menos la sombra de todo lo
  /// que tape (hojas, negros, telas, personas). Lo que solo filtra (un
  /// cristal, una red, una gelatina) va aparte en [veiled], con la parte
  /// de luz que deja.
  static Path? patchFor(
    LightScene scene,
    PlanAmbient env,
    LightAperture gap, {
    List<(Path, double)>? veiled,
  }) {
    if (!env.hasSun) return null;
    final inside = _inside(scene, gap);
    if (inside == null) return null;
    final (room, inward) = inside;
    final toward = env.towardSun;
    // El sol tiene que venir de fuera.
    if (toward.dx * inward.dx + toward.dy * inward.dy > -0.05) return null;
    final mpu = scene.metersPerUnit;
    final near = toward * (-env.shadowLength(gap.sillM) / mpu);
    final far = toward * (-env.shadowLength(gap.headM) / mpu);
    Path combine(PathOperation op, Path a, Path b) {
      try {
        return Path.combine(op, a, b);
      } catch (_) {
        return a;
      }
    }

    var patch = combine(
      PathOperation.intersect,
      Path()..addPolygon([
        gap.a + near,
        gap.b + near,
        gap.b + far,
        gap.a + far,
      ], true),
      room.room.path,
    );
    final bounds = patch.getBounds();
    if (bounds.isEmpty) return null;

    final filters = <(Path, double)>[];
    for (final blocker in scene.blockers) {
      if (blocker.isWall && !_interiorWall(blocker, room)) continue;
      if (blocker.domeRadius != null) continue;
      final shadow = floorShadow(blocker, env, mpu);
      if (shadow == null || !shadow.getBounds().overlaps(bounds)) continue;
      if (blocker.isOpaque) {
        patch = combine(PathOperation.difference, patch, shadow);
      } else {
        filters.add((shadow, blocker.transmission));
      }
    }
    for (final (shadow, keep) in filters) {
      final part = combine(PathOperation.intersect, patch, shadow);
      if (part.getBounds().isEmpty) continue;
      veiled?.add((part, keep));
      patch = combine(PathOperation.difference, patch, shadow);
    }
    return patch;
  }

  static void paint(
    Canvas canvas,
    LightScene scene,
    PlanAmbient env,
    Rect view,
  ) {
    if (!env.hasSun) return;
    final mpu = scene.metersPerUnit;
    final colour = LightBeam.colorForCct(env.condition.sunCct);

    // Al aire libre: el baño del sol y las sombras.
    var outdoors = Path()..addRect(view);
    for (final room in scene.rooms) {
      if (!room.roofed) continue;
      try {
        outdoors = Path.combine(
          PathOperation.difference,
          outdoors,
          room.room.path,
        );
      } catch (_) {}
    }
    canvas.save();
    canvas.clipPath(outdoors);
    canvas.drawRect(
      view,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = colour.withValues(alpha: 0.13),
    );

    final solid = <(Path, double)>[];
    final dappled = <(Path, double)>[];
    // Un recinto con techo da una sola sombra: la de todo su volumen. Sus
    // paredes no sombrean por separado, o cada puerta abierta dejaría una
    // raya de luz.
    final roofed = [
      for (final room in scene.rooms)
        if (room.roofed) room,
    ];
    for (final room in roofed) {
      final shift = _cast(env, room.ceilingM, mpu);
      final poly = room.room.polygon;
      final sweep = Path()..addPath(room.room.path.shift(shift), Offset.zero);
      for (var i = 0; i < poly.length; i++) {
        final a = poly[i];
        final b = poly[(i + 1) % poly.length];
        sweep.addPolygon([a, b, b + shift, a + shift], true);
      }
      solid.add((sweep, shift.distance));
    }
    bool ofRoofed(LightBlocker wall) {
      final span = wall.b - wall.a;
      if (span.distance < 1) return false;
      final normal = Offset(-span.dy, span.dx) / span.distance;
      final mid = (wall.a + wall.b) / 2;
      return roofed.any(
        (r) =>
            r.room.contains(mid + normal * 8) ||
            r.room.contains(mid - normal * 8),
      );
    }

    for (final blocker in scene.blockers) {
      // El grip no da sombra de sol que merezca dibujarse fuera.
      if (blocker.element?.type == ElementType.light) continue;
      if (blocker.isWall && ofRoofed(blocker)) continue;
      // Hojas, cristales y cortinas: van con su edificio.
      if (!blocker.isWall &&
          !blocker.isCircle &&
          blocker.element?.type == ElementType.wall &&
          blocker.label != null) {
        continue;
      }
      final shadow = floorShadow(blocker, env, mpu);
      if (shadow == null) continue;
      final length = _cast(env, blocker.heightM, mpu).distance;
      (blocker.isOpaque ? solid : dappled).add((shadow, length));
    }

    void layer(List<(Path, double)> shadows, Color tint) {
      if (shadows.isEmpty) return;
      // En una sola capa, para que donde se pisan no se oscurezcan dos
      // veces. El borde es más blando cuanto más larga es la sombra.
      canvas.saveLayer(null, Paint()..color = tint);
      for (final (path, length) in shadows) {
        final sigma = (0.06 + length * mpu * 0.012).clamp(0.06, 0.35) / mpu;
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF000000)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
        );
      }
      canvas.restore();
    }

    layer(solid, const Color(0x66000000));
    layer(dappled, const Color(0x33000000));
    canvas.restore();

    // Bajo techo: la mancha de cada hueco.
    for (final gap in scene.apertures) {
      final veiled = <(Path, double)>[];
      final patch = patchFor(scene, env, gap, veiled: veiled);
      if (patch == null) continue;
      void fill(Path path, double keep) => canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.plus
          ..color = colour.withValues(alpha: (0.36 * keep).clamp(0.0, 0.4))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.03 / mpu),
      );
      fill(patch, 1);
      for (final (part, keep) in veiled) {
        fill(part, keep);
      }
    }
  }
}
