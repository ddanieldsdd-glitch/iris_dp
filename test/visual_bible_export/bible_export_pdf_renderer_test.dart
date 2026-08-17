import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/visual_bible/bible_block_catalog.dart';
import 'package:iris_dp/features/visual_bible/export/model/bible_export_composition.dart';
import 'package:iris_dp/features/visual_bible/export/pdf/bible_export_pdf_renderer.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_block.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_export_config.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String normalized(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  final now = DateTime.utc(2026, 8, 8);
  final config = VisualBibleExportConfig(
    id: 'pdf-renderer',
    name: 'Entrega PDF',
    audience: VisualBibleExportAudience.general,
    mode: VisualBibleExportMode.full,
    sections: const {},
    destination: VisualBibleExportDestination.saveFile,
    updatedAt: now,
  );

  BibleExportComposition composition(List<BibleExportPage> pages) =>
      BibleExportComposition(
        id: 'composition',
        projectId: 10,
        config: config,
        pages: pages,
        createdAt: now,
        updatedAt: now,
      );

  BibleExportPage textPage({
    required String id,
    required String label,
    required int sortOrder,
    BibleExportPageFormat format = BibleExportPageFormat.a4Portrait,
  }) => BibleExportPage(
    id: id,
    label: label,
    type: BibleExportPageType.generated,
    sortOrder: sortOrder,
    format: format,
    blocks: [
      BibleBlock(
        id: '$id-text',
        type: BibleBlockKind.text,
        content: {'text': label},
      ),
    ],
  );

  test('genera A4, respeta landscape, orden y página blank', () async {
    final bytes = await BibleExportPdfRenderer().buildBytes(
      composition([
        textPage(
          id: 'landscape',
          label: 'TERCERA LANDSCAPE',
          sortOrder: 2,
          format: BibleExportPageFormat.a4Landscape,
        ),
        const BibleExportPage(
          id: 'blank',
          label: 'ESTO NO DEBE RENDERIZARSE',
          type: BibleExportPageType.blank,
          sortOrder: 1,
        ),
        textPage(id: 'portrait', label: 'PRIMERA A4', sortOrder: 0),
      ]),
    );

    final pdf = sf.PdfDocument(inputBytes: bytes);
    addTearDown(pdf.dispose);

    expect(pdf.pages.count, 3);
    expect(pdf.pages[0].size.width, closeTo(595.28, 0.5));
    expect(pdf.pages[0].size.height, closeTo(841.89, 0.5));
    expect(pdf.pages[2].size.width, closeTo(841.89, 0.5));
    expect(pdf.pages[2].size.height, closeTo(595.28, 0.5));

    final extractor = sf.PdfTextExtractor(pdf);
    expect(
      normalized(extractor.extractText(startPageIndex: 0, endPageIndex: 0)),
      contains('PRIMERA A4'),
    );
    expect(
      extractor.extractText(startPageIndex: 1, endPageIndex: 1).trim(),
      isEmpty,
    );
    expect(
      normalized(extractor.extractText(startPageIndex: 2, endPageIndex: 2)),
      contains('TERCERA LANDSCAPE'),
    );
  });

  test('superpone post-it y trazos vectoriales', () async {
    final source = composition([
      textPage(id: 'annotated', label: 'PÁGINA ANOTADA', sortOrder: 0),
    ]);
    const annotation = AnnotationDocument(
      strokes: [
        AnnotationStroke(
          id: 'stroke',
          tool: AnnotationToolType.pen,
          colorArgb: 0xFF0066FF,
          width: 4,
          points: [
            AnnotationPoint(x: 0.1, y: 0.1),
            AnnotationPoint(x: 0.8, y: 0.8),
          ],
        ),
      ],
      notes: [
        AnnotationNote(
          id: 'note',
          text: 'NOTA PDF VISIBLE',
          x: 0.55,
          y: 0.1,
          width: 0.25,
          height: 0.12,
          colorArgb: 0xFFFFE082,
        ),
      ],
    );
    final renderer = BibleExportPdfRenderer();
    final plain = await renderer.buildBytes(source);
    final annotated = await renderer.buildBytes(
      source,
      annotationsByPage: const {'annotated': annotation},
    );

    final pdf = sf.PdfDocument(inputBytes: annotated);
    addTearDown(pdf.dispose);
    expect(
      normalized(sf.PdfTextExtractor(pdf).extractText()),
      contains('NOTA PDF VISIBLE'),
    );
    expect(annotated.length, greaterThan(plain.length));
  });

  test('carga anotaciones de cada página desde AppDatabase', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final projectId = await database.insertProject(
      ProjectsCompanion.insert(name: 'Proyecto PDF'),
    );
    const annotation = AnnotationDocument(
      notes: [
        AnnotationNote(
          id: 'database-note',
          text: 'NOTA DESDE DATABASE',
          x: 0.1,
          y: 0.1,
          width: 0.3,
          height: 0.1,
          colorArgb: 0xFFFFE082,
        ),
      ],
    );
    await database.saveProjectAnnotationDocument(
      projectId: projectId,
      targetType: kBibleExportAnnotationTargetType,
      targetId: 'database-page',
      documentJson: annotation.encode(),
      documentSchemaVersion: annotation.schemaVersion,
    );
    final source = BibleExportComposition(
      id: 'database-composition',
      projectId: projectId,
      config: config,
      pages: [
        textPage(id: 'database-page', label: 'Página persistida', sortOrder: 0),
      ],
      createdAt: now,
      updatedAt: now,
    );

    final bytes = await BibleExportPdfRenderer(
      database: database,
    ).buildBytes(source);
    final pdf = sf.PdfDocument(inputBytes: bytes);
    addTearDown(pdf.dispose);

    expect(
      normalized(sf.PdfTextExtractor(pdf).extractText()),
      contains('NOTA DESDE DATABASE'),
    );
  });

  test('renderiza los kinds principales y fallback dinámico', () async {
    const page = BibleExportPage(
      id: 'blocks',
      label: 'Bloques',
      type: BibleExportPageType.generated,
      blocks: [
        BibleBlock(
          id: 'narrative',
          type: BibleBlockKind.narrative,
          content: {'text': 'Luz íntima'},
        ),
        BibleBlock(
          id: 'image',
          type: BibleBlockKind.heroImage,
          content: {'path': '/imagen/inexistente.jpg'},
        ),
        BibleBlock(
          id: 'moodboard',
          type: BibleBlockKind.moodboardRefs,
          content: {'images': <String>[]},
        ),
        BibleBlock(
          id: 'palette',
          type: BibleBlockKind.colorPalette,
          content: {
            'colors': [
              {'hex': '#FF8800', 'name': 'Ámbar'},
            ],
          },
        ),
        BibleBlock(
          id: 'telemetry',
          type: BibleBlockKind.telemetry,
          content: {'kelvin': '3200K', 'ratio': '4:1', 'ire': '55'},
        ),
        BibleBlock(
          id: 'equipment',
          type: BibleBlockKind.equipmentList,
          content: {
            'items': ['Fresnel 2K'],
          },
        ),
        BibleBlock(
          id: 'specs',
          type: BibleBlockKind.specsTable,
          content: {
            'columns': ['label', 'value'],
            'rows': [
              {'label': 'Sensor', 'value': 'S35'},
            ],
          },
        ),
        BibleBlock(
          id: 'workflow',
          type: BibleBlockKind.workflowPipeline,
          content: {
            'steps': ['Rodaje', 'DIT'],
          },
        ),
        BibleBlock(
          id: 'lighting',
          type: BibleBlockKind.lightingDiagram,
          content: {
            'label': 'Key window',
            'nodes': [
              {'type': 'key', 'x': 100, 'y': 80},
            ],
          },
        ),
        BibleBlock(
          id: 'dynamic',
          type: BibleBlockKind.dynamicBlocks,
          content: {
            'items': ['Look A'],
          },
        ),
      ],
    );

    final bytes = await BibleExportPdfRenderer(
      imageLoader: (path, {maxEdge = 2048}) async => null,
    ).buildBytes(composition([page]));
    final pdf = sf.PdfDocument(inputBytes: bytes);
    addTearDown(pdf.dispose);
    final text = normalized(sf.PdfTextExtractor(pdf).extractText());

    expect(bytes.take(4), orderedEquals('%PDF'.codeUnits));
    expect(text, contains('Luz íntima'));
    expect(text, contains('Imagen no disponible'));
    expect(text, contains('Moodboard sin imágenes'));
    expect(text, contains('3200K'));
    expect(text, contains('Fresnel 2K'));
    expect(text, contains('S35'));
    expect(text, contains('Rodaje'));
    expect(text.toUpperCase(), contains('KEY WINDOW'));
    expect(text, contains('Look A'));
  });

  test('omite bloque narrative vacío (sin comillas literales)', () async {
    const page = BibleExportPage(
      id: 'empty-narrative',
      label: 'Cámara',
      type: BibleExportPageType.generated,
      blocks: [
        BibleBlock(
          id: 'narrative-empty',
          type: BibleBlockKind.narrative,
          content: {'text': '   '},
        ),
        BibleBlock(
          id: 'body',
          type: BibleBlockKind.text,
          content: {'text': 'CUERPO VISIBLE'},
        ),
      ],
    );

    final bytes = await BibleExportPdfRenderer().buildBytes(
      composition([page]),
    );
    final pdf = sf.PdfDocument(inputBytes: bytes);
    addTearDown(pdf.dispose);
    final text = normalized(sf.PdfTextExtractor(pdf).extractText());

    expect(text, contains('CUERPO VISIBLE'));
    expect(text, isNot(contains('""')));
  });

  test('cada kind live tiene renderer PDF (sin fallback genérico)', () async {
    final live = BibleBlockKind.values
        .where((k) => k.status == BibleBlockStatus.live)
        .toList();
    final page = BibleExportPage(
      id: 'live-kinds',
      label: 'Live',
      type: BibleExportPageType.generated,
      blocks: [
        for (final kind in live)
          BibleBlock(id: kind.name, type: kind, content: _livePdfContent(kind)),
      ],
    );
    final bytes = await BibleExportPdfRenderer(
      imageLoader: (path, {maxEdge = 2048}) async => null,
    ).buildBytes(composition([page]));
    final pdf = sf.PdfDocument(inputBytes: bytes);
    addTearDown(pdf.dispose);
    final text = normalized(sf.PdfTextExtractor(pdf).extractText());

    expect(text, contains('CITA LIVE'));
    expect(text, contains('TAGLIVE'));
    expect(text, contains('CÁMARA'));
    expect(text, contains('3200K'));
    expect(text, isNot(contains('Campo de texto')));
  });
}

Map<String, dynamic> _livePdfContent(BibleBlockKind kind) => switch (kind) {
  BibleBlockKind.narrative => {'text': 'CITA LIVE'},
  BibleBlockKind.text => {'text': 'Texto live'},
  BibleBlockKind.chipSelect => {
    'chips': ['TAGLIVE'],
  },
  BibleBlockKind.telemetry => {'kelvin': '3200K'},
  BibleBlockKind.workflowPipeline => const {'steps': <String>[]},
  BibleBlockKind.colorPalette => {
    'colors': [
      {'hex': '#111111', 'name': 'INK'},
    ],
  },
  BibleBlockKind.equipmentList => {
    'items': ['HMI'],
  },
  BibleBlockKind.specsTable => {
    'columns': ['label', 'value'],
    'rows': [
      {'label': 'ISO', 'value': '800'},
    ],
  },
  BibleBlockKind.moodboardRefs => {'images': <String>[]},
  BibleBlockKind.heroImage => {'path': '/missing.jpg'},
  BibleBlockKind.lightingDiagram => {
    'label': 'Planta live',
    'nodes': [
      {'type': 'key', 'x': 10, 'y': 10},
    ],
  },
  BibleBlockKind.dynamicBlocks => {'items': ['x']},
};
