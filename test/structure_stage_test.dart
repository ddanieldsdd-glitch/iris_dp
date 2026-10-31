import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';
import 'package:iris_dp/features/unreal_link/unreal_stage_payload.dart';

/// El set a escala en Unreal (F6.21.3).
void main() {
  const mpu = 0.01;

  PlanElement wall(Offset a, Offset b) =>
      PlanSegment.create(start: a, end: b)..props['uid'] = 'W${a.dx}';
  PlanElement fresnel(Offset at) => PlanElement(
    id: 1,
    type: ElementType.light,
    position: at,
    lightType: LightType.fresnelMedium,
    props: {'uid': 'L', 'intensity': 100},
  );
  PlanElement table({Map<String, dynamic>? props}) => PlanElement(
    id: 2,
    type: ElementType.prop,
    position: const Offset(100, 100),
    label: PropType.table.dbValue,
    props: {'uid': 'T', ...?props},
  );

  Map<String, dynamic> scene(List<PlanElement> els) =>
      PlanScene3d.build(els, metersPerUnit: mpu);

  tearDown(() => UnrealStagePayload.structure = null);

  test('la huella de la estructura cambia con las paredes, no con los focos',
      () {
    final walls = [
      wall(Offset.zero, const Offset(400, 0)),
      wall(const Offset(400, 0), const Offset(400, 300)),
    ];
    expect(PlanScene3d.structureKey(scene([fresnel(Offset.zero)])), isNull);
    final key = PlanScene3d.structureKey(scene([...walls, fresnel(Offset.zero)]));
    expect(key, hasLength(16));
    // Mover el foco: la misma estructura.
    expect(
      PlanScene3d.structureKey(
        scene([...walls, fresnel(const Offset(200, 150))]),
      ),
      key,
    );
    // Mover una pared: otra.
    walls.last.props['dx'] = 0;
    walls.last.props['dy'] = 350;
    expect(
      PlanScene3d.structureKey(scene([...walls, fresnel(Offset.zero)])),
      isNot(key),
    );
  });

  test('la estructura va a Unreal y se manda solo cuando cambia', () {
    final s = scene([wall(Offset.zero, const Offset(400, 0))]);
    UnrealStagePayload.structure = {'file': 'abc.glb', 'folder': 'C:/IRIS'};
    final first = UnrealStagePayload.build(s);
    expect(first['structure']['file'], 'abc.glb');
    expect(UnrealStagePayload.diff(first, UnrealStagePayload.build(s)), isNull);
    UnrealStagePayload.structure = {'file': 'def.glb', 'folder': 'C:/IRIS'};
    final diff = UnrealStagePayload.diff(first, UnrealStagePayload.build(s))!;
    expect(diff['structure']['file'], 'def.glb');
  });

  test('una mesa llega con su ancho, su fondo y su alto', () {
    final t = table(props: {'widthM': 1.6, 'depthM': 0.9, 'height': 0.75});
    final prop = (UnrealStagePayload.build(scene([t]))['props'] as List)
        .single as Map;
    // Fondo hacia donde mira (+X del bloque), ancho de lado, alto.
    expect(prop['sizeCm'], [90, 160, 75]);
  });

  test('un mueble sin medidas nuevas: el de siempre si tenía tamaño, y uno '
      'típico si no', () {
    final old = table(props: {'size': 0.8});
    final s = LightScene.furnitureSizeM(old);
    expect((s.width, s.depth), (0.8, 0.8));
    final fresh = LightScene.furnitureSizeM(table());
    expect((fresh.width, fresh.depth), (1.6, 0.9));
    final sofa = PlanElement(
      id: 3,
      type: ElementType.prop,
      position: Offset.zero,
      label: PropType.sofa.dbValue,
      props: {'size': 2.0},
    );
    // El sofá antiguo de 2 m tenía 0,9 de fondo en el 3D: igual.
    expect(LightScene.furnitureSizeM(sofa).depth, closeTo(0.9, 1e-9));
  });
}
