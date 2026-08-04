import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/update/app_release.dart';
import 'package:iris_dp/core/update/app_update_checker.dart';
import 'package:iris_dp/core/update/app_update_providers.dart';

void main() {
  group('applyAppUpdateCheckResult', () {
    const sampleRelease = AppRelease(
      platform: 'macos',
      version: '1.0.2',
      buildNumber: 2,
      downloadUrl: 'https://github.com/example/releases/download/v1.0.2/IRIS-DP.dmg',
    );

    test('conserva availableRelease cuando el throttle devolvió caché', () {
      const result = AppUpdateCheckResult(
        availableRelease: sampleRelease,
        skippedThrottle: true,
      );

      final state = applyAppUpdateCheckResult(result);

      expect(state.checkCompleted, isTrue);
      expect(state.checking, isFalse);
      expect(state.availableRelease, sampleRelease);
      expect(state.error, isNull);
    });

    test('marca al día cuando no hay release remota', () {
      const result = AppUpdateCheckResult();

      final state = applyAppUpdateCheckResult(result);

      expect(state.checkCompleted, isTrue);
      expect(state.hasUpdate, isFalse);
      expect(state.error, isNull);
    });

    test('propaga error de comprobación', () {
      const result = AppUpdateCheckResult(error: 'Sin conexión');

      final state = applyAppUpdateCheckResult(result);

      expect(state.checkCompleted, isTrue);
      expect(state.error, 'Sin conexión');
      expect(state.availableRelease, isNull);
    });
  });
}
