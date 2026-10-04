import 'package:flutter/material.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/exposure.dart';
import 'package:iris_dp/features/camera_plan/light/modifiers.dart';
import 'package:iris_dp/features/camera_plan/light/photometry.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';

void main() {
  group('caída de la luz', () {
    const source = LightSource(candela: 90000, beamDeg: 40, sizeM: 0);

    test('al doble de distancia llega la cuarta parte: dos stops menos', () {
      final near = source.illuminance(3);
      final far = source.illuminance(6);
      expect(near, 10000);
      expect(far, 2500);
      expect(stopsBetweenLux(near, far), closeTo(2, 1e-9));
    });

    test('en el borde del haz queda la mitad: un stop menos', () {
      expect(source.profile(0), 1);
      expect(source.profile(20), closeTo(0.5, 1e-9));
      expect(source.illuminance(3, offAxisDeg: 20), closeTo(5000, 1e-6));
      // Fuera del haz hay derrame, y muy lejos del eje, nada.
      expect(source.profile(30), inInclusiveRange(0.1, 0.3));
      expect(source.profile(80), 0);
    });

    test('una fuente grande cae más despacio de cerca', () {
      const point = LightSource(candela: 1000, beamDeg: 100, sizeM: 0);
      const panel = LightSource(candela: 1000, beamDeg: 100, sizeM: 1.2);
      final pointDrop = stopsBetweenLux(
        point.illuminance(0.5),
        point.illuminance(1),
      );
      final panelDrop = stopsBetweenLux(
        panel.illuminance(0.5),
        panel.illuminance(1),
      );
      expect(pointDrop, closeTo(2, 1e-9));
      expect(panelDrop, lessThan(1.3));
      // De lejos se comportan igual.
      expect(panel.illuminance(10) / point.illuminance(10), closeTo(1, 0.01));
    });

    test('una práctica emite igual en todas direcciones', () {
      const bulb = LightSource(candela: 100, beamDeg: 360);
      expect(bulb.profile(170), 1);
    });

    test('la distancia a la que queda un nivel de luz', () {
      expect(source.distanceFor(10000), closeTo(3, 1e-9));
      expect(source.distanceFor(2500), closeTo(6, 1e-9));
    });
  });

  group('vatios y tecnología', () {
    test('más vatios dan más luz, en proporción', () {
      double cd(double watts) => LightSource.estimateCandela(
        watts: watts,
        tech: LightTech.led,
        beamDeg: 45,
      );
      expect(cd(1200) / cd(600), closeTo(2, 1e-9));
      expect(stopsBetweenLux(cd(1200), cd(300)), closeTo(2, 1e-9));
    });

    test('a igual potencia, un HMI da mucho más que un tungsteno', () {
      double cd(LightTech tech) =>
          LightSource.estimateCandela(watts: 1000, tech: tech, beamDeg: 40);
      expect(
        cd(LightTech.hmi) / cd(LightTech.tungsten),
        closeTo(90 / 26, 1e-9),
      );
    });

    test('cerrar el haz concentra la luz', () {
      double cd(double beam) => LightSource.estimateCandela(
        watts: 1000,
        tech: LightTech.tungsten,
        beamDeg: beam,
      );
      expect(cd(15), greaterThan(cd(50) * 8));
    });

    test('la estimación queda en el orden de magnitud real', () {
      // Un LED de 600 W con reflector de 55° ronda los 8.500 lux a 3 m
      // según fabricante. La estimación debe quedar a menos de un stop.
      final led600 = LightSource.estimated(
        watts: 600,
        tech: LightTech.led,
        beamDeg: 55,
      );
      expect(stopsBetweenLux(led600.illuminance(3), 8500).abs(), lessThan(1.0));
      expect(led600.status, PhotometryStatus.estimated);
    });

    test('con el dato medido, el cálculo parte de él', () {
      final measured = LightSource.measured(
        lux: 12000,
        meters: 3,
        beamDeg: 45,
        sizeM: 0,
      );
      expect(measured.candela, 108000);
      expect(measured.illuminance(3), closeTo(12000, 1e-6));
      expect(measured.status, PhotometryStatus.measured);
    });
  });

  group('exposición', () {
    const camera = ExposureSettings();

    test('de lux a diafragma y vuelta', () {
      final stop = camera.stopFor(1000);
      expect(stop, closeTo(7.0, 0.05));
      expect(camera.luxFor(stop), closeTo(1000, 1e-6));
    });

    test('cuatro veces la luz cierran dos stops', () {
      expect(
        stopsBetweenApertures(camera.stopFor(4000), camera.stopFor(1000)),
        closeTo(2, 1e-9),
      );
    });

    test('ISO, obturación, fps y ND mueven el diafragma lo que deben', () {
      final base = camera.stopFor(1000);
      double diff(ExposureSettings s) =>
          stopsBetweenApertures(s.stopFor(1000), base);
      expect(diff(camera.copyWith(iso: 1600)), closeTo(1, 1e-9));
      expect(diff(camera.copyWith(shutterDeg: 90)), closeTo(-1, 1e-9));
      expect(diff(camera.copyWith(fps: 48)), closeTo(-1, 1e-9));
      expect(diff(camera.copyWith(ndStops: 3)), closeTo(-3, 1e-9));
    });

    test('rótulos de diafragma, diferencia y lux', () {
      expect(formatStop(2.83), 'T2.8');
      expect(formatStop(4.1), 'T4');
      expect(formatStop(7.0), 'T7.1');
      expect(formatStop(0), '—');
      expect(formatStop(60), 'T32+');
      expect(formatStopDifference(1.34), '+1⅓');
      expect(formatStopDifference(-0.66), '−⅔');
      expect(formatStopDifference(2), '+2');
      expect(formatStopDifference(0.1), '0');
      expect(formatLux(12400), '12.4k lx');
      expect(formatLux(850.4), '850 lx');
      expect(formatLux(3.24), '3.2 lx');
    });
  });

  group('difusiones, redes y gelatinas', () {
    const bare = LightSource(candela: 100000, beamDeg: 40, cct: 5600);

    test('cada material quita los stops que le tocan', () {
      expect(LightModifier.byId('grid-half')!.stopsLost, closeTo(1, 1e-9));
      expect(LightModifier.byId('grid-full')!.stopsLost, closeTo(2, 1e-9));
      expect(LightModifier.byId('scrim-single')!.stopsLost, closeTo(0.5, 0.01));
      expect(LightModifier.byId('scrim-double')!.stopsLost, closeTo(1, 1e-9));
      expect(LightModifier.byId('white-full')!.stopsLost, closeTo(1.47, 0.01));
    });

    test('una red quita luz sin abrir el haz', () {
      final lit = PlanLight.apply(bare, [LightModifier.byId('scrim-double')!]);
      expect(lit.candela, 50000);
      expect(lit.beamDeg, 40);
      expect(lit.cct, 5600);
    });

    test('una difusión quita luz y abre el haz: el eje baja más', () {
      final grid = LightModifier.byId('grid-half')!;
      final lit = PlanLight.apply(bare, [grid]);
      expect(lit.beamDeg, 95);
      // Más de un stop en el eje: la mitad de la luz, y repartida.
      expect(stopsBetweenLux(bare.candela, lit.candela), greaterThan(2));
      // Y bien fuera del haz original, donde antes no llegaba nada, ahora
      // sí hay luz.
      expect(bare.illuminance(3, offAxisDeg: 55), 0);
      expect(lit.illuminance(3, offAxisDeg: 55), greaterThan(100));
    });

    test('el CTO lleva la luz día a tungsteno y el CTB al revés', () {
      expect(
        LightModifier.byId('cto-full')!.shiftCct(5600),
        closeTo(2900, 150),
      );
      expect(
        LightModifier.byId('ctb-full')!.shiftCct(3200),
        closeTo(5500, 200),
      );
      expect(
        LightModifier.byId('cto-half')!.shiftCct(5600),
        closeTo(3850, 150),
      );
    });

    test('los modificadores se suman', () {
      final lit = PlanLight.apply(bare, [
        LightModifier.byId('scrim-double')!,
        LightModifier.byId('cto-full')!,
      ], dimmer: 0.5);
      expect(lit.candela, closeTo(100000 * 0.5 * 0.47 * 0.5, 1e-6));
    });

    test('hay gelatinas CTO, CTB y difusión blanca en el catálogo', () {
      final ids = kLightModifiers.map((m) => m.id).toSet();
      expect(ids.length, kLightModifiers.length);
      expect(ids, containsAll(['cto-full', 'ctb-full', 'white-full']));
      expect(LightModifier.ofKind(ModifierKind.correction), hasLength(10));
    });
  });

  group('una luz de la planta', () {
    PlanElement light(LightType type, [Map<String, dynamic>? props]) =>
        PlanElement(
          id: 0,
          type: ElementType.light,
          position: Offset.zero,
          lightType: type,
          props: props,
        );

    test('sin más datos, se estima con la potencia típica de su tipo', () {
      final hmi = PlanLight.of(light(LightType.hmi))!;
      expect(hmi.watts, 1800);
      expect(hmi.tech, LightTech.hmi);
      expect(hmi.source.status, PhotometryStatus.estimated);
      // Regulada al 75 % por defecto.
      expect(hmi.source.candela, closeTo(hmi.bare.candela * 0.75, 1e-6));
    });

    test('cambiar los vatios cambia la luz', () {
      final a = PlanLight.of(light(LightType.led, {'intensity': 100}))!;
      final b = PlanLight.of(
        light(LightType.led, {'intensity': 100, 'watts': 1200}),
      )!;
      expect(
        stopsBetweenLux(b.source.illuminance(3), a.source.illuminance(3)),
        closeTo(2, 1e-9),
      );
    });

    test('el dato medido manda sobre la estimación', () {
      final lit = PlanLight.of(
        light(LightType.hmi, {
          'intensity': 100,
          'measuredLux': 12000,
          'measuredMeters': 3,
        }),
      )!;
      expect(lit.source.status, PhotometryStatus.measured);
      expect(lit.source.candela, 108000);
    });

    test('difusión y gelatina en el aparato', () {
      final lit = PlanLight.of(
        light(LightType.hmi, {
          'intensity': 100,
          'modifiers': ['white-full', 'cto-half'],
        }),
      )!;
      expect(lit.modifiers.map((m) => m.id), ['white-full', 'cto-half']);
      expect(lit.source.beamDeg, 100);
      expect(lit.source.cct, closeTo(3850, 150));
      expect(lit.stopsLost, greaterThan(2));
    });

    test('apagada no da luz y el grip no es una luz', () {
      expect(
        PlanLight.of(light(LightType.hmi, {'off': true}))!.source.candela,
        0,
      );
      expect(PlanLight.of(light(LightType.flag)), isNull);
    });
  });
}
