import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/widgets/scene_meta_display.dart';

void main() {
  testWidgets('SceneMetaDisplay muestra icono de día/noche', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SceneMetaDisplay(
            intExt: 'EXT',
            dayNight: 'NOCHE',
            location: 'CALLE',
          ),
        ),
      ),
    );

    expect(find.text('EXT. CALLE - NOCHE'), findsOneWidget);
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
  });

  test('dayNightPeriodFrom normaliza valores', () {
    expect(dayNightPeriodFrom('NOCHE'), DayNightPeriod.noche);
    expect(dayNightPeriodFrom('DÍA'), DayNightPeriod.dia);
    expect(dayNightPeriodFrom('AMANECER'), DayNightPeriod.amanecer);
    expect(dayNightPeriodFrom('CONTINUO'), DayNightPeriod.continuo);
  });
}
