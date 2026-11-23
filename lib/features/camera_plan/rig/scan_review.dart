import 'dart:math' as math;
import 'dart:ui';

import '../../unreal_link/unreal_asset_ref.dart';
import '../../unreal_link/unreal_library.dart';
import '../arch/arch_material.dart';
import '../arch/arch_solid.dart';
import '../arch/arch_stair.dart';
import '../arch/plan_levels.dart';
import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../light/light_scene.dart';
import '../light/plan_light.dart';
import '../plan_opening.dart';
import '../plan_segment.dart';
import 'plan_rig.dart';
import 'scan_capture.dart';
import 'scan_engine.dart';
import 'scan_structure.dart';

/// Qué es cada cosa que se revisa (ES.3).
enum ReviewKind {
  wall,
  door,
  window,
  passage,
  storefront,
  object,
  light,

  /// Del escaneo al motor (AM.U3): el suelo y el techo del recinto como
  /// forjados, otro suelo como nivel y una escalera o rampa.
  floor,
  ceiling,
  level,
  stair,
}

/// Una propuesta del solucionador en la revisión: se acepta o no, y se le
/// pueden corregir las medidas.
class ReviewItem {
  final ReviewKind kind;

  /// Índice en la lista de su tipo dentro de [ScanStructure].
  final int index;
  final double confidence;
  bool accepted;

  /// Medidas que se pueden corregir, en metros: ancho del hueco o del
  /// mueble, alféizar, dintel, grosor de la pared, fondo y alto del mueble.
  double width, sill, head, thickness, depth, height;

  /// Tipo de mueble, solo para [ReviewKind.object].
  PropType propType;

  /// Qué luz práctica es (farola, fluorescente…), solo para
  /// [ReviewKind.light].
  String name;

  /// Un mueble sin tipo entra como volumen (AM.U3); con tipo, como pieza
  /// de atrezzo con su asset de Unreal si la biblioteca tiene uno.
  bool asVolume;

  /// El material propuesto por el color de la foto (AM.U3), o el elegido.
  String? materialId;

  ReviewItem({
    required this.kind,
    required this.index,
    required this.confidence,
    this.accepted = true,
    this.width = 0,
    this.sill = 0,
    this.head = 0,
    this.thickness = 0,
    this.depth = 0,
    this.height = 0,
    this.propType = PropType.rectangle,
    this.name = '',
    this.asVolume = true,
    this.materialId,
  });

  /// Un hueco en una pared: puerta, ventana, paso o escaparate.
  bool get isOpening => switch (kind) {
    ReviewKind.door ||
    ReviewKind.window ||
    ReviewKind.passage ||
    ReviewKind.storefront => true,
    _ => false,
  };

  /// Lo que no está claro: se pregunta enseñando la foto.
  bool get dubious => confidence < 0.7;

  String get label => switch (kind) {
    ReviewKind.wall => 'Pared',
    ReviewKind.door => 'Puerta',
    ReviewKind.window => 'Ventana',
    ReviewKind.passage => 'Paso',
    ReviewKind.storefront => 'Escaparate',
    ReviewKind.light =>
      name.isEmpty ? 'Luz práctica' : name[0].toUpperCase() + name.substring(1),
    ReviewKind.floor => 'Suelo',
    ReviewKind.ceiling => 'Techo',
    ReviewKind.level => name.isEmpty ? 'Nivel' : name,
    ReviewKind.stair => name.isEmpty ? 'Escalera' : name,
    ReviewKind.object => switch (propType) {
      PropType.bed => 'Cama',
      PropType.table => 'Mesa',
      PropType.sofa => 'Sofá',
      PropType.chair => 'Silla',
      _ => 'Mueble',
    },
  };
}

