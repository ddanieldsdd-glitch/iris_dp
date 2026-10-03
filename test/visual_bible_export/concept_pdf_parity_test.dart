import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';


import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/dao/visual_bible_dao.dart';
import 'package:iris_dp/features/visual_bible/data/visual_bible_repository.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_pdf_service.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_stitch_module_registry.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

String _extract(Uint8List bytes) {
  final document = sf.PdfDocument(inputBytes: bytes);
  try {
    final extractor = sf.PdfTextExtractor(document);
    return [
      for (var i = 0; i < document.pages.count; i++)
        extractor.extractText(startPageIndex: i, endPageIndex: i),
    ].join(' ').replaceAll(RegExp(r'\s+'), ' ');
  } finally {
    document.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('registro de Concepto', () {
    test('por defecto: ocho puntos, con los actos y sin composición', () {
      expect(
        BibleStitchModuleRegistry.defaultFieldsFor(
          BibleSectionId.concept,
        ).map((f) => f.key),
        [
          'narrative',
          'colorPalette',
          'colorSymbolism',
          'lightPhilosophy',
          'shadowTreatment',
          'actNotes',
          'keyFrame',
          'references',
        ],
      );
    });

    test('«Composición por actos» se puede volver a añadir', () {
      final missing = BibleStitchModuleRegistry.missingModules(
        BibleSectionId.concept,
        BibleStitchModuleRegistry.defaultFieldsFor(BibleSectionId.concept),
      );
      expect(missing.map((m) => m.key), ['actComposition']);
    });
  });

  test('el PDF de Concepto lleva los puntos de la pantalla en su orden',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Concepto'),
    );
    final bible = await db.ensureVisualBibleForProject(projectId);
    await db.addBuiltinBibleSection(
      bibleId: bible.id,
      sectionId: BibleSectionId.concept,
    );
    await db.into(db.visualBibleColorBlocks).insert(
      VisualBibleColorBlocksCompanion.insert(
        bibleId: bible.id,
        blockName: 'Acto I',
        dominantColors: jsonEncode(['#0F1C2E', '#F5B841']),
      ),
    );

    final fields = [
      for (final field in BibleStitchModuleRegistry.defaultFieldsFor(
        BibleSectionId.concept,
      )) ...[
        field,
        if (field.key == 'colorSymbolism')
          const BibleSectionField(key: 'field_mio', label: 'Punto propio'),
      ],
    ];
    await db.saveBibleSectionFields(bible.id, BibleSectionId.concept, fields);
    await db.saveBibleSectionFieldValue(
      bible.id,
      BibleSectionId.concept,
      'conceptData',
      jsonEncode({
        'colorSymbols': [
          {
            'poeticName': 'Azul profundo',
            'hex': '#0F1C2E',
            'narrativeMeaning': 'Soledad institucional',
          },
        ],
        'lightingMetrics': {'motivation': 'Prácticos visibles'},
        'shadowTreatment': 'Negros densos que anclan el cuadro',
        'act2Intent': 'Contrastes agresivos',
        'keyFrameTech': '2.39:1 / 21mm / T2.8',
        'keyReferences': [
          {
            'film': 'Blade Runner 2049',
            'dp': 'Roger Deakins',
            'tone': 'Melancolía brutalista',
          },
        ],
      }),
    );
    await db.saveBibleSectionFieldValue(
      bible.id,
      BibleSectionId.concept,
      'field_mio',
      'Nota intercalada',
    );

    final repo = VisualBibleRepository(VisualBibleDao(db));
    final bundle = await repo.loadExportBundle(projectId: projectId);
    bundle.data
      ..conceptNarrativeIntent = 'Naturalismo estilizado'
      ..lightingPhilosophy = 'Luz direccional dura'
      ..contrastStyle = 'Alto (4:1)';

    final bytes = await VisualBiblePdfService.buildBytes(
      mode: VisualBibleExportMode.full,
      projectName: 'Concepto',
      director: null,
      data: bundle.data,
      colorBlocks: bundle.blocks,
      exposureBlocks: bundle.exposureBlocks,
      lightingSetups: bundle.lightingSetups,
      cameraTests: bundle.cameraTests,
      moodboard: bundle.moodboard,
      sectionContentJsonById: bundle.sectionContentJsonById,
      sectionOrder: bundle.sectionOrder,
    );
    final out = Directory('build/concept_parity')..createSync(recursive: true);
    File('${out.path}/concepto.pdf').writeAsBytesSync(bytes);

    final text = _extract(bytes);
    final expected = [
      'Naturalismo estilizado',
      '#0F1C2E',
      'Azul profundo',
      'Soledad institucional',
      'Nota intercalada',
      'Luz direccional dura',
      'Alto (4:1)',
      'Prácticos visibles',
      'Negros densos que anclan el cuadro',
      'El Descenso',
      'Contrastes agresivos',
      '2.39:1 / 21mm / T2.8',
      'Blade Runner 2049',
      'Melancolía brutalista',
    ];
    var cursor = -1;
    for (final piece in expected) {
      final at = text.indexOf(piece, cursor + 1);
      expect(at, greaterThan(cursor), reason: '«$piece» falta o va antes');
      cursor = at;
    }
    expect(text, isNot(contains('El Orden Frágil')), reason: 'acto vacío');
  });
}
