import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/dao/visual_bible_dao.dart';
import 'package:iris_dp/features/visual_bible/data/visual_bible_repository.dart';
import 'package:iris_dp/features/visual_bible/export/bible_section_export_reader.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_pdf_service.dart';
import 'package:iris_dp/shared/visual_bible/bible_layout.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Secciones cuya pantalla admite puntos añadidos por el usuario.
const _sectionsWithPoints = [
  BibleSectionId.direction,
  BibleSectionId.concept,
  BibleSectionId.camera,
  BibleSectionId.optics,
  BibleSectionId.exposure,
  BibleSectionId.lighting,
  BibleSectionId.colorImage,
  BibleSectionId.format,
  BibleSectionId.texture,
  BibleSectionId.workflow,
];

String _marker(String sectionId) =>
    'PUNTO-${sectionId.toUpperCase().replaceAll('_', '')}';

/// Texto del PDF con los espacios normalizados (el extractor parte por palabra).
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

  late AppDatabase db;
  late int projectId;
  late int bibleId;

  Future<Uint8List> export() async {
    final bundle = await VisualBibleRepository(
      VisualBibleDao(db),
    ).loadExportBundle(projectId: projectId);
    return VisualBiblePdfService.buildBytes(
      mode: VisualBibleExportMode.full,
      projectName: 'Paridad',
      director: null,
      data: bundle.data,
      colorBlocks: bundle.blocks,
      exposureBlocks: bundle.exposureBlocks,
      lightingSetups: bundle.lightingSetups,
      cameraTests: bundle.cameraTests,
      moodboard: bundle.moodboard,
      sectionContentJsonById: bundle.sectionContentJsonById,
      sectionOrder: bundle.sectionOrder,
      primaryCameraLabel: bundle.primaryCameraLabel,
    );
  }

  Future<void> addPoint(
    String sectionId,
    BibleSectionField field,
    String value,
  ) async {
    final def =
        await (db.select(
              db.bibleSectionDefinitions,
            )..where((d) => d.bibleId.equals(bibleId) & d.id.equals(sectionId)))
            .getSingle();
    await db.saveBibleSectionFields(bibleId, sectionId, [
      ...BibleSectionFieldsConfig.parse(def.contentJson, sectionId),
      field,
    ]);
    await db.saveBibleSectionFieldValue(bibleId, sectionId, field.key, value);
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Paridad'),
    );
    bibleId = (await db.ensureVisualBibleForProject(projectId)).id;
    for (final sectionId in _sectionsWithPoints) {
      await db.addBuiltinBibleSection(bibleId: bibleId, sectionId: sectionId);
    }
  });

  test(
    'un punto propio con contenido sale una vez en el PDF de cada sección',
    () async {
      for (final sectionId in _sectionsWithPoints) {
        await addPoint(
          sectionId,
          BibleSectionField(key: 'field_$sectionId', label: 'Nota propia'),
          _marker(sectionId),
        );
      }

      final text = _extract(await export());
      for (final sectionId in _sectionsWithPoints) {
        expect(
          _marker(sectionId).allMatches(text),
          hasLength(1),
          reason: 'el punto propio de $sectionId debe salir una sola vez',
        );
      }
    },
  );

  test('lista y datos técnicos se leen, no salen como JSON', () async {
    await addPoint(
      BibleSectionId.direction,
      const BibleSectionField(
        key: 'field_lista',
        label: 'Riesgos',
        type: BibleSectionFieldType.list,
      ),
      BibleSectionPointValue.encodeList(['Lluvia en exteriores', 'Viento'])!,
    );
    await addPoint(
      BibleSectionId.camera,
      const BibleSectionField(
        key: 'field_specs',
        label: 'Filtros',
        type: BibleSectionFieldType.specs,
      ),
      BibleSectionPointValue.encodeSpecs([('Polarizador', 'Circular')])!,
    );

    final text = _extract(await export());
    expect(text, contains('RIESGOS'));
    expect(text, contains('Lluvia en exteriores'));
    expect(text, contains('Viento'));
    expect(text, contains('Circular'));
    expect(text, isNot(contains('["')));
    expect(text, isNot(contains('{"label"')));
  });

  test(
    'paleta y referencias añadidas a cualquier sección salen en el PDF',
    () async {
      await addPoint(
        BibleSectionId.exposure,
        const BibleSectionField(
          key: 'field_paleta',
          label: 'Paleta de noche',
          type: BibleSectionFieldType.palette,
        ),
        jsonEncode([
          {'hex': '#0B1D2A', 'name': 'Azul petróleo'},
        ]),
      );
      await addPoint(
        BibleSectionId.exposure,
        const BibleSectionField(
          key: 'field_refs',
          label: 'Referencias de exposición',
          type: BibleSectionFieldType.referenceDeck,
        ),
        jsonEncode({
          'preset': 'technical',
          'items': [
            {
              'title': 'Subexposición controlada',
              'refLabel': 'Se7en · Darius Khondji',
              'kind': 'Iluminación',
              'why': 'Dos pasos por debajo con relleno mínimo',
              'purpose': 'Probar el ruido a ISO 1600',
              'imageId': null,
            },
          ],
        }),
      );

      final text = _extract(await export());
      final expected = [
        'PALETA DE NOCHE',
        '#0B1D2A',
        'AZUL PETRÓLEO',
        'REFERENCIAS DE EXPOSICIÓN',
        'ILUMINACIÓN · SE7EN',
        'Subexposición controlada',
        'CÓMO SE HIZO',
        'Dos pasos por debajo con relleno mínimo',
        'QUÉ NECESITAMOS',
        'Probar el ruido a ISO 1600',
      ];
      var cursor = -1;
      for (final piece in expected) {
        final at = text.indexOf(piece, cursor + 1);
        expect(at, greaterThan(cursor), reason: '«$piece» falta o va antes');
        cursor = at;
      }
    },
  );

  test('actos, pilares, puntos con título, etiquetas y simbología salen en el '
      'PDF de cualquier pantalla', () async {
    await addPoint(
      BibleSectionId.exposure,
      const BibleSectionField(
        key: 'field_actos',
        label: 'Exposición por actos',
        type: BibleSectionFieldType.acts,
        widget: 'acts',
      ),
      jsonEncode([
        {'kicker': 'CALMA', 'title': 'Luz plena', 'body': 'Sin sombras duras'},
        {'kicker': '', 'title': 'Caída', 'body': 'Dos pasos por debajo'},
      ]),
    );
    await addPoint(
      BibleSectionId.exposure,
      const BibleSectionField(
        key: 'field_pilares',
        label: 'Pilares de exposición',
        type: BibleSectionFieldType.cards,
        widget: 'cards_pillars',
      ),
      jsonEncode([
        {'title': 'Altas luces', 'body': 'Se protegen siempre'},
      ]),
    );
    await addPoint(
      BibleSectionId.exposure,
      const BibleSectionField(
        key: 'field_puntos',
        label: 'Reglas',
        type: BibleSectionFieldType.cards,
        widget: 'cards',
      ),
      jsonEncode([
        {'title': 'Piel', 'body': 'Nunca por encima de zona VI'},
      ]),
    );
    await addPoint(
      BibleSectionId.exposure,
      const BibleSectionField(
        key: 'field_tags',
        label: 'Sensaciones',
        type: BibleSectionFieldType.tags,
        widget: 'tags',
      ),
      jsonEncode(['Asfixia', 'Vigilia']),
    );
    await addPoint(
      BibleSectionId.exposure,
      const BibleSectionField(
        key: 'field_simbolos',
        label: 'Qué dice cada color',
        type: BibleSectionFieldType.palette,
        widget: 'palette_symbolism',
      ),
      jsonEncode([
        {'hex': '#8A1C1C', 'name': 'Rojo óxido', 'note': 'La culpa heredada'},
      ]),
    );

    final text = _extract(await export());
    final expected = [
      'EXPOSICIÓN POR ACTOS',
      'ACTO 1 · CALMA',
      'Luz plena',
      'ACTO 2',
      'Dos pasos por debajo',
      'PILARES DE EXPOSICIÓN',
      'Altas luces',
      'REGLAS',
      'Nunca por encima de zona VI',
      'SENSACIONES',
      'QUÉ DICE CADA COLOR',
      'La culpa heredada',
    ];
    var cursor = -1;
    for (final piece in expected) {
      final at = text.indexOf(piece, cursor + 1);
      expect(at, greaterThan(cursor), reason: '«$piece» falta o va antes');
      cursor = at;
    }
    expect(text.toUpperCase(), contains('ASFIXIA'));
    expect(text, isNot(contains('{"')));
  });

  test('las secciones salen en el orden de la biblia', () async {
    for (final sectionId in [
      BibleSectionId.direction,
      BibleSectionId.concept,
    ]) {
      await addPoint(
        sectionId,
        BibleSectionField(key: 'field_$sectionId', label: 'Nota propia'),
        _marker(sectionId),
      );
    }

    var text = _extract(await export());
    expect(
      text.indexOf(_marker(BibleSectionId.direction)),
      lessThan(text.indexOf(_marker(BibleSectionId.concept))),
    );

    await db.reorderBibleSectionsInGroup(bibleId, BibleLayoutGroup.narrative, [
      BibleSectionId.concept,
      BibleSectionId.direction,
    ]);
    text = _extract(await export());
    expect(
      text.indexOf(_marker(BibleSectionId.concept)),
      lessThan(text.indexOf(_marker(BibleSectionId.direction))),
    );
  });

  test('una pantalla personalizada sale en el PDF con su nombre', () async {
    await db.insertCustomBibleSection(
      bibleId: bibleId,
      groupId: BibleLayoutGroup.narrative,
      label: 'Vestuario y piel',
      contentJson: BibleSectionFieldsConfig.encode(
        const [
          BibleSectionField(key: 'body', label: 'Contenido'),
          BibleSectionField(
            key: 'tonos',
            label: 'Tonos',
            type: BibleSectionFieldType.list,
          ),
        ],
        values: {
          'body': 'Tejidos mates para evitar brillos',
          'tonos': jsonEncode(['Ocre', 'Azul petróleo']),
        },
      ),
    );

    final text = _extract(await export());
    expect(text, contains('VESTUARIO Y PIEL'));
    expect(text, contains('Tejidos mates para evitar brillos'));
    expect(text, contains('Azul petróleo'));
  });

  test('blobRows no repite los valores de los puntos propios', () async {
    await addPoint(
      BibleSectionId.optics,
      const BibleSectionField(key: 'field_x', label: 'Nota propia'),
      'VALOR-UNICO',
    );
    final bundle = await VisualBibleRepository(
      VisualBibleDao(db),
    ).loadExportBundle(projectId: projectId);
    final json = bundle.sectionContentJsonById[BibleSectionId.optics];
    expect(
      BibleSectionExportReader.blobRows(
        json,
        BibleSectionId.optics,
      ).where((row) => row.value.contains('VALOR-UNICO')),
      isEmpty,
    );
    expect(
      BibleSectionExportReader.userPoints(json, BibleSectionId.optics),
      hasLength(1),
    );
  });
}
