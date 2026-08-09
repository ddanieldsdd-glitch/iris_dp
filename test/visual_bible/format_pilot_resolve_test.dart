import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/shared/visual_bible/format_pilot_resolve.dart';

void main() {
  final legacyData = VisualBibleData(
    id: 1,
    projectId: 1,
    aspectRatio: '1.85:1',
    captureResolution: '1080p legacy',
    formatNarrativeIntent: 'Narrativa legacy',
    aspectRatioJustification: 'Justificación legacy',
  );

  group('FormatPilotResolve', () {
    test('blob gana sobre columna cuando ambos existen y difieren', () {
      const blob = {
        'activeRatio': 'FASE3-FMT-RATIO-239',
        'resolution': 'FASE3-FMT-RES-4K',
        'intentNarrative': 'FASE3-FMT-NARR-PILOT',
      };

      expect(
        FormatPilotResolve.activeRatio(blob, legacyData),
        'FASE3-FMT-RATIO-239',
      );
      expect(
        FormatPilotResolve.resolution(blob, legacyData),
        'FASE3-FMT-RES-4K',
      );
      expect(
        FormatPilotResolve.intentNarrative(blob, legacyData),
        'FASE3-FMT-NARR-PILOT',
      );
    });

    test('fallback legacy cuando blob no tiene claves canónicas', () {
      expect(
        FormatPilotResolve.activeRatio(const {}, legacyData),
        '1.85:1',
      );
      expect(
        FormatPilotResolve.resolution(const {}, legacyData),
        '1080p legacy',
      );
      expect(
        FormatPilotResolve.intentNarrative(const {}, legacyData),
        'Narrativa legacy',
      );
    });

    test('clave presente con valor vacío no cae a legacy', () {
      const blob = {'activeRatio': '', 'intentNarrative': ''};

      expect(FormatPilotResolve.activeRatio(blob, legacyData), '');
      expect(FormatPilotResolve.intentNarrative(blob, legacyData), '');
    });

    test('intentNarrative usa aspectRatioJustification como último fallback', () {
      final data = VisualBibleData(
        id: 1,
        projectId: 1,
        aspectRatioJustification: 'Solo justificación',
      );

      expect(
        FormatPilotResolve.intentNarrative(const {}, data),
        'Solo justificación',
      );
    });

    test('legacyJustificationForPdf oculta slot si hay narrativa canónica', () {
      const blob = {'intentNarrative': 'Canónica'};

      expect(
        FormatPilotResolve.legacyJustificationForPdf(blob, legacyData),
        isNull,
      );
    });

    test('customRowsForPdf excluye claves piloto para evitar duplicados', () {
      const blob = {
        'activeRatio': '2.39:1',
        'resolution': '4K',
        'intentNarrative': 'Intent',
        'overlayCam': 'ARRI',
      };

      final rows = FormatPilotResolve.customRowsForPdf(blob);
      final labels = rows.map((row) => row.$1).join('\n');

      expect(labels, isNot(contains('Aspect ratio activo')));
      expect(labels, isNot(contains('Resolución')));
      expect(labels, contains('Overlay cámara'));
    });
  });
}
