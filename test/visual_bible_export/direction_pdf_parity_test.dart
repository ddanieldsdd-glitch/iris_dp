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

  group('registro de Dirección', () {
    test('por defecto: seis puntos tras la cabecera, sin Key Frame', () {
      expect(
        BibleStitchModuleRegistry.defaultFieldsFor(
          BibleSectionId.direction,
        ).map((f) => f.key),
        [
          'header',
          'narrative',
          'tone',
          'strategies',
          'acts',
          'references',
          'transitions',
        ],
      );
    });

    test('Key Frame se puede volver a añadir', () {
      final missing = BibleStitchModuleRegistry.missingModules(
        BibleSectionId.direction,
        BibleStitchModuleRegistry.defaultFieldsFor(BibleSectionId.direction),
      );
      expect(missing.map((m) => m.key), ['keyFrame']);
      expect(
        BibleStitchModuleRegistry.hasRenderer(
          BibleSectionId.direction,
          'keyFrame',
        ),
        isTrue,
      );
    });

    test('una biblia antigua parte «Tono y estrategias» en dos y conserva '
        'Key Frame', () {
      final fields = BibleStitchModuleRegistry.normalizeFields(
        BibleSectionId.direction,
        const [
          BibleSectionField(key: 'header', label: 'Cabecera de escena'),
          BibleSectionField(key: 'toneStrategies', label: 'Tono y estrategias'),
          BibleSectionField(key: 'keyFrame', label: 'Key Frame'),
          BibleSectionField(key: 'field_1', label: 'Mío'),
        ],
      );
      expect(fields.map((f) => f.key), [
        'header',
        'tone',
        'strategies',
        'keyFrame',
        'field_1',
      ]);
    });
  });

  test('el PDF de Dirección lleva los puntos de la pantalla en su orden',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Dirección'),
    );
    final bible = await db.ensureVisualBibleForProject(projectId);
    await db.addBuiltinBibleSection(
      bibleId: bible.id,
      sectionId: BibleSectionId.direction,
    );

    // El punto propio va entre Tono y Estrategia.
    final fields = [
      for (final field in BibleStitchModuleRegistry.defaultFieldsFor(
        BibleSectionId.direction,
      )) ...[
        field,
        if (field.key == 'tone')
          const BibleSectionField(key: 'field_mio', label: 'Punto propio'),
      ],
    ];
    await db.saveBibleSectionFields(bible.id, BibleSectionId.direction, fields);
    await db.saveBibleSectionFieldValue(
      bible.id,
      BibleSectionId.direction,
      'directionData',
      jsonEncode({
        'emotionTags': ['Tensión'],
        'tonePoints': [
          {'title': 'Frío e industrial', 'body': 'Luces fluorescentes'},
        ],
        'extraStrategies': [
          {'title': 'Ritmo', 'body': 'Planos largos'},
        ],
        'act1Desc': 'Composiciones simétricas',
        'refsMetadata': [
          {
            'refLabel': 'FINCHER / SE7EN',
            'title': 'Espacio negativo',
            'body': 'Tercio inferior',
            'lens': '35mm',
            'tech2Label': 'APERTURE',
            'tech2Value': 'T5.6',
          },
        ],
        'transitionLanguage': [
          {'title': 'Match cuts', 'body': 'Líneas geométricas'},
        ],
      }),
    );
    await db.saveBibleSectionFieldValue(
      bible.id,
      BibleSectionId.direction,
      'field_mio',
      'Nota intercalada',
    );

    final repo = VisualBibleRepository(VisualBibleDao(db));
    final bundle = await repo.loadExportBundle(projectId: projectId);
    bundle.data
      ..directionNarrativeIntent = 'Aislamiento psicológico'
      ..cameraPhilosophy = 'Movimientos lentos'
      ..stagingApproach = 'Personajes aislados'
      ..pointOfView = 'Angulares a media distancia';

    final bytes = await VisualBiblePdfService.buildBytes(
      mode: VisualBibleExportMode.full,
      projectName: 'Dirección',
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
    final out = Directory('build/direction_parity')..createSync(recursive: true);
    File('${out.path}/direccion.pdf').writeAsBytesSync(bytes);

    final text = _extract(bytes);
    final expected = [
      'Aislamiento psicológico',
      'TENSIÓN',
      'Frío e industrial',
      'Nota intercalada',
      'Movimientos lentos',
      'Personajes aislados',
      'Angulares a media distancia',
      'Planos largos',
      'Orden y Rigidez',
      'Composiciones simétricas',
      'Espacio negativo',
      'Lente 35mm',
      'Match cuts',
    ];
    var cursor = -1;
    for (final piece in expected) {
      final at = text.indexOf(piece);
      expect(at, greaterThan(cursor), reason: '«$piece» falta o va antes');
      cursor = at;
    }
    expect(text, isNot(contains('Fragmentación')), reason: 'acto vacío');
    expect(text, isNot(contains('KEY FRAME')));
  });
}
