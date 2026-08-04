import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/storage_calculator/storage_calculator.dart';
import 'package:iris_dp/features/storage_calculator/storage_codec_catalog.dart';
import 'package:iris_dp/features/storage_calculator/storage_resolution_catalog.dart';

/// Golden tests calibrados contra PHFX framesToDataRate @ 24 fps.
void main() {
  const res4k = StorageResolution(
    width: 4096,
    height: 2160,
    label: '4K DCI Full',
  );
  const res1080 = StorageResolution(
    width: 1920,
    height: 1080,
    label: 'HD 1080p',
  );

  group('StorageCalculator PHFX golden', () {
    test('DPX 10-bit @ 4096x2160 24fps 1h', () {
      final result = StorageCalculator.compute(
        source: res4k,
        frameRate: 24,
        hours: 1,
      );
      final dpx = result.sections
          .firstWhere((s) => s.title.contains('DPX'))
          .rows
          .firstWhere((r) => r.label == 'DPX 10-bit');

      expect(dpx.bytesPerFrame, closeTo(33177600, 50000));
      expect(dpx.bytesPerSecond, closeTo(796262400, 500000));
      expect(dpx.bytesForProject, closeTo(2866544640000, 5e10));
    });

    test('REDCODE RAW 5:1 @ 4096x2160', () {
      final result = StorageCalculator.compute(
        source: res4k,
        frameRate: 24,
        recordingCodec: RecordingCodecFamily.redcodeRaw,
        recordingVariantId: '5:1',
        includeDpx: false,
        includeIntermediateCodecs: false,
      );
      final row = result.sections.single.rows.single;
      expect(row.bytesPerFrame, closeTo(2841640, 80000));
    });

    test('REDCODE RAW 5:1 @ 1920x1080', () {
      final result = StorageCalculator.compute(
        source: res1080,
        frameRate: 24,
        recordingCodec: RecordingCodecFamily.redcodeRaw,
        recordingVariantId: '5:1',
        includeDpx: false,
        includeIntermediateCodecs: false,
      );
      final row = result.sections.single.rows.single;
      expect(row.bytesPerFrame, closeTo(666000, 30000));
    });

    test('ARRIRAW @ 4096x2160', () {
      final result = StorageCalculator.compute(
        source: res4k,
        frameRate: 24,
        recordingCodec: RecordingCodecFamily.arriRaw,
        recordingVariantId: 'ARRIRAW',
        includeDpx: false,
        includeIntermediateCodecs: false,
      );
      final row = result.sections.single.rows.single;
      expect(row.bytesPerFrame, closeTo(14062797, 200000));
    });

    test('ProRes 422 HQ escala lineal a 4K', () {
      final result = StorageCalculator.compute(
        source: res4k,
        frameRate: 24,
        includeDpx: false,
        recordingCodec: RecordingCodecFamily.none,
      );
      final prores = result.sections
          .firstWhere((s) => s.title.contains('intermedios'))
          .rows
          .firstWhere((r) => r.label.contains('422 HQ'));

      expect(prores.bytesPerFrame, closeTo(4096000, 80000));
    });

    test('effectiveDeliveryResolution downscale sin upscale', () {
      const source = StorageResolution(width: 4096, height: 2160, label: '4K');
      const delivery = DeliveryFormat(
        id: 'HD1080p',
        label: 'HD 1080p',
        maxWidth: 1920,
        maxHeight: 1080,
      );
      final effective = effectiveDeliveryResolution(source, delivery);
      expect(effective.width, 1920);
      expect(effective.height, closeTo(1013, 1));

      const small = StorageResolution(width: 1280, height: 720, label: '720');
      final noUpscale = effectiveDeliveryResolution(small, delivery);
      expect(noUpscale.width, 1280);
      expect(noUpscale.height, 720);
    });
  });
}
