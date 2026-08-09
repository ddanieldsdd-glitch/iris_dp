import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/shared/visual_bible/camera_pilot_resolve.dart';

void main() {
  final legacyData = VisualBibleData(
    id: 1,
    projectId: 1,
    captureResolution: '6K legacy',
  );

  group('CameraPilotResolve', () {
    test('blob gana sobre columna cuando ambos existen y difieren', () {
      const blob = {'captureResolution': 'FASE3-CAM-RES-4K'};

      expect(
        CameraPilotResolve.captureResolution(blob, legacyData),
        'FASE3-CAM-RES-4K',
      );
    });

    test('fallback legacy cuando blob no tiene clave canónica', () {
      expect(
        CameraPilotResolve.captureResolution(const {}, legacyData),
        '6K legacy',
      );
    });

    test('clave presente con valor vacío no cae a legacy', () {
      const blob = {'captureResolution': ''};

      expect(CameraPilotResolve.captureResolution(blob, legacyData), '');
    });

    test('customRowsForPdf excluye clave piloto para evitar duplicados', () {
      const blob = {
        'captureResolution': '4.6K',
        'isoNote': '800 nativo',
      };

      final rows = CameraPilotResolve.customRowsForPdf(blob);
      final labels = rows.map((row) => row.$1).join('\n');

      expect(labels, isNot(contains('Resolución de captura')));
      expect(labels, contains('Nota ISO'));
    });
  });
}
