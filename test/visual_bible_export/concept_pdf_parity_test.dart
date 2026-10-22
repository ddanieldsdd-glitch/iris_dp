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
import 'package:shared_preferences/shared_preferences.dart';
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

  group('registro de Concepto', () {
    test('por defecto: ocho puntos, luz y sombras antes que el color', () {
      expect(
        BibleStitchModuleRegistry.defaultFieldsFor(
          BibleSectionId.concept,
        ).map((f) => f.key),
        [
          'narrative',
          'lightPhilosophy',
          'shadowTreatment',
          'colorPalette',
          'colorSymbolism',
          'composition',
          'actNotes',
          'references',
        ],
      );
    });

    test('Key Frame y «Composición por actos» se pueden volver a añadir', () {
      final missing = BibleStitchModuleRegistry.missingModules(
        BibleSectionId.concept,
        BibleStitchModuleRegistry.defaultFieldsFor(BibleSectionId.concept),
      );
      expect(missing.map((m) => m.key), ['keyFrame', 'actComposition']);
    });
  });

  test('el PDF de Concepto lleva los puntos de la pantalla en su orden',
      () async {
    SharedPreferences.setMockInitialValues({});
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

    final out = Directory('build/concept_parity')..createSync(recursive: true);
    final still = File('${out.path}/still.png')..writeAsBytesSync(_tinyPng);
    final imageId = await db.into(db.moodboardImages).insert(
      MoodboardImagesCompanion.insert(
        projectId: projectId,
        imagePath: still.path,
      ),
    );

    final fields = [
      for (final field in BibleStitchModuleRegistry.defaultFieldsFor(
        BibleSectionId.concept,
      )) ...[
        field,
        if (field.key == 'colorSymbolism')
          const BibleSectionField(key: 'field_mio', label: 'Punto propio'),
        // Punto de biblias anteriores que el usuario conserva.
        if (field.key == 'actNotes')
          const BibleSectionField(key: 'keyFrame', label: 'Key Frame'),
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
        'masterPalette': [
          {'hex': '#112233', 'name': 'Noche'},
        ],
        'shadowTreatment': 'Negros densos que anclan el cuadro',
        'composition': 'Personaje pequeño en el tercio inferior',
        'compositionMetrics': {'balance': 'Asimétrico'},
        'pointImages': {
          'shadowTreatment': [imageId],
          'composition': [imageId, 999],
        },
        'act2Intent': 'Contrastes agresivos',
        'keyFrameTech': '2.39:1 / 21mm / T2.8',
        'keyReferences': [
          {
            'film': 'Blade Runner 2049',
            'dp': 'Roger Deakins',
            'tone': 'Melancolía brutalista',
          },
          {
            'refLabel': 'Good Time · Sean Price Williams',
            'title': 'Color que aprieta',
            'kind': 'Color',
            'why': 'Neones sucios pegados a la piel',
            'purpose': 'Las noches de la huida',
            'imageId': imageId,
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
    File('${out.path}/concepto.pdf').writeAsBytesSync(bytes);

    final text = _extract(bytes);
    final expected = [
      'Naturalismo estilizado',
      'Luz direccional dura',
      'Alto (4:1)',
      'Prácticos visibles',
      'Negros densos que anclan el cuadro',
      '#112233',
      'NOCHE',
      'Azul profundo',
      'Soledad institucional',
      'Nota intercalada',
      'Personaje pequeño en el tercio inferior',
      'Asimétrico',
      'Contrastes agresivos',
      '2.39:1 / 21mm / T2.8',
      'Blade Runner 2049',
      'Melancolía brutalista',
      'COLOR · GOOD TIME',
      'Color que aprieta',
      'Neones sucios pegados a la piel',
      'Las noches de la huida',
    ];
    var cursor = -1;
    for (final piece in expected) {
      final at = text.indexOf(piece, cursor + 1);
      expect(at, greaterThan(cursor), reason: '«$piece» falta o va antes');
      cursor = at;
    }
    // Ni títulos ni datos de ejemplo: solo lo que se escribió.
    expect(text, isNot(contains('El Orden Frágil')));
    expect(text, isNot(contains('El Descenso')));
    expect(text, isNot(contains('RELLENO')), reason: 'dato sin valor');
  });
}
