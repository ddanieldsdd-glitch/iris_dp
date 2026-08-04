import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/luka_export/luka_compatibility_service.dart';
import 'package:iris_dp/features/luka_export/luka_manifest_models.dart';

void main() {
  final manifest = LukaManifest.fromJson({
    'version': 1,
    'fixtures': [
      {'id': 'skypanel_s60', 'label': 'SkyPanel S60-C'},
      {'id': 't5', 'label': 'T5'},
      {'id': 'm18', 'label': 'M18'},
    ],
    'cameraProfiles': [
      {
        'id': 'alexa35',
        'label': 'ALEXA 35',
        'sensorWidthMm': 27.99,
        'sensorHeightMm': 19.22,
        'lukaPreset': 'ALEXA 35',
      },
    ],
  });

  final svc = LukaCompatibilityService(manifest);

  group('LukaCompatibilityService', () {
    test('Light with valid fixture is full compat', () {
      final report = svc.evaluateLight(_light(
        lukaCompatible: true,
        lukaFixtureId: 'skypanel_s60',
      ));
      expect(report.level, LukaCompatLevel.full);
      expect(report.resolvedFixtureId, 'skypanel_s60');
    });

    test('Light with unknown fixture is manual_only', () {
      final report = svc.evaluateLight(_light(
        lukaCompatible: true,
        lukaFixtureId: 'unknown_fixture',
      ));
      expect(report.level, LukaCompatLevel.manualOnly);
      expect(report.messages, isNotEmpty);
    });

    test('Camera with preset in manifest is full', () {
      final report = svc.evaluateCamera(_camera(
        lukaCompatible: true,
        lukaProfileJson: '{"lukaPreset":"ALEXA 35"}',
      ));
      expect(report.level, LukaCompatLevel.full);
    });

    test('Lens vintage returns manual setup', () {
      final report = svc.evaluateLens(_lens(
        focalLength: 32,
        minTStop: 2.0,
        lukaProfileJson: '{"manualSetup":true}',
      ));
      expect(report.level, LukaCompatLevel.manualOnly);
      expect(report.manualSetup?['focalMm'], 32);
    });
  });
}

Light _light({required bool lukaCompatible, String? lukaFixtureId}) => Light(
      id: 1,
      brand: 'ARRI',
      model: 'SkyPanel',
      lightType: 'led_panel',
      powerW: 475,
      colorTempMin: 2800,
      colorTempMax: 10000,
      isLukaCompatible: lukaCompatible,
      lukaFixtureId: lukaFixtureId,
      catalogVersion: 2,
      isCustom: false,
      vintage: false,
    );

Camera _camera({required bool lukaCompatible, String? lukaProfileJson}) => Camera(
      id: 1,
      brand: 'ARRI',
      model: 'ALEXA 35',
      sensorWidthMm: 27.99,
      sensorHeightMm: 19.22,
      lukaCompatible: lukaCompatible,
      lukaProfileJson: lukaProfileJson,
      catalogVersion: 2,
      isCustom: false,
      vintage: false,
    );

Lense _lens({required double focalLength, required double minTStop, String? lukaProfileJson}) =>
    Lense(
      id: 1,
      brand: 'Cooke',
      model: 'S4 32mm',
      focalLength: focalLength,
      minTStop: minTStop,
      formatCoverage: 'S35',
      lukaCompatible: false,
      lukaProfileJson: lukaProfileJson,
      catalogVersion: 2,
      isCustom: false,
      isAnamorphic: false,
      vintage: false,
    );
