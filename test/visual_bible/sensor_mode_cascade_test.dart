import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/visual_bible/format_sensor_mode_resolve.dart';
import 'package:iris_dp/shared/visual_bible/sensor_mode_cascade.dart';

void main() {
  group('SensorModeCascade.reconcileFormatBlob', () {
    const modesJson = '''
[
  {"name":"4.6K 3:2 Open Gate","widthMm":27.99,"heightMm":19.22,"maxWidthPx":4608,"maxHeightPx":3164},
  {"name":"4K 16:9","widthMm":26.0,"heightMm":14.6,"maxWidthPx":4096,"maxHeightPx":2304}
]
''';

    test('conserva el modo si sigue existiendo en la cámara', () {
      final patch = SensorModeCascade.reconcileFormatBlob(
        formatBlob: {
          FormatSensorModeResolve.nameKey: '4K 16:9',
          FormatSensorModeResolve.detailKey: '4096×2304',
        },
        sensorModesJson: modesJson,
      );
      expect(patch, isNull);
    });

    test('re-resuelve al primer modo si el nombre no existe', () {
      final patch = SensorModeCascade.reconcileFormatBlob(
        formatBlob: {
          FormatSensorModeResolve.nameKey: 'Modo Sony inexistente',
          FormatSensorModeResolve.detailKey: 'viejo',
        },
        sensorModesJson: modesJson,
      );
      expect(patch, isNotNull);
      expect(patch![FormatSensorModeResolve.nameKey], '4.6K 3:2 Open Gate');
      expect(patch[FormatSensorModeResolve.detailKey], contains('4608'));
    });

    test('sin modos de catálogo no inventa patch', () {
      final patch = SensorModeCascade.reconcileFormatBlob(
        formatBlob: {FormatSensorModeResolve.nameKey: 'cualquier'},
        sensorModesJson: null,
      );
      expect(patch, isNull);
    });
  });
}
