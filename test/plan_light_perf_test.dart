import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/theme/app_colors.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/light/ambient.dart';
import 'package:iris_dp/features/camera_plan/light/exposure.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/plan_light_map.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';

/// Rendimiento de la planta de luz con muchas luces: una casa de 24
/// habitaciones (60 paredes, 6 huecos) con 40 aparatos y sol.
///
/// Los tiempos salen por consola; los umbrales son holgados (el test corre
/// en modo depuración y en máquinas distintas) y solo saltan si algo se
/// vuelve a ir de las manos.
void main() {
  const mpu = 0.02;
  const ambient = PlanAmbient(day: true, sunAzimuth: 200, sunElevation: 35);

  test('la planta sintética tiene lo que dice', () {
    final plan = syntheticPlan();
    expect(plan.where((e) => e.type == ElementType.light), hasLength(40));
    expect(plan.where(PlanSegment.isSegment), hasLength(60));
    expect(
      plan.where(
        (e) => e.type == ElementType.wall && !PlanSegment.isSegment(e),
      ),
      hasLength(6),
    );
  });

  test('LightScene.from con 40 luces y 60 paredes', () {
    final plan = syntheticPlan();
    LightScene build() =>
        LightScene.from(plan, metersPerUnit: mpu, ambient: ambient);
    build(); // Calienta el JIT.
    final ms = medianMs(5, build);
    final scene = build();
    report('LightScene.from', ms, '${scene.lights.length} fuentes');
    expect(ms, lessThan(400));
  });

  test('fundir los rebotes mate da la misma luz y el mismo fotómetro', () {
    final plan = syntheticPlan();
    final fused = LightScene.from(plan, metersPerUnit: mpu, ambient: ambient);
    final apart = LightScene.from(
      plan,
      metersPerUnit: mpu,
      ambient: ambient,
      fuseBounces: false,
    );
    note(
      'fuentes: ${apart.lights.length} sin fundir → ${fused.lights.length} fundidas',
    );
    expect(fused.lights.length, lessThan(apart.lights.length / 2));
    for (var x = 20.0; x < 1200; x += 97) {
      for (var y = 20.0; y < 800; y += 83) {
        final at = Offset(x, y);
        final a = apart.sampleAt(at);
        final f = fused.sampleAt(at);
        expect(f.lux, closeTo(a.lux, a.lux * 1e-9 + 1e-9), reason: '$at');
        if (a.lux > 0) expect(f.cct, closeTo(a.cct, 1e-6), reason: '$at');
        // El fotómetro enseña las mismas aportaciones, una a una.
        String parts(LightScene s) => ([
          for (final c in s.contributionsAt(at))
            if (c.lux > 0.02)
              '${c.light.label} ${c.lux.toStringAsFixed(6)} '
                  '${c.cct.toStringAsFixed(3)}',
        ]..sort()).join('\n');
        expect(parts(fused), parts(apart), reason: '$at');
        expect(fused.luxAt(at), closeTo(apart.luxAt(at), 1e-6 * a.lux + 1e-9));
      }
    }
  });

  test('grabar la capa de luz (exposición de la cámara)', () {
    final plan = syntheticPlan();
    final ms = medianMs(3, () => recordLayer(plan, LightView.camera).dispose());
    report('capa de luz, cámara', ms);
    expect(ms, lessThan(1500));
  });

  test('grabar la capa de luz («Ver todo»)', () {
    final plan = syntheticPlan();
    final ms = medianMs(3, () => recordLayer(plan, LightView.all).dispose());
    report('capa de luz, ver todo', ms);
    expect(ms, lessThan(2500));
  });

  testWidgets('rasterizar la planta (exposición de la cámara)', (tester) async {
    final plan = syntheticPlan();
    await tester.runAsync(() async {
      Future<double> once() async {
        final picture = recordLayer(plan, LightView.camera);
        final watch = Stopwatch()..start();
        final image = await picture.toImage(1400, 900);
        await image.toByteData();
        final ms = watch.elapsedMicroseconds / 1000;
        image.dispose();
        picture.dispose();
        return ms;
      }

      await once();
      final times = [for (var i = 0; i < 3; i++) await once()]..sort();
      report('rasterizar la planta', times[1]);
      expect(times[1], lessThan(3000));
    });
  });

  test('sin cambios no se repinta; al mover algo en su sitio, sí', () {
    final plan = syntheticPlan();
    final cache = PlanLightMapCache();
    addTearDown(cache.dispose);
    CameraPlanPainter painter() => CameraPlanPainter(
      elements: plan,
      palette: AppPalette.dark,
      metersPerUnit: mpu,
      ambient: ambient,
      exposure: const ExposureSettings(iso: 800),
      lightMap: cache,
    );
    final before = painter();
    expect(painter().shouldRepaint(before), isFalse);
    // El editor mueve los elementos sin cambiar de lista.
    plan.firstWhere((e) => e.type == ElementType.light).position +=
        const Offset(5, 0);
    expect(painter().shouldRepaint(before), isTrue);
  });

  test('la escena se construye una vez por estado de la planta', () {
    final plan = syntheticPlan();
    final cache = PlanLightMapCache();
    addTearDown(cache.dispose);
    LightScene scene() =>
        cache.scene(plan, metersPerUnit: mpu, ambient: ambient);
    final first = scene();
    expect(scene(), same(first));
    // Un nombre no cambia la luz pero sale en el fotómetro.
    plan.firstWhere((e) => e.type == ElementType.light).props['name'] = 'Key';
    expect(scene(), isNot(same(first)));
  });

  test('mover la vista no recalcula la luz', () {
    final plan = syntheticPlan();
    final cache = PlanLightMapCache();
    addTearDown(cache.dispose);
    recordLayer(plan, LightView.camera, cache: cache).dispose();
    var dx = 0.0;
    final ms = medianMs(5, () {
      dx += 13;
      recordLayer(
        plan,
        LightView.camera,
        cache: cache,
        offset: Offset(dx, 0),
      ).dispose();
    });
    report('repintado al mover la vista', ms);
    expect(ms, lessThan(150));
  });
}

