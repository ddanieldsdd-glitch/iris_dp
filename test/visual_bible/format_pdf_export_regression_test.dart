import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_pdf_service.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/format_pilot_resolve.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

const _markerRatio = 'FASE3-FMT-RATIO-239';
const _markerResolution = 'FASE3-FMT-RES-4K';
const _markerNarrative = 'FASE3-FMT-NARR-PILOT';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PDF clásico Format usa blob canónico y no repite valor legacy stale',
    () async {
      final formatContent = BibleSectionFieldsConfig.encode(
        BibleSectionFieldsConfig.defaultsFor(BibleSectionId.format),
        values: {
          'formatData': jsonEncode({
            'activeRatio': _markerRatio,
            'resolution': _markerResolution,
            'intentNarrative': _markerNarrative,
          }),
        },
      );

      final data = VisualBibleData(
        id: 1,
        projectId: 1,
        aspectRatio: '1.85:1 stale',
        captureResolution: '1080p stale',
        formatNarrativeIntent: 'Narrativa stale',
      );

      final bytes = await VisualBiblePdfService.buildBytes(
        mode: VisualBibleExportMode.full,
        projectName: 'Format PDF regression',
        director: 'Director',
        data: data,
        colorBlocks: const [],
        exposureBlocks: const [],
        lightingSetups: const [],
        cameraTests: const [],
        moodboard: const [],
        includedSections: {BibleSectionId.format},
        sectionContentJsonById: {
          BibleSectionId.format: formatContent,
        },
      );

      expect(bytes, isNotEmpty);

      final document = PdfDocument(inputBytes: bytes);
      addTearDown(() => document.dispose());

      final text = PdfTextExtractor(document).extractText();

      expect(text, contains(_markerRatio));
      expect(text, contains(_markerResolution));
      expect(text, contains(_markerNarrative));
      expect(text, isNot(contains('1.85:1 stale')));
      expect(text, isNot(contains('1080p stale')));
      expect(text, isNot(contains('Narrativa stale')));

      final blob = FormatPilotResolve.parseBlob(formatContent);
      final customRows = FormatPilotResolve.customRowsForPdf(blob);
      final customText = customRows.map((row) => row.$2).join('\n');
      expect(customText, isNot(contains(_markerRatio)));
      expect(customText, isNot(contains(_markerResolution)));
      expect(customText, isNot(contains(_markerNarrative)));
    },
  );
}
