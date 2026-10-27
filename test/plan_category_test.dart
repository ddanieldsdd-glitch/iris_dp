import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_category.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';

PlanElement _el(ElementType type, {LightType? light, String? label}) =>
    PlanElement(
      id: 0,
      type: type,
      position: Offset.zero,
      lightType: light,
      label: label,
    );

void main() {
  test('cada elemento cae en su categoría', () {
    expect(PlanCategory.of(_el(ElementType.camera)), PlanCategory.camera);
    expect(PlanCategory.of(_el(ElementType.actor)), PlanCategory.people);
    expect(PlanCategory.of(_el(ElementType.wall)), PlanCategory.architecture);
    expect(
      PlanCategory.of(_el(ElementType.light, light: LightType.hmi)),
      PlanCategory.light,
    );
    expect(
      PlanCategory.of(_el(ElementType.light, light: LightType.flag)),
      PlanCategory.grip,
    );
    expect(
      PlanCategory.of(_el(ElementType.prop, label: PropType.sofa.dbValue)),
      PlanCategory.furniture,
    );
    expect(
      PlanCategory.of(_el(ElementType.prop, label: PropType.hill.dbValue)),
      PlanCategory.other,
    );
  });

  test('los colores de las categorías se distinguen', () {
    final colors = {for (final c in PlanCategory.values) c.color};
    expect(colors, hasLength(PlanCategory.values.length));
    expect(PlanCategory.palette['furniture'], startsWith('#'));
  });

  test('la escena 3D lleva la paleta y la categoría de cada pieza', () {
    final els = [
      _el(ElementType.light, light: LightType.hmi),
      _el(ElementType.camera),
      _el(ElementType.actor, label: 'ADIL'),
      _el(ElementType.prop, label: PropType.table.dbValue),
    ];
    LightOverrides.ensureUids(els);
    final scene = PlanScene3d.build(els, metersPerUnit: 0.01);
    expect(scene['palette'], PlanCategory.palette);
    expect(scene['fixtures'][0]['cat'], 'light');
    expect(scene['cameras'][0]['cat'], 'camera');
    expect(scene['people'][0]['cat'], 'people');
    expect(scene['props'][0]['cat'], 'furniture');
    expect(scene['props'][0]['type'], 'table');
  });
}
