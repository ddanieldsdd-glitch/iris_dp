import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/rig/scan_capture.dart';
import 'package:iris_dp/features/camera_plan/rig/scan_direct.dart';
import 'package:iris_dp/features/camera_plan/rig/scan_structure.dart';

/// Una habitación de 5 × 4 m y 2,5 de alto, con el suelo a −1,4 m (ARKit
/// pone el origen donde empieza la sesión).
const floor = -1.4, ceiling = 1.1;

CapturePlane wall(
  Offset a,
  Offset b, {
  double bottom = -0.9,
  double top = 0.8,
  String classification = 'wall',
}) {
  final along = b - a;
  final len = along.distance;
  final d = along / len;
  final mid = (a + b) / 2;
  return CapturePlane(
    id: '$a',
    vertical: true,
    classification: classification,
    transform: [
      d.dx, 0, d.dy, 0,
      -d.dy, 0, d.dx, 0,
      0, 1, 0, 0,
      mid.dx, (bottom + top) / 2, mid.dy, 1,
    ],
    center: const [0, 0, 0],
    extent: [len, top - bottom],
  );
}

CapturePlane flat(Offset at, double y, double w, double d, String kind) =>
    CapturePlane(
      id: '$at',
      vertical: false,
      classification: kind,
      transform: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, at.dx, y, at.dy, 1],
      center: const [0, 0, 0],
      extent: [w, d],
    );

CaptureMark corner(double x, double z) =>
    CaptureMark('corner', [x, floor + 1, z]);

const c0 = Offset(0, 0), c1 = Offset(5, 0), c2 = Offset(5, 4), c3 = Offset(0, 4);

final partialWalls = [
  wall(const Offset(0.8, 0), const Offset(4.2, 0)),
  wall(const Offset(5, 0.5), const Offset(5, 3.5)),
  wall(const Offset(4.2, 4), const Offset(0.8, 4)),
  wall(const Offset(0, 3.5), const Offset(0, 0.5)),
];

final markedCorners = [
  corner(0, 0),
  corner(5, 0),
  corner(5, 4),
  corner(0, 4),
];

final levels = [
  CaptureMark('floor', [2, floor, 2]),
  CaptureMark('ceiling', [2, ceiling, 2]),
];

CapturePackage pack({
  List<CapturePlane> planes = const [],
  List<CaptureMark> marks = const [],
  bool exterior = false,
}) => CapturePackage(
  '/tmp/x',
  const [],
  version: 2,
  planes: planes,
  marks: marks,
  exterior: exterior,
);

void expectNear(Offset got, Offset want) =>
    expect((got - want).distance, lessThan(0.06), reason: '$got ≠ $want');

