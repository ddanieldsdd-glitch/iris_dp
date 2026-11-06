import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/light_color.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/light_beam.dart';
import 'package:iris_dp/features/camera_plan/plan_equipment.dart';
import 'package:iris_dp/features/camera_plan/plan_light_color_control.dart';
import 'package:iris_dp/features/camera_plan/plan_light_map.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';

const _red = 0xFF0000;
const _blue = 0x0000FF;

PlanElement _panel(Offset at, {int? rgb, double rotation = 0}) => PlanElement(
  id: at.dx.toInt(),
  type: ElementType.light,
  position: at,
  rotation: rotation,
  lightType: LightType.lightPanel,
  props: {LightBeam.spreadKey: 120.0, LightBeam.rgbKey: ?rgb},
);

LightScene _scene(List<PlanElement> elements) =>
    LightScene.from(elements, metersPerUnit: 0.02);

int _r(int rgb) => (rgb >> 16) & 255;
int _g(int rgb) => (rgb >> 8) & 255;
int _b(int rgb) => rgb & 255;

Light _catalog(String model, String type, int min, int max) => Light(
  id: 1,
  brand: 'Marca',
  model: model,
  lightType: type,
  powerW: 100,
  colorTempMin: min,
  colorTempMax: max,
  isLukaCompatible: false,
  isCustom: false,
  vintage: false,
  dataStatus: 'PENDIENTE',
);

void main() {
  test('una luz sin color no cambia nada: el mapa sigue a temperatura', () {
    final scene = _scene([_panel(const Offset(100, 100))]);
    expect(scene.hasColor, isFalse);
    expect(scene.sampleAt(const Offset(200, 100)).rgb, isNull);
    final map = PlanLightMap.compute(
      scene,
      const Rect.fromLTWH(0, 0, 400, 200),
      budget: 2000,
    );
    expect(map.tint, isNull);
    expect(map.rgbAt(0), isNull);
  });

  test('un panel en rojo pinta de rojo lo que alumbra', () {
    final scene = _scene([_panel(const Offset(100, 100), rgb: _red)]);
    expect(scene.sampleAt(const Offset(200, 100)).rgb, _red);
    final map = PlanLightMap.compute(
      scene,
      const Rect.fromLTWH(0, 0, 400, 200),
      budget: 2000,
    );
    final lit = [
      for (var i = 0; i < map.lux.length; i++)
        if (map.lux[i] > 0) map.rgbAt(i),
    ];
    expect(lit, isNotEmpty);
    expect(lit.every((c) => c == _red), isTrue);
  });

  test('rojo y azul se suman en magenta', () {
    final mix = LightMix()
      ..add(1, 5600, _red)
      ..add(1, 5600, _blue);
    expect(mix.rgb, 0xFF00FF);
  });

  test('un rojo sobre mucha luz blanca se queda en rosa pálido', () {
    final mix = LightMix()
      ..add(1, 5600, _red)
      ..add(3, 5600, null);
    final rgb = mix.rgb!;
    expect(_r(rgb), 255);
    expect(_g(rgb), greaterThan(150));
    expect(_b(rgb), greaterThan(150));
  });

  test('mezclar una sola temperatura da el color de esa temperatura', () {
    final mix = LightMix()..add(5, 3200, null);
    final want = LightBeam.colorForCct(3200).toARGB32() & 0xFFFFFF;
    expect((_r(mix.rgb!) - _r(want)).abs(), lessThanOrEqualTo(1));
    expect((_g(mix.rgb!) - _g(want)).abs(), lessThanOrEqualTo(1));
    expect((_b(mix.rgb!) - _b(want)).abs(), lessThanOrEqualTo(1));
  });

  test('un color saturado da menos luz que el blanco del mismo aparato', () {
    final white = PlanLight.of(_panel(const Offset(0, 0)))!;
    final blue = PlanLight.of(_panel(const Offset(0, 0), rgb: _blue))!;
    final pure = PlanLight.of(_panel(const Offset(0, 0), rgb: 0xFFFFFF))!;
    expect(
      blue.source.candela / white.source.candela,
      closeTo(LightMix.minOutput, 1e-9),
    );
    expect(pure.source.candela, closeTo(white.source.candela, 1e-6));
    // El color no cuenta como filtros perdidos.
    expect(blue.stopsLost, closeTo(white.stopsLost, 1e-9));
    expect(blue.colorLabel, 'RGB');
    expect(white.colorLabel, endsWith('K'));
  });

  test('el rebote de una pared conserva el color', () {
    final elements = [
      PlanSegment.create(
        start: const Offset(300, 0),
        end: const Offset(300, 400),
      ),
      _panel(const Offset(100, 200), rgb: _red),
    ];
    final scene = LightScene.from(
      elements,
      metersPerUnit: 0.02,
      wallBounce: true,
    );
    final bounced = scene.lights.where((l) => l.isSecondary);
    expect(bounced, isNotEmpty);
    expect(bounced.every((l) => l.source.rgb == _red), isTrue);
  });

  test('qué aparatos del catálogo dan color', () {
    bool rgb(String model, String type, int min, int max) =>
        PlanEquipment.isRgb(_catalog(model, type, min, max));
    expect(rgb('SkyPanel S60-C', 'led_panel', 2800, 10000), isTrue);
    expect(rgb('Diva/C', 'led_panel', 2700, 6500), isTrue);
    expect(rgb('LED Strip RGB', 'led_practical', 2000, 10000), isTrue);
    expect(rgb('INFINIBAR PB6', 'led_tube', 2500, 7500), isTrue);
    expect(rgb('STORM 1200x', 'led_cob', 2500, 10000), isFalse);
    expect(rgb('F22x', 'led_flex', 2500, 7500), isFalse);
    expect(rgb('T5', 'tungsten_fresnel', 3200, 3200), isFalse);
  });

  test('solo se ofrece color a lo que puede darlo', () {
    final bicolor = _panel(Offset.zero)..props[PlanLight.rgbCapableKey] = false;
    final rgb = _panel(Offset.zero)..props[PlanLight.rgbCapableKey] = true;
    final tungsten = PlanElement(
      id: 3,
      type: ElementType.light,
      position: Offset.zero,
      lightType: LightType.fresnelSmall,
      props: {},
    );
    final sun = PlanElement(
      id: 4,
      type: ElementType.light,
      position: Offset.zero,
      lightType: LightType.sun,
      props: {},
    );
    expect(PlanLight.canColor(bicolor), isFalse);
    expect(PlanLight.canColor(rgb), isTrue);
    expect(PlanLight.canColor(_panel(Offset.zero)), isTrue);
    expect(PlanLight.canColor(tungsten), isFalse);
    expect(PlanLight.canColor(sun), isFalse);
  });

  testWidgets('el panel enciende el color, cambia de muestra y lo apaga', (
    tester,
  ) async {
    final el = _panel(Offset.zero);
    var updates = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PlanLightColorControl(
              element: el,
              onPreview: () => setState(() {}),
              onUpdate: () => setState(() => updates++),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Tono'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(el.props[LightBeam.rgbKey], PlanLightColorControl.presets.first.$2);
    expect(find.text('Tono'), findsOneWidget);

    await tester.tap(find.byTooltip('Azul'));
    await tester.pump();
    expect(el.props[LightBeam.rgbKey], 0x1E3CFF);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(el.props.containsKey(LightBeam.rgbKey), isFalse);
    expect(updates, 3);
  });
}
