import 'package:flutter/material.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/plan_gear_list.dart';

void main() {
  var id = 0;
  PlanElement light(
    String name,
    LightType type,
    double watts, {
    bool off = false,
  }) => PlanElement(
    id: ++id,
    type: ElementType.light,
    position: Offset.zero,
    lightType: type,
    props: {
      'name': name,
      'watts': watts,
      'intensity': 100,
      if (off) 'off': true,
    },
  );

  test('la leyenda agrupa por modelo, numera unidades y suma lo encendido', () {
    final plan = [
      light('ARRI M18', LightType.hmi, 1800),
      light('Mole 5K', LightType.fresnelLarge, 5000),
      PlanElement(
        id: ++id,
        type: ElementType.light,
        position: Offset.zero,
        lightType: LightType.flag,
      ),
      light('ARRI M18', LightType.hmi, 1800, off: true),
    ];
    final legend = LightLegend.of(plan);
    expect(legend.rows.map((r) => r.name), ['ARRI M18', 'Mole 5K']);
    final m18 = legend.rows.first;
    expect(m18.count, 2);
    // La bandera no es una unidad.
    expect(m18.unitsLabel, 'U1, U3');
    expect(legend.watts, 6800);
    expect(legend.totalLabel, 'Total 6,8 kW · 29,6 A a 230 V');
  });

  test('lúmenes: un 5K de tungsteno da unos 85 000; un LED de 600 W, más', () {
    final tungsten = PlanLight.of(light('5K', LightType.fresnelLarge, 5000))!;
    final led = PlanLight.of(light('LED', LightType.led, 600))!;
    expect(tungsten.lumens, closeTo(84500, 500));
    expect(led.lumens, closeTo(37050, 100));
    expect(formatLumens(tungsten.lumens), '85k lm');
    expect(formatWatts(1800), '1,8 kW');
    expect(formatWatts(20000), '20 kW');
    expect(formatWatts(650), '650 W');
  });

  test('unidades seguidas se rotulan como rango', () {
    const row = LightLegendRow(
      name: 'Tubo',
      count: 4,
      watts: 40,
      lumens: 2000,
      units: [3, 4, 5, 6],
    );
    expect(row.unitsLabel, 'U3–U6');
  });
}
