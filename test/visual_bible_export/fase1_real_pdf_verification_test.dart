import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/dao/visual_bible_dao.dart';
import 'package:iris_dp/features/visual_bible/data/visual_bible_repository.dart';
import 'package:iris_dp/features/visual_bible/export/builder/bible_export_composition_builder.dart';
import 'package:iris_dp/features/visual_bible/export/pdf/bible_export_pdf_renderer.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_export_config.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_pdf_service.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

/// Marcadores únicos para verificación visual/textual del PDF generado.
const fase1MarkerCameraIso = 'FASE1-CAM-ISO-6400';
const fase1MarkerCameraBit = 'FASE1-CAM-BIT-12';
const fase1MarkerLocationWeather = 'FASE1-LOC-WEATHER-TORMENTA';
const fase1MarkerLocationCoords = 'FASE1-LOC-COORDS-41.38';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('genera PDFs reales clásico y compositor con custom camera + location', () async {
    final outDir = Directory('build/fase1_verification');
    outDir.createSync(recursive: true);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final projectId = await db.insertProject(
      ProjectsCompanion.insert(
        name: 'Verificación Fase 1 Export',
        director: const Value('Director Prueba'),
      ),
    );
    final bible = await db.ensureVisualBibleForProject(projectId);
    await db.addBuiltinBibleSection(
      bibleId: bible.id,
      sectionId: BibleSectionId.camera,
    );
    await db.addBuiltinBibleSection(
      bibleId: bible.id,
      sectionId: BibleSectionId.location,
    );

    final cameraContent = BibleSectionFieldsConfig.encode(
      BibleSectionFieldsConfig.defaultsFor(BibleSectionId.camera),
      values: {
        'cameraData': jsonEncode({
          'isoNote': fase1MarkerCameraIso,
          'bitDepth': fase1MarkerCameraBit,
          'colorSpace': 'LogC4',
          'dualIso': 'Sí',
          'editorialCaption': 'EXT. NIGHT — CHECKPOINT',
        }),
      },
    );
    final locationContent = BibleSectionFieldsConfig.encode(
      BibleSectionFieldsConfig.defaultsFor(BibleSectionId.location),
      values: {
        'locationData': jsonEncode({
          'byPlan': {
            '99': {
              'weather': fase1MarkerLocationWeather,
              'coords': fase1MarkerLocationCoords,
              'locLabel': 'LOC-A',
              'strategy': 'Rodar en golden hour',
            },
          },
        }),
      },
    );

    for (final sectionId in [BibleSectionId.camera, BibleSectionId.location]) {
      final def = await (db.select(db.bibleSectionDefinitions)
            ..where(
              (d) => d.bibleId.equals(bible.id) & d.id.equals(sectionId),
            ))
          .getSingle();
      await db.upsertBibleSectionDefinition(
        def.copyWith(
          contentJson: Value(
            sectionId == BibleSectionId.camera ? cameraContent : locationContent,
          ),
        ),
      );
    }

    final repo = VisualBibleRepository(VisualBibleDao(db));
    final bundle = await repo.loadExportBundle(projectId: projectId);
    final now = DateTime.utc(2026, 8, 9, 10);

    final config = VisualBibleExportConfig(
      id: 'fase1-verify',
      name: 'Verificación Fase 1',
      audience: VisualBibleExportAudience.general,
      mode: VisualBibleExportMode.full,
      sections: {
        BibleSectionId.camera,
        BibleSectionId.location,
        BibleSectionId.exposure,
      },
      destination: VisualBibleExportDestination.saveFile,
      updatedAt: now,
    );

    final classicBytes = await VisualBiblePdfService.buildBytes(
      mode: config.mode,
      projectName: 'Verificación Fase 1 Export',
      director: 'Director Prueba',
      data: bundle.data,
      colorBlocks: bundle.blocks,
      exposureBlocks: bundle.exposureBlocks,
      lightingSetups: bundle.lightingSetups,
      cameraTests: bundle.cameraTests,
      moodboard: bundle.moodboard,
      includedSections: config.sections,
      sectionContentJsonById: bundle.sectionContentJsonById,
    );
    final classicPath = File('${outDir.path}/classic_export.pdf');
    await classicPath.writeAsBytes(classicBytes);

    final composition = BibleExportCompositionBuilder(
      idFactory: () => 'fase1-composition',
      clock: () => now,
    ).build(
      projectId: projectId,
      config: config,
      bundle: bundle,
      includeCover: true,
    );
    final composerBytes = await BibleExportPdfRenderer(database: db).buildBytes(
      composition,
    );
    final composerPath = File('${outDir.path}/composer_export.pdf');
    await composerPath.writeAsBytes(composerBytes);

    expect(classicPath.existsSync(), isTrue);
    expect(composerPath.existsSync(), isTrue);
    expect(classicBytes.length, greaterThan(1000));
    expect(composerBytes.length, greaterThan(1000));

    // Extracción textual real (el binario PDF comprime streams; latin1 directo no sirve).
    final classicExtracted = await _extractPdfText(classicPath);
    final composerExtracted = await _extractPdfText(composerPath);

    for (final marker in [
      fase1MarkerCameraIso,
      fase1MarkerCameraBit,
      fase1MarkerLocationWeather,
      fase1MarkerLocationCoords,
    ]) {
      expect(
        classicExtracted.contains(marker),
        isTrue,
        reason: 'PDF clásico debe contener $marker',
      );
      expect(
        composerExtracted.contains(marker),
        isTrue,
        reason: 'PDF compositor debe contener $marker',
      );
    }

    expect(classicExtracted.toUpperCase(), contains('LOCALIZACIÓN'));
    expect(composerExtracted, contains('Localización'));

    // Escribir manifiesto para revisión humana.
    await File('${outDir.path}/VERIFICATION.txt').writeAsString('''
PDFs generados para checkpoint Fase 1
Classic: ${classicPath.absolute.path}
Composer: ${composerPath.absolute.path}

Marcadores esperados en ambos PDFs:
- $fase1MarkerCameraIso (Nota ISO / cámara)
- $fase1MarkerCameraBit (Bit depth / cámara)
- $fase1MarkerLocationWeather (Clima / localización set 99)
- $fase1MarkerLocationCoords (Coordenadas / localización set 99)

Abrir los PDFs y confirmar sección LOCALIZACIÓN + campos custom de cámara.
''');
  });
}

Future<String> _extractPdfText(File pdf) async {
  final venvPython = File('.venv_pdf/bin/python');
  if (!venvPython.existsSync()) {
    // Fallback mínimo si no hay venv (p.ej. CI): comprueba marcadores en binario sin garantía.
    return latin1.decode(await pdf.readAsBytes(), allowInvalid: true);
  }
  final result = await Process.run(
    venvPython.path,
    [
      '-c',
      'from pypdf import PdfReader; import sys; r=PdfReader(sys.argv[1]); print("\\n".join((p.extract_text() or "") for p in r.pages))',
      pdf.path,
    ],
    runInShell: true,
  );
  if (result.exitCode != 0) {
    throw StateError('No se pudo extraer texto del PDF: ${result.stderr}');
  }
  return result.stdout as String;
}