/// Las propuestas de [s] listas para revisar, en el orden en que se dibujan.
List<ReviewItem> reviewItems(ScanStructure s) => [
  for (var i = 0; i < s.walls.length; i++)
    ReviewItem(
      kind: ReviewKind.wall,
      index: i,
      confidence: s.walls[i].confidence,
      thickness: s.walls[i].thickness,
      height: s.heightM,
    ),
  for (var i = 0; i < s.openings.length; i++)
    ReviewItem(
      kind: switch (s.openings[i].kind) {
        ScanOpeningKind.door => ReviewKind.door,
        ScanOpeningKind.window => ReviewKind.window,
        ScanOpeningKind.passage => ReviewKind.passage,
        ScanOpeningKind.storefront => ReviewKind.storefront,
      },
      index: i,
      confidence: s.openings[i].confidence,
      width: s.openings[i].width,
      sill: s.openings[i].sill,
      head: s.openings[i].head,
    ),
  for (var i = 0; i < s.objects.length; i++)
    ReviewItem(
      kind: ReviewKind.object,
      index: i,
      confidence: s.objects[i].confidence,
      width: s.objects[i].width,
      depth: s.objects[i].depth,
      height: s.objects[i].heightM,
      propType: guessFurniture(s.objects[i]),
    ),
  for (var i = 0; i < s.lights.length; i++)
    ReviewItem(
      kind: ReviewKind.light,
      index: i,
      // La ha tocado quien escaneaba: segura.
      confidence: 1,
      height: s.lights[i].y,
      name: s.lights[i].label,
    ),
  // Del escaneo al motor (AM.U3).
  if (!s.exterior && ScanEngine.outline(s.walls) != null) ...[
    ReviewItem(
      kind: ReviewKind.floor,
      index: 0,
      confidence: 0.9,
      thickness: 0.1,
    ),
    ReviewItem(
      kind: ReviewKind.ceiling,
      index: 0,
      confidence: s.heightEstimated ? 0.5 : 0.9,
      // Un techo que no se vio, mejor no ponerlo sin mirar.
      accepted: !s.heightEstimated,
      thickness: 0.2,
      height: s.heightM,
    ),
    for (var i = 0; i < s.floors.length; i++)
      ReviewItem(
        kind: ReviewKind.level,
        index: i,
        confidence: 0.7,
        thickness: PlanLevels.defaultSlabThickM,
        height: s.floors[i],
        name: 'Planta ${i + 1}',
      ),
  ],
  for (var i = 0; i < s.stairs.length; i++)
    ReviewItem(
      kind: ReviewKind.stair,
      index: i,
      confidence: s.stairs[i].confidence,
      width: s.stairs[i].widthM,
      height: s.stairs[i].riseM,
      name: s.stairs[i].ramp ? 'Rampa' : 'Escalera',
    ),
];

/// Un primer tipo para el mueble por su tamaño; se cambia en la revisión.
PropType guessFurniture(ScanObject o) {
  final long = math.max(o.width, o.depth), short = math.min(o.width, o.depth);
  if (o.heightM < 0.7 && long >= 1.8 && short >= 0.8) return PropType.bed;
  if (o.heightM < 1.0 && long >= 1.6 && short >= 0.7) return PropType.sofa;
  if (o.heightM >= 0.65 && o.heightM <= 0.85 && long >= 0.7) {
    return PropType.table;
  }
  return PropType.rectangle;
}

/// Puntos de la planta (x, altura, y) que enseñan [item] en una foto: el
/// primero es su centro; los demás, su contorno.
List<List<double>> reviewPoints(ScanStructure s, ReviewItem item) {
  final f = s.floorY;
  List<double> at(Offset p, double h) => [p.dx, f + h, p.dy];
  switch (item.kind) {
    case ReviewKind.wall:
      final w = s.walls[item.index];
      final mid = (w.start + w.end) / 2;
      return [
        at(mid, s.heightM / 2),
        at(w.start, 0),
        at(w.end, 0),
        at(w.end, s.heightM),
        at(w.start, s.heightM),
      ];
    case ReviewKind.light:
      return [at(s.lights[item.index].position, item.height)];
    case ReviewKind.floor || ReviewKind.ceiling || ReviewKind.level:
      final o = ScanEngine.outline(s.walls) ?? const <Offset>[];
      if (o.isEmpty) return const [];
      final h = item.kind == ReviewKind.floor ? 0.0 : item.height;
      var c = Offset.zero;
      for (final p in o) {
        c += p;
      }
      c = c / o.length.toDouble();
      // Un poco hacia dentro: en la foto, sin las paredes.
      return [at(c, h), for (final p in o) at(Offset.lerp(p, c, 0.2)!, h)];
    case ReviewKind.stair:
      final st = s.stairs[item.index];
      final n = Offset(-(st.to - st.from).dy, (st.to - st.from).dx) /
          math.max(1e-6, st.runM) *
          (item.width / 2);
      return [
        at((st.from + st.to) / 2, item.height / 2),
        at(st.from - n, 0),
        at(st.from + n, 0),
        at(st.to + n, item.height),
        at(st.to - n, item.height),
      ];
    case ReviewKind.door ||
        ReviewKind.window ||
        ReviewKind.passage ||
        ReviewKind.storefront:
      final o = s.openings[item.index];
      final d = s.walls[o.wall].dir * (item.width / 2);
      return [
        at(o.center, (item.sill + item.head) / 2),
        at(o.center - d, item.sill),
        at(o.center + d, item.sill),
        at(o.center + d, item.head),
        at(o.center - d, item.head),
      ];
    case ReviewKind.object:
      final o = s.objects[item.index];
      final r = o.rotationDeg * math.pi / 180;
      final u = Offset(math.cos(r), math.sin(r)) * (item.width / 2);
      final v = Offset(-math.sin(r), math.cos(r)) * (item.depth / 2);
      return [
        at(o.center, item.height / 2),
        at(o.center - u - v, item.height),
        at(o.center + u - v, item.height),
        at(o.center + u + v, item.height),
        at(o.center - u + v, item.height),
      ];
  }
}

