import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/shared/equipment/official_catalog_import.dart';

void main() {
  test('classifyOfficialCatalogJson por nombre y por forma', () {
    expect(
      classifyOfficialCatalogJson(
        fileName: 'cameras_modos_v1_7.json',
        jsonStr: '[]',
      ),
      OfficialCatalogJsonKind.cameras,
    );
    expect(
      classifyOfficialCatalogJson(
        fileName: 'lenses_v1_7.json',
        jsonStr: '[]',
      ),
      OfficialCatalogJsonKind.lenses,
    );
    expect(
      classifyOfficialCatalogJson(
        fileName: 'lights_v1_7.json',
        jsonStr: '[]',
      ),
      OfficialCatalogJsonKind.lights,
    );
    expect(
      classifyOfficialCatalogJson(
        fileName: 'pack.json',
        jsonStr: '[{"externalId":"x","sensorWidthMm":24.0,"sensorModes":[]}]',
      ),
      OfficialCatalogJsonKind.cameras,
    );
    expect(
      classifyOfficialCatalogJson(
        fileName: 'pack.json',
        jsonStr: '[{"externalId":"x","focalLength":35.0}]',
      ),
      OfficialCatalogJsonKind.lenses,
    );
    expect(
      classifyOfficialCatalogJson(
        fileName: 'pack.json',
        jsonStr: '[{"externalId":"x","lightType":"led_panel","powerW":100}]',
      ),
      OfficialCatalogJsonKind.lights,
    );
  });

  test('importOfficialCatalogJsonFiles importa packs v1.7 de docs/catalog', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final cameras = File('docs/catalog/cameras_modos_v1_7.json');
    final lenses = File('docs/catalog/lenses_v1_7.json');
    final lights = File('docs/catalog/lights_v1_7.json');
    expect(cameras.existsSync(), isTrue);
    expect(lenses.existsSync(), isTrue);
    expect(lights.existsSync(), isTrue);

    final summary = await importOfficialCatalogJsonFiles(db, [
      (name: cameras.uri.pathSegments.last, content: cameras.readAsStringSync()),
      (name: lenses.uri.pathSegments.last, content: lenses.readAsStringSync()),
      (name: lights.uri.pathSegments.last, content: lights.readAsStringSync()),
    ]);

    expect(summary.ok, isTrue);
    expect(summary.camerasUpserted, greaterThan(0));
    expect(summary.lensesUpserted, greaterThan(0));
    expect(summary.lightsUpserted, greaterThan(0));
    expect(summary.modesParsed, greaterThan(0));
    expect(summary.importedKinds, containsAll(['cameras', 'lenses', 'lights']));
  });
}
