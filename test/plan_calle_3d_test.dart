import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/light/street_lamp.dart';
import 'package:iris_dp/features/camera_plan/light/wall_mount.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/plan_street.dart';
import 'package:iris_dp/features/camera_plan/street_controls.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';

/// 3D legible y calle con perfil (plan CA).
void main() {
  const mpu = 0.01;

  PlanElement wall(Offset a, Offset b, {Map<String, dynamic>? props}) =>
      PlanSegment.create(start: a, end: b)
        ..props['uid'] = 'W${a.dx}'
        ..props.addAll(props ?? const {});

  PlanElement door(ArchitectureType t, Offset at) => PlanElement(
    id: 3,
    type: ElementType.wall,
    position: at,
    label: t.dbValue,
    props: {'uid': 'D', 'width': 90},
  );

  Map<String, dynamic> scene(List<PlanElement> els) =>
      PlanScene3d.build(els, metersPerUnit: mpu);

  Map<String, dynamic> firstWall(Map<String, dynamic> sc) =>
      (sc['walls'] as List).first as Map<String, dynamic>;

  test('CA.1: la pared lleva su grosor (12 cm si no se dice)', () {
    final plain = firstWall(scene([wall(Offset.zero, const Offset(400, 0))]));
    expect(plain['thick'], PlanSegment.defaultThicknessM);
    final thick = firstWall(
      scene([
        wall(
          Offset.zero,
          const Offset(400, 0),
          props: {PlanSegment.thicknessKey: 0.3},
        ),
      ]),
    );
    expect(thick['thick'], 0.3);
  });

  test('CA.2: una puerta cerrada lleva su hoja sobre el hueco', () {
    final w = firstWall(
      scene([
        wall(Offset.zero, const Offset(400, 0)),
        door(ArchitectureType.doorClosed, const Offset(200, 0)),
      ]),
    );
    final hole = (w['openings'] as List).single as Map<String, dynamic>;
    expect(hole['kind'], 'door');
    final span = hole['span'] as List;
    expect(span[0], closeTo(1.55, 1e-6));
    expect(span[2], closeTo(2.45, 1e-6));
    final leaf = (hole['leaves'] as List).single as List;
    // Cerrada: de la bisagra al otro canto, sobre la línea de la pared.
    expect(leaf[0], closeTo(1.55, 1e-6));
    expect(leaf[2], closeTo(2.45, 1e-6));
    expect(leaf[3], closeTo(0, 1e-6));
  });

  test('CA.2: una puerta doble abierta lleva dos hojas giradas', () {
    final w = firstWall(
      scene([
        wall(Offset.zero, const Offset(400, 0)),
        door(ArchitectureType.doubleDoor, const Offset(200, 0)),
      ]),
    );
    final hole = (w['openings'] as List).single as Map<String, dynamic>;
    final leaves = hole['leaves'] as List;
    expect(leaves, hasLength(2));
    for (final l in leaves.cast<List>()) {
      // A 90°: la hoja sale de la pared, 45 cm.
      expect((l[3] as double).abs(), closeTo(0.45, 1e-6));
    }
  });

  PlanElement tube({Map<String, dynamic>? props}) => PlanElement(
    id: 4,
    type: ElementType.light,
    position: const Offset(200, 60),
    lightType: LightType.floSingle,
    props: {'uid': 'T', 'intensity': 100, ...?props},
  );

  test('CA.3: un tubo pegado a la pared se queda a ras y tumbado', () {
    final w = wall(Offset.zero, const Offset(400, 0));
    final t = tube(props: {PlanLight.mountKey: PlanLight.mountWall});
    expect(LightWallMount.snap(t, [w, t], mpu), isTrue);
    // A 6 + 5 cm de la línea de la pared, por el lado en que estaba.
    expect(t.position.dx, closeTo(200, 1e-6));
    expect(t.position.dy, closeTo(11, 1e-6));
    // Mira hacia fuera de la pared (+y en la planta = 180°).
    expect(t.rotation, closeTo(180, 1e-6));
    expect(t.props[PlanLight.heightKey], LightWallMount.defaultHeightM);

    final f = (scene([w, t])['fixtures'] as List).single as Map;
    expect(f['shape'], 'tube');
    expect(f['mount'], 'wall');
    expect(f['lengthM'], greaterThan(0.2));
    final axis = (f['axis'] as List).cast<double>();
    // Tumbado a lo largo de la pared (el eje x).
    expect(axis[0].abs(), closeTo(1, 1e-6));
    expect(axis[2], 0);
    expect((f['pos'] as List)[2], closeTo(2.2, 1e-6));
  });

  test('CA.3: de pie si se pide, y lejos de toda pared no se pega', () {
    final t = tube(
      props: {LightWallMount.tubeAxisKey: LightWallMount.axisVertical},
    );
    final f = (scene([t])['fixtures'] as List).single as Map;
    expect(f['axis'], [0.0, 0.0, 1.0]);
    final far = tube()..position = const Offset(200, 900);
    expect(
      LightWallMount.snap(far, [wall(Offset.zero, const Offset(400, 0))], mpu),
      isFalse,
    );
  });

  test('CA.3: cada aparato con su forma', () {
    PlanElement light(LightType t) => PlanElement(
      id: 5,
      type: ElementType.light,
      position: Offset.zero,
      lightType: t,
    );
    expect(PlanScene3d.shapeOf(light(LightType.lightPanel)), 'panel');
    expect(PlanScene3d.shapeOf(light(LightType.softbox)), 'softbox');
    expect(PlanScene3d.shapeOf(light(LightType.practical)), 'practical');
    expect(PlanScene3d.shapeOf(light(LightType.fresnelLarge)), 'can');
  });

  test('CA.4: el alto de la pared vale para el 3D y para la luz', () {
    final w = wall(
      Offset.zero,
      const Offset(400, 0),
      props: {PlanSegment.heightKey: 6.0},
    );
    expect((firstWall(scene([w]))['tops'] as List).first, 6.0);
    final light = LightScene.from([w], metersPerUnit: mpu);
    final walls = light.blockers.where((b) => b.isWall).toList();
    expect(walls, isNotEmpty);
    for (final b in walls) {
      expect(b.heightM, 6.0);
    }
    // Sin alto puesto, la de siempre.
    final plain = LightScene.from([
      wall(Offset.zero, const Offset(400, 0)),
    ], metersPerUnit: mpu);
    expect(plain.blockers.firstWhere((b) => b.isWall).heightM, 2.5);
  });

  test(
    'CA.5: la farola de brazo, en la fachada, cálida y mirando al suelo',
    () {
      final w = wall(
        Offset.zero,
        const Offset(800, 0),
        props: {PlanSegment.heightKey: 16.0},
      );
      final lamp = PlanElement(
        id: 6,
        type: ElementType.light,
        position: const Offset(300, 50),
        props: {'uid': 'F'},
      );
      StreetLamp.apply(lamp);
      expect(LightWallMount.snap(lamp, [w, lamp], mpu), isTrue);
      expect(lamp.lightType, LightType.practical);
      expect(PlanLight.heightOf(lamp), 4.5);
      expect(PlanLight.elevationOf(lamp), -90);

      final f = (scene([w, lamp])['fixtures'] as List).single as Map;
      expect(f['shape'], 'lamp');
      expect(f['lampStyle'], 'arm');
      expect(f['cct'], StreetLamp.defaultKelvin);
      expect((f['pos'] as List)[2], closeTo(4.5, 1e-6));
      // Apunta a plomo hacia abajo.
      expect((f['aim'] as List)[2], lessThan(0.1));
      // El brazo va hacia la pared (que está en y = 0, detrás).
      final back = (f['back'] as List).cast<double>();
      expect(back[1], closeTo(1, 1e-6));

      // Y alumbra lo que tiene debajo como una luz de verdad.
      final light = PlanLight.of(lamp)!;
      expect(light.watts, StreetLamp.defaultWatts);
    },
  );

  test('CA.5: de báculo no se pega a nada', () {
    final lamp = PlanElement(
      id: 7,
      type: ElementType.light,
      position: Offset.zero,
    );
    StreetLamp.apply(lamp, style: StreetLamp.stylePole);
    expect(LightWallMount.isOn(lamp), isFalse);
    final f = (scene([lamp])['fixtures'] as List).single as Map;
    expect(f['lampStyle'], 'pole');
  });

  /// Una calle de 30 m hacia +x con la plantilla del Raval.
  PlanElement raval() {
    final st = PlanSegment.create(
      start: Offset.zero,
      end: const Offset(3000, 0),
      kind: PlanSegment.kindStreet,
    )..props['uid'] = 'S';
    kStreetPresets.first.$2.writeTo(st);
    return st;
  }

  test('CA.6: la calle del Raval, a un nivel, con fachadas de 16 m', () {
    final sc = scene([raval()]);
    final surfaces = (sc['surfaces'] as List).cast<Map>();
    expect(surfaces, hasLength(3));
    // Plataforma única: todo a la misma cota.
    for (final s in surfaces) {
      expect(s['top'], 0);
    }
    final road = surfaces.firstWhere((s) => s['kind'] == 'road');
    final ys = [for (final p in (road['outline'] as List).cast<List>()) p[1]];
    // 3 m de calzada, centrada en el eje.
    expect(ys.reduce((a, b) => a > b ? a : b), closeTo(1.5, 1e-6));
    final walls = (sc['walls'] as List).cast<Map>();
    expect(walls, hasLength(2));
    for (final w in walls) {
      expect((w['tops'] as List).first, 16);
      expect(w['thick'], StreetProfile.facadeThicknessM);
      // La cara de la fachada a 3,5 m del eje: 7 m entre fachadas.
      final y = ((w['points'] as List).first as List)[1] as double;
      expect(y.abs(), closeTo(3.5 + StreetProfile.facadeThicknessM / 2, 1e-6));
    }
  });

  test('CA.6: con bordillo, las aceras suben', () {
    final st = raval();
    kStreetPresets[1].$2.writeTo(st);
    final surfaces = (scene([st])['surfaces'] as List).cast<Map>();
    expect(
      surfaces.where((s) => s['kind'] == 'walk').map((s) => s['top']),
      everyElement(0.15),
    );
  });

  test('CA.6: las fachadas tapan la luz a su altura', () {
    final light = LightScene.from([raval()], metersPerUnit: mpu);
    final facades = light.blockers.where((b) => b.isWall).toList();
    expect(facades, hasLength(2));
    expect(facades.map((b) => b.heightM), everyElement(16));
  });

  test('CA.6: «Poner farolas» las pone en las fachadas, al tresbolillo', () {
    final st = raval();
    final lamps = StreetProfile.of(st).lamps(st, mpu);
    // 30 m cada 15: 2 a la izquierda (7,5 y 22,5) y 1 a la derecha (15).
    expect(lamps, hasLength(3));
    for (final l in lamps) {
      expect(StreetLamp.isOn(l), isTrue);
      expect(LightWallMount.isOn(l), isTrue);
      expect(PlanLight.heightOf(l), 4.5);
      // Junto a la cara de la fachada (3,5 m), por dentro.
      expect(l.position.dy.abs(), closeTo(345, 1e-6));
    }
    final left = lamps.where((l) => l.position.dy < 0).toList();
    expect(left.map((l) => l.position.dx), [750, 2250]);
    // Las de la izquierda (−y) miran hacia +y: 180°.
    expect(left.first.rotation, closeTo(180, 1e-6));
  });

  test('CA.6: separar las fachadas en paredes', () {
    final st = raval();
    final walls = StreetControls.facadeWalls(st, mpu);
    expect(walls, hasLength(2));
    expect(PlanSegment.heightM(walls.first), 16);
    expect(PlanSegment.thicknessM(walls.first), StreetProfile.facadeThicknessM);
  });
}
