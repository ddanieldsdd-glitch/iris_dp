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

/// Marcadores únicos para verificación visual/textual del PDF generado.
const fase1MarkerCameraIso = 'FASE1-CAM-ISO-6400';
const fase1MarkerCameraBit = 'FASE1-CAM-BIT-12';
const fase1MarkerLocationWeather = 'FASE1-LOC-WEATHER-TORMENTA';
const fase1MarkerLocationCoords = 'FASE1-LOC-COORDS-41.38';
const fase1MarkerLocationGoldenHour = 'FASE1-LOC-GOLDEN-0630';
const fase1MarkerOpticsFilter = 'FASE1-OPTICS-FILTER';
const fase1MarkerOpticsFocal = 'FASE1-OPTICS-FOCAL-40';
const fase1MarkerOpticsMaint = 'FASE1-OPTICS-MAINT';
const fase1MarkerOpticsSet = 'FASE1-OPTICS-SET-A';
const fase1MarkerOpticsNarrative = 'FASE1-OPTICS-NARRATIVE';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'genera PDFs reales clásico y compositor con camera, location y optics',
    () async {
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
      for (final sectionId in [
        BibleSectionId.camera,
        BibleSectionId.location,
        BibleSectionId.optics,
      ]) {
        await db.addBuiltinBibleSection(
          bibleId: bible.id,
          sectionId: sectionId,
        );
      }

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
                'goldenHour': fase1MarkerLocationGoldenHour,
                'palette': ['#112233', '#AABBCC'],
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
              sectionId == BibleSectionId.camera
                  ? cameraContent
                  : locationContent,
            ),
          ),
        );
      }

      await db.upsertVisualBible(
        VisualBiblesCompanion(
          id: Value(bible.id),
          projectId: Value(projectId),
          opticsConfigJson: Value(
            jsonEncode({
              'styleSubtitle': 'Minimalist Character',
              'tStop': 'T2.8',
              'filtrationStack': [
                {
                  'name': fase1MarkerOpticsFilter,
                  'density': '1/4',
                  'justification': 'Suavizar piel en primeros planos',
                },
              ],
              'anamorphicSpecs': [
                {
                  'focalLength': fase1MarkerOpticsFocal,
                  'tStop': 'T2.0',
                  'cfd': '12"',
                  'distortion': 'Low',
                },
              ],
              'maintenanceLog': [
                {
                  'title': fase1MarkerOpticsMaint,
                  'date': '2026-08-09',
                  'description': 'Calibración de back focus',
                },
              ],
              'lensSets': [
                {
                  'name': fase1MarkerOpticsSet,
                  'isAnamorphic': true,
                  'squeezeRatio': 2.0,
                  'aspectRatio': '2.39:1',
                },
              ],
            }),
          ),
          opticsNarrativeIntent: const Value(fase1MarkerOpticsNarrative),
        ),
      );

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
          BibleSectionId.optics,
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

      final classicExtracted = await _extractPdfText(classicPath);
      final composerExtracted = await _extractPdfText(composerPath);

      for (final marker in [
        fase1MarkerCameraIso,
        fase1MarkerCameraBit,
        fase1MarkerLocationWeather,
        fase1MarkerLocationCoords,
        fase1MarkerLocationGoldenHour,
        fase1MarkerOpticsFilter,
        fase1MarkerOpticsFocal,
        fase1MarkerOpticsMaint,
        fase1MarkerOpticsSet,
        fase1MarkerOpticsNarrative,
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
      expect(classicExtracted.toUpperCase(), contains('ÓPTICA'));
      expect(composerExtracted, contains('Localización'));
      expect(composerExtracted, contains('Óptica'));

      await File('${outDir.path}/VERIFICATION.txt').writeAsString('''
PDFs generados para checkpoint Fase 1 (cierre)
Classic: ${classicPath.absolute.path}
Composer: ${composerPath.absolute.path}

Marcadores esperados en ambos PDFs:
- Cámara: $fase1MarkerCameraIso, $fase1MarkerCameraBit
- Location: $fase1MarkerLocationWeather, $fase1MarkerLocationCoords, $fase1MarkerLocationGoldenHour
- Optics: $fase1MarkerOpticsFilter, $fase1MarkerOpticsFocal, $fase1MarkerOpticsMaint, $fase1MarkerOpticsSet, $fase1MarkerOpticsNarrative
''');
    },
  );
}

Future<String> _extractPdfText(File pdf) async {
  final venvPython = File('.venv_pdf/bin/python');
  if (!venvPython.existsSync()) {
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
