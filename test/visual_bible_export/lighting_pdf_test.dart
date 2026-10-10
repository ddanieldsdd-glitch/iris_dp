import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/dao/visual_bible_dao.dart';
import 'package:iris_dp/features/visual_bible/data/visual_bible_repository.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_pdf_service.dart';
import 'package:iris_dp/shared/visual_bible/lighting_metrics.dart';
import 'package:iris_dp/shared/visual_bible/narrative_card_kind.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el PDF de Iluminación lleva cada ficha con sus puntos', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Luz'),
    );
    final bible = await db.ensureVisualBibleForProject(projectId);
    await db.addBuiltinBibleSection(
      bibleId: bible.id,
      sectionId: BibleSectionId.lighting,
    );
    await db.saveBibleSectionFieldValue(
      bible.id,
      BibleSectionId.lighting,
      'lightingData',
      jsonEncode({
        'metrics': const LightingMetrics(
          kelvin: 3200,
          ratio: 4,
          sourceKelvin: 5600,
        ).toJson(),
        'fixtureTypes': ['Tubos LED'],
      }),
    );
    Future<void> card(
      String kind,
      String title, {
      String? body,
      Map<String, dynamic> meta = const {},
    }) => db.insertNarrativeCard(
      VisualBibleNarrativeCardsCompanion.insert(
        bibleId: bible.id,
        sectionId: BibleSectionId.lighting,
        kind: kind,
        title: title,
        body: Value(body),
        metaJson: Value(meta.isEmpty ? null : jsonEncode(meta)),
      ),
    );
    await card(
      NarrativeCardKind.style,
      'Niebla y luz rota',
      body: 'La niebla hace visible la luz',
      meta: {
        'points': [
          {
            'title': 'Niebla con luz dura',
            'kicker': 'CONTRASTE 16:1',
            'body': 'Fuentes pequeñas y lejanas',
          },
        ],
      },
    );
    await card(
      NarrativeCardKind.locationLight,
      'KEBAB KHALED',
      body: 'Fluorescente verdoso y neón',
      meta: {
        'light': LightingMetrics(
          colorMode: true,
          ratio: 8,
          colors: const [
            LightColor(rgb: 0xFF1FA2, name: 'Magenta'),
            LightColor(rgb: 0x19E3FF, name: 'Cian', role: LightColorRole.fill),
          ],
        ).toJson(),
      },
    );
    // Una ficha vacía no debe ocupar sitio.
    await card(NarrativeCardKind.locationLight, 'RELLANO VACÍO');

    final repo = VisualBibleRepository(VisualBibleDao(db));
    final bundle = await repo.loadExportBundle(projectId: projectId);
    bundle.data.lightingPhilosophy = 'Luz motivada por lo que hay';

    final bytes = await VisualBiblePdfService.buildBytes(
      mode: VisualBibleExportMode.full,
      projectName: 'Luz',
      director: null,
      data: bundle.data,
      colorBlocks: bundle.blocks,
      exposureBlocks: bundle.exposureBlocks,
      lightingSetups: bundle.lightingSetups,
      cameraTests: bundle.cameraTests,
      moodboard: bundle.moodboard,
      sectionContentJsonById: bundle.sectionContentJsonById,
      sectionOrder: bundle.sectionOrder,
      lightingCards: bundle.narrativeCards,
    );
    final out = Directory('build/lighting_pdf')..createSync(recursive: true);
    File('${out.path}/iluminacion.pdf').writeAsBytesSync(bytes);

    final text = _extract(bytes);
    final expected = [
      'Luz motivada por lo que hay',
      '3200 K',
      '4:1',
      'CTO',
      'TUBOS LED',
      'IDEAS DE LUZ',
      'Niebla y luz rota',
      'La niebla hace visible la luz',
      'Niebla con luz dura',
      'Fuentes pequeñas y lejanas',
      'LUZ POR LOCALIZACIÓN',
      'KEBAB KHALED',
      'Fluorescente verdoso y neón',
      '8:1',
      'MAGENTA',
      'R 255',
    ];
    var cursor = -1;
    for (final piece in expected) {
      final at = text.indexOf(piece, cursor + 1);
      expect(at, greaterThan(cursor), reason: '«$piece» falta o va antes');
      cursor = at;
    }
    expect(text, isNot(contains('RELLANO VACÍO')));
    expect(text, isNot(contains('REFERENCIAS DE CINE')), reason: 'no hay');
  });
}