/// La foto de la captura que mejor enseña unos puntos, y dónde caen en ella.
class PhotoView {
  final CaptureFrame frame;

  /// Los puntos en píxeles de la foto; null si quedan detrás de la cámara.
  final List<Offset?> pixels;

  const PhotoView(this.frame, this.pixels);
}

/// Dónde cae el punto [x] (mundo de ARKit) en la foto [f]; null si está
/// detrás o a menos de 20 cm.
Offset? projectInto(CaptureFrame f, List<double> x) {
  final right = f.column(0), up = f.column(1), back = f.column(2);
  final c = f.column(3);
  final v = [x[0] - c[0], x[1] - c[1], x[2] - c[2]];
  double dot(List<double> a) => a[0] * v[0] + a[1] * v[1] + a[2] * v[2];
  final depth = -dot(back);
  if (depth < 0.2) return null;
  final k = f.intrinsics;
  return Offset(
    k[0] * dot(right) / depth + k[2],
    k[3] - k[1] * dot(up) / depth,
  );
}

/// Entre [frames], la foto que mejor enseña [world] (mundo de ARKit, el
/// primero es el centro): el centro dentro de la foto y cerca de su centro,
/// a una distancia cómoda y con todo el contorno a la vista.
PhotoView? bestPhoto(List<CaptureFrame> frames, List<List<double>> world) {
  if (world.isEmpty) return null;
  PhotoView? best;
  var bestScore = -double.infinity;
  for (final f in frames) {
    final px = [for (final x in world) projectInto(f, x)];
    final centre = px.first;
    if (centre == null) continue;
    final w = f.width.toDouble(), h = f.height.toDouble();
    if (centre.dx < 0 || centre.dy < 0 || centre.dx > w || centre.dy > h) {
      continue;
    }
    final off = (centre - Offset(w / 2, h / 2)).distance / (math.max(w, h) / 2);
    final inside = px.where(
      (p) => p != null && p.dx >= 0 && p.dy >= 0 && p.dx <= w && p.dy <= h,
    );
    final cam = f.column(3);
    final dist = math.sqrt(
      math.pow(world.first[0] - cam[0], 2) +
          math.pow(world.first[1] - cam[1], 2) +
          math.pow(world.first[2] - cam[2], 2),
    );
    final score =
        inside.length / px.length - off * 0.6 - (dist - 2.5).abs() * 0.1;
    if (score > bestScore) {
      bestScore = score;
      best = PhotoView(f, px);
    }
  }
  return best;
}

/// Clave en las props de lo que sale del escaneo.
const kScanSourceKey = 'source';
const kScanSourceValue = 'scan';
const kScanThicknessKey = 'thicknessM';

/// Entre qué materiales se busca el de una cara por el color de su foto
/// (AM.U3); `null` si esa propuesta no lleva material.
Set<ArchFamily>? photoMaterialFamilies(ReviewKind kind) => switch (kind) {
  ReviewKind.wall => ScanEngine.wallFamilies,
  ReviewKind.floor => ScanEngine.floorFamilies,
  ReviewKind.ceiling => ScanEngine.ceilingFamilies,
  _ => null,
};

