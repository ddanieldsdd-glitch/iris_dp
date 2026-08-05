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
        remoteLatest: sampleRelease,
        localVersion: '1.0.1',
        localBuild: 1,
        skippedThrottle: true,
      );

      final state = applyAppUpdateCheckResult(result);

      expect(state.checkCompleted, isTrue);
      expect(state.checking, isFalse);
      expect(state.availableRelease, sampleRelease);
      expect(state.localVersionLabel, '1.0.1 (1)');
      expect(state.error, isNull);
    });

    test('marca al día cuando no hay release remota', () {
      const result = AppUpdateCheckResult(
        localVersion: '1.0.4',
        localBuild: 9,
      );

      final state = applyAppUpdateCheckResult(result);

      expect(state.checkCompleted, isTrue);
      expect(state.hasUpdate, isFalse);
      expect(state.localVersionLabel, '1.0.4 (9)');
      expect(state.error, isNull);
    });

    test('detecta app más nueva que lo publicado', () {
      const result = AppUpdateCheckResult(
        remoteLatest: AppRelease(
          platform: 'macos',
          version: '1.0.4',
          buildNumber: 9,
          downloadUrl: 'https://example.com',
        ),
        localVersion: '1.0.5',
        localBuild: 10,
      );

      expect(result.installedIsNewerThanPublished, isTrue);
      final state = applyAppUpdateCheckResult(result);
      expect(state.installedIsNewerThanPublished, isTrue);
    });

    test('propaga error de comprobación', () {
      const result = AppUpdateCheckResult(error: 'Sin conexión');

      final state = applyAppUpdateCheckResult(result);

      expect(state.checkCompleted, isTrue);
      expect(state.error, 'Sin conexión');
      expect(state.availableRelease, isNull);
    });
  });

  group('isRemoteNewer', () {
    test('prioriza build_number', () {
      expect(
        isRemoteNewer(
          localBuild: 9,
          localVersion: '1.0.4',
          remoteBuild: 10,
          remoteVersion: '1.0.5',
        ),
        isTrue,
      );
    });
  });
}
