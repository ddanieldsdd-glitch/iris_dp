import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/plan_opening.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/rig/scan_capture.dart';
import 'package:iris_dp/features/camera_plan/rig/scan_review.dart';
import 'package:iris_dp/features/camera_plan/rig/scan_structure.dart';

/// Una habitación de 4 × 3 con una puerta dudosa en la pared de abajo, una
/// ventana y una cama.
ScanStructure room() {
  ScanWall w(Offset a, Offset b, {double c = 1}) =>
      ScanWall(a, b, thickness: 0.12, confidence: c);
  return ScanStructure(
    floorY: 0,
    heightM: 2.6,
    heightEstimated: false,
    axisDeg: 0,
    walls: [
      w(const Offset(0, 0), const Offset(4, 0)),
      w(const Offset(4, 0), const Offset(4, 3)),
      w(const Offset(4, 3), const Offset(0, 3), c: 0.5),
      w(const Offset(0, 3), const Offset(0, 0)),
    ],
    openings: const [
      ScanOpening(
        kind: ScanOpeningKind.window,
        wall: 0,
        center: Offset(2, 0),
        width: 1.2,
        sill: 0.9,
        head: 2.1,
        confidence: 0.75,
      ),
      ScanOpening(
        kind: ScanOpeningKind.door,
        wall: 2,
        center: Offset(1, 3),
        width: 0.9,
        sill: 0,
        head: 2.05,
        confidence: 0.45,
      ),
    ],
    objects: const [
      ScanObject(
        center: Offset(3, 1),
        width: 1.4,
        depth: 2,
        rotationDeg: 0,
        heightM: 0.55,
        confidence: 0.8,
      ),
    ],
  );
}

/// Cámara de ARKit en (2, 1.5, 4) mirando hacia −Z (la pared de z = 0 de la
/// planta, que en el mundo es la misma).
const frontFrame = CaptureFrame(
  file: 'f_00001.jpg',
  transform: [
    1, 0, 0, 0, //
    0, 1, 0, 0, //
    0, 0, 1, 0, //
    2, 1.5, 4, 1,
  ],
  intrinsics: [1500, 1500, 1000, 750],
  width: 2000,
  height: 1500,
);

/// La misma cámara mirando hacia +Z: la pared le queda detrás.
const backFrame = CaptureFrame(
  file: 'f_00002.jpg',
  transform: [
    -1, 0, 0, 0, //
    0, 1, 0, 0, //
    0, 0, -1, 0, //
    2, 1.5, 4, 1,
  ],
  intrinsics: [1500, 1500, 1000, 750],
  width: 2000,
  height: 1500,
);