/// Los elementos de la planta para lo aceptado de [s], en unidades de la
/// planta ([mpu] metros por unidad). Las paredes llevan su grosor y lo que
/// sale del escaneo va marcado con `source: scan`.
List<PlanElement> reviewElements(
  ScanStructure s,
  List<ReviewItem> items,
  double mpu,
) {
  final out = <PlanElement>[];
  for (final it in items.where((it) => it.accepted)) {
    switch (it.kind) {
      case ReviewKind.wall:
        final w = s.walls[it.index];
        out.add(
          PlanSegment.create(start: w.start / mpu, end: w.end / mpu)
            ..layer = PlanLayer.environment
            ..props[kScanThicknessKey] = _round(it.thickness)
            ..props[kScanSourceKey] = kScanSourceValue
            ..props.addAll({
              if (it.materialId case final m?) ArchMaterials.key: m,
            }),
        );
      case ReviewKind.floor || ReviewKind.ceiling || ReviewKind.level:
        final o = ScanEngine.outline(s.walls);
        if (o == null) continue;
        var c = Offset.zero;
        for (final p in o) {
          c += p;
        }
        c = c / o.length.toDouble();
        // Con la cara de arriba en su cota: el suelo, a 0 y hacia abajo;
        // el techo, con la de abajo a la altura del techo.
        final top = switch (it.kind) {
          ReviewKind.floor => 0.0,
          ReviewKind.ceiling => it.height + it.thickness,
          _ => it.height,
        };
        final slab = ArchSolid.create(RigType.slab, c / mpu, [
          for (final p in o) p - c,
        ]);
        slab
          ..layer = PlanLayer.environment
          ..props[ArchSolid.topKey] = _round(top)
          ..props[ArchSolid.thickKey] = _round(it.thickness)
          ..props[ArchMaterials.key] =
              it.materialId ??
              switch (it.kind) {
                ReviewKind.floor => 'concrete-floor',
                ReviewKind.ceiling => 'plaster-raw',
                _ => PlanLevels.defaultSlabMat,
              }
          ..props[kScanSourceKey] = kScanSourceValue;
        if (it.kind == ReviewKind.level) {
          slab.props[PlanLevels.nameKey] = it.label;
        }
        out.add(slab);
      case ReviewKind.stair:
        final st = s.stairs[it.index];
        final el = ArchStair.create(
          st.from / mpu,
          st.to / mpu,
          mpu,
          shape: st.ramp ? StairShape.ramp : StairShape.straight,
        );
        el
          ..layer = PlanLayer.environment
          ..props[ArchStair.widthKey] = _round(it.width)
          ..props[ArchStair.riseKey] = _round(it.height)
          ..props[kScanSourceKey] = kScanSourceValue;
        out.add(el);
      case ReviewKind.light:
        // Una luz práctica de la localización: entra como luz en la planta,
        // a su altura y con su nombre.
        out.add(
          PlanElement(
            id: 0,
            type: ElementType.light,
            position: s.lights[it.index].position / mpu,
            lightType: LightType.practical,
            label: it.label,
            props: {
              PlanLight.heightKey: _round(it.height),
              kScanSourceKey: kScanSourceValue,
            },
          ),
        );
      case ReviewKind.door ||
          ReviewKind.window ||
          ReviewKind.passage ||
          ReviewKind.storefront:
        final o = s.openings[it.index];
        // Un hueco va sobre su pared: sin ella no tiene dónde ir.
        if (!items.any(
          (w) => w.kind == ReviewKind.wall && w.index == o.wall && w.accepted,
        )) {
          continue;
        }
        final d = s.walls[o.wall].dir;
        final type = switch (it.kind) {
          // Un escaparate es una ventana de cristal que llega al suelo.
          ReviewKind.window || ReviewKind.storefront => ArchitectureType.window,
          ReviewKind.passage => ArchitectureType.opening,
          _ when it.width >= 1.3 => ArchitectureType.doubleDoor,
          _ => ArchitectureType.doorOpen,
        };
        out.add(
          PlanElement(
            id: 0,
            type: ElementType.wall,
            position: o.center / mpu,
            rotation: math.atan2(d.dy, d.dx) * 180 / math.pi,
            label: type.dbValue,
            props: {
              PlanOpening.widthKey: it.width / mpu,
              PlanOpening.sillKey: _round(it.sill),
              PlanOpening.headKey: _round(it.head),
              kScanSourceKey: kScanSourceValue,
            },
          )..layer = PlanLayer.environment,
        );
      case ReviewKind.object
          when it.propType == PropType.rectangle && it.asVolume:
        // Un mueble sin tipo: un volumen con su caja (AM.U3).
        final o = s.objects[it.index];
        final hw = it.width / 2, hd = it.depth / 2;
        final vol = ArchSolid.create(RigType.volume, o.center / mpu, [
          Offset(-hw, -hd),
          Offset(hw, -hd),
          Offset(hw, hd),
          Offset(-hw, hd),
        ]);
        vol
          ..rotation = o.rotationDeg
          ..layer = PlanLayer.environment
          ..props[ArchSolid.heightKey] = _round(it.height)
          ..props[kScanSourceKey] = kScanSourceValue;
        if (it.materialId case final m?) vol.props[ArchMaterials.key] = m;
        out.add(vol);
      case ReviewKind.object:
        final o = s.objects[it.index];
        final asset = it.propType == PropType.rectangle
            ? null
            : UnrealLibrary.instance.suggestFor(it.propType);
        out.add(
          PlanElement(
            id: 0,
            type: ElementType.prop,
            position: o.center / mpu,
            rotation: o.rotationDeg,
            label: it.propType.dbValue,
            props: {
              LightScene.widthKey: _round(it.width),
              LightScene.depthKey: _round(it.depth),
              LightScene.heightKey: _round(it.height),
              kScanSourceKey: kScanSourceValue,
            },
          )
            ..layer = PlanLayer.environment
            // En Unreal, el asset de ese tipo que ya está en la biblioteca.
            ..props.addAll({
              if (asset != null) UnrealAssetRef.key: asset.toJson(),
            }),
        );
    }
  }
  return out;
}

