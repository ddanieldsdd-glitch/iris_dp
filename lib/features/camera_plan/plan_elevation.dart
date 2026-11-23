import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'arch/arch_solid.dart';
import 'arch/arch_stair.dart';
import 'arch/arch_sweep.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/light_scene.dart';
import 'light/plan_light.dart';
import 'light_beam.dart';
import 'plan_opening.dart';
import 'plan_segment.dart';
import 'plan_terrain_painter.dart';
import 'light_overrides.dart';
import 'rig/plan_drape.dart';
import 'rig/plan_rig.dart';

/// Desde dónde se mira la planta para levantarla en altura.
enum ElevationSide {
  /// Alzado: desde el sur, mirando al norte. Izquierda = oeste.
  front,

  /// Perfil: desde el este, mirando al oeste. Izquierda = sur.
  side,
}

extension ElevationSideLabel on ElevationSide {
  String get label => switch (this) {
    ElevationSide.front => 'Alzado',
    ElevationSide.side => 'Perfil',
  };

  String get hint => switch (this) {
    ElevationSide.front => 'desde el sur, mirando al norte',
    ElevationSide.side => 'desde el este, mirando al oeste',
  };
}

/// Una sección (AM.6): la planta cortada por una línea y vista hacia un
/// lado. Lo que queda delante de la línea no se ve y lo que la cruza sale
/// cortado, relleno. Se mira desde [from] hacia [to] a la derecha: lo que
/// se ve está a la izquierda de la línea, en el lienzo.
class ElevationCut {
  /// Extremos de la línea en el lienzo.
  final Offset from;
  final Offset to;

  /// La letra de la sección: «A» da «Sección A-A».
  final String name;

  const ElevationCut(this.from, this.to, {this.name = 'A'});

  /// A lo largo de la línea, de [from] a [to], de largo 1.
  Offset get along {
    final d = to - from;
    return d.distance < 1e-9 ? const Offset(1, 0) : d / d.distance;
  }

  /// Hacia donde se mira, de largo 1.
  Offset get look => Offset(along.dy, -along.dx);

  String get label => 'Sección $name-$name';
}

enum ElevationKind {
  wall,
  opening,
  light,
  actor,
  camera,
  prop,

  /// Pared de tela: su borde de arriba en catenaria y su bajo.
  drape,

  /// Truss: a lo largo, una banda con diagonales; de punta, su sección.
  truss,

  /// Motor (encima del truss) o torre de ground support (desde el suelo).
  rigPoint,
}

/// Una pieza de la planta vista de lado: dónde cae a lo ancho, a qué
/// altura y a qué distancia del que mira.
class ElevationItem {
  final ElevationKind kind;
  final PlanElement element;

  /// A lo ancho de la vista, en metros.
  final double from;
  final double to;

  /// Altura, en metros.
  final double bottom;
  final double top;

  /// Distancia al que mira, en metros: lo lejano se pinta detrás.
  final double depth;
  final String label;

  /// Luces: hacia dónde apunta en el plano de la vista (radianes desde la
  /// horizontal hacia la derecha; positivo hacia arriba), apertura y
  /// alcance en metros. `aim` es `null` si apunta hacia el que mira o en
  /// sentido contrario.
  final double? aim;
  final double beamDeg;
  final double reachM;
  final double cct;

  /// Color de un aparato RGB; `null` = blanco.
  final int? rgb;

  /// Tela: el borde de arriba y el bajo a lo ancho, punto a punto
  /// (`across`, `top`, `bottom`).
  final List<(double, double, double)> profile;

  /// En una sección, la pieza cruza la línea de corte: se rellena.
  final bool cut;

  const ElevationItem({
    required this.kind,
    required this.element,
    required this.from,
    required this.to,
    required this.bottom,
    required this.top,
    required this.depth,
    this.label = '',
    this.aim,
    this.beamDeg = 0,
    this.reachM = 0,
    this.cct = 5600,
    this.rgb,
    this.profile = const [],
    this.cut = false,
  });

  double get centre => (from + to) / 2;
}

/// La planta levantada en altura desde un lado: paredes con sus huecos,
/// luces a su altura con su haz, personas, cámaras y atrezo.
class PlanElevation {
  final ElevationSide side;
  final List<ElevationItem> items;

  /// Si es una sección, por dónde corta. `null` en un alzado.
  final ElevationCut? cut;

  const PlanElevation(this.side, this.items, [this.cut]);

  /// «Alzado», «Perfil» o «Sección A-A».
  String get title => cut?.label ?? side.label;

  /// Desde dónde se mira, en palabras.
  String get hint => cut == null ? side.hint : 'lo que hay detrás del corte';

  /// Cuánto va a lo ancho de esta vista una dirección del lienzo.
  double acrossOfDir(Offset dir) => acrossOf(dir, side, cut);

  /// Cuánto se aleja del que mira una dirección del lienzo.
  double depthOfDir(Offset dir) => cut == null
      ? project(dir, 1, side).depth
      : dir.dx * cut!.look.dx + dir.dy * cut!.look.dy;

