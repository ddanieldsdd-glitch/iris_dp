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
    test('por defecto: seis puntos, de la idea a las referencias', () {
      expect(
        BibleStitchModuleRegistry.defaultFieldsFor(
          BibleSectionId.direction,
        ).map((f) => f.key),
        [
          'narrative',
          'tone',
          'strategies',
          'acts',
          'transitions',
          'references',
        ],
      );
    });

    test('la cabecera de escena y el Key Frame ya no se ofrecen', () {
      final missing = BibleStitchModuleRegistry.missingModules(
        BibleSectionId.direction,
        BibleStitchModuleRegistry.defaultFieldsFor(BibleSectionId.direction),
      );
      expect(missing, isEmpty);
      for (final key in ['header', 'keyFrame']) {
        expect(
          BibleStitchModuleRegistry.hasRenderer(BibleSectionId.direction, key),
          isFalse,
        );
      }
    });

    test('los puntos se pintan con su widget del catálogo', () {
      final byKey = {
        for (final f in BibleStitchModuleRegistry.defaultFieldsFor(
          BibleSectionId.direction,
        ))
          f.key: f,
      };
      expect(byKey['tone']!.type, BibleSectionFieldType.cards);
      expect(byKey['strategies']!.widget, 'cards_pillars');
      expect(byKey['acts']!.type, BibleSectionFieldType.acts);
      expect(byKey['transitions']!.type, BibleSectionFieldType.cards);
    });

    test('una biblia guardada antes pasa las transiciones delante de las '
        'referencias, una sola vez', () {
      const saved = [
        BibleSectionField(key: 'header', label: 'Cabecera de escena'),
        BibleSectionField(key: 'narrative', label: 'Intención narrativa'),
        BibleSectionField(key: 'tone', label: 'Mi tono'),
        BibleSectionField(key: 'references', label: 'Referencias'),
        BibleSectionField(key: 'transitions', label: 'Transiciones'),
      ];
      final migrated = BibleStitchModuleRegistry.normalizeFields(
        BibleSectionId.direction,
        saved,
        layoutVersion: 2,
      );
      expect(migrated.map((f) => f.key), [
        'narrative',
        'tone',
        'transitions',
        'references',
      ]);
      // Conserva el nombre del usuario y toma el tipo del catálogo.
      expect(migrated[1].label, 'Mi tono');
      expect(migrated[1].type, BibleSectionFieldType.cards);

      // Ya migrada, se respeta el orden que el usuario elija.
      final kept = BibleStitchModuleRegistry.normalizeFields(
        BibleSectionId.direction,
        saved,
        layoutVersion: 3,
      );
      expect(kept.map((f) => f.key).toList().sublist(2), [
        'references',
        'transitions',
      ]);
    });

    test('una biblia antigua parte «Tono y estrategias» en dos y pierde la '
        'cabecera y el Key Frame', () {
      final fields = BibleStitchModuleRegistry.normalizeFields(
        BibleSectionId.direction,
        const [
          BibleSectionField(key: 'header', label: 'Cabecera de escena'),
          BibleSectionField(key: 'toneStrategies', label: 'Tono y estrategias'),
          BibleSectionField(key: 'keyFrame', label: 'Key Frame'),
          BibleSectionField(key: 'field_1', label: 'Mío'),
        ],
      );
      expect(fields.map((f) => f.key), ['tone', 'strategies', 'field_1']);
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
            'kind': 'Puesta en escena',
            'why': 'El entorno pesa más que el personaje',
            'purpose': 'Que la ciudad oprima a la protagonista',
            'imageId': null,
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
    // Texto complementario del menú «⋯» de «Tono».
    await db.saveBibleSectionFieldValue(
      bible.id,
      BibleSectionId.direction,
      'tone__extra',
      '{"images":[],"text":"Complemento del tono"}',
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
      'Complemento del tono',
      'Nota intercalada',
      'Movimientos lentos',
      'Personajes aislados',
      'Angulares a media distancia',
      'Planos largos',
      'ACTO 1 · PLANTEAMIENTO',
      'Composiciones simétricas',
      'Match cuts',
      'PUESTA EN ESCENA',
      'Espacio negativo',
      'El entorno pesa más que el personaje',
      'Que la ciudad oprima a la protagonista',
    ];
    var cursor = -1;
    for (final piece in expected) {
      final at = text.indexOf(piece);
      expect(at, greaterThan(cursor), reason: '«$piece» falta o va antes');
      cursor = at;
    }
    expect(text, isNot(contains('ACTO 2')), reason: 'acto sin intención');
    expect(text, isNot(contains('KEY FRAME')));
  });
}
