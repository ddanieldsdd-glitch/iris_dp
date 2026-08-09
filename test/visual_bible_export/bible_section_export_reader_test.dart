import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/export/bible_section_export_reader.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

void main() {
  group('BibleSectionExportReader', () {
    test('parsea cameraData y genera filas exportables', () {
      final contentJson = BibleSectionFieldsConfig.encode(
        BibleSectionFieldsConfig.defaultsFor(BibleSectionId.camera),
        values: {
          'cameraData': jsonEncode({
            'isoNote': '800 base',
            'bitDepth': '10-bit',
            'colorSpace': 'LogC3',
          }),
        },
      );

      final custom = BibleSectionExportReader.parseCustomBlob(
        contentJson,
        BibleSectionId.camera,
      );
      final rows = BibleSectionExportReader.rowsForSection(
        BibleSectionId.camera,
        custom,
      );

      expect(custom['isoNote'], '800 base');
      expect(rows.map((row) => row.label), contains('Nota ISO'));
      expect(rows.firstWhere((row) => row.label == 'Nota ISO').value, '800 base');
    });

    test('aplaniza byPlan de location con prefijo de set', () {
      final contentJson = BibleSectionFieldsConfig.encode(
        BibleSectionFieldsConfig.defaultsFor(BibleSectionId.location),
        values: {
          'locationData': jsonEncode({
            'byPlan': {
              '12': {'weather': 'Lluvia', 'coords': '41.38, 2.17'},
            },
          }),
        },
      );

      final custom = BibleSectionExportReader.parseCustomBlob(
        contentJson,
        BibleSectionId.location,
      );
      final rows = BibleSectionExportReader.rowsForSection(
        BibleSectionId.location,
        custom,
      );

      expect(
        rows.any(
          (row) => row.label.contains('Set 12') && row.value == 'Lluvia',
        ),
        isTrue,
      );
    });

    test('hasExportableContent es false para blob vacío', () {
      expect(
        BibleSectionExportReader.hasExportableContent(
          BibleSectionId.camera,
          const {},
        ),
        isFalse,
      );
    });

    test('parsea opticsConfigJson con listas anidadas', () {
      final rows = BibleSectionExportReader.rowsFromOpticsConfigJson(
        jsonEncode({
          'styleSubtitle': 'FASE1-OPTICS-STYLE',
          'tStop': 'T2.8',
          'filtrationStack': [
            {
              'name': 'FASE1-OPTICS-FILTER',
              'density': '1/4',
              'justification': 'Suavizar piel en primeros planos',
            },
          ],
          'anamorphicSpecs': [
            {
              'focalLength': 'FASE1-OPTICS-FOCAL-40',
              'tStop': 'T2.0',
              'cfd': '12"',
              'distortion': 'Low',
            },
          ],
          'maintenanceLog': [
            {
              'title': 'FASE1-OPTICS-MAINT',
              'date': '2026-08-09',
              'description': 'Calibración de back focus',
            },
          ],
          'lensSets': [
            {
              'name': 'FASE1-OPTICS-SET-A',
              'isAnamorphic': true,
              'squeezeRatio': 2.0,
              'aspectRatio': '2.39:1',
            },
          ],
        }),
        narrativeIntent: 'FASE1-OPTICS-NARRATIVE',
      );

      final labels = rows.map((row) => row.label).join('\n');
      final values = rows.map((row) => row.value).join('\n');
      final all = '$labels\n$values';
      expect(labels, contains('Filtración · FASE1-OPTICS-FILTER'));
      expect(all, contains('FASE1-OPTICS-FOCAL-40'));
      expect(all, contains('FASE1-OPTICS-MAINT'));
      expect(all, contains('FASE1-OPTICS-SET-A'));
      expect(all, contains('FASE1-OPTICS-NARRATIVE'));
    });
  });
}