  /// Altura de una persona de pie y del objetivo de una cámara en mano o en
  /// trípode, en metros.
  static const double personM = 1.7;
  static const double lensM = 1.5;

  /// Altura de una luz en pie si no dice otra.
  static const double standM = 2.0;

  double get left =>
      items.isEmpty ? 0 : items.map((i) => i.from).reduce(math.min);
  double get right =>
      items.isEmpty ? 1 : items.map((i) => i.to).reduce(math.max);
  double get height => math.max(
    3,
    items.isEmpty ? 3 : items.map((i) => i.top).reduce(math.max) + 0.5,
  );

  /// Posición de un punto de la planta en la vista: a lo ancho y en
  /// profundidad, en metros.
  static ({double across, double depth}) project(
    Offset p,
    double metersPerUnit,
    ElevationSide side, [
    ElevationCut? cut,
  ]) => cut != null
      ? (
          across: ((p - cut.from).dx * cut.along.dx +
                  (p - cut.from).dy * cut.along.dy) *
              metersPerUnit,
          depth: ((p - cut.from).dx * cut.look.dx +
                  (p - cut.from).dy * cut.look.dy) *
              metersPerUnit,
        )
      : switch (side) {
    ElevationSide.front => (
      across: p.dx * metersPerUnit,
      depth: -p.dy * metersPerUnit,
    ),
    ElevationSide.side => (
      across: -p.dy * metersPerUnit,
      depth: -p.dx * metersPerUnit,
    ),
  };

  /// Una dirección de la planta en la vista: cuánto va a lo ancho.
  static double acrossOf(
    Offset dir,
    ElevationSide side, [
    ElevationCut? cut,
  ]) => cut != null
      ? dir.dx * cut.along.dx + dir.dy * cut.along.dy
      : switch (side) {
          ElevationSide.front => dir.dx,
          ElevationSide.side => -dir.dy,
        };

