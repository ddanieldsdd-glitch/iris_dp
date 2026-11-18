import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light_beam.dart';
import 'package:iris_dp/features/camera_plan/plan_marks.dart';

PlanElement _light() => PlanElement(
  id: 1,
  type: ElementType.light,
  position: const Offset(0, 0),
  lightType: LightType.fresnelMedium,
  props: {'uid': 'L1', LightBeam.intensityKey: 50},
);

/// PL.3: un foco con posiciones 1, 2, 3 y cambios en cada una.
void main() {
  test('los cambios siguen hasta que otro los cambia', () {
    final el = _light();
    PlanMarks.add(el, const Offset(30, 0));
    PlanMarks.add(el, const Offset(60, 0));
    PlanMarks.add(el, const Offset(90, 0));
    PlanMarks.setLightAt(el, 0, LightBeam.intensityKey, 100);
    PlanMarks.setLightAt(el, 2, LightBeam.offKey, true);

    double intensity(int p) =>
        LightBeam.of(PlanMarks.atPosition(el, p))!.intensity;
    expect(intensity(0), 50);
    expect(intensity(1), 100);
    expect(intensity(2), 100);
    expect(LightBeam.of(PlanMarks.atPosition(el, 3))!.off, isTrue);
    expect(PlanMarks.atPosition(el, 2).position, const Offset(60, 0));
    // Pasada la última, se queda en ella.
    expect(PlanMarks.atPosition(el, 9).position, const Offset(90, 0));
    // El original no cambia.
    expect(LightBeam.of(el)!.intensity, 50);
  });

  test('en el PDF, el cambio de cada tramo', () {
    final el = _light();
    PlanMarks.add(el, const Offset(0, 30));
    PlanMarks.add(el, const Offset(0, 60));
    PlanMarks.setLightAt(el, 0, LightBeam.intensityKey, 100);
    PlanMarks.setLightAt(el, 1, LightBeam.offKey, true);
    expect(PlanMarks.lightChangeLabels(el, 0), ['50 % → 100 %']);
    expect(PlanMarks.lightChangeLabels(el, 1), ['se apaga']);
  });

  test('quitar una marca quita su cambio', () {
    final el = _light();
    PlanMarks.add(el, const Offset(0, 30));
    PlanMarks.add(el, const Offset(0, 60));
    PlanMarks.setLightAt(el, 0, LightBeam.intensityKey, 80);
    PlanMarks.setLightAt(el, 1, LightBeam.intensityKey, 20);
    PlanMarks.removeAt(el, 0);
    expect(PlanMarks.lightChangeAt(el, 0), {LightBeam.intensityKey: 20});
    PlanMarks.clear(el);
    expect(el.props.containsKey(PlanMarks.lightKey), isFalse);
  });

  test('un foco puede tener posiciones; un decorado, no', () {
    expect(PlanMarks.canMark(_light()), isTrue);
    expect(PlanMarks.supports(_light()), isFalse);
    expect(
      PlanMarks.canMark(
        PlanElement(id: 2, type: ElementType.prop, position: Offset.zero),
      ),
      isFalse,
    );
  });
}
