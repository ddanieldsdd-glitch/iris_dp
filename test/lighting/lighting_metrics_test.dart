import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/lighting/lighting_metrics_widget.dart';
import 'package:iris_dp/shared/visual_bible/lighting_metrics.dart';

import '../support/snapshot.dart';

void main() {
  test('el ratio se da también en stops', () {
    expect(kContrastRatios.first.stopsLabel, 'sin diferencia');
    expect(const ContrastRatioOption(2, '').stopsLabel, '1 stop');
    expect(const ContrastRatioOption(8, '').stopsLabel, '3 stops');
    expect(const ContrastRatioOption(1.5, '').label, '1,5:1');
    expect(const ContrastRatioOption(3, '').stopsLabel, '1,6 stops');
    // Un ratio suelto se asimila a la opción más cercana.
    expect(const LightingMetrics(ratio: 7.5).ratioOption!.ratio, 8);
  });

  test('el color de una temperatura: cálido abajo, frío arriba', () {
    int r(int rgb) => rgb >> 16;
    int b(int rgb) => rgb & 0xFF;
    final warm = LightingMetrics.colorOf(2700);
    final cold = LightingMetrics.colorOf(9000);
    expect(r(warm), greaterThan(b(warm)));
    expect(b(cold), greaterThan(r(cold)));
    // El tinte verde sube el verde frente al neutro.
    int g(int rgb) => (rgb >> 8) & 0xFF;
    expect(
      g(LightingMetrics.colorOf(4000, tint: 30)),
      greaterThan(g(LightingMetrics.colorOf(4000))),
    );
  });

  test('cómo se ve respecto al balance de la cámara', () {
    expect(
      const LightingMetrics(kelvin: 3200).lookAgainst(5600),
      contains('muy cálida'),
    );
    expect(
      const LightingMetrics(kelvin: 6500).lookAgainst(5600),
      contains('fría'),
    );
    expect(
      const LightingMetrics(kelvin: 5600).lookAgainst(5600),
      startsWith('Neutra'),
    );
    expect(const LightingMetrics(kelvin: 5600).lookAgainst(null), isNull);
  });

  test('receta de gelatinas con las del motor de luz', () {
    final gels = correctionGels();
    expect(gels.map((g) => g.name), containsAll(['CTO', '½ CTO', 'CTB']));

    // HMI a tungsteno: un CTO entero.
    final warm = const LightingMetrics(
      kelvin: 3200,
      sourceKelvin: 5600,
    ).recipe(gels)!;
    expect(warm.miredShift, closeTo(134, 1));
    expect(warm.gels.map((g) => g.name).join('+'), contains('CTO'));
    expect(warm.resultKelvin, closeTo(3200, 250));
    expect(warm.stopsLost, greaterThan(0.5));

    // Tungsteno a luz día: CTB.
    final cold = const LightingMetrics(
      kelvin: 5600,
      sourceKelvin: 3200,
    ).recipe(gels)!;
    expect(cold.gels.every((g) => g.name.contains('CTB')), isTrue);
    expect(cold.resultKelvin, closeTo(5600, 500));

    // La fuente ya da ese color: nada que poner.
    final same = const LightingMetrics(
      kelvin: 5600,
      sourceKelvin: 5600,
    ).recipe(gels)!;
    expect(same.needsNothing, isTrue);

    // Tinte verde: plusgreen, aunque la temperatura coincida.
    final green = const LightingMetrics(
      kelvin: 5600,
      sourceKelvin: 5600,
      tint: 15,
    ).recipe(gels)!;
    expect(green.tintGel, '½ Plusgreen');

    // Sin fuente no hay receta.
    expect(const LightingMetrics(kelvin: 5600).recipe(gels), isNull);
  });

  test('lo guardado va y vuelve; de lo antiguo solo lo que se tocó', () {
    const m = LightingMetrics(kelvin: 4300, tint: -8, ratio: 4, sourceKelvin: 3200);
    final back = LightingMetrics.fromJson(m.encode());
    expect(back.kelvin, 4300);
    expect(back.tint, -8);
    expect(back.ratio, 4);
    expect(back.sourceKelvin, 3200);

    // La pantalla antigua enseñaba 5600 K y 8:1 sin que nadie los pusiera.
    expect(LightingMetrics.fromLegacy(const {}).isEmpty, isTrue);
    final legacy = LightingMetrics.fromLegacy(const {
      'colorTemp': 4300,
      'tintValue': 0.25,
      'contrastNum': 16,
    });
    expect(legacy.kelvin, 4300);
    expect(legacy.tint, 15);
    expect(legacy.ratio, 16);
  });

  testWidgets('el widget nace vacío, enseña todos los ratios y se elige '
      'tocando', (tester) async {
    await loadSnapshotFonts();
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var value = const LightingMetrics();
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return LightingMetricsWidget(
                  value: value,
                  whiteBalance: 5600,
                  reference: const LightingMetrics(kelvin: 5600, ratio: 2),
                  onChanged: (next) => rebuild(() => value = next),
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // Vacío: ni valor ni receta.
    expect(find.text('EL COLOR DE ESTA LUZ'), findsNothing);
    for (final option in kContrastRatios) {
      expect(find.text(option.label), findsOneWidget);
    }

    await tester.tap(find.text('Tungsteno'));
    await tester.pump();
    expect(value.kelvin, 3200);
    expect(find.text('EL COLOR DE ESTA LUZ'), findsOneWidget);
    expect(find.textContaining('muy cálida'), findsOneWidget);

    await tester.tap(find.text('8:1'));
    await tester.pump();
    expect(value.ratio, 8);
    expect(find.textContaining('3 stops'), findsOneWidget);

    await tester.tap(find.text('HMI / luz día'));
    await tester.pump();
    expect(value.sourceKelvin, 5600);
    expect(find.textContaining('CTO'), findsWidgets);
    expect(find.textContaining('mired'), findsOneWidget);

    // Tocar la barra de tinte hacia la derecha: verde.
    final tint = find.bySemanticsLabel('Tinte');
    await tester.tapAt(tester.getTopRight(tint) + const Offset(-20, 12));
    await tester.pump();
    expect(value.tint, greaterThan(0));
    expect(tester.takeException(), isNull);

    await saveSnapshot(tester, 'luz_metricas');
  });
}