  /// Lo que queda detrás de la línea de corte de un contorno cerrado, en
  /// el lienzo: el corte de Sutherland–Hodgman por un semiplano.
  static List<Offset> clipBehind(List<Offset> poly, ElevationCut cut) {
    double d(Offset p) =>
        (p - cut.from).dx * cut.look.dx + (p - cut.from).dy * cut.look.dy;
    final out = <Offset>[];
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      final da = d(a), db = d(b);
      if (da >= 0) out.add(a);
      if ((da >= 0) != (db >= 0)) {
        out.add(Offset.lerp(a, b, da / (da - db))!);
      }
    }
    return out;
  }

  /// Lo más alto de un volumen con cubierta a lo ancho de la vista: la
  /// malla de su cubierta proyectada y, en cada franja, lo más alto.
  static List<(double, double, double)> _roofSilhouette(
    PlanElement el,
    double mpu,
    ({double across, double depth}) Function(Offset) at,
    double from,
    double to,
    double level,
    double bottom, {
    ElevationCut? cut,
  }) {
    final roof = ArchSolid.roof(el);
    if (roof == null || to - from < 0.01) return const [];
    const bins = 32;
    final eave = level + ArchSolid.heightM(el);
    final top = List<double?>.filled(bins + 1, null);
    final mesh = roof.mesh(ArchSolid.outlineM(el), stepM: 0.2).roof;
    for (var i = 0; i + 2 < mesh.length; i += 3) {
      final p = at(
        ArchSolid.toCanvas(el, Offset(mesh[i], mesh[i + 1]), mpu),
      );
      if (cut != null && p.depth < 0) continue;
      final k = ((p.across - from) / (to - from) * bins).round().clamp(0, bins);
      top[k] = math.max(top[k] ?? eave, eave + mesh[i + 2]);
    }
    // Las casillas sin ningún punto de la malla, entre sus vecinas.
    for (var k = 0; k <= bins; k++) {
      if (top[k] != null) continue;
      var a = k - 1, b = k + 1;
      while (a >= 0 && top[a] == null) {
        a--;
      }
      while (b <= bins && top[b] == null) {
        b++;
      }
      final ya = a >= 0 ? top[a] : null, yb = b <= bins ? top[b] : null;
      top[k] = ya != null && yb != null
          ? ya + (yb - ya) * (k - a) / (b - a)
          : ya ?? yb ?? eave;
    }
    return [
      for (var k = 0; k <= bins; k++)
        (from + (to - from) * k / bins, top[k]!, bottom),
    ];
  }

  factory PlanElevation.of(
    List<PlanElement> elements, {
    required double metersPerUnit,
    required ElevationSide side,

    /// La planta vista por la luz, si ya está hecha. Si no, se hace sin
    /// rebotes: aquí solo hacen falta los recintos y sus techos.
    LightScene? scene,

    /// Si se da, es una sección por esa línea (AM.6) y no un alzado.
    ElevationCut? cut,
  }) {
    final mpu = metersPerUnit;
    scene ??= LightScene.from(elements, metersPerUnit: mpu, wallBounce: false);
    final items = <ElevationItem>[];
    ({double across, double depth}) at(Offset p) =>
        project(p, mpu, side, cut);

    // En una sección: lo de delante de la línea no se ve.
    bool behind(Offset p) => cut == null || at(p).depth >= 0;
    bool crosses(Iterable<Offset> pts) =>
        cut != null && pts.any(behind) && !pts.every(behind);

    /// Un tramo recortado a lo que queda detrás de la línea, o `null`.
    (Offset, Offset)? clipSpan(Offset a, Offset b) {
      if (cut == null) return (a, b);
      final da = at(a).depth, db = at(b).depth;
      if (da < 0 && db < 0) return null;
      if (da >= 0 && db >= 0) return (a, b);
      final x = Offset.lerp(a, b, da / (da - db))!;
      return da >= 0 ? (a, x) : (x, b);
    }

    final trusses = {
      for (final t in elements.where(PlanTruss.isTruss))
        if (LightOverrides.uidOf(t) != null) LightOverrides.uidOf(t)!: t,
    };
    for (final el in elements) {
      if (PlanDrape.isDrape(el)) {
        final c = PlanDrape.catenary(el, mpu);
        final profile = [
          for (var k = 0; k <= 24; k++)
            if (behind(PlanSegment.pointAt(el, k / 24)))
            (
              at(PlanSegment.pointAt(el, k / 24)).across,
              PlanDrape.topAt(el, k / 24, c),
              PlanDrape.bottomAt(el, k / 24, c),
            ),
        ];
        if (profile.length < 2) continue;
        final mid = at(PlanSegment.pointAt(el, 0.5));
        items.add(
          ElevationItem(
            kind: ElevationKind.drape,
            element: el,
            from: profile.map((p) => p.$1).reduce(math.min),
            to: profile.map((p) => p.$1).reduce(math.max) + 0.02,
            bottom: profile.map((p) => p.$3).reduce(math.min),
            top: profile.map((p) => p.$2).reduce(math.max),
            depth: mid.depth,
            label: 'libre ${PlanDrape.clearanceM(el, c).toStringAsFixed(2)} m',
            profile: profile,
            cut: crosses([
              PlanSegment.pointAt(el, 0),
              PlanSegment.pointAt(el, 1),
            ]),
          ),
        );
        continue;
      }
      switch (RigTypeCodec.of(el)) {
        case RigType.truss:
          final span = clipSpan(PlanTruss.start(el), PlanTruss.end(el));
          if (span == null) continue;
          final a = at(span.$1), b = at(span.$2);
          final half = PlanTruss.outerM(PlanTruss.sizeCm(el)) / 2;
          final low = PlanLevel.of(el) + PlanTruss.lowM(el);
          items.add(
            ElevationItem(
              kind: ElevationKind.truss,
              element: el,
              from: math.min(a.across, b.across) - half,
              to: math.max(a.across, b.across) + half,
              bottom: low,
              top: low + PlanTruss.depthM(el),
              depth: (a.depth + b.depth) / 2,
              cut: crosses([PlanTruss.start(el), PlanTruss.end(el)]),
            ),
          );
          continue;
        case RigType.motor || RigType.groundSupport:
          if (!behind(el.position)) continue;
          final truss = trusses[el.props[PlanRigPoint.trussKey]];
          final top = truss == null
              ? 3.0
              : PlanLevel.of(truss) +
                    PlanTruss.lowM(truss) +
                    PlanTruss.depthM(truss);
          final p = at(el.position);
          final motor = RigTypeCodec.of(el) == RigType.motor;
          items.add(
            ElevationItem(
              kind: ElevationKind.rigPoint,
              element: el,
              from: p.across - (motor ? 0.14 : 0.15),
              to: p.across + (motor ? 0.14 : 0.15),
              bottom: motor ? top : PlanLevel.of(el),
              top: motor ? top + 0.42 : top,
              depth: p.depth,
            ),
          );
          continue;
        case RigType.pillar:
          if (!behind(el.position)) continue;
          final p = at(el.position);
          final half = PlanPillar.sizeM(el) / 2;
          items.add(
            ElevationItem(
              kind: ElevationKind.prop,
              element: el,
              from: p.across - half,
              to: p.across + half,
              bottom: PlanLevel.of(el),
              top: PlanLevel.of(el) + PlanPillar.heightM(el),
              depth: p.depth,
            ),
          );
          continue;
        case RigType.slab || RigType.volume:
          // Forjado o volumen (AM.2): de su cota de abajo a la de arriba,
          // a lo ancho de su contorno visto desde este lado.
          final outline = ArchSolid.outline(el, mpu);
          final pts = [
            for (final p in cut == null
                ? outline
                : PlanElevation.clipBehind(outline, cut))
              at(p),
          ];
          if (pts.isEmpty) continue;
          final level = PlanLevel.of(el);
          final from = pts.map((p) => p.across).reduce(math.min);
          final to = pts.map((p) => p.across).reduce(math.max);
          final bottom = level + ArchSolid.bottomM(el);
          items.add(
            ElevationItem(
              kind: ElevationKind.prop,
              element: el,
              from: from,
              to: to,
              bottom: bottom,
              top: level + ArchSolid.topM(el),
              depth: pts.map((p) => p.depth).reduce(math.min),
              // Con cubierta (AM.3), su silueta vista desde este lado.
              profile: _roofSilhouette(
                el,
                mpu,
                at,
                from,
                to,
                level,
                bottom,
                cut: cut,
              ),
              cut: crosses(outline),
            ),
          );
          continue;
        case RigType.stair:
          // Escalera o rampa (AM.6): su silueta de peldaños vista desde
          // este lado.
          final level = PlanLevel.of(el);
          final spans = <(double, double, double Function(double), double)>[];
          var stairCut = false;
          for (final step in ArchStair.steps(el)) {
            final corners = [
              for (final p in step.poly) ArchStair.toCanvas(el, p, mpu),
            ];
            if (!corners.any(behind)) {
              stairCut = true;
              continue;
            }
            if (crosses(corners)) stairCut = true;
            final pts = [
              for (final p in step.poly)
                at(ArchStair.toCanvas(el, p, mpu)),
            ];
            final lo = pts.map((p) => p.across).reduce(math.min);
            final hi = pts.map((p) => p.across).reduce(math.max);
            final tMin = step.tops.reduce(math.min);
            final tMax = step.tops.reduce(math.max);
            double avgAcross(double t) {
              final xs = [
                for (var i = 0; i < pts.length; i++)
                  if ((step.tops[i] - t).abs() < 1e-6) pts[i].across,
              ];
              return xs.reduce((a, b) => a + b) / xs.length;
            }

            final a0 = avgAcross(tMin), a1 = avgAcross(tMax);
            spans.add((
              lo,
              hi,
              (double x) => tMax - tMin < 1e-6 || (a1 - a0).abs() < 1e-6
                  ? tMax
                  : (tMin + (tMax - tMin) * ((x - a0) / (a1 - a0)))
                        .clamp(tMin, tMax),
              step.bottom,
            ));
          }
          if (spans.isEmpty) continue;
          final from = spans.map((s) => s.$1).reduce(math.min);
          final to = spans.map((s) => s.$2).reduce(math.max);
          final profile = <(double, double, double)>[];
          // Las aristas de cada peldaño, a un pelo a cada lado, para que
          // se vea escalonada y no en rampa.
          final xs = <double>{
            for (var k = 0; k <= 48; k++) from + (to - from) * k / 48,
            for (final (lo, hi, _, _) in spans) ...[
              lo + 1e-4,
              hi - 1e-4,
              if (lo - 1e-4 > from) lo - 1e-4,
              if (hi + 1e-4 < to) hi + 1e-4,
            ],
          }.toList()..sort();
          for (final x in xs) {
            var top = 0.0, bottom = double.infinity;
            for (final (lo, hi, h, b) in spans) {
              if (x < lo - 1e-6 || x > hi + 1e-6) continue;
              top = math.max(top, h(x));
              bottom = math.min(bottom, b);
            }
            if (bottom.isInfinite) bottom = 0;
            profile.add((x, level + top, level + bottom));
          }
          items.add(
            ElevationItem(
              kind: ElevationKind.prop,
              element: el,
              from: from,
              to: to,
              bottom: level,
              top: level + profile.map((p) => p.$2 - level).reduce(math.max),
              depth: spans.isEmpty ? 0 : at(el.position).depth,
              profile: profile,
              cut: stairCut,
            ),
          );
          continue;
        case RigType.sweep:
          // Barrido (AM.5): la silueta de cada perfil a lo largo de su
          // camino y cada pieza que se repite, como una caja.
          final level = PlanLevel.of(el);
          final f = ArchSweep.frames(el, mpu);
          final len = f.last.s;
          final n = math.min(400, math.max(2, (len / 0.25).ceil()));
          final dense = [for (var k = 0; k <= n; k++) ArchSweep.frameAt(f, len * k / n)];
          for (final part in ArchSweep.parts(el)) {
            final pts = <(double, double, double)>[];
            var hidden = false;
            for (final fr in dense) {
              final prof = part.profile;
              for (var j = 0; j < prof.length; j++) {
                final a = prof[j], b = prof[(j + 1) % prof.length];
                for (var t = 0.0; t < 1; t += 0.25) {
                  final q = Offset.lerp(a, b, t)!;
                  final c = ArchSweep.place(fr, q.dx, mpu);
                  if (!behind(c)) {
                    hidden = true;
                    continue;
                  }
                  final pr = at(c);
                  pts.add((pr.across, level + q.dy, pr.depth));
                }
              }
            }
            if (pts.isEmpty) continue;
            final from = pts.map((p) => p.$1).reduce(math.min);
            final to = math.max(
              from + 0.02,
              pts.map((p) => p.$1).reduce(math.max),
            );
            const bins = 48;
            final tops = List<double?>.filled(bins + 1, null);
            final bottoms = List<double?>.filled(bins + 1, null);
            for (final (x, z, _) in pts) {
              final k = ((x - from) / (to - from) * bins).round().clamp(0, bins);
              tops[k] = math.max(tops[k] ?? z, z);
              bottoms[k] = math.min(bottoms[k] ?? z, z);
            }
            for (final list in [tops, bottoms]) {
              for (var k = 0; k <= bins; k++) {
                if (list[k] != null) continue;
                var a = k - 1, b = k + 1;
                while (a >= 0 && list[a] == null) {
                  a--;
                }
                while (b <= bins && list[b] == null) {
                  b++;
                }
                final ya = a >= 0 ? list[a] : null;
                final yb = b <= bins ? list[b] : null;
                list[k] = ya != null && yb != null
                    ? ya + (yb - ya) * (k - a) / (b - a)
                    : ya ?? yb;
              }
            }
            items.add(
              ElevationItem(
                kind: ElevationKind.prop,
                element: el,
                from: from,
                to: to,
                bottom: level + part.bottom,
                top: level + part.top,
                depth: pts.map((p) => p.$3).reduce(math.min),
                profile: [
                  for (var k = 0; k <= bins; k++)
                    (from + (to - from) * k / bins, tops[k]!, bottoms[k]!),
                ],
                cut: hidden,
              ),
            );
          }
          for (final (r, g) in ArchSweep.instances(el, mpu)) {
            final corners = ArchSweep.band(
              g,
              r.offsetM - r.acrossM / 2,
              r.offsetM + r.acrossM / 2,
              mpu,
            );
            if (!corners.any(behind)) continue;
            final pr = [for (final c in corners.where(behind)) at(c)];
            items.add(
              ElevationItem(
                kind: ElevationKind.prop,
                element: el,
                from: pr.map((p) => p.across).reduce(math.min),
                to: math.max(
                  pr.map((p) => p.across).reduce(math.min) + 0.02,
                  pr.map((p) => p.across).reduce(math.max),
                ),
                bottom: level + r.baseM,
                top: level + r.topM,
                depth: pr.map((p) => p.depth).reduce(math.min),
                cut: crosses(corners),
              ),
            );
          }
          continue;
        case RigType.hall || RigType.scan || RigType.section:
          continue;
        case null:
          break;
      }
      if (PlanSegment.isSegment(el)) {
        if (PlanSegment.kind(el) != PlanSegment.kindWall) continue;
        final a = at(el.position), b = at(PlanSegment.end(el));
        // En una sección: lo que queda detrás y, si la cruza, su corte.
        const samples = 32;
        final seen = [
          for (var k = 0; k <= samples; k++)
            if (behind(PlanSegment.pointAt(el, k / samples))) k / samples,
        ];
        if (seen.isEmpty) continue;
        final top =
            (el.props[LightScene.heightKey] as num?)?.toDouble() ??
            (el.props[PlanPillar.heightKey] as num?)?.toDouble() ??
            scene.wallTopAt(
              Offset.lerp(el.position, PlanSegment.end(el), 0.5)!,
            );
        // Con perfil (AM.4): alto distinto en cada punta o hastial.
        final profile = PlanSegment.hasProfile(el)
            ? [
                for (final t in <double>{
                  for (var k = 0; k <= 16; k++) k / 16,
                  ...PlanSegment.profileTs(el),
                }.toList()..sort())
                  if (behind(PlanSegment.pointAt(el, t)))
                  (
                    at(PlanSegment.pointAt(el, t)).across,
                    PlanSegment.topAtM(el, t)!,
                    0.0,
                  ),
              ]
            : const <(double, double, double)>[];
        final xs = cut == null
            ? [a.across, b.across]
            : [for (final t in seen) at(PlanSegment.pointAt(el, t)).across];
        final from = xs.reduce(math.min), to = xs.reduce(math.max) + 0.02;
        if (to - from > 0.03 || seen.length == samples + 1) {
          items.add(
            ElevationItem(
              kind: ElevationKind.wall,
              element: el,
              from: from,
              to: to,
              bottom: 0,
              top: profile.isEmpty
                  ? top
                  : profile.map((p) => p.$2).reduce(math.max),
              depth: (a.depth + b.depth) / 2,
              label: el.label ?? '',
              profile: profile,
            ),
          );
        }
        if (seen.length <= samples) {
          // Por donde la cruza la línea: su grosor, relleno.
          final t = _crossing(el, (q) => at(q).depth);
          final c = at(PlanSegment.pointAt(el, t)).across;
          final half = math.max(0.05, PlanSegment.thicknessM(el) / 2);
          items.add(
            ElevationItem(
              kind: ElevationKind.wall,
              element: el,
              from: c - half,
              to: c + half,
              bottom: 0,
              top: PlanSegment.topAtM(el, t) ?? top,
              depth: 0,
              cut: true,
            ),
          );
        }
        continue;
      }
      // Una pared suelta de las de antes (AM.4).
      if (el.type == ElementType.wall &&
          !PlanOpening.isOpening(el) &&
          el.architectureType == ArchitectureType.wall) {
        final (s0, e0) = LightScene.legacyWallSpan(el);
        final span = clipSpan(s0, e0);
        if (span == null) continue;
        final (s, e) = span;
        final a = at(s), b = at(e);
        items.add(
          ElevationItem(
            kind: ElevationKind.wall,
            element: el,
            from: math.min(a.across, b.across),
            to: math.max(a.across, b.across) + 0.02,
            bottom: 0,
            top:
                (el.props[LightScene.heightKey] as num?)?.toDouble() ??
                scene.wallTopAt(el.position),
            depth: (a.depth + b.depth) / 2,
            label: el.label ?? '',
            cut: crosses([s0, e0]),
          ),
        );
        continue;
      }
      if (PlanOpening.isOpening(el)) {
        final (s, e) = PlanOpening.span(el);
        if (!behind(Offset.lerp(s, e, 0.5)!)) continue;
        final a = at(s), b = at(e);
        items.add(
          ElevationItem(
            kind: ElevationKind.opening,
            element: el,
            from: math.min(a.across, b.across),
            to: math.max(a.across, b.across) + 0.02,
            bottom: PlanOpening.sill(el),
            top: PlanOpening.head(el),
            depth: (a.depth + b.depth) / 2,
            // En arco (AM.4): su contorno.
            profile: PlanOpening.arch(el) == null
                ? const []
                : [
                    for (var k = 0; k <= 16; k++)
                      (
                        a.across + (b.across - a.across) * k / 16,
                        PlanOpening.headAtM(el, -1 + k / 8, mpu),
                        PlanOpening.sill(el),
                      ),
                  ],
          ),
        );
        continue;
      }
      if (!behind(el.position)) continue;
      final p = at(el.position);
      switch (el.type) {
        case ElementType.light:
          final light = PlanLight.of(el);
          final beam = LightBeam.of(el);
          if (light == null || beam == null) continue;
          final overhead = PlanLight.isOverhead(el);
          final z = overhead
              ? PlanLight.heightOf(el)
              : (el.props[PlanLight.heightKey] as num?)?.toDouble() ?? standM;
          final dir = LightScene.aimOf(el);
          final across = acrossOf(dir, side, cut);
          double? aim;
          // Con su inclinación (F6.21.5): hacia el lado al que apunta en
          // planta, subiendo o bajando lo que diga el tilt.
          final tilt = PlanLight.elevationOf(el) * math.pi / 180;
          if (overhead || PlanLight.hasOwnAim(el)) {
            aim = across >= 0 ? tilt : math.pi - tilt;
          } else if (across.abs() > 0.2) {
            aim = across > 0 ? 0 : math.pi;
          }
          items.add(
            ElevationItem(
              kind: ElevationKind.light,
              element: el,
              from: p.across - 0.15,
              to: p.across + 0.15,
              bottom: z - 0.15,
              top: z + 0.15,
              depth: p.depth,
              label: (el.props['name'] as String?) ?? el.displayLabel,
              aim: aim,
              beamDeg: beam.spread,
              reachM: light.source.distanceFor(20).clamp(0.5, 8.0),
              cct: beam.cct,
              rgb: beam.rgb,
            ),
          );
        case ElementType.actor:
          items.add(
            ElevationItem(
              kind: ElevationKind.actor,
              element: el,
              from: p.across - 0.25,
              to: p.across + 0.25,
              bottom: 0,
              top: personM,
              depth: p.depth,
              label: el.displayLabel,
            ),
          );
        case ElementType.camera:
          final z =
              (el.props[PlanLight.heightKey] as num?)?.toDouble() ?? lensM;
          final across = acrossOf(LightScene.aimOf(el), side, cut);
          items.add(
            ElevationItem(
              kind: ElevationKind.camera,
              element: el,
              from: p.across - 0.2,
              to: p.across + 0.2,
              bottom: z - 0.12,
              top: z + 0.12,
              depth: p.depth,
              label: el.cameraLabel,
              aim: across.abs() > 0.2 ? (across > 0 ? 0 : math.pi) : null,
            ),
          );
        case ElementType.prop:
          if (PlanTerrainPainter.isTerrain(el) ||
              el.propType == PropType.meter) {
            continue;
          }
          final half = LightScene.propSizeM(el);
          items.add(
            ElevationItem(
              kind: ElevationKind.prop,
              element: el,
              from: p.across - half,
              to: p.across + half,
              bottom: 0,
              top: LightScene.propHeightM(el),
              depth: p.depth,
              label: el.displayLabel,
            ),
          );
        case ElementType.wall:
          break;
      }
    }
    // Lo lejano primero: lo cercano se pinta encima.
    items.sort((a, b) => b.depth.compareTo(a.depth));
    return PlanElevation(side, items, cut);
  }

  /// Dónde cruza un tramo la línea de corte (profundidad 0), de 0 a 1.
  static double _crossing(
    PlanElement el,
    double Function(Offset) depthAt,
  ) {
    var lo = 0.0, hi = 1.0;
    final front = depthAt(PlanSegment.pointAt(el, 0)) < 0;
    for (var i = 0; i < 30; i++) {
      final mid = (lo + hi) / 2;
      final behind = depthAt(PlanSegment.pointAt(el, mid)) >= 0;
      if (behind == front) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return (lo + hi) / 2;
  }
}

