import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/visual_bible/format_sensor_mode_resolve.dart';

void main() {
  group('FormatSensorModeResolve', () {
    test('displayTitle prefiere sensorModeName sobre ratio legacy', () {
      expect(
        FormatSensorModeResolve.displayTitle({
          'sensorModeName': '4.6K 3:2 Open Gate',
          'sensorMode': '4:3',
        }),
        '4.6K 3:2 Open Gate',
      );
      expect(
        FormatSensorModeResolve.displayTitle({'sensorMode': '16:9'}),
        '16:9',
      );
    });

    test('blobUpdateForMode no toca resolution ni captureResolution', () {
      final update = FormatSensorModeResolve.blobUpdateForMode(
        name: '4.6K 3:2 Open Gate',
        widthPx: 4608,
        heightPx: 3164,
        widthMm: 28,
        heightMm: 19.2,
      );
      expect(update['sensorModeName'], '4.6K 3:2 Open Gate');
      expect(update.containsKey('resolution'), isFalse);
      expect(update.containsKey('captureResolution'), isFalse);
      expect(update['sensorMode'], contains(':'));
      expect(update['sensorDetail'], contains('4608'));
    });

    test('ratioTokenForCalc usa mm cuando no hay aspectRatio', () {
      final token = FormatSensorModeResolve.ratioTokenForCalc(
        const {},
        widthMm: 28,
        heightMm: 19.2,
      );
      expect(token, startsWith('28'));
      expect(token, contains(':'));
    });
  });
}
