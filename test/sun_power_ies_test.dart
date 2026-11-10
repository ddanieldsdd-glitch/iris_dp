import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/settings/app_prefs.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/ambient.dart';
import 'package:iris_dp/features/camera_plan/light/ies_profile.dart';
import 'package:iris_dp/features/camera_plan/light/photometry.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/light/sun_position.dart';
import 'package:iris_dp/features/camera_plan/light_beam.dart';
import 'package:iris_dp/features/camera_plan/plan_power.dart';
import 'package:iris_dp/features/camera_plan/plan_power_sheet.dart';
import 'package:iris_dp/features/camera_plan/plan_sun_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlanElement lamp(int id, double watts, {bool off = false}) =>
    PlanElement(
        id: id,
        type: ElementType.light,
        lightType: LightType.fresnelMedium,
        position: Offset.zero,
      )
      ..props[PlanLight.wattsKey] = watts
      ..props[LightBeam.offKey] = off;

void main() {
  group('sol real', () {
    const lat = 40.4168, lon = -3.7038;

    test('Madrid en el solsticio: mediodía solar al sur y a 73°', () {
      final noon = SunPosition.at(DateTime.utc(2025, 6, 21, 12, 15), lat, lon);
      expect(noon.azimuth, closeTo(180, 3));
      expect(noon.elevation, closeTo(90 - lat + 23.44, 0.5));
      expect(noon.compass, 'S');
    });

    test('Madrid: sale y se pone a las horas publicadas', () {
      final day = SunPosition.dayOf(
        DateTime(2025, 6, 21),
        lat,
        lon,
        utcOffsetMinutes: 120,
      )!;
      expect(day.rise, closeTo(6 * 60 + 44, 4));
      expect(day.set, closeTo(21 * 60 + 48, 4));
    });

    test('por la mañana está al este, por la tarde al oeste', () {
      final am = SunPosition.at(DateTime.utc(2025, 3, 20, 8), lat, lon);
      final pm = SunPosition.at(DateTime.utc(2025, 3, 20, 17), lat, lon);
      expect(am.azimuth, inInclusiveRange(90, 150));
      expect(pm.azimuth, inInclusiveRange(235, 275));
    });

    test('de noche no está arriba, y en el hemisferio sur va por el norte', () {
      expect(
        SunPosition.at(DateTime.utc(2025, 6, 21, 0), lat, lon).up,
        isFalse,
      );
      final sydney = SunPosition.at(
        DateTime.utc(2025, 6, 21, 2),
        -33.87,
        151.2,
      );
      expect(sydney.azimuth < 30 || sydney.azimuth > 330, isTrue);
    });

    test('orienta el sol según el norte de la planta', () {
      const east = SunPosition(90, 30);
      expect(east.planAzimuth(0), 90);
      expect(east.planAzimuth(90), 180);
      expect(east.planAzimuth(300), 30);
    });

    test('el norte se guarda con el ambiente', () {
      const a = PlanAmbient(northDeg: 45);
      expect(PlanAmbient.fromJson(a.toJson()).northDeg, 45);
      expect(const PlanAmbient().toJson().containsKey('northDeg'), isFalse);
    });

    testWidgets('el diálogo devuelve el sol para la planta', (tester) async {
      SunPick? pick;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => pick = await showDialog<SunPick>(
                context: context,
                builder: (_) => PlanSunDialog(
                  latitude: lat,
                  longitude: lon,
                  northDeg: 0,
                  now: DateTime(2025, 6, 21, 13),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sun-result')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sun-apply')));
      await tester.pumpAndSettle();
      expect(pick, isNotNull);
      expect(pick!.elevation, greaterThan(0));
    });
  });

  group('corriente', () {
    test('reparte de mayor a menor sin pasarse del 80 %', () {
      final els = [for (var i = 1; i <= 6; i++) lamp(i, 500.0 * (i % 3 + 1))];
      final loads = PowerPlan.loadsOf(els);
      const limit = 230 * 16 * 0.8;
      final assigned = PowerPlan.distribute(loads, limit);
      expect(assigned, hasLength(6));
      assigned.forEach((el, n) => el.props[PowerPlan.circuitKey] = n);
      final plan = PowerPlan.of(els);
      expect(plan.unassigned, isEmpty);
      expect(plan.circuits.any(plan.isOver), isFalse);
      expect(plan.totalWatts, 6000);
    });

    test('un aparato apagado no suma', () {
      final plan = PowerPlan.of([lamp(1, 1000), lamp(2, 2000, off: true)]);
      expect(plan.totalWatts, 1000);
    });

    test('avisa del aparato que no cabe y del circuito sobrecargado', () {
      final big = lamp(1, 18000);
      final small = lamp(2, 2000)..props[PowerPlan.circuitKey] = 1;
      final other = lamp(3, 1500)..props[PowerPlan.circuitKey] = 1;
      final plan = PowerPlan.of([big, small, other]);
      expect(plan.tooBig.single.element, big);
      expect(plan.isOver(plan.circuits.single), isTrue);
      expect(plan.toText(), contains('SOBRECARGADO'));
    });

    test('elige grupo con margen y equilibra las fases', () {
      final els = [
        lamp(1, 4000)..props[PowerPlan.circuitKey] = 1,
        lamp(2, 3000)..props[PowerPlan.circuitKey] = 2,
        lamp(3, 2000)..props[PowerPlan.circuitKey] = 3,
        lamp(4, 1000)..props[PowerPlan.circuitKey] = 4,
      ];
      final plan = PowerPlan.of(els);
      // 10 kW / 0,8 / 0,8 = 15,6 kVA.
      expect(plan.generatorKva, 20);
      final phases = [...plan.phases]..sort();
      expect(phases, [3000, 3000, 4000]);
    });

    testWidgets('«Repartir solo» asigna y avisa para guardar', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await AppPrefs.reloadForTest();
      final els = [lamp(1, 2000), lamp(2, 2000)];
      var saved = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: PlanPowerSheet(
              elements: els,
              title: 'Set',
              onChanged: () => saved++,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('power-distribute')));
      await tester.pump();
      expect(saved, 1);
      expect(find.textContaining('Circuito 2'), findsOneWidget);
      expect(els.map((e) => e.props[PowerPlan.circuitKey]).toSet(), {1, 2});
    });
  });

  group('IES', () {
    // Tipo C, simétrico: 1000 cd en el eje, mitad a 20°.
    const sample = '''IESNA:LM-63-2002
[TEST] prueba
[MANUFAC] Prueba
TILT=NONE
1 -1 2 5 1 1 2 0.3 0.3 0.1
1 1 150
0 10 20 40 90
0
500 450 250 50 0
''';

    test('saca pico, haz y vatios', () {
      final p = IesProfile.parse(sample);
      expect(p.peakCandela, 1000);
      expect(p.beamDeg, closeTo(40, 0.01));
      expect(p.inputWatts, 150);
    });

    test('admite TILT=INCLUDE y haz simétrico en ángulos negativos', () {
      const text = '''TILT=INCLUDE
1
2
0 90
1 1
1 1000 1 5 1 2 2 0 0 0
1 1 0
-40 -20 0 20 40
0
0 500 1000 500 0
''';
      final p = IesProfile.parse(text);
      expect(p.peakCandela, 1000);
      expect(p.beamDeg, closeTo(40, 0.01));
      expect(p.inputWatts, isNull);
    });

    test('rechaza lo que no es un IES', () {
      expect(() => IesProfile.parse('hola'), throwsA(isA<FormatException>()));
      expect(
        () => IesProfile.parse('TILT=NONE\n1 2 3'),
        throwsA(isA<FormatException>()),
      );
    });

    test('al cargarlo manda su fotometría, marcada de fabricante', () {
      final el = lamp(1, 650)
        ..props[PlanLight.curveKey] = [
          [10, 1, 1],
        ];
      PlanLight.applyIes(
        el,
        const IesProfile(peakCandela: 2000, beamDeg: 40, inputWatts: 150),
      );
      final light = PlanLight.of(el)!;
      expect(light.watts, 150);
      expect(light.source.status, PhotometryStatus.manufacturer);
      expect(light.source.beamDeg, 40);
      expect(el.props.containsKey(PlanLight.curveKey), isFalse);
    });
  });
}
