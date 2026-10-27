import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_gear_list.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';

PlanElement _light({Map<String, dynamic>? props}) => PlanElement(
  id: 1,
  type: ElementType.light,
  position: const Offset(100, 100),
  lightType: LightType.fresnelMedium,
  props: props ?? {},
);

PlanElement _sofa() => PlanElement(
  id: 2,
  type: ElementType.prop,
  position: Offset.zero,
  label: PropType.sofa.dbValue,
);

void main() {
  group('F6.20 A1 · uid estable para todos', () {
    test('todos los tipos lo reciben, y una sola vez', () {
      final els = [
        _light(),
        _sofa(),
        PlanElement(id: 3, type: ElementType.camera, position: Offset.zero),
        PlanElement(id: 4, type: ElementType.actor, position: Offset.zero),
        PlanElement(id: 5, type: ElementType.wall, position: Offset.zero),
      ];
      final fresh = LightOverrides.ensureUids(els);
      expect(fresh, hasLength(5));
      final uids = [for (final el in els) LightOverrides.uidOf(el)];
      expect(uids.toSet(), hasLength(5));
      expect(LightOverrides.ensureUids(els), isEmpty);
      expect([for (final el in els) LightOverrides.uidOf(el)], uids);
    });

    test('sobrevive a guardar y cargar', () {
      final els = [_light(), _sofa()];
      LightOverrides.ensureUids(els);
      final back = FloorPlanJson.decode(FloorPlanJson.encode(els));
      expect(
        [for (final el in back) LightOverrides.uidOf(el)],
        [for (final el in els) LightOverrides.uidOf(el)],
      );
    });

    test('el 3D lo usa, aunque cambie el orden', () {
      final els = [_light(), _sofa()];
      LightOverrides.ensureUids(els);
      final a = PlanScene3d.build(els, metersPerUnit: 0.01);
      final b = PlanScene3d.build(els.reversed.toList(), metersPerUnit: 0.01);
      expect(a['fixtures'][0]['id'], LightOverrides.uidOf(els[0]));
      expect(b['fixtures'][0]['id'], a['fixtures'][0]['id']);
      expect(b['props'][0]['id'], a['props'][0]['id']);
    });

    test('las copias estrenan uid y rehacen sus referencias internas', () {
      final truss = PlanElement(
        id: 1,
        type: ElementType.prop,
        position: Offset.zero,
        props: {'uid': 'T1', 'kind': 'truss'},
      );
      final hung = _light(
        props: {
          'uid': 'L1',
          'rig': {'truss': 'T1', 'along': 1.0},
        },
      );
      final elsewhere = _light(props: {'uid': 'L2', 'truss': 'OTRO'});
      final copies = FloorPlanJson.decode(
        FloorPlanJson.encode([truss, hung, elsewhere]),
      );
      LightOverrides.renewUids(copies);
      final newTruss = LightOverrides.uidOf(copies[0])!;
      expect(newTruss, isNot('T1'));
      expect(LightOverrides.uidOf(copies[1]), isNot('L1'));
      expect((copies[1].props['rig'] as Map)['truss'], newTruss);
      expect((copies[1].props['rig'] as Map)['along'], 1.0);
      // Lo que apunta fuera del grupo se queda como estaba.
      expect(copies[2].props['truss'], 'OTRO');
      // El original no se toca.
      expect((hung.props['rig'] as Map)['truss'], 'T1');
    });
  });

  group('F6.20 A2 · nombre libre', () {
    test('se ve en vez del tipo, y vacío vuelve al tipo', () {
      final sofa = _sofa();
      expect(sofa.displayLabel, PropType.sofa.label);
      sofa.customName = '  Sofá de la abuela ';
      expect(sofa.displayLabel, 'Sofá de la abuela');
      expect(sofa.typeLabel, PropType.sofa.label);
      expect(sofa.propType, PropType.sofa);
      sofa.customName = '';
      expect(sofa.props.containsKey(PlanElement.nameKey), isFalse);
      expect(sofa.displayLabel, PropType.sofa.label);
    });

    test('las cámaras guardan su letra y número aparte', () {
      final cam = PlanElement(
        id: 3,
        type: ElementType.camera,
        position: Offset.zero,
      )..customName = 'Grúa';
      expect(cam.displayLabel, 'Grúa');
      expect(cam.typeLabel, cam.cameraLabel);
    });

    test('los actores siguen con su label', () {
      final actor = PlanElement(
        id: 4,
        type: ElementType.actor,
        position: Offset.zero,
        label: 'ADIL',
      );
      expect(actor.displayLabel, 'ADIL');
    });

    test('renombrar una luz no cambia su modelo, la leyenda ni la lista', () {
      PlanElement sky() => _light(props: {'name': 'ARRI SkyPanel S60'});
      final lights = [sky(), sky(), sky(), sky()];
      LightOverrides.ensureUids(lights);
      final before = LightLegend.of(lights);
      final gearBefore = GearList.from(lights).lights.map((l) => '$l');

      lights.first.customName = 'Principal';

      expect(lights.first.model, 'ARRI SkyPanel S60');
      expect(lights.first.props['name'], 'ARRI SkyPanel S60');
      expect(lights.first.displayLabel, 'Principal');
      expect(lights.first.fullLabel, 'Principal · ARRI SkyPanel S60');
      expect(lights[1].displayLabel, 'ARRI SkyPanel S60');
      final after = LightLegend.of(lights);
      expect(
        [for (final r in after.rows) '${r.name} ×${r.count}'],
        [for (final r in before.rows) '${r.name} ×${r.count}'],
      );
      expect(after.rows.single.name, 'ARRI SkyPanel S60');
      expect(after.rows.single.count, 4);
      expect(GearList.from(lights).lights.map((l) => '$l'), gearBefore);
      expect(
        PlanScene3d.build(lights, metersPerUnit: 0.01)['fixtures'][0]['name'],
        'Principal · ARRI SkyPanel S60',
      );
    });

    test('el 3D y Unreal reciben el nombre', () {
      final light = _light()..customName = 'Contra';
      final sofa = _sofa()..customName = 'Sofá rojo';
      final cam = PlanElement(
        id: 3,
        type: ElementType.camera,
        position: Offset.zero,
      )..customName = 'Grúa';
      final scene = PlanScene3d.build([
        light,
        sofa,
        cam,
      ], metersPerUnit: 0.01);
      expect(scene['fixtures'][0]['name'], 'Contra');
      expect(scene['props'][0]['name'], 'Sofá rojo');
      expect(scene['cameras'][0]['name'], 'Grúa');
    });
  });
}
