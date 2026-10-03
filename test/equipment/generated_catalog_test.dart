import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/shared/equipment/catalog_data_status.dart';
import 'package:iris_dp/shared/equipment/catalog_importer.dart';
import 'package:iris_dp/shared/equipment/catalog_models.dart';

/// Comprueba el catálogo que genera `tools/build_catalog.py`.
void main() {
  final cameras = parseCameraCatalog(
    File('assets/catalog/cameras.json').readAsStringSync(),
  );
  final lenses = parseLensCatalog(
    File('assets/catalog/lenses.json').readAsStringSync(),
  );
  final lights = parseLightCatalog(
    File('assets/catalog/lights.json').readAsStringSync(),
  );
  CatalogLensEntry lens(String id) =>
      lenses.singleWhere((l) => l.externalId == id);

  test('el manifiesto y la versión embebida coinciden', () {
    final manifest = CatalogManifest.fromJson(
      jsonDecode(File('assets/catalog/manifest.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    expect(manifest.version, kEmbeddedCatalogVersion);
  });

  test('todas las fichas se leen, con identidad única y estado', () {
    expect(cameras.length, greaterThanOrEqualTo(72));
    expect(lenses.length, greaterThanOrEqualTo(440));
    expect(lights.length, greaterThanOrEqualTo(100));
    for (final ids in [
      cameras.map((c) => c.externalId),
      lenses.map((l) => l.externalId),
      lights.map((l) => l.externalId),
    ]) {
      expect(ids.toSet().length, ids.length);
    }
    expect(cameras.every((c) => c.provenance != null), isTrue);
    expect(lenses.every((l) => l.provenance != null), isTrue);
    expect(lights.every((l) => l.provenance != null), isTrue);
  });

  test('todo modo de sensor tiene nombre y gate', () {
    for (final camera in cameras) {
      for (final mode in camera.sensorModes) {
        expect(mode['name'], isNotNull, reason: camera.externalId);
        expect(mode['widthMm'], isA<num>(), reason: '${camera.externalId}');
        expect(mode['heightMm'], isA<num>(), reason: '${camera.externalId}');
      }
    }
    final alexa35 = cameras.singleWhere((c) => c.externalId == 'arri_alexa35');
    final openGate = alexa35.sensorModes.firstWhere(
      (m) => m['name'] == '4.6K 3:2 Open Gate',
    );
    expect(openGate['codec'], isNotNull);
    expect(openGate['fpsMax'], 120);
    expect(openGate['dataStatus'], 'CONFIRMADO');
  });

  test('el círculo de imagen solo aparece con fuente', () {
    final withCircle = lenses.where((l) => l.imageCircleMm != null).toList();
    expect(withCircle, isNotEmpty);
    expect(withCircle.length, lessThan(lenses.length ~/ 2));
    for (final l in withCircle) {
      expect(
        l.provenance!.statusForField('image_circle_mm').usableInCalculations ||
            l.provenance!.status.usableInCalculations,
        isTrue,
        reason: l.externalId,
      );
    }
  });

  test('Signature Prime: círculo contrastado y ficha por focal del master',
      () {
    final sig47 = lens('arri_signature_47');
    expect(sig47.imageCircleMm, 46.3);
    expect(sig47.projectionType, 'ESFÉRICA');
    expect(sig47.closeFocusM, 0.45);
    expect(sig47.specs?['aovH'], '42.6°');
    expect(sig47.provenance!.status.usableInCalculations, isTrue);
    expect(sig47.provenance!.sourceUrl, startsWith('https://www.arri.com'));
    expect(
      sig47.provenance!.statusForField('image_circle_mm').calcUse,
      CatalogCalcUse.high,
    );
    expect(lens('arri_signature_200').minTStop, 2.5);
  });

  test('el squeeze solo existe en anamórficas', () {
    for (final l in lenses.where((l) => l.squeezeRatio != null)) {
      expect(l.isAnamorphic, isTrue, reason: l.externalId);
    }
    final masterAnamorphic = lens('zeiss_ma_50');
    expect(masterAnamorphic.squeezeRatio, 2);
    expect(masterAnamorphic.projectionType, 'ANAMÓRFICA');
  });

  group('import', () {
    late AppDatabase db;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
    });

    test('el catálogo generado guarda estado, fuente y ficha óptica',
        () async {
      await upsertCatalogLenses(db, lenses);
      final row = (await db.getLensByExternalId('arri_signature_47'))!;
      expect(row.imageCircleMm, 46.3);
      expect(row.projectionType, 'ESFÉRICA');
      expect(row.specsJson, contains('42.6'));
      final provenance = CatalogProvenance.fromColumns(
        dataStatus: row.dataStatus,
        verifiedFieldsJson: row.verifiedFieldsJson,
        sourceLabel: row.sourceLabel,
        sourceUrl: row.sourceUrl,
      );
      expect(provenance.status.usableInCalculations, isTrue);
      expect(provenance.verifiedFields, contains('image_circle_mm'));
    });

    test('reemplazar limpia un círculo inferido; fusionar no pisa con vacíos',
        () async {
      const id = 'prueba_lente';
      CatalogLensEntry entry({double? circle, String? mount}) =>
          CatalogLensEntry(
            externalId: id,
            brand: 'Prueba',
            model: 'Lente 50mm',
            focalLength: 50,
            minTStop: 2,
            formatCoverage: 'S35',
            imageCircleMm: circle,
            mountType: mount,
          );

      await upsertCatalogLenses(db, [entry(circle: 31.2, mount: 'PL')]);
      await upsertCatalogLenses(db, [entry()], merge: true);
      var row = (await db.getLensByExternalId(id))!;
      expect(row.imageCircleMm, 31.2);
      expect(row.mountType, 'PL');

      await upsertCatalogLenses(db, [entry(mount: 'LPL')]);
      row = (await db.getLensByExternalId(id))!;
      expect(row.imageCircleMm, isNull);
      expect(row.mountType, 'LPL');
    });
  });
}