void note(String text) {
  // ignore: avoid_print
  print('⏱ $text');
}

void report(String what, double ms, [String extra = '']) {
  // ignore: avoid_print
  print('⏱ $what: ${ms.toStringAsFixed(1)} ms $extra');
}

/// Mediana de [runs] ejecuciones, en milisegundos.
double medianMs(int runs, void Function() body) {
  final times = <double>[];
  for (var i = 0; i < runs; i++) {
    final watch = Stopwatch()..start();
    body();
    times.add(watch.elapsedMicroseconds / 1000);
  }
  times.sort();
  return times[times.length ~/ 2];
}

/// Pinta la planta entera, como en el editor, y devuelve lo grabado.
ui.Picture recordLayer(
  List<PlanElement> plan,
  LightView view, {
  PlanLightMapCache? cache,
  Offset offset = const Offset(40, 40),
}) {
  final own = cache == null;
  final map = cache ?? PlanLightMapCache();
  final painter = CameraPlanPainter(
    elements: plan,
    palette: AppPalette.dark,
    metersPerUnit: 0.02,
    ambient: const PlanAmbient(day: true, sunAzimuth: 200, sunElevation: 35),
    lightView: view,
    lightMap: map,
    scale: 0.6,
    offset: offset,
  );
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(1400, 900));
  final picture = recorder.endRecording();
  if (own) map.dispose();
  return picture;
}

/// Un plató de 24 × 16 m: el perímetro en 40 tramos de 2 m, 20 tabiques
/// sueltos de 3 m dentro, 4 ventanas, 2 puertas, 40 luces de todo tipo,
/// cuatro actores y una cámara. Casi todas las luces ven casi todas las
/// paredes: es el caso que más rebotes da.
List<PlanElement> syntheticPlan() {
  var id = 0;
  final random = math.Random(7);
  final plan = <PlanElement>[];
  const step = 100.0; // 2 m.
  const width = 1200.0; // 24 m.
  const depth = 800.0; // 16 m.
  PlanElement wall(Offset a, Offset b) =>
      PlanSegment.create(start: a, end: b)..id = --id;

  for (var x = 0.0; x < width; x += step) {
    plan.add(wall(Offset(x, 0), Offset(x + step, 0)));
    plan.add(wall(Offset(x, depth), Offset(x + step, depth)));
  }
  for (var y = 0.0; y < depth; y += step) {
    plan.add(wall(Offset(0, y), Offset(0, y + step)));
    plan.add(wall(Offset(width, y), Offset(width, y + step)));
  }
  // Tabiques: cinco columnas de cuatro, alternando el sentido.
  for (var c = 0; c < 5; c++) {
    for (var r = 0; r < 4; r++) {
      final at = Offset(200 + c * 200, 100 + r * 200);
      final half = (c + r).isEven ? const Offset(75, 0) : const Offset(0, 75);
      plan.add(wall(at - half, at + half));
    }
  }

  // Cuatro ventanas arriba y dos puertas a la izquierda.
  for (final x in const [150.0, 450.0, 750.0, 1050.0]) {
    plan.add(
      PlanElement(
        id: --id,
        type: ElementType.wall,
        position: Offset(x, 0),
        label: ArchitectureType.window.dbValue,
        props: {'width': 120.0},
      ),
    );
  }
  for (final y in const [250.0, 550.0]) {
    plan.add(
      PlanElement(
        id: --id,
        type: ElementType.wall,
        position: Offset(0, y),
        rotation: 90,
        label: ArchitectureType.doorOpen.dbValue,
        props: {'open': 90.0, 'width': 80.0},
      ),
    );
  }

  const types = [
    LightType.hmi,
    LightType.led1x1,
    LightType.fresnelMedium,
    LightType.lightPanel,
    LightType.softbox,
    LightType.practical,
    LightType.fresnelSmall,
    LightType.led,
  ];
  for (var i = 0; i < 40; i++) {
    final x = 40 + random.nextDouble() * (width - 80);
    final y = 40 + random.nextDouble() * (depth - 80);
    final overhead = i % 5 == 4;
    plan.add(
      PlanElement(
        id: --id,
        type: ElementType.light,
        position: Offset(x, y),
        rotation: random.nextDouble() * 360,
        lightType: types[i % types.length],
        props: {
          'intensity': 60 + random.nextInt(41),
          if (overhead) PlanLight.mountKey: PlanLight.mountCeiling,
        },
      ),
    );
  }
  for (var i = 0; i < 4; i++) {
    plan.add(
      PlanElement(
        id: --id,
        type: ElementType.actor,
        position: Offset(100 + i * 300, 300),
        label: 'Actor ${i + 1}',
      ),
    );
  }
  plan.add(
    PlanElement(
      id: --id,
      type: ElementType.camera,
      position: const Offset(700, 700),
    ),
  );
  return plan;
}