/// Un punto dentro de la casa para guardar la altura del techo de su
/// recinto: medio metro hacia dentro desde el centro de la pared más larga.
Offset? interiorPoint(ScanStructure s) {
  if (s.walls.isEmpty) return null;
  var c = Offset.zero;
  for (final w in s.walls) {
    c += (w.start + w.end) / 2;
  }
  c = c / s.walls.length.toDouble();
  final longest = s.walls.reduce((a, b) => a.length >= b.length ? a : b);
  final mid = (longest.start + longest.end) / 2;
  var n = longest.normal;
  final toC = c - mid;
  if (n.dx * toC.dx + n.dy * toC.dy < 0) n = -n;
  return mid + n * (longest.thickness / 2 + 0.5);
}

double _round(double v) => (v * 100).round() / 100;

/// «Pegar al escaneo» (ES.3): una pared dibujada a mano ([start]–[end], en
/// metros) se lleva a la pared del escaneo que tiene al lado: misma recta y
/// mismo grosor, con sus extremos proyectados. Null si no hay ninguna a
/// menos de [tol] metros y [angleTolDeg] grados.
({Offset start, Offset end, double thickness})? snapToScan(
  Offset start,
  Offset end,
  ScanStructure s, {
  double tol = 0.4,
  double angleTolDeg = 10,
}) {
  final len = (end - start).distance;
  if (len < 0.05) return null;
  final d = (end - start) / len;
  final cosTol = math.cos(angleTolDeg * math.pi / 180);
  ScanWall? best;
  var bestDist = tol;
  for (final w in s.walls) {
    if ((d.dx * w.dir.dx + d.dy * w.dir.dy).abs() < cosTol) continue;
    final mid = (start + end) / 2;
    final dist = (mid.dx * w.normal.dx + mid.dy * w.normal.dy - w.offset).abs();
    if (dist > bestDist) continue;
    // Que se solapen a lo largo.
    final t0 = math.min(w.tOf(start), w.tOf(end));
    final t1 = math.max(w.tOf(start), w.tOf(end));
    final w0 = math.min(w.tOf(w.start), w.tOf(w.end));
    final w1 = math.max(w.tOf(w.start), w.tOf(w.end));
    if (math.min(t1, w1) - math.max(t0, w0) < 0.3 * math.min(len, w.length)) {
      continue;
    }
    best = w;
    bestDist = dist;
  }
  if (best == null) return null;
  final w = best;
  Offset onLine(Offset p) => w.normal * w.offset + w.dir * w.tOf(p);
  // Un extremo cerca del de la pared del escaneo se lleva a él: así las
  // esquinas quedan como las midió el escaneo.
  Offset snapEnd(Offset p) {
    final q = onLine(p);
    for (final e in [w.start, w.end]) {
      if ((e - q).distance <= tol) return e;
    }
    return q;
  }

  return (start: snapEnd(start), end: snapEnd(end), thickness: w.thickness);
}
