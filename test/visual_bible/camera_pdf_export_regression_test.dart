import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_pdf_service.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/camera_pilot_resolve.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

const _markerResolution = 'FASE3-CAM-RES-4K';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PDF clásico Cámara incluye slots de columna y resolución canónica del blob',
    () async {
      final cameraContent = BibleSectionFieldsConfig.encode(
        BibleSectionFieldsConfig.defaultsFor(BibleSectionId.camera),
        values: {
          'cameraData': jsonEncode({
            'captureResolution': _markerResolution,
          }),
        },
      );

      final data = VisualBibleData(
        id: 1,
        projectId: 1,
        captureResolution: '1080p stale',
        cameraNarrativeIntent: 'Textura orgánica large format',
        nativeIso: 800,
        codec: 'ProRes 4444',
        frameRateNotes: '24 fps',
      );

      final bytes = await VisualBiblePdfService.buildBytes(
        mode: VisualBibleExportMode.full,
        projectName: 'Camera PDF regression',
        director: 'Director',
        data: data,
        colorBlocks: const [],
        exposureBlocks: const [],
        lightingSetups: const [],
        cameraTests: const [],
        moodboard: const [],
        includedSections: {BibleSectionId.camera},
        sectionContentJsonById: {
          BibleSectionId.camera: cameraContent,
        },
        primaryCameraLabel: 'ARRI Alexa 35',
      );

      expect(bytes, isNotEmpty);

      final document = PdfDocument(inputBytes: bytes);
      addTearDown(() => document.dispose());

      final text = PdfTextExtractor(document).extractText();

      expect(text, contains('CÁMARA'));
      expect(text, contains('SENSOR'));
      expect(text, contains('Alexa'));
      expect(text, contains('Textura'));
      expect(text, contains('orgánica'));
      expect(text, contains('800'));
      expect(text, contains(_markerResolution));
      expect(text, contains('ProRes'));
      expect(text, contains('4444'));
      expect(text, contains('24'));
      expect(text, contains('fps'));
      expect(text, isNot(contains('1080p stale')));

      final blob = CameraPilotResolve.parseBlob(cameraContent);
      final customRows = CameraPilotResolve.customRowsForPdf(blob);
      final customText = customRows.map((row) => row.$2).join('\n');
      expect(customText, isNot(contains(_markerResolution)));
    },
  );
}
