import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/ambient.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/light/meter.dart';
import 'package:iris_dp/features/camera_plan/light/plan_grip.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';

/// La exposición del actor refleja el grip (F6.22.3): lo que lee el
/// fotómetro en la cara de un actor baja con un negro, con una tela y con
/// un palio, y sube con un rebote.
void main() {
  const mpu = 0.01;
  // El actor, 3 m por delante del foco; el grip, a mitad de camino.
  const face = Offset(0, -300);

  PlanElement fresnel() => PlanElement(
    id: 1,
    type: ElementType.light,
    position: Offset.zero,
    lightType: LightType.fresnelMedium,
    props: {'uid': 'L', 'intensity': 100},
  );
  PlanElement actor() => PlanElement(
    id: 2,
    type: ElementType.actor,
    position: face,
    props: {'uid': 'A'},
  );
  PlanElement camera() => PlanElement(
    id: 3,
    type: ElementType.camera,
    position: const Offset(0, -600),
    rotation: 0,
    lens: '35mm',
    props: {'uid': 'C'},
  );
  PlanElement grip(LightType type, {Map<String, dynamic>? props, Offset? at}) =>
      PlanElement(
        id: 4,
        type: type == LightType.bounce ? ElementType.light : ElementType.light,
        position: at ?? const Offset(0, -150),
        lightType: type,
        props: {'uid': 'G', ...?props},
      );

  MeterReading read(List<PlanElement> extra, {PlanAmbient? ambient}) {
    final els = [fresnel(), actor(), camera(), ...extra];
    final scene = LightScene.from(els, metersPerUnit: mpu, ambient: ambient);
    return MeterReading.at(scene, face, camera: els[2]);
  }

  test('un negro entre el foco y el actor le quita la luz', () {
    final open = read(const []);
    final cut = read([grip(LightType.flag)]);
    expect(open.lux, greaterThan(100));
    expect(cut.lux, lessThan(open.lux * 0.15));
    expect(cut.stopsOverTarget, lessThan(open.stopsOverTarget));
  });

  test('una tela le da menos luz, y más difusión, menos', () {
    final open = read(const []);
    double withCloth(String id) => read([
      grip(
        LightType.diffusionFrame,
        props: {
          PlanLight.modifiersKey: [id],
          PlanGrip.heightKey: 2.0,
          LightScene.lenKey: 200.0,
        },
      ),
    ]).lux;
    final quarter = withCloth('grid-quarter');
    final full = withCloth('grid-full');
    expect(quarter, lessThan(open.lux));
    expect(full, lessThan(quarter));
    // Y lo que le llega es la tela, no el foco directo.
    final reading = read([
      grip(
        LightType.diffusionFrame,
        props: {
          PlanLight.modifiersKey: ['grid-full'],
          PlanGrip.heightKey: 2.0,
          LightScene.lenKey: 200.0,
        },
      ),
    ]);
    expect(
      reading.parts.any((p) => p.light.surface?.element?.lightType ==
          LightType.diffusionFrame),
      isTrue,
    );
  });

  test('un rebote al otro lado le suma luz', () {
    final open = read(const []);
    // Detrás del actor y a un lado, de cara al foco: le devuelve luz.
    final bounced = read([
      grip(
        LightType.bounce,
        at: const Offset(150, -420),
        props: {PlanGrip.heightKey: 2.0, LightScene.lenKey: 200.0},
      ),
    ]);
    expect(bounced.lux, greaterThan(open.lux));
  });

  test('un palio horizontal sobre el actor le baja el sol', () {
    const sunny = PlanAmbient(day: true, sunElevation: 80);
    final palio = grip(
      LightType.diffusionFrame,
      at: face,
      props: {
        PlanGrip.tiltKey: 90.0,
        PlanGrip.centreKey: 3.5,
        PlanLight.modifiersKey: ['grid-full'],
      },
    );
    PlanGrip.applyFormat(palio, GripFormat.palio4, mpu);
    final open = read(const [], ambient: sunny);
    final under = read([palio], ambient: sunny);
    expect(under.lux, lessThan(open.lux * 0.7));
    expect(under.lux, greaterThan(0));
  });
}
