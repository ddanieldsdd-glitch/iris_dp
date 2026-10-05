import 'package:flutter/material.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/light/ambient.dart';
import 'package:iris_dp/features/camera_plan/light/exposure.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/light/meter.dart';
import 'package:iris_dp/features/camera_plan/light/modifiers.dart';
import 'package:iris_dp/features/camera_plan/light/photometry.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/plan_opening.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';

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

  group('paredes y ventanas', () {
    var id = 0;
    PlanElement hmi(double x, double y, double rotation) => PlanElement(
      id: --id,
      type: ElementType.light,
      position: Offset(x, y),
      rotation: rotation,
      lightType: LightType.hmi,
      props: {'intensity': 100},
    );
    PlanElement piece(
      ArchitectureType type,
      double x,
      double y, {
      double rotation = 90,
      Map<String, dynamic>? props,
    }) => PlanElement(
      id: --id,
      type: ElementType.wall,
      position: Offset(x, y),
      rotation: rotation,
      label: type.dbValue,
      props: props,
    );
    // Una luz en (100, 300) que mira a la derecha, y una pared vertical en
    // x = 400 que va de y = 0 a y = 600.
    PlanElement wall() => PlanSegment.create(
      start: const Offset(400, 0),
      end: const Offset(400, 600),
    )..id = --id;
    LightScene scene(List<PlanElement> elements) =>
        LightScene.from(elements, metersPerUnit: 0.02);

    const behind = Offset(700, 300);
    const before = Offset(300, 300);

    test('sin nada en medio, la luz llega', () {
      final open = scene([hmi(100, 300, 90)]);
      expect(open.luxAt(behind), greaterThan(100));
      expect(open.contributionsAt(behind), hasLength(1));
    });

    test('una pared corta la luz', () {
      final walled = scene([hmi(100, 300, 90), wall()]);
      expect(walled.luxAt(behind), 0);
      // Delante de la pared sigue llegando.
      expect(walled.luxAt(before), greaterThan(100));
    });

    test('una ventana en la pared la deja pasar, menos lo que quita el '
        'cristal', () {
      final open = scene([hmi(100, 300, 90)]).luxAt(behind);
      final windowed = scene([
        hmi(100, 300, 90),
        wall(),
        piece(ArchitectureType.window, 400, 300),
      ]);
      expect(windowed.luxAt(behind), closeTo(open * 0.9, open * 0.001));
      // Fuera del hueco de la ventana, la pared sigue cortando.
      expect(windowed.luxAt(const Offset(700, 560)), 0);
    });

    test('una ventana con difusión quita los stops de la tela', () {
      final plain = scene([
        hmi(100, 300, 90),
        wall(),
        piece(ArchitectureType.window, 400, 300),
      ]).luxAt(behind);
      final diffused = scene([
        hmi(100, 300, 90),
        wall(),
        piece(
          ArchitectureType.window,
          400,
          300,
          props: {
            'modifiers': ['grid-half'],
          },
        ),
      ]).luxAt(behind);
      expect(stopsBetweenLux(plain, diffused), closeTo(1, 1e-6));
    });

    test('puerta abierta y abertura dejan pasar todo; cerrada, nada', () {
      final open = scene([hmi(100, 300, 90)]).luxAt(behind);
      for (final type in [
        ArchitectureType.doorOpen,
        ArchitectureType.opening,
      ]) {
        final lux = scene([
          hmi(100, 300, 90),
          wall(),
          piece(type, 400, 300),
        ]).luxAt(behind);
        expect(lux, closeTo(open, open * 0.001), reason: type.name);
      }
      expect(
        scene([
          hmi(100, 300, 90),
          wall(),
          piece(ArchitectureType.doorClosed, 400, 300),
        ]).luxAt(behind),
        0,
      );
    });

    test('una pared curva también corta', () {
      final curved = wall()..props['curve'] = 60.0;
      expect(scene([hmi(100, 300, 90), curved]).luxAt(behind), 0);
    });

    test('una bandera corta la luz que tiene detrás', () {
      final flag = PlanElement(
        id: --id,
        type: ElementType.light,
        position: const Offset(250, 300),
        rotation: 90,
        lightType: LightType.flag,
      );
      final flagged = scene([hmi(100, 300, 90), flag]);
      expect(flagged.luxAt(behind), 0);
      // A un lado de la bandera, la luz pasa.
      expect(flagged.luxAt(const Offset(700, 520)), greaterThan(0));
    });

    test('el área visible se recorta en la pared', () {
      final walled = scene([hmi(100, 300, 90), wall()]);
      final area = walled.visibleArea(const Offset(100, 300), 2000);
      expect(area.contains(before), isTrue);
      expect(area.contains(behind), isFalse);
      expect(
        walled.reachAlong(const Offset(100, 300), const Offset(1, 0), 2000),
        300,
      );
    });

    test('varias luces se suman y se ordenan de más a menos', () {
      final two = scene([hmi(100, 300, 90), hmi(1300, 300, 270)]);
      final parts = two.contributionsAt(before);
      expect(parts, hasLength(2));
      expect(parts.first.lux, greaterThan(parts.last.lux));
      expect(
        two.luxAt(before),
        closeTo(parts.first.lux + parts.last.lux, 1e-6),
      );
    });
  });

  group('simulador: colisiones, grip y rebotes', () {
    var id = 0;
    PlanElement light(
      LightType type,
      double x,
      double y,
      double rotation, [
      Map<String, dynamic>? props,
    ]) => PlanElement(
      id: --id,
      type: ElementType.light,
      position: Offset(x, y),
      rotation: rotation,
      lightType: type,
      props: {'intensity': 100, ...?props},
    );
    PlanElement hmi(double x, double y, double rotation) =>
        light(LightType.hmi, x, y, rotation);
    PlanElement wall(
      double x1,
      double y1,
      double x2,
      double y2, [
      String? material,
    ]) {
      final el = PlanSegment.create(start: Offset(x1, y1), end: Offset(x2, y2))
        ..id = --id;
      if (material != null) el.props['material'] = material;
      return el;
    }

    PlanElement door({double open = 90, double width = 60}) => PlanElement(
      id: --id,
      type: ElementType.wall,
      position: const Offset(400, 300),
      rotation: 90,
      label: ArchitectureType.doorOpen.dbValue,
      props: {'open': open, 'width': width},
    );
    LightScene scene(List<PlanElement> elements, {bool wallBounce = false}) =>
        LightScene.from(elements, metersPerUnit: 0.02, wallBounce: wallBounce);
    const behind = Offset(700, 300);

    test('el haz dibujado se corta en la pared, esté donde esté la luz', () {
      // La planta con la que falló: sala arriba, luz debajo mirando hacia
      // arriba, con coordenadas negativas.
      final room = scene([
        light(LightType.led1x1, -80, 560, 0),
        wall(-150, 160, -150, 390),
        wall(-150, 390, 40, 420),
        wall(40, 420, 30, 160),
        wall(30, 160, -150, 160),
      ]);
      final area = room.visibleArea(const Offset(-80, 560), 3000);
      expect(area.contains(const Offset(-80, 480)), isTrue);
      expect(area.contains(const Offset(-80, 300)), isFalse);
      expect(area.contains(const Offset(-80, 100)), isFalse);
      expect(room.luxAt(const Offset(-80, 300)), 0);
    });

    test('una persona hace sombra, salvo que se le quite', () {
      final actor = PlanElement(
        id: --id,
        type: ElementType.actor,
        position: const Offset(300, 300),
      );
      final open = scene([hmi(100, 300, 90)]).luxAt(behind);
      expect(scene([hmi(100, 300, 90), actor]).luxAt(behind), 0);
      // A un lado de la persona, la luz pasa.
      expect(
        scene([hmi(100, 300, 90), actor]).luxAt(const Offset(700, 420)),
        greaterThan(0),
      );
      // La propia persona sí está iluminada.
      expect(
        scene([hmi(100, 300, 90), actor]).luxAt(actor.position),
        greaterThan(0),
      );
      actor.props['noShadow'] = true;
      expect(scene([hmi(100, 300, 90), actor]).luxAt(behind), open);
    });

    test('una puerta se engancha a la pared y se alinea con ella', () {
      final w = wall(400, 0, 400, 600);
      final piece = door()
        ..position = const Offset(420, 310)
        ..rotation = 0;
      expect(PlanOpening.snapToWall(piece, [w]), isTrue);
      expect(
        (piece.position - const Offset(400, 310)).distance,
        lessThan(1e-6),
      );
      expect(piece.rotation, 90);
      // Lejos de cualquier pared no se engancha.
      final far = door()..position = const Offset(900, 300);
      expect(PlanOpening.snapToWall(far, [w]), isFalse);
    });

    test('puerta abierta: la luz pasa por el hueco; cerrada, no', () {
      final open = scene([hmi(100, 300, 90)]).luxAt(behind);
      final w = wall(400, 0, 400, 600);
      expect(
        scene([hmi(100, 300, 90), w, door(open: 90)]).luxAt(behind),
        closeTo(open, open * 0.001),
      );
      expect(scene([hmi(100, 300, 90), w, door(open: 0)]).luxAt(behind), 0);
      // Fuera del hueco, la pared sigue cortando.
      expect(
        scene([hmi(100, 300, 90), w, door()]).luxAt(const Offset(700, 560)),
        0,
      );
    });

    test('la hoja de una puerta abierta hace sombra', () {
      final piece = door(open: 60);
      final (hinge, tip) = PlanOpening.leaves(piece).single;
      expect(hinge, const Offset(400, 270));
      expect((tip - hinge).distance, closeTo(60, 1e-6));
      // Una luz detrás de la hoja no llega al otro lado de ella.
      final mid = (hinge + tip) / 2;
      final normal = Offset(-(tip - hinge).dy, (tip - hinge).dx) / 60;
      final lamp = light(
        LightType.practical,
        (mid + normal * 30).dx,
        (mid + normal * 30).dy,
        0,
      );
      final s = scene([lamp, piece]);
      expect(s.luxAt(mid - normal * 30), 0);
      expect(s.luxAt(mid + normal * 60), greaterThan(0));
    });

    test('un negro corta y una red quita medio stop', () {
      final open = scene([hmi(100, 300, 90)]).luxAt(behind);
      expect(
        scene([
          hmi(100, 300, 90),
          light(LightType.flag, 250, 300, 90),
        ]).luxAt(behind),
        0,
      );
      final netted = scene([
        hmi(100, 300, 90),
        light(LightType.net, 250, 300, 90),
      ]).luxAt(behind);
      expect(stopsBetweenLux(open, netted), closeTo(0.5, 0.01));
    });

    test('una gelatina en marco quita luz y cambia el color', () {
      final gelled = scene([
        hmi(100, 300, 90),
        light(LightType.gel, 250, 300, 90, {
          'modifiers': ['cto-full'],
        }),
      ]);
      final open = scene([hmi(100, 300, 90)]);
      expect(gelled.luxAt(behind), closeTo(open.luxAt(behind) * 0.47, 1));
      expect(open.cctAt(behind), closeTo(5600, 1));
      expect(gelled.cctAt(behind), closeTo(2900, 150));
    });

    test('un marco de difusión corta el haz y lo devuelve más ancho', () {
      final open = scene([hmi(100, 300, 90)]);
      final framed = scene([
        hmi(100, 300, 90),
        light(LightType.diffusionFrame, 250, 300, 90, {'len': 120}),
      ]);
      // En el eje hay menos luz que sin tela…
      expect(framed.luxAt(behind), greaterThan(0));
      expect(framed.luxAt(behind), lessThan(open.luxAt(behind) * 0.5));
      // …y lo que llega viene de la tela, no del aparato.
      final parts = framed.contributionsAt(behind);
      expect(parts.single.light.isSecondary, isTrue);
      expect(parts.single.light.label, contains('Grid Cloth'));
      // Muy fuera del haz original, donde antes no había nada, ahora sí.
      const side = Offset(270, 640);
      expect(open.luxAt(side), 0);
      expect(framed.luxAt(side), greaterThan(0));
      // Por detrás de la tela no sale nada de ella.
      expect(
        framed.contributionsAt(const Offset(180, 300)).single.light.isSecondary,
        isFalse,
      );
    });

    test('un rebote ilumina lo que el aparato no ve, con su tinte', () {
      // La luz mira a la derecha; el punto está detrás de ella.
      const hidden = Offset(60, 420);
      expect(scene([hmi(100, 300, 90)]).luxAt(hidden), 0);

      PlanElement bounce(String material) => light(
        LightType.bounce,
        400,
        300,
        90,
        {'len': 120, 'material': material},
      );
      final white = scene([hmi(100, 300, 90), bounce('ultrabounce')]);
      final gold = scene([hmi(100, 300, 90), bounce('gold')]);
      expect(white.luxAt(hidden), greaterThan(0));
      // El oro devuelve algo menos y bastante más cálido.
      expect(gold.luxAt(hidden), lessThan(white.luxAt(hidden)));
      expect(gold.cctAt(hidden)!, lessThan(white.cctAt(hidden)! - 1000));
      // El rebote no deja pasar la luz.
      expect(white.luxAt(behind), 0);
    });

    test('las paredes devuelven luz a la sala, con el tinte del material', () {
      const hidden = Offset(60, 420);
      List<PlanElement> room(String material) => [
        hmi(100, 300, 90),
        wall(400, 0, 400, 600, material),
      ];
      expect(scene(room('white')).luxAt(hidden), 0);

      final white = scene(room('white'), wallBounce: true);
      final brick = scene(room('brick'), wallBounce: true);
      final black = scene(room('black'), wallBounce: true);
      expect(white.luxAt(hidden), greaterThan(brick.luxAt(hidden) * 2));
      expect(brick.luxAt(hidden), greaterThan(black.luxAt(hidden) * 3));
      // Blanca: algo más fría que la fuente. Ladrillo: más cálida.
      expect(white.cctAt(hidden)!, greaterThan(5600));
      expect(brick.cctAt(hidden)!, lessThan(5000));
      // La pared sigue sin dejar pasar la luz.
      expect(white.luxAt(behind), 0);
      // Y quien aporta es la pared.
      expect(
        white.contributionsAt(hidden).first.light.label,
        startsWith('Pared blanca'),
      );
    });
  });

  group('fotómetro', () {
    var id = 0;
    PlanElement hmi(double x, double y, double rotation, [double? intensity]) =>
        PlanElement(
          id: --id,
          type: ElementType.light,
          position: Offset(x, y),
          rotation: rotation,
          lightType: LightType.hmi,
          props: {'intensity': intensity ?? 100},
        );
    PlanElement camera(double x, double y, [Map<String, dynamic>? props]) =>
        PlanElement(
          id: --id,
          type: ElementType.camera,
          position: Offset(x, y),
          props: {'noShadow': true, ...?props},
        );
    LightScene scene(List<PlanElement> elements) =>
        LightScene.from(elements, metersPerUnit: 0.02, wallBounce: false);

    // Sujeto en (500, 300); la cámara debajo, mirando hacia arriba.
    const subject = Offset(500, 300);

    test('lee lux y diafragma con los ajustes de la cámara', () {
      final cam = camera(500, 600);
      final s = scene([hmi(200, 300, 90), cam]);
      final r = MeterReading.at(s, subject, camera: cam);
      expect(r.lux, closeTo(s.luxAt(subject), 1e-9));
      expect(r.stop, closeTo(const ExposureSettings().stopFor(r.lux), 1e-9));
      expect(r.targetStop, 2.8);
      expect(
        r.stopsOverTarget,
        closeTo(stopsBetweenApertures(r.stop, 2.8), 1e-9),
      );
      expect(r.shortLabel, startsWith('T'));
      expect(r.estimated, isTrue);
      expect(r.cct, closeTo(5600, 1));
    });

    test('subir el ISO un stop cierra el diafragma un stop', () {
      final base = camera(500, 600);
      final fast = camera(500, 600, {'iso': 1600, 'tStop': 4});
      final s = scene([hmi(200, 300, 90)]);
      final a = MeterReading.at(s, subject, camera: base);
      final b = MeterReading.at(s, subject, camera: fast);
      expect(stopsBetweenApertures(b.stop, a.stop), closeTo(1, 1e-9));
      expect(b.targetStop, 4);
    });

    test('separa clave, relleno y contra respecto a la cámara', () {
      final cam = camera(500, 600);
      // Clave fuerte por la izquierda de cámara, relleno flojo por la
      // derecha y un contra por detrás del sujeto.
      final s = scene([
        hmi(200, 300, 90),
        hmi(800, 300, 270, 25),
        hmi(500, 60, 180, 50),
        cam,
      ]);
      final r = MeterReading.at(s, subject, camera: cam);
      expect(r.hasCamera, isTrue);
      expect(r.keyIsLeft, isTrue);
      expect(r.left.lux, greaterThan(r.right.lux));
      expect(r.back.lux, greaterThan(0));
      expect(r.left.lux + r.right.lux + r.back.lux, closeTo(r.lux, 1e-6));
      // Relleno al 25 % de la clave: dos stops, 4:1.
      expect(r.contrastStops, closeTo(2, 1e-6));
      expect(r.ratioLabel, '4:1');
    });

    test('con la cámara al otro lado, izquierda y derecha se cambian', () {
      final s = scene([hmi(200, 300, 90)]);
      final below = MeterReading.at(s, subject, camera: camera(500, 600));
      final above = MeterReading.at(s, subject, camera: camera(500, 0));
      expect(below.keyIsLeft, isTrue);
      expect(above.keyIsLeft, isFalse);
    });

    test('sin relleno y sin luz', () {
      final cam = camera(500, 600);
      final one = MeterReading.at(
        scene([hmi(200, 300, 90), cam]),
        subject,
        camera: cam,
      );
      expect(one.ratioLabel, 'sin relleno');
      final dark = MeterReading.at(scene([cam]), subject, camera: cam);
      expect(dark.lux, 0);
      expect(dark.cct, isNull);
      expect(dark.stopsOverTarget, 0);
    });

    test('el diafragma del plano se lee en cualquier formato', () {
      expect(CameraExposure.parseStop('T2.8'), 2.8);
      expect(CameraExposure.parseStop('f/5,6'), 5.6);
      expect(CameraExposure.parseStop('4'), 4);
      expect(CameraExposure.parseStop('abierto'), isNull);
    });

    test('el color del mapa va de azul a rojo pasando por verde', () {
      final under = exposureColor(-4);
      final on = exposureColor(0);
      final over = exposureColor(4);
      expect(under.b, greaterThan(under.r));
      expect(on.g, greaterThan(on.r));
      expect(on.g, greaterThan(on.b));
      expect(over.r, greaterThan(over.b));
    });
  });

  group('ambiente: sol y cielo', () {
    var id = 0;
    PlanElement wall(double x1, double y1, double x2, double y2) =>
        PlanSegment.create(start: Offset(x1, y1), end: Offset(x2, y2))
          ..id = --id;
    PlanElement window(double x, double y) => PlanElement(
      id: --id,
      type: ElementType.wall,
      position: Offset(x, y),
      rotation: 90,
      label: ArchitectureType.window.dbValue,
    );
    // Sol desde la izquierda (270°), bajo. Pared vertical en x = 400.
    const sunFromLeft = PlanAmbient(
      day: true,
      sunAzimuth: 270,
      sunElevation: 30,
      skyOn: false,
    );
    LightScene scene(List<PlanElement> elements, PlanAmbient ambient) =>
        LightScene.from(elements, metersPerUnit: 0.02, ambient: ambient);

    test('al sol, sin nada en medio, llega el sol directo', () {
      final s = scene([], sunFromLeft);
      expect(s.luxAt(const Offset(500, 300)), 60000);
      expect(
        s.contributionsAt(const Offset(500, 300)).single.light.label,
        'Sol',
      );
      expect(sunFromLeft.towardSun.dx, closeTo(-1, 1e-9));
    });

    test('una pared da sombra hasta donde alcanza según la altura del sol', () {
      final s = scene([wall(400, 0, 400, 600)], sunFromLeft);
      // Con el sol a 30°, una pared de 2,5 m da 4,33 m de sombra: 216
      // unidades.
      expect(sunFromLeft.shadowLength(2.5), closeTo(4.33, 0.01));
      expect(s.luxAt(const Offset(500, 300)), 0);
      expect(s.luxAt(const Offset(700, 300)), 60000);
      // Con el sol más alto, la sombra se acorta.
      final high = scene([
        wall(400, 0, 400, 600),
      ], sunFromLeft.copyWith(sunElevation: 70));
      expect(high.luxAt(const Offset(500, 300)), 60000);
    });

    test('el sol entra por una ventana', () {
      final s = scene([wall(400, 0, 400, 600), window(400, 300)], sunFromLeft);
      expect(s.luxAt(const Offset(500, 300)), closeTo(54000, 1));
      expect(s.luxAt(const Offset(500, 500)), 0);
    });

    test('nublado no hay sol directo, solo cielo', () {
      const overcast = PlanAmbient(day: true, condition: SkyCondition.overcast);
      final s = scene([], overcast);
      final parts = s.contributionsAt(const Offset(500, 300));
      expect(parts.single.light.label, 'Cielo');
      expect(parts.single.lux, 8000);
    });

    test('dentro de una sala cerrada no llega cielo; por la ventana, algo', () {
      const sky = PlanAmbient(day: true, sunOn: false);
      final room = [
        wall(300, 200, 500, 200),
        wall(500, 200, 500, 400),
        wall(500, 400, 300, 400),
        wall(300, 400, 300, 200),
      ];
      const inside = Offset(400, 300);
      expect(scene(room, sky).luxAt(inside), 0);
      final opened = scene([...room, window(300, 300)], sky).luxAt(inside);
      expect(opened, greaterThan(0));
      expect(opened, lessThan(12000));
      // Fuera, el cielo entero.
      expect(scene(room, sky).luxAt(const Offset(900, 300)), 12000);
    });

    test('de noche solo queda la luna', () {
      final s = scene([], const PlanAmbient());
      final part = s.contributionsAt(const Offset(500, 300)).single;
      expect(part.light.label, 'Luna');
      expect(part.lux, PlanAmbient.moonLux);
    });

    test('el ambiente se guarda y se lee', () {
      const a = PlanAmbient(
        day: true,
        sunAzimuth: 200,
        sunElevation: 50,
        condition: SkyCondition.hazy,
        wallBounce: false,
      );
      expect(PlanAmbient.fromJson(a.toJson()), a);
      expect(PlanAmbient.fromJson(null), const PlanAmbient());
      final doc = FloorPlanJson.decodeDocument(
        FloorPlanJson.encodeDocument(FloorPlanDocument(ambient: a.toJson())),
      );
      expect(PlanAmbient.fromJson(doc.ambient), a);
    });
  });

  group('ajustes de luz por plano', () {
    PlanElement lamp(String uid, [Map<String, dynamic>? props]) => PlanElement(
      id: 0,
      type: ElementType.light,
      position: const Offset(100, 100),
      lightType: LightType.hmi,
      props: {'uid': uid, ...?props},
    );

    test('el plano ve su ajuste y el resto del esquema tal cual', () {
      final setup = [lamp('key'), lamp('fill')];
      final json = LightOverrides.encode({
        'key': lamp('key', {'off': true})..position = const Offset(250, 90),
      });
      final seen = LightOverrides.apply(setup, json);
      expect(seen[0].shotOverride, isTrue);
      expect(seen[0].props['off'], isTrue);
      expect(seen[0].position, const Offset(250, 90));
      expect(seen[1].shotOverride, isFalse);
      expect(seen[1].props['off'], isNull);
      // Sin ajustes, lo mismo que el esquema.
      expect(LightOverrides.apply(setup, null), same(setup));
      expect(LightOverrides.encode({}), isNull);
    });

    test('un ajuste de una luz que ya no está en el esquema se ignora', () {
      final json = LightOverrides.encode({'gone': lamp('gone')});
      final seen = LightOverrides.apply([lamp('key')], json);
      expect(seen.single.shotOverride, isFalse);
    });

    test('cada elemento recibe un identificador estable', () {
      final a = PlanElement(
        id: 0,
        type: ElementType.light,
        position: Offset.zero,
      );
      final b = PlanElement(
        id: 0,
        type: ElementType.light,
        position: Offset.zero,
      );
      LightOverrides.ensureUids([a, b]);
      final first = LightOverrides.uidOf(a);
      expect(first, isNotNull);
      expect(LightOverrides.uidOf(b), isNot(first));
      LightOverrides.ensureUids([a]);
      expect(LightOverrides.uidOf(a), first);
    });
  });

  group('ventanas, cortinas y luz del techo', () {
    var id = 0;
    PlanElement hmi(
      double x,
      double y,
      double rotation, [
      Map<String, dynamic>? props,
    ]) => PlanElement(
      id: --id,
      type: ElementType.light,
      position: Offset(x, y),
      rotation: rotation,
      lightType: LightType.hmi,
      props: {'intensity': 100, ...?props},
    );
    PlanElement wall(double x1, double y1, double x2, double y2) =>
        PlanSegment.create(start: Offset(x1, y1), end: Offset(x2, y2))
          ..id = --id;
    PlanElement window([Map<String, dynamic>? props]) => PlanElement(
      id: --id,
      type: ElementType.wall,
      position: const Offset(400, 300),
      rotation: 90,
      label: ArchitectureType.window.dbValue,
      props: {'width': 120.0, ...?props},
    );
    LightScene scene(List<PlanElement> elements) =>
        LightScene.from(elements, metersPerUnit: 0.02, wallBounce: false);
    const behind = Offset(700, 300);
    double through(Map<String, dynamic>? props, [Offset at = behind]) => scene([
      hmi(100, 300, 90),
      wall(400, 0, 400, 600),
      window(props),
    ]).luxAt(at);

    test('al engancharse, el ángulo queda entre 0 y 360', () {
      // Una pared dibujada de abajo arriba da un ángulo negativo.
      final w = wall(400, 600, 400, 0);
      final piece = window()..position = const Offset(410, 300);
      expect(PlanOpening.snapToWall(piece, [w]), isTrue);
      expect(piece.rotation, inInclusiveRange(0, 360));
      expect(piece.rotation, closeTo(270, 1e-6));
    });

    test('se engancha a una pared curva y le abre hueco entero', () {
      final curved = wall(400, 0, 400, 600)..props['curve'] = 80.0;
      final piece = window()..position = const Offset(370, 300);
      expect(PlanOpening.snapToWall(piece, [curved]), isTrue);
      // Queda sobre la curva, no sobre la cuerda.
      expect(
        (piece.position - PlanSegment.midpoint(curved)).distance,
        lessThan(8),
      );
      final s = scene([hmi(100, 300, 90), curved, piece]);
      // La luz pasa por el centro y por los dos lados del hueco.
      final x = piece.position.dx + 250;
      expect(s.luxAt(Offset(x, 300)), greaterThan(0));
      expect(s.luxAt(Offset(x, 300 - 60)), greaterThan(0));
      expect(s.luxAt(Offset(x, 300 + 60)), greaterThan(0));
      // Y la pared sigue cortando lejos del hueco.
      expect(s.luxAt(const Offset(700, 580)), 0);
    });

    test('abierta no hay cristal: pasa toda la luz', () {
      final open = scene([hmi(100, 300, 90)]).luxAt(behind);
      expect(through(null), closeTo(open * 0.9, open * 0.001));
      // Hojas hacia el lado de la luz, para que no den sombra al punto.
      expect(
        through({'open': 90.0, 'swingIn': true}),
        closeTo(open, open * 0.001),
      );
      expect(PlanOpening.leaves(window({'open': 90.0})), hasLength(2));
      expect(PlanOpening.leaves(window()), isEmpty);
    });

    test('la cortina tapa solo la parte que cubre', () {
      // La ventana va de y = 240 a y = 360; la cortina empieza en 240.
      const top = Offset(700, 240);
      const bottom = Offset(700, 360);
      final bare = through(null, top);
      // Media cortina opaca: arriba no pasa nada, abajo todo.
      final half = {'curtain': 0.5, 'curtainMaterial': 'blackout'};
      expect(through(half, top), 0);
      expect(through(half, bottom), closeTo(through(null, bottom), 1e-6));
      // Un visillo echado del todo quita el 40 %.
      expect(
        through({'curtain': 1.0, 'curtainMaterial': 'sheer'}, top),
        closeTo(bare * 0.6, bare * 0.001),
      );
      // Sin cortina, como si no existiera.
      expect(through({'curtain': 0.0}, top), bare);
    });

    test(
      'colgada del techo, hace un charco bajo ella y pasa sobre la gente',
      () {
        final rigged = hmi(300, 300, 0, {'mount': 'ceiling', 'height': 4.5});
        final actor = PlanElement(
          id: --id,
          type: ElementType.actor,
          position: const Offset(330, 300),
        );
        final s = scene([rigged, actor]);
        // Justo debajo hay 3 m de caída (4,5 m menos 1,5 m del sujeto).
        final light = PlanLight.of(rigged)!;
        expect(PlanLight.overheadDrop(rigged), 3);
        expect(
          s.luxAt(const Offset(300, 300)),
          closeTo(light.source.illuminance(3), 1e-6),
        );
        // Igual a un lado que al otro: ya no importa hacia dónde «mira».
        expect(
          s.luxAt(const Offset(400, 300)),
          closeTo(s.luxAt(const Offset(200, 300)), 1e-6),
        );
        expect(
          s.luxAt(const Offset(300, 400)),
          closeTo(s.luxAt(const Offset(400, 300)), 1e-6),
        );
        // Menos luz lejos de la vertical, y nada muy lejos.
        expect(
          s.luxAt(const Offset(400, 300)),
          lessThan(s.luxAt(const Offset(300, 300))),
        );
        expect(s.luxAt(const Offset(900, 300)), 0);
        // La persona no tapa a quien tiene detrás.
        expect(s.luxAt(const Offset(380, 300)), greaterThan(0));
        // Más alta, menos luz debajo.
        final higher = scene([
          hmi(300, 300, 0, {'mount': 'ceiling', 'height': 7.5}),
        ]);
        expect(
          stopsBetweenLux(
            s.luxAt(const Offset(300, 300)),
            higher.luxAt(const Offset(300, 300)),
          ),
          closeTo(2, 0.01),
        );
      },
    );

    test('las telas de palio de Rosco están en el catálogo', () {
      for (final id in [
        'grid-full',
        'grid-half',
        'grid-quarter',
        'silent-grid-full',
        'silent-grid-half',
        'silent-grid-quarter',
        'silk-china',
        'silk',
        'muslin-bleached',
        'muslin',
        'scrim-triple',
      ]) {
        expect(LightModifier.byId(id), isNotNull, reason: id);
      }
      // Las reducciones que publica Rosco.
      expect(LightModifier.byId('silk')!.stopsLost, closeTo(1, 1e-9));
      expect(LightModifier.byId('silk-china')!.stopsLost, closeTo(0.5, 0.01));
      expect(
        LightModifier.byId('silk-quarter')!.stopsLost,
        closeTo(0.25, 0.01),
      );
      expect(LightModifier.byId('scrim-triple')!.stopsLost, closeTo(1.5, 0.01));
      expect(LightModifier.byId('silk')!.published, isTrue);
      expect(LightModifier.byId('grid-full')!.published, isFalse);
      // El silent grid quita lo mismo que su grid cloth.
      expect(
        LightModifier.byId('silent-grid-half')!.transmission,
        LightModifier.byId('grid-half')!.transmission,
      );
      final ids = kLightModifiers.map((m) => m.id).toSet();
      expect(ids.length, kLightModifiers.length);
    });
  });
}