void main() {
  test('las esquinas tocadas dan las paredes enteras', () {
    final plan = solveCaptureDirect(
      pack(planes: partialWalls, marks: [...markedCorners, ...levels]),
    )!;
    final s = plan.structure;
    expect(s.walls, hasLength(4));
    expect(s.heightM, closeTo(2.5, 0.01));
    expect(s.heightEstimated, isFalse);
    expect(s.floorY, closeTo(floor, 0.01));
    final lengths = s.walls.map((w) => w.length).toList()..sort();
    expect(lengths[0], closeTo(4, 0.1));
    expect(lengths[3], closeTo(5, 0.1));
    for (final point in [c0, c1, c2, c3]) {
      expect(
        s.walls.any(
          (w) =>
              (w.start - point).distance < 0.06 ||
              (w.end - point).distance < 0.06,
        ),
        isTrue,
        reason: 'falta la esquina $point',
      );
    }
  });

  test('las esquinas sirven aunque se toquen desordenadas', () {
    final s = solveCaptureDirect(
      pack(
        marks: [
          corner(0, 0),
          corner(5, 4),
          corner(5, 0),
          corner(0, 4),
          ...levels,
        ],
      ),
    )!.structure;
    expect(s.walls, hasLength(4));
    final lengths = s.walls.map((w) => w.length).toList()..sort();
    expect(lengths.first, closeTo(4, 0.1));
  });

  test('solo con planos, sin esquinas, también sale la planta', () {
    final s = solveCaptureDirect(
      pack(
        planes: [
          wall(c0, c1),
          wall(c1, c2),
          wall(c2, c3),
          wall(c3, c0),
          flat(const Offset(2.5, 2), floor, 4, 3, 'floor'),
        ],
      ),
    )!.structure;
    expect(s.walls, hasLength(4));
    expect(s.floorY, closeTo(floor, 0.01));
    expect(s.heightEstimated, isTrue);
  });

  test('un trozo de pared sin ver no se inventa un paso', () {
    final s = solveCaptureDirect(
      pack(
        planes: [
          wall(c0, const Offset(1.5, 0)),
          wall(const Offset(3.5, 0), c1),
          flat(const Offset(2.5, 2), floor, 4, 3, 'floor'),
        ],
      ),
    )!.structure;
    expect(s.openings, isEmpty);
  });

  test('el costado de un mueble no es una pared', () {
    final s = solveCaptureDirect(
      pack(
        planes: [
          wall(c0, c1),
          wall(
            const Offset(1, 2),
            const Offset(3, 2),
            bottom: floor,
            top: floor + 0.8,
          ),
          flat(const Offset(2.5, 2), floor, 4, 3, 'floor'),
        ],
      ),
    )!.structure;
    expect(s.walls, hasLength(1));
  });

  test('puertas y ventanas salen de sus dos toques', () {
    final s = solveCaptureDirect(
      pack(
        marks: [
          ...markedCorners,
          ...levels,
          CaptureMark('door', [1, floor + 1, 0]),
          CaptureMark('door', [1.9, floor + 1, 0]),
          CaptureMark('window', [5, floor + 0.9, 1]),
          CaptureMark('window', [5, floor + 2, 2.2]),
        ],
      ),
    )!.structure;
    final door = s.openings.singleWhere((o) => o.kind == ScanOpeningKind.door);
    expect(door.width, closeTo(0.9, 0.01));
    expect(door.sill, 0);
    expectNear(door.center, const Offset(1.45, 0));
    expect(door.confidence, greaterThan(0.8));

    final window = s.openings.singleWhere(
      (o) => o.kind == ScanOpeningKind.window,
    );
    expect(window.width, closeTo(1.2, 0.01));
    expect(window.sill, closeTo(0.9, 0.01));
    expect(window.head, closeTo(2, 0.01));
  });

  test('un toque suelto de puerta queda con medida de serie y dudoso', () {
    final s = solveCaptureDirect(
      pack(
        marks: [
          ...markedCorners,
          ...levels,
          CaptureMark('door', [2, floor + 1, 0]),
        ],
      ),
    )!.structure;
    final door = s.openings.single;
    expect(door.width, 0.8);
    expect(door.confidence, lessThan(0.7));
  });

  test('una puerta clasificada por ARKit entra si no se ha tocado', () {
    final s = solveCaptureDirect(
      pack(
        planes: [
          wall(
            const Offset(2, 0),
            const Offset(2.8, 0),
            bottom: floor,
            top: floor + 2,
            classification: 'door',
          ),
        ],
        marks: [...markedCorners, ...levels],
      ),
    )!.structure;
    expect(s.openings.single.kind, ScanOpeningKind.door);
    expect(s.openings.single.width, closeTo(0.8, 0.01));
  });

  test('una mesa de ARKit es un mueble a su altura', () {
    final s = solveCaptureDirect(
      pack(
        planes: [flat(const Offset(2.5, 2), floor + 0.75, 1.2, 0.8, 'table')],
        marks: [...markedCorners, ...levels],
      ),
    )!.structure;
    final table = s.objects.single;
    expect(table.heightM, closeTo(0.75, 0.01));
    expect(table.width, closeTo(1.2, 0.01));
    expectNear(table.center, const Offset(2.5, 2));
  });

  test('en exterior no hay techo', () {
    final s = solveCaptureDirect(
      pack(marks: [...markedCorners, ...levels], exterior: true),
    )!.structure;
    expect(s.exterior, isTrue);
    expect(s.heightEstimated, isTrue);
  });

  test('sin paredes ni esquinas no hay planta', () {
    expect(
      solveCaptureDirect(
        pack(planes: [flat(const Offset(2.5, 2), floor, 4, 3, 'floor')]),
      ),
      isNull,
    );
  });

  test('mover la estructura lo mueve todo', () {
    final s = solveCaptureDirect(
      pack(
        marks: [
          ...markedCorners,
          ...levels,
          CaptureMark('door', [2, floor + 1, 0]),
        ],
      ),
    )!.structure;
    final moved = movedStructure(s, const Offset(10, 3));
    expectNear(moved.walls.first.start, s.walls.first.start + const Offset(10, 3));
    expectNear(moved.openings.first.center, s.openings.first.center + const Offset(10, 3));
    expect(moved.heightM, s.heightM);
  });
}
