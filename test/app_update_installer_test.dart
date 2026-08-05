import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/update/app_update_installer.dart';

void main() {
  group('AppUpdateDownloadProgress', () {
    test('fraction calcula progreso cuando hay total', () {
      const p = AppUpdateDownloadProgress(receivedBytes: 50, totalBytes: 100);
      expect(p.fraction, 0.5);
    });

    test('fraction es null sin total', () {
      const p = AppUpdateDownloadProgress(receivedBytes: 50);
      expect(p.fraction, isNull);
    });
  });
}
