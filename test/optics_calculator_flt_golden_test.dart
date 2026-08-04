import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/optics_lab/optics_calculator.dart';

/// Casos golden curados manualmente (referencia ARRI FLT / datasheets).
void main() {
  group('OpticsCalculator FLT golden', () {
    test('Alexa 35 Open Gate + Cooke S4 32mm @ 2.39:1', () {
      const mode = SensorModeSpec(
        name: '4.6K Open Gate',
        widthMm: 27.99,
        heightMm: 19.22,
        maxWidthPx: 4608,
        maxHeightPx: 3164,
      );
      final result = OpticsCalculator.computeFromMode(
        mode: mode,
        focalMm: 32,
        imageCircleMm: 31.2,
        formatCoverage: 'S35',
        aspectRatio: 2.39,
        tStop: 2.8,
      );
      expect(result.hFovDeg, closeTo(47.2, 1.0));
      expect(result.coversSensor, isTrue);
      expect(result.activeWidthPx, isNotNull);
      expect(result.activeHeightPx, isNotNull);
    });

    test('Anamórfico Atlas Orion 50mm 2x desqueezed HFOV', () {
      const mode = SensorModeSpec(
        name: 'Open Gate',
        widthMm: 27.99,
        heightMm: 19.22,
      );
      final result = OpticsCalculator.computeFromMode(
        mode: mode,
        focalMm: 50,
        imageCircleMm: 31.2,
        formatCoverage: 'S35',
        aspectRatio: 2.39,
        isAnamorphic: true,
        squeezeRatio: 2.0,
      );
      expect(result.focalEffectiveMm, closeTo(25.0, 0.1));
      expect(result.hFovDeg, greaterThan(50));
    });

    test('Mini LF + Zeiss Supreme 25mm portholing S35 circle', () {
      const mode = SensorModeSpec(
        name: 'Open Gate LF',
        widthMm: 36.70,
        heightMm: 25.54,
      );
      final result = OpticsCalculator.computeFromMode(
        mode: mode,
        focalMm: 25,
        imageCircleMm: 31.2,
        formatCoverage: 'S35',
        aspectRatio: 2.39,
      );
      expect(result.portholingWarning || !result.coversSensor, isTrue);
    });

    test('Mount mismatch PL lens on E mount warns', () {
      final result = OpticsCalculator.compute(
        sensorWidthMm: 35.6,
        sensorHeightMm: 23.8,
        focalMm: 35,
        imageCircleMm: 43.3,
        formatCoverage: 'FF',
        cameraMount: 'E',
        lensMount: 'PL',
      );
      expect(result.mountWarning, isNotNull);
    });

    test('Resolution scales with AR crop', () {
      const mode = SensorModeSpec(
        name: '4.6K Open Gate',
        widthMm: 27.99,
        heightMm: 19.22,
        maxWidthPx: 4608,
        maxHeightPx: 3164,
      );
      final full = OpticsCalculator.computeFromMode(
        mode: mode,
        focalMm: 50,
        imageCircleMm: 43.3,
        formatCoverage: 'FF',
        aspectRatio: 16 / 9,
      );
      final wide = OpticsCalculator.computeFromMode(
        mode: mode,
        focalMm: 50,
        imageCircleMm: 43.3,
        formatCoverage: 'FF',
        aspectRatio: 2.39,
      );
      expect(full.activeHeightPx!, lessThan(full.activeWidthPx!));
      expect(wide.activeHeightPx!, lessThan(full.activeHeightPx!));
    });
  });
}
