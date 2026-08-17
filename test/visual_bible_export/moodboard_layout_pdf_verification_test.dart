import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/moodboard_export_layout.dart';
import 'package:iris_dp/features/visual_bible/moodboard_reference_meta.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_export_config.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_pdf_service.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Marcadores únicos para verificación de layout moodboard en PDF.
const moodboardMarkerCaptionLight = 'MOODBOARD-VERIFY-CAPTION-LIGHT';
const moodboardMarkerCaptionColor = 'MOODBOARD-VERIFY-CAPTION-COLOR';
const moodboardMarkerCaptionTexture = 'MOODBOARD-VERIFY-CAPTION-TEXTURE';
const moodboardMarkerMetaRich = 'MOODBOARD-VERIFY-META-RICH';

/// PNG 1×1 mínimo válido.
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

  test(
    'genera PDFs moodboard flat, byFacet y minimal con marcadores verificables',
    () async {
      final outDir = Directory('build/moodboard_layout_verification');
      outDir.createSync(recursive: true);

      final imageDir = Directory.systemTemp.createTempSync('iris_moodboard_pdf');
      final imagePath = '${imageDir.path}/still.png';
      await File(imagePath).writeAsBytes(_tinyPng);

      final moodboard = [
        MoodboardImageModel(
          id: 1,
          projectId: 1,
          imagePath: imagePath,
          source: MoodboardSource.manual,
          category: MoodboardCategory.lighting,
          caption: moodboardMarkerCaptionLight,
          meta: const MoodboardReferenceMeta(lightingLook: 'Suave'),
        ),
        MoodboardImageModel(
          id: 2,
          projectId: 1,
          imagePath: imagePath,
          source: MoodboardSource.manual,
          category: MoodboardCategory.color,
          caption: moodboardMarkerCaptionColor,
          filmReference: moodboardMarkerMetaRich,
          meta: const MoodboardReferenceMeta(colorMood: 'Frío'),
        ),
        MoodboardImageModel(
          id: 3,
          projectId: 1,
          imagePath: imagePath,
          source: MoodboardSource.manual,
          category: MoodboardCategory.texture,
          caption: moodboardMarkerCaptionTexture,
        ),
      ];

      final data = VisualBibleData(id: 1, projectId: 1);
      final sections = {BibleSectionId.moodboard};

      final flatLayout = const MoodboardExportLayout(
        grouping: MoodboardExportGrouping.flat,
        density: MoodboardExportDensity.standard,
      );
      final byFacetLayout = MoodboardExportLayout(
        grouping: MoodboardExportGrouping.byFacet,
        facets: MoodboardExportFacet.values.toSet(),
        density: MoodboardExportDensity.standard,
      );
      final minimalLayout = const MoodboardExportLayout(
        grouping: MoodboardExportGrouping.flat,
        density: MoodboardExportDensity.minimal,
      );

      final flatBytes = await VisualBiblePdfService.buildBytes(
        mode: VisualBibleExportMode.full,
        projectName: 'Moodboard layout verify',
        director: 'Director',
        data: data,
        colorBlocks: const [],
        exposureBlocks: const [],
        lightingSetups: const [],
        cameraTests: const [],
        moodboard: moodboard,
        includedSections: sections,
        moodboardLayout: flatLayout,
      );
      final flatPath = File('${outDir.path}/moodboard_flat_standard.pdf');
      await flatPath.writeAsBytes(flatBytes);

      final byFacetBytes = await VisualBiblePdfService.buildBytes(
        mode: VisualBibleExportMode.full,
        projectName: 'Moodboard layout verify',
        director: 'Director',
        data: data,
        colorBlocks: const [],
        exposureBlocks: const [],
        lightingSetups: const [],
        cameraTests: const [],
        moodboard: moodboard,
        includedSections: sections,
        moodboardLayout: byFacetLayout,
      );
      final byFacetPath = File('${outDir.path}/moodboard_by_facet.pdf');
      await byFacetPath.writeAsBytes(byFacetBytes);

      final minimalBytes = await VisualBiblePdfService.buildBytes(
        mode: VisualBibleExportMode.full,
        projectName: 'Moodboard layout verify',
        director: 'Director',
        data: data,
        colorBlocks: const [],
        exposureBlocks: const [],
        lightingSetups: const [],
        cameraTests: const [],
        moodboard: moodboard,
        includedSections: sections,
        moodboardLayout: minimalLayout,
      );
      final minimalPath = File('${outDir.path}/moodboard_minimal.pdf');
      await minimalPath.writeAsBytes(minimalBytes);

      final pitchLayout =
          VisualBibleExportConfig.defaultMoodboardLayoutForMode(
            VisualBibleExportMode.pitch,
          );
      final pitchBytes = await VisualBiblePdfService.buildBytes(
        mode: VisualBibleExportMode.pitch,
        projectName: 'Moodboard layout verify',
        director: 'Director',
        data: data,
        colorBlocks: const [],
        exposureBlocks: const [],
        lightingSetups: const [],
        cameraTests: const [],
        moodboard: moodboard,
        includedSections: {
          BibleSectionId.moodboard,
          BibleSectionId.colorImage,
        },
        moodboardLayout: pitchLayout,
      );
      final pitchPath = File('${outDir.path}/moodboard_pitch_rich.pdf');
      await pitchPath.writeAsBytes(pitchBytes);

      final flatText = await _extractPdfText(flatPath);
      final byFacetText = await _extractPdfText(byFacetPath);
      final minimalText = await _extractPdfText(minimalPath);
      final pitchText = await _extractPdfText(pitchPath);

      expect(flatText.toUpperCase(), contains('PLANO'));
      for (final marker in [
        moodboardMarkerCaptionLight,
        moodboardMarkerCaptionColor,
        moodboardMarkerCaptionTexture,
      ]) {
        expect(
          flatText.contains(marker),
          isTrue,
          reason: 'PDF plano debe incluir $marker',
        );
      }

      expect(
        byFacetText.contains('MOODBOARD'),
        isTrue,
      );
      expect(
        byFacetText.toUpperCase(),
        contains('LUZ'),
      );
      expect(
        byFacetText.toUpperCase(),
        contains('TEXTURA'),
      );
      expect(
        byFacetText.contains(moodboardMarkerCaptionTexture),
        isTrue,
      );

      expect(
        minimalText.contains(moodboardMarkerCaptionLight),
        isFalse,
        reason: 'densidad mínima no debe pintar captions',
      );
      expect(minimalText.toUpperCase(), contains('MOODBOARD'));

      expect(
        pitchText.contains(moodboardMarkerMetaRich),
        isTrue,
        reason: 'Pitch rico debe incluir filmReference en ficha',
      );

      await File('${outDir.path}/VERIFICATION.txt').writeAsString('''
PDFs generados — verificación layout moodboard (slice 7)

Archivos:
- Plano / Estándar: ${flatPath.absolute.path}
- Por faceta / Estándar: ${byFacetPath.absolute.path}
- Plano / Mínima: ${minimalPath.absolute.path}
- Pitch / Rica (refs): ${pitchPath.absolute.path}

Checklist manual:
1. Plano vs Por faceta: el PDF por faceta muestra títulos Luz, Color, Textura.
2. Mínima vs Estándar: bajo los stills, Mínima sin texto; Estándar con captions.
3. Pitch REFERENCIAS VISUALES: ficha rica muestra film/meta ($moodboardMarkerMetaRich).

Fuera de alcance (v2): swatches Color, exportDetailLines filtrado por faceta, export solo-moodboard.
''');
    },
  );
}

Future<String> _extractPdfText(File pdf) async {
  final bytes = await pdf.readAsBytes();
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
