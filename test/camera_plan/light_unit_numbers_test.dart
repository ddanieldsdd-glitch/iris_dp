import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/plan_gear_list.dart';

void main() {
  var id = 0;
  PlanElement light([int? unit]) => PlanElement(
    id: ++id,
    type: ElementType.light,
    position: Offset.zero,
    lightType: LightType.fresnelMedium,
    props: {'intensity': 100, kLightUnitKey: ?unit},
  );

  test('una planta sin números se numera en orden, como antes', () {
    final plan = [light(), light(), light()];
    expect(lightUnitNumbers(plan).values, [1, 2, 3]);
  });

  test('al borrar un foco, los demás conservan su número', () {
    final plan = [light(), light(), light()];
    freezeLightUnits(plan);
    plan.removeAt(1);
    expect(lightUnitNumbers(plan).values, [1, 3]);
  });

  test('un foco nuevo toma el siguiente al más alto', () {
    final plan = [light(1), light(5)];
    expect(nextLightUnit(plan), 6);
    expect(nextLightUnit(const []), 1);
  });

  test('los que no tienen número llenan los huecos', () {
    final plan = [light(2), light(), light(4), light()];
    expect(lightUnitNumbers(plan).values, [2, 1, 4, 3]);
  });

  test('un número repetido (copiar y pegar) no se pisa', () {
    final a = light(3), b = light(3);
    final numbers = lightUnitNumbers([a, b]);
    expect(numbers[a], 3);
    expect(numbers[b], 1);
  });

  test('renumerar deja 1, 2, 3 sin huecos', () {
    final plan = [light(7), light(2), light(9)];
    final changed = renumberLightUnits(plan);
    expect(lightUnitNumbers(plan).values, [1, 2, 3]);
    expect(changed, hasLength(2));
  });

  test('la leyenda usa los números guardados', () {
    final legend = LightLegend.of([light(4), light(8)]);
    expect(legend.rows.single.unitsLabel, 'U4, U8');
  });
}
