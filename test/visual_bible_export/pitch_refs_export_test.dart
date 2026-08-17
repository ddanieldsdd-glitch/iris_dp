import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_pdf_service.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

const pitchMarkerClassified = 'PITCH-LIGHT';
const pitchMarkerUnclassified = 'PITCH-UNCL';

final _tinyPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pitch REFERENCIAS VISUALES', () {
    test('orderedPitchRefsEntries respeta orden canónico y sin clasificar al final',
        () {
      final lightingImg = MoodboardImageModel(
        id: 1,
        projectId: 1,
        imagePath: '/a.jpg',
        source: MoodboardSource.manual,
        category: MoodboardCategory.lighting,
      );
      final locationImg = MoodboardImageModel(
        id: 2,
        projectId: 1,
        imagePath: '/b.jpg',
        source: MoodboardSource.manual,
        category: MoodboardCategory.location,
      );
      final unclassifiedImg = MoodboardImageModel(
        id: 3,
        projectId: 1,
        imagePath: '/c.jpg',
        source: MoodboardSource.manual,
      );
      final refs = {
        BibleSectionId.location: [(img: locationImg, image: null)],
        BibleSectionId.lighting: [(img: lightingImg, image: null)],
        VisualBiblePdfService.pitchRefsUnclassifiedKey: [
          (img: unclassifiedImg, image: null),
        ],
      };

      final ordered = VisualBiblePdfService.orderedPitchRefsEntries(refs);
      expect(ordered.map((e) => e.key), [
        BibleSectionId.lighting,
        BibleSectionId.location,
        VisualBiblePdfService.pitchRefsUnclassifiedKey,
      ]);
    });

    test('pitch export incluye stills sin clasificar en el PDF', () async {
      final imageDir = Directory.systemTemp.createTempSync('iris_pitch_refs');
      final imagePath = '${imageDir.path}/still.png';
      await File(imagePath).writeAsBytes(_tinyPng);

      final moodboard = [
        MoodboardImageModel(
          id: 1,
          projectId: 1,
          imagePath: imagePath,
          source: MoodboardSource.manual,
          category: MoodboardCategory.lighting,
          caption: pitchMarkerClassified,
        ),
        MoodboardImageModel(
          id: 2,
          projectId: 1,
          imagePath: imagePath,
          source: MoodboardSource.manual,
          caption: pitchMarkerUnclassified,
        ),
      ];

      final bytes = await VisualBiblePdfService.buildBytes(
        mode: VisualBibleExportMode.pitch,
        projectName: 'Pitch refs test',
        director: 'Director',
        data: VisualBibleData(id: 1, projectId: 1),
        colorBlocks: const [],
        exposureBlocks: const [],
        lightingSetups: const [],
        cameraTests: const [],
        moodboard: moodboard,
        includedSections: {
          BibleSectionId.lighting,
          BibleSectionId.moodboard,
        },
      );

      final pdfText = await _extractPdfText(bytes);
      final normalized = pdfText.replaceAll(RegExp(r'\s+'), '');
      expect(bytes.sublist(0, 4), '%PDF'.codeUnits);
      expect(pdfText, contains('REFERENCIAS'));
      expect(pdfText, contains('VISUALES'));
      expect(pdfText, contains(pitchMarkerUnclassified));
      expect(normalized, contains('Sinclasificar'));
      expect(pdfText, contains(pitchMarkerClassified));
    });

    test(
      'includeAllMoodboardImages añade sección filtrada a Sin clasificar',
      () async {
        final imageDir =
            Directory.systemTemp.createTempSync('iris_pitch_all_refs');
        final imagePath = '${imageDir.path}/still.png';
        await File(imagePath).writeAsBytes(_tinyPng);

        final lightingOnly = MoodboardImageModel(
          id: 1,
          projectId: 1,
          imagePath: imagePath,
          source: MoodboardSource.manual,
          category: MoodboardCategory.lighting,
          caption: 'PITCH-LIGHT-ONLY',
        );

        final sections = {
          BibleSectionId.colorImage,
          BibleSectionId.moodboard,
        };

        final strictBytes = await VisualBiblePdfService.buildBytes(
          mode: VisualBibleExportMode.pitch,
          projectName: 'Pitch strict',
          director: 'Director',
          data: VisualBibleData(id: 1, projectId: 1),
          colorBlocks: const [],
          exposureBlocks: const [],
          lightingSetups: const [],
          cameraTests: const [],
          moodboard: [lightingOnly],
          includedSections: sections,
          includeAllMoodboardImages: false,
        );
        final strictText = await _extractPdfText(strictBytes);
        expect(strictText, isNot(contains('PITCH-LIGHT-ONLY')));

        final allBytes = await VisualBiblePdfService.buildBytes(
          mode: VisualBibleExportMode.pitch,
          projectName: 'Pitch all refs',
          director: 'Director',
          data: VisualBibleData(id: 1, projectId: 1),
          colorBlocks: const [],
          exposureBlocks: const [],
          lightingSetups: const [],
          cameraTests: const [],
          moodboard: [lightingOnly],
          includedSections: sections,
          includeAllMoodboardImages: true,
        );
        final allText = await _extractPdfText(allBytes);
        final normalized = allText.replaceAll(RegExp(r'\s+'), '');
        expect(allText, contains('PITCH-LIGHT-ONLY'));
        expect(normalized, contains('Sinclasificar'));
      },
    );

    test('pitchRefsSectionLabel distingue sin clasificar', () {
      expect(
        VisualBiblePdfService.pitchRefsSectionLabel(
          VisualBiblePdfService.pitchRefsUnclassifiedKey,
        ),
        'Sin clasificar',
      );
      expect(
        VisualBiblePdfService.pitchRefsSectionLabel(BibleSectionId.lighting),
        'Iluminación',
      );
    });

    test('orderedPitchRefsLocationGroups agrupa por set y nombre', () {
      final planA = MoodboardImageModel(
        id: 1,
        projectId: 1,
        imagePath: '/a.jpg',
        source: MoodboardSource.manual,
        category: MoodboardCategory.location,
        linkedLocationBasePlanId: 10,
        linkedLocationName: 'Casa roja',
        caption: 'LOC-PLAN-A',
      );
      final planB = MoodboardImageModel(
        id: 2,
        projectId: 1,
        imagePath: '/b.jpg',
        source: MoodboardSource.manual,
        category: MoodboardCategory.location,
        linkedLocationBasePlanId: 20,
        linkedLocationName: 'Playa norte',
        caption: 'LOC-PLAN-B',
      );
      final orphanName = MoodboardImageModel(
        id: 3,
        projectId: 1,
        imagePath: '/c.jpg',
        source: MoodboardSource.manual,
        category: MoodboardCategory.location,
        linkedLocationName: 'Calle secundaria',
        caption: 'LOC-NAME',
      );
      final unassigned = MoodboardImageModel(
        id: 4,
        projectId: 1,
        imagePath: '/d.jpg',
        source: MoodboardSource.manual,
        category: MoodboardCategory.location,
        caption: 'LOC-UNASSIGNED',
      );
      final items = [
        (img: planA, image: null),
        (img: planB, image: null),
        (img: orphanName, image: null),
        (img: unassigned, image: null),
      ];

      final groups =
          VisualBiblePdfService.orderedPitchRefsLocationGroups(items);
      expect(groups.length, 4);
      expect(groups.last.key,
          VisualBiblePdfService.pitchRefsLocationUnassignedKey);
      final planAGroup = groups.firstWhere((g) => g.key == 'plan:10');
      expect(
        VisualBiblePdfService.pitchRefsLocationGroupLabel(
          planAGroup.key,
          planAGroup.value.first.img,
        ),
        'Casa roja',
      );
      expect(
        VisualBiblePdfService.pitchRefsLocationGroupLabel(
          VisualBiblePdfService.pitchRefsLocationUnassignedKey,
          unassigned,
        ),
        'Sin set asignado',
      );
    });

    test('pitch export subagrupa localización por set en el PDF', () async {
      final imageDir = Directory.systemTemp.createTempSync('iris_pitch_loc');
      final imagePath = '${imageDir.path}/still.png';
      await File(imagePath).writeAsBytes(_tinyPng);

      final moodboard = [
        MoodboardImageModel(
          id: 1,
          projectId: 1,
          imagePath: imagePath,
          source: MoodboardSource.manual,
          category: MoodboardCategory.location,
          linkedLocationBasePlanId: 5,
          linkedLocationName: 'Set Alpha',
          caption: 'LOC-ALPHA',
        ),
        MoodboardImageModel(
          id: 2,
          projectId: 1,
          imagePath: imagePath,
          source: MoodboardSource.manual,
          category: MoodboardCategory.location,
          linkedLocationBasePlanId: 9,
          linkedLocationName: 'Set Beta',
          caption: 'LOC-BETA',
        ),
      ];

      final bytes = await VisualBiblePdfService.buildBytes(
        mode: VisualBibleExportMode.pitch,
        projectName: 'Pitch loc test',
        director: 'Director',
        data: VisualBibleData(id: 1, projectId: 1),
        colorBlocks: const [],
        exposureBlocks: const [],
        lightingSetups: const [],
        cameraTests: const [],
        moodboard: moodboard,
        includedSections: {
          BibleSectionId.location,
          BibleSectionId.moodboard,
        },
      );

      final pdfText = await _extractPdfText(bytes);
      final normalized = pdfText.replaceAll(RegExp(r'\s+'), '');
      expect(pdfText, contains('Localización'));
      expect(normalized, contains('SetAlpha'));
      expect(normalized, contains('SetBeta'));
      expect(pdfText, contains('LOC-ALPHA'));
      expect(pdfText, contains('LOC-BETA'));
    });
  });
}

Future<String> _extractPdfText(Uint8List bytes) async {
  final document = sf.PdfDocument(inputBytes: bytes);
  try {
    final extractor = sf.PdfTextExtractor(document);
    final buffer = StringBuffer();
    for (var i = 0; i < document.pages.count; i++) {
      buffer.writeln(
        extractor.extractText(startPageIndex: i, endPageIndex: i),
      );
    }
    return buffer.toString();
  } finally {
    document.dispose();
  }
}