/// Pinta un [PlanElevation]: suelo, regla de alturas y cada pieza, más
/// tenue cuanto más lejos.
class PlanElevationPainter extends CustomPainter {
  final PlanElevation elevation;
  final Color ink;
  final Color faint;
  final Color background;
  final Color accent;

  PlanElevationPainter({
    required this.elevation,
    required this.ink,
    required this.faint,
    required this.background,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    const margin = EdgeInsets.fromLTRB(56, 24, 24, 40);
    final e = elevation;
    final spanM = math.max(1.0, e.right - e.left + 1);
    final scale = math.min(
      (size.width - margin.horizontal) / spanM,
      (size.height - margin.vertical) / e.height,
    );
    final floorY = size.height - margin.bottom;
    final leftX = margin.left + 0.5 * scale - e.left * scale;
    Offset to(double across, double z) =>
        Offset(leftX + across * scale, floorY - z * scale);

    // Regla de alturas y suelo.
    final rule = Paint()
      ..color = faint
      ..strokeWidth = 0.5;
    for (var z = 0; z <= e.height; z++) {
      final y = floorY - z * scale;
      canvas.drawLine(Offset(margin.left, y), Offset(size.width - 8, y), rule);
      _text(canvas, '$z m', Offset(10, y - 6), faint, 10);
    }
    canvas.drawLine(
      Offset(margin.left, floorY),
      Offset(size.width - 8, floorY),
      Paint()
        ..color = ink
        ..strokeWidth = 1.2,
    );

    final depths = e.items.map((i) => i.depth);
    final near = depths.isEmpty ? 0.0 : depths.reduce(math.min);
    final far = depths.isEmpty ? 0.0 : depths.reduce(math.max);
    for (final item in e.items) {
      // Lo de más lejos, a la mitad de tinta.
      final t = far - near < 0.01 ? 1.0 : (far - item.depth) / (far - near);
      final alpha = 0.45 + 0.55 * t;
      final color = ink.withValues(alpha: alpha);
      final rect = Rect.fromPoints(
        to(item.from, item.bottom),
        to(item.to, item.top),
      );
      switch (item.kind) {
        case ElevationKind.wall || ElevationKind.opening
            when item.profile.isNotEmpty:
          final outline = Path();
          for (final (i, (x, top, _)) in item.profile.indexed) {
            final p = to(x, top);
            i == 0 ? outline.moveTo(p.dx, p.dy) : outline.lineTo(p.dx, p.dy);
          }
          for (final (x, _, bottom) in item.profile.reversed) {
            final p = to(x, bottom);
            outline.lineTo(p.dx, p.dy);
          }
          outline.close();
          final wall = item.kind == ElevationKind.wall;
          canvas
            ..drawPath(
              outline,
              Paint()
                ..color = wall
                    ? (item.cut
                          ? ink.withValues(alpha: 0.85)
                          : faint.withValues(alpha: 0.18 * alpha))
                    : background,
            )
            ..drawPath(
              outline,
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = wall ? 1 : 0.8,
            );
        case ElevationKind.wall:
          canvas.drawRect(
            rect,
            Paint()
              ..color = item.cut
                  ? ink.withValues(alpha: 0.85)
                  : faint.withValues(alpha: 0.18 * alpha),
          );
          canvas.drawRect(
            rect,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        case ElevationKind.opening:
          canvas.drawRect(rect, Paint()..color = background);
          canvas.drawRect(
            rect,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );
        case ElevationKind.light:
          final c = to(item.centre, (item.bottom + item.top) / 2);
          final aim = item.aim;
          if (aim != null && item.beamDeg < 359) {
            final half = item.beamDeg / 2 * math.pi / 180;
            final r = item.reachM * scale;
            final beam = Path()
              ..moveTo(c.dx, c.dy)
              ..lineTo(
                c.dx + r * math.cos(aim - half),
                c.dy - r * math.sin(aim - half),
              )
              ..lineTo(
                c.dx + r * math.cos(aim + half),
                c.dy - r * math.sin(aim + half),
              )
              ..close();
            final tint = LightBeam.colorOf(item.cct, item.rgb);
            // La luz no pasa del suelo.
            canvas.save();
            canvas.clipRect(
              Rect.fromLTRB(margin.left, margin.top, size.width - 8, floorY),
            );
            canvas.drawPath(
              beam,
              Paint()
                ..shader = RadialGradient(
                  colors: [
                    tint.withValues(alpha: 0.45 * alpha),
                    tint.withValues(alpha: 0),
                  ],
                ).createShader(Rect.fromCircle(center: c, radius: r)),
            );
            canvas.restore();
          } else if (item.beamDeg >= 359) {
            canvas.drawCircle(
              c,
              0.6 * scale,
              Paint()
                ..color = LightBeam.colorOf(
                  item.cct,
                  item.rgb,
                ).withValues(alpha: 0.18 * alpha),
            );
          }
          // El pie hasta el suelo, si no cuelga.
          if (!PlanLight.isOverhead(item.element)) {
            canvas.drawLine(
              c,
              to(item.centre, 0),
              Paint()
                ..color = color
                ..strokeWidth = 1,
            );
          }
          canvas.drawCircle(c, 0.13 * scale, Paint()..color = accent);
          _text(canvas, item.label, c + const Offset(8, -14), color, 10);
        case ElevationKind.actor:
          final head = to(item.centre, item.top - 0.12);
          final paint = Paint()
            ..color = color
            ..strokeWidth = 1.4
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(head, 0.12 * scale, paint);
          canvas.drawLine(
            to(item.centre, item.top - 0.24),
            to(item.centre, 0.9),
            paint,
          );
          canvas.drawLine(
            to(item.centre, 0.9),
            to(item.centre - 0.18, 0),
            paint,
          );
          canvas.drawLine(
            to(item.centre, 0.9),
            to(item.centre + 0.18, 0),
            paint,
          );
          _text(
            canvas,
            item.label,
            to(item.centre, item.top) + const Offset(-14, -16),
            color,
            10,
          );
        case ElevationKind.camera:
          canvas.drawRect(rect, Paint()..color = color);
          canvas.drawLine(
            to(item.centre, item.bottom),
            to(item.centre, 0),
            Paint()
              ..color = color
              ..strokeWidth = 1,
          );
          _text(
            canvas,
            item.label,
            rect.topRight + const Offset(4, -12),
            color,
            10,
          );
        case ElevationKind.prop when item.profile.isNotEmpty:
          // Un volumen con cubierta: su silueta.
          final body = Path();
          for (final (i, (x, top, _)) in item.profile.indexed) {
            final p = to(x, top);
            i == 0 ? body.moveTo(p.dx, p.dy) : body.lineTo(p.dx, p.dy);
          }
          for (final (x, _, bottom) in item.profile.reversed) {
            final p = to(x, bottom);
            body.lineTo(p.dx, p.dy);
          }
          body.close();
          if (item.cut) {
            canvas.drawPath(body, Paint()..color = ink.withValues(alpha: 0.5));
          }
          canvas.drawPath(
            body,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );
        case ElevationKind.prop:
          if (item.cut) {
            canvas.drawRect(rect, Paint()..color = ink.withValues(alpha: 0.5));
          }
          canvas.drawRect(
            rect,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );
        case ElevationKind.drape:
          final cloth = Path();
          for (final (i, (x, top, _)) in item.profile.indexed) {
            final p = to(x, top);
            i == 0 ? cloth.moveTo(p.dx, p.dy) : cloth.lineTo(p.dx, p.dy);
          }
          for (final (x, _, bottom) in item.profile.reversed) {
            final p = to(x, bottom);
            cloth.lineTo(p.dx, p.dy);
          }
          cloth.close();
          canvas
            ..drawPath(
              cloth,
              Paint()
                ..color = PlanDrape.color(
                  item.element,
                ).withValues(alpha: 0.55 * alpha),
            )
            ..drawPath(
              cloth,
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.8,
            );
          _text(canvas, item.label, rect.bottomLeft + const Offset(2, 2),
              accent, 10);
        case ElevationKind.truss:
          final stroke = Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;
          canvas.drawRect(rect, stroke);
          if (rect.width > rect.height * 2) {
            // A lo largo: diagonales.
            final n = math.max(1, (rect.width / rect.height).round());
            for (var k = 0; k < n; k++) {
              final x0 = rect.left + rect.width * k / n;
              final x1 = rect.left + rect.width * (k + 1) / n;
              canvas.drawLine(
                Offset(x0, k.isEven ? rect.bottom : rect.top),
                Offset(x1, k.isEven ? rect.top : rect.bottom),
                stroke..strokeWidth = 0.6,
              );
            }
          } else {
            canvas
              ..drawLine(rect.topLeft, rect.bottomRight, stroke)
              ..drawLine(rect.topRight, rect.bottomLeft, stroke);
          }
        case ElevationKind.rigPoint:
          canvas
            ..drawRect(rect, Paint()..color = background)
            ..drawRect(
              rect,
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1,
            );
      }
    }
    _text(
      canvas,
      '${e.title} · ${e.hint}',
      Offset(margin.left, size.height - 22),
      faint,
      11,
    );
  }

  void _text(Canvas canvas, String text, Offset at, Color color, double size) {
    if (text.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 160);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant PlanElevationPainter old) =>
      old.elevation != elevation;
}
