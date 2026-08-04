import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/optics_lab/frame_line_geometry.dart';
import 'package:iris_dp/features/optics_lab/frame_line_models.dart';
import 'package:iris_dp/features/optics_lab/optics_calculator.dart';
import 'package:iris_dp/features/optics_lab/sensor_mode_utils.dart';

void main() {
  group('FrameLineGeometry', () {
    const openGate = SensorModeSpec(
      name: '4.6K Open Gate',
      widthMm: 27.99,
      heightMm: 19.22,
      maxWidthPx: 4608,
      maxHeightPx: 3164,
    );
    const mode169 = SensorModeSpec(
      name: '4.6K 16:9',
      widthMm: 27.99,
      heightMm: 15.74,
      maxWidthPx: 4608,
      maxHeightPx: 2592,
    );

    SensorModeContext ctx(SensorModeSpec mode) => SensorModeContext(
          fullWidthMm: openGate.widthMm,
          fullHeightMm: openGate.heightMm,
          openGateWidthPx: openGate.maxWidthPx,
          openGateHeightPx: openGate.maxHeightPx,
          mode: mode,
        );

    test('fovImageScale uses tan(HFOV/2) ratio', () {
      final wide = FrameLineGeometry.fovImageScale(
        hFovDeg: 60,
        referenceHfovDeg: 30,
      );
      final tele = FrameLineGeometry.fovImageScale(
        hFovDeg: 15,
        referenceHfovDeg: 30,
      );
      expect(wide, lessThan(1));
      expect(tele, greaterThan(1));
    });

    test('16:9 mode shows smaller active rect on full chip', () {
      final optics = OpticsCalculator.computeFromMode(
        mode: mode169,
        focalMm: 32,
        imageCircleMm: 31.2,
        formatCoverage: 'S35',
        aspectRatio: 2.39,
        fullSensorWidthMm: openGate.widthMm,
        fullSensorHeightMm: openGate.heightMm,
        recordingWidthPx: 4608,
        recordingHeightPx: 2592,
      );
      final layout = FrameLineGeometry.compute(
        context: ctx(mode169),
        optics: optics,
        frameLines: const [],
      );

      expect(layout.modeActiveRect.height, lessThan(layout.fullChipRect.height));
      expect(layout.modeActiveRect.width, layout.fullChipRect.width);
    });

    test('active gate rect matches optics active area', () {
      final optics = OpticsCalculator.computeFromMode(
        mode: openGate,
        focalMm: 32,
        imageCircleMm: 31.2,
        formatCoverage: 'S35',
        aspectRatio: 2.39,
      );
      final layout = FrameLineGeometry.compute(
        context: ctx(openGate),
        optics: optics,
        frameLines: FrameLineConfig.defaults(),
      );

      expect(layout.activeGateRect.width, closeTo(
        layout.modeActiveRect.width * (optics.activeWidthMm / openGate.widthMm),
        0.02,
      ));
    });

    test('image circle centered on full chip', () {
      final optics = OpticsCalculator.computeFromMode(
        mode: openGate,
        focalMm: 50,
        imageCircleMm: 31.2,
        formatCoverage: 'S35',
      );
      final layout = FrameLineGeometry.compute(
        context: ctx(openGate),
        optics: optics,
        frameLines: const [],
      );
      expect(layout.imageCircleRect.center.dx, closeTo(layout.fullChipRect.center.dx, 0.001));
      expect(layout.imageCircleRect.center.dy, closeTo(layout.fullChipRect.center.dy, 0.001));
    });
  });

  group('SensorModeContext', () {
    test('crop label for 16:9 mode', () {
      const openGate = SensorModeSpec(
        name: 'Open Gate',
        widthMm: 28.25,
        heightMm: 18.17,
        maxWidthPx: 3424,
        maxHeightPx: 2202,
      );
      const mode169 = SensorModeSpec(
        name: '16:9',
        widthMm: 28.25,
        heightMm: 15.89,
        maxWidthPx: 3424,
        maxHeightPx: 1920,
      );
      final ctx = SensorModeContext(
        fullWidthMm: openGate.widthMm,
        fullHeightMm: openGate.heightMm,
        openGateWidthPx: 3424,
        openGateHeightPx: 2202,
        mode: mode169,
      );
      expect(ctx.cropWidthPercent, closeTo(100, 0.1));
      expect(ctx.cropHeightPercent, lessThan(100));
      expect(ctx.isFullOpenGate, isFalse);
    });
  });

  group('OpticsCalculator image circle fallback', () {
    test('format coverage provides standard circle diameters', () {
      expect(OpticsCalculator.imageCircleForFormat('FF'), 43.3);
      expect(OpticsCalculator.imageCircleForFormat('S35'), 31.2);
      expect(OpticsCalculator.imageCircleForFormat('LF'), 54.0);
    });
  });
}
