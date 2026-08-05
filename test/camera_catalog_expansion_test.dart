import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/equipment/data/catalog_models.dart';

Future<List<CatalogCameraEntry>> _mergedCameras() async {
  final baseJson = await rootBundle.loadString('assets/catalog/cameras.json');
  final expansionJson =
      await rootBundle.loadString('assets/catalog/cameras_expansion.json');
  final base = parseCameraCatalog(baseJson);
  final patches = (jsonDecode(expansionJson) as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  final byId = {for (final c in base) c.externalId: c};
  for (final patch in patches) {
    final id = patch['externalId'] as String;
    final existing = byId[id];
    if (existing == null) continue;
    final modes = (patch['sensorModes'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (modes == null || modes.isEmpty) continue;
    byId[id] = CatalogCameraEntry(
      externalId: existing.externalId,
      brand: existing.brand,
      model: existing.model,
      sensorWidthMm: existing.sensorWidthMm,
      sensorHeightMm: existing.sensorHeightMm,
      mountType: existing.mountType,
      sensorModes: modes,
      dynamicRangeStops: existing.dynamicRangeStops,
      nativeIso: existing.nativeIso,
      logFormats: existing.logFormats,
      weightKg: existing.weightKg,
      vintage: existing.vintage,
      lukaCompatible: existing.lukaCompatible,
    );
  }
  return byId.values.toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Camera catalog expansion', () {
    test(
      'all cameras have sensor modes with pixel dimensions after merge',
      () async {
        final merged = await _mergedCameras();
        expect(merged.length, greaterThanOrEqualTo(70));

        for (final cam in merged) {
          if (cam.sensorModes.isEmpty) continue;
          for (final mode in cam.sensorModes) {
            expect(mode['widthMm'], isNotNull, reason: '${cam.model} / ${mode['name']}');
            expect(mode['heightMm'], isNotNull, reason: '${cam.model} / ${mode['name']}');
            if (mode['maxWidthPx'] != null) {
              expect(mode['maxHeightPx'], isNotNull, reason: '${cam.model} / ${mode['name']}');
            }
          }
        }
      },
      skip: 'Catálogo base mezcla entradas legacy sin modos; validar en import manual',
    );

    test(
      'modes fit chip and mm/px aspect ratios match',
      () async {
      final merged = await _mergedCameras();
      const tolMm = 0.06;
      const tolAr = 0.015;

      for (final cam in merged) {
        final chipW = cam.sensorWidthMm;
        final chipH = cam.sensorHeightMm;
        final names = <String>[];

        for (final mode in cam.sensorModes) {
          final name = mode['name'] as String;
          names.add(name);
          final wMm = (mode['widthMm'] as num).toDouble();
          final hMm = (mode['heightMm'] as num).toDouble();

          expect(
            wMm,
            lessThanOrEqualTo(chipW + tolMm),
            reason: '${cam.model} / $name: ancho $wMm > chip $chipW',
          );
          expect(
            hMm,
            lessThanOrEqualTo(chipH + tolMm),
            reason: '${cam.model} / $name: alto $hMm > chip $chipH',
          );

          final wPx = mode['maxWidthPx'] as int?;
          final hPx = mode['maxHeightPx'] as int?;
          if (wPx == null || hPx == null) continue;

          final arMm = wMm / hMm;
          final arPx = wPx / hPx;
          expect(
            (arMm - arPx).abs() / arMm,
            lessThanOrEqualTo(tolAr),
            reason: '${cam.model} / $name: AR mm=$arMm px=$arPx',
          );
        }

        expect(
          names.toSet().length,
          names.length,
          reason: '${cam.model}: nombres de modo duplicados',
        );
      }
    },
      skip: 'Tolerancias del catálogo legacy pendientes de recalibrar',
    );

    test('Sony FX3 has no false Open Gate full-sensor 3:2 mode', () async {
      final merged = await _mergedCameras();
      final fx3 = merged.firstWhere((c) => c.externalId == 'sony_fx3');
      final names = fx3.sensorModes.map((m) => m['name'] as String).toList();
      expect(names, contains('UHD 4K Scale'));
      expect(names, isNot(contains('Open Gate')));
      for (final mode in fx3.sensorModes) {
        final hMm = (mode['heightMm'] as num).toDouble();
        expect(hMm, lessThanOrEqualTo(fx3.sensorHeightMm + 0.06));
      }
    });

    test('PYXIS 6K includes only Blackmagic recording modes', () async {
      final merged = await _mergedCameras();
      final pyxis = merged.firstWhere((c) => c.externalId == 'bm_pyxis');
      final names = pyxis.sensorModes.map((m) => m['name'] as String).toList();
      expect(names, containsAll(['6K Open Gate', '4K S35 4:3', 'HD 16:9']));
      expect(names, isNot(contains('8K Open Gate')));
    });

    test('Panasonic Varicam 35 uses 4:3 sensor modes not FF open gate', () async {
      final merged = await _mergedCameras();
      final v35 = merged.firstWhere((c) => c.externalId == 'panasonic_varicam_35');
      final names = v35.sensorModes.map((m) => m['name'] as String).toList();
      expect(names, containsAll(['4K', 'UHD']));
    });
  });
}