void main() {
  test('las propuestas, con lo dudoso marcado y la cama reconocida', () {
    final items = reviewItems(room());
    expect(items, hasLength(7));
    expect(items.where((it) => it.dubious), hasLength(2));
    final bed = items.firstWhere((it) => it.kind == ReviewKind.object);
    expect(bed.propType, PropType.bed);
    expect(bed.label, 'Cama');
  });

  test('lo aceptado pasa a la planta en sus unidades y con sus medidas', () {
    final s = room();
    final items = reviewItems(s);
    const mpu = 0.02;
    final els = reviewElements(s, items, mpu);
    final walls = els.where(PlanSegment.isSegment).toList();
    expect(walls, hasLength(4));
    expect(PlanSegment.end(walls.first), const Offset(200, 0));
    expect(walls.first.props[kScanThicknessKey], 0.12);
    expect(walls.first.props[kScanSourceKey], kScanSourceValue);

    final window = els.firstWhere(PlanOpening.isWindow);
    expect(PlanOpening.width(window), closeTo(60, 1e-6));
    expect(PlanOpening.sill(window), 0.9);
    expect(PlanOpening.head(window), 2.1);
    expect(window.position, const Offset(100, 0));

    final door = els.firstWhere(PlanOpening.isDoor);
    expect(door.rotation.abs(), closeTo(180, 1e-6));

    final bed = els.firstWhere((e) => e.type == ElementType.prop);
    expect(LightScene.furnitureSizeM(bed).width, 1.4);
    expect(LightScene.furnitureSizeM(bed).depth, 2);
    expect(LightScene.propHeightM(bed), 0.55);
  });

  test('sin su pared, el hueco no entra', () {
    final s = room();
    final items = reviewItems(s);
    items
            .firstWhere((it) => it.kind == ReviewKind.wall && it.index == 2)
            .accepted =
        false;
    final els = reviewElements(s, items, 0.02);
    expect(els.where(PlanOpening.isDoor), isEmpty);
    expect(els.where(PlanOpening.isWindow), hasLength(1));
  });

  test('las medidas corregidas en la revisión son las que se guardan', () {
    final s = room();
    final items = reviewItems(s);
    items.firstWhere((it) => it.kind == ReviewKind.window)
      ..width = 1.0
      ..sill = 1.0;
    final els = reviewElements(s, items, 0.01);
    final window = els.firstWhere(PlanOpening.isWindow);
    expect(PlanOpening.width(window), closeTo(100, 1e-6));
    expect(PlanOpening.sill(window), 1.0);
  });

  test('una foto de frente enseña la ventana; una de espaldas no', () {
    final s = room();
    final window = reviewItems(
      s,
    ).firstWhere((it) => it.kind == ReviewKind.window);
    final pts = reviewPoints(s, window);
    // El centro de la ventana: (2, 1.5, 0), justo delante de la cámara.
    expect(pts.first, [2.0, 1.5, 0.0]);
    final px = projectInto(frontFrame, pts.first)!;
    expect(px.dx, closeTo(1000, 1e-6));
    expect(px.dy, closeTo(750, 1e-6));
    expect(projectInto(backFrame, pts.first), isNull);
    final best = bestPhoto([backFrame, frontFrame], pts);
    expect(best!.frame.file, 'f_00001.jpg');
    // El alféizar queda por debajo del centro en la foto.
    expect(best.pixels[1]!.dy, greaterThan(750));
  });

  test('pegar al escaneo: la pared a mano se lleva a la del escaneo', () {
    final s = room();
    // Dibujada 15 cm desplazada, 3° torcida y algo corta.
    final snap = snapToScan(const Offset(0.1, 0.1), const Offset(3.9, 0.3), s)!;
    expect(snap.start.dy, closeTo(0, 1e-9));
    expect(snap.end.dy, closeTo(0, 1e-9));
    expect(snap.start.dx, closeTo(0, 1e-9));
    expect(snap.end.dx, closeTo(4, 1e-9));
    expect(snap.thickness, 0.12);
    // Lejos de todo: no se toca.
    expect(snapToScan(const Offset(1, 1.5), const Offset(3, 1.5), s), isNull);
  });

  test('el punto del techo cae dentro de la habitación', () {
    final p = interiorPoint(room())!;
    expect(p.dx, greaterThan(0));
    expect(p.dx, lessThan(4));
    expect(p.dy, greaterThan(0));
    expect(p.dy, lessThan(3));
  });

  test('escaparate y farola pasan a la planta', () {
    final base = room();
    final s = ScanStructure(
      floorY: 0,
      heightM: 2.6,
      heightEstimated: false,
      axisDeg: 0,
      walls: base.walls,
      openings: const [
        ScanOpening(
          kind: ScanOpeningKind.storefront,
          wall: 0,
          center: Offset(2, 0),
          width: 3,
          sill: 0,
          head: 2.4,
          confidence: 0.9,
        ),
      ],
      objects: const [],
      lights: const [ScanLight(Offset(2, 1.5), 2.4, 'neón o rótulo')],
    );
    final items = reviewItems(s);
    final shop = items.firstWhere((it) => it.kind == ReviewKind.storefront);
    expect(shop.label, 'Escaparate');
    final light = items.firstWhere((it) => it.kind == ReviewKind.light);
    expect(light.label, 'Neón o rótulo');
    expect(light.dubious, isFalse);

    final els = reviewElements(s, items, 0.01);
    final window = els.firstWhere(PlanOpening.isWindow);
    expect(PlanOpening.width(window), closeTo(300, 1e-6));
    expect(PlanOpening.sill(window), 0);
    final lamp = els.firstWhere((e) => e.type == ElementType.light);
    expect(lamp.position, const Offset(200, 150));
    expect(lamp.props[PlanLight.heightKey], 2.4);
  });
}
