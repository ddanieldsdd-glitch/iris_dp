import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_pdf_service.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildBytes incluye secciones custom y location sin fallar', () async {
    final locationContent = BibleSectionFieldsConfig.encode(
      BibleSectionFieldsConfig.defaultsFor(BibleSectionId.location),
      values: {
        'locationData': jsonEncode({
          'byPlan': {
            '1': {'weather': 'Nublado', 'coords': '40.41, -3.70'},
          },
        }),
      },
    );
    final cameraContent = BibleSectionFieldsConfig.encode(
      BibleSectionFieldsConfig.defaultsFor(BibleSectionId.camera),
      values: {
        'cameraData': jsonEncode({'isoNote': '800 nativo', 'bitDepth': '10-bit'}),
      },
    );

    final bytes = await VisualBiblePdfService.buildBytes(
      mode: VisualBibleExportMode.full,
      projectName: 'Proyecto prueba',
      director: 'Director',
      data: VisualBibleData(id: 1, projectId: 1),
      colorBlocks: const [],
      exposureBlocks: const [],
      lightingSetups: const [],
      cameraTests: const [],
      moodboard: const [],
      includedSections: {
        BibleSectionId.camera,
        BibleSectionId.location,
        BibleSectionId.exposure,
      },
      sectionContentJsonById: {
        BibleSectionId.location: locationContent,
        BibleSectionId.camera: cameraContent,
      },
    );

    expect(bytes, isNotEmpty);
    expect(bytes.sublist(0, 4), '%PDF'.codeUnits);
  });

  test('buildBytes no falla si Concepto solo tiene contentJson custom', () async {
    final conceptContent = BibleSectionFieldsConfig.encode(
      BibleSectionFieldsConfig.defaultsFor(BibleSectionId.concept),
      values: {
        'conceptData': jsonEncode({'act1Intent': 'Prueba acto 1'}),
      },
    );

    final bytes = await VisualBiblePdfService.buildBytes(
      mode: VisualBibleExportMode.full,
      projectName: 'Proyecto prueba',
      director: 'Director',
      data: VisualBibleData(id: 1, projectId: 1),
      colorBlocks: const [],
      exposureBlocks: const [],
      lightingSetups: const [],
      cameraTests: const [],
      moodboard: const [],
      includedSections: {BibleSectionId.concept},
      sectionContentJsonById: {
        BibleSectionId.concept: conceptContent,
      },
    );

    expect(bytes, isNotEmpty);
  });
}
