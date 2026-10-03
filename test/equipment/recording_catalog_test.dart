import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/equipment/catalog_data_status.dart';
import 'package:iris_dp/shared/equipment/catalog_models.dart';
import 'package:iris_dp/shared/equipment/recording_catalog.dart';

/// Datos del flujo v2.0 (ALEXA SXT + ZEISS Super Speed) en el catálogo
/// generado, y el plan de volcado de la hoja `16_Volcado_Calculadora`.
void main() {
  final recording = parseRecordingCatalog(
    File('assets/catalog/recording.json').readAsStringSync(),
  );
  final cameras = parseCameraCatalog(
    File('assets/catalog/cameras.json').readAsStringSync(),
  );
  final lenses = parseLensCatalog(
    File('assets/catalog/lenses.json').readAsStringSync(),
  );
  final sxt = recording.singleWhere((c) => c.cameraId == 'arri_alexa_sxt');
  RecordingFormat format(String id) =>
      sxt.formats.singleWhere((f) => f.id == id);
  RecordingMedium medium(double gb) =>
      sxt.media.singleWhere((m) => m.capacityGb == gb);

  test('la SXT trae sus 6 medios y 41 formatos', () {
    expect(sxt.media, hasLength(6));
    expect(sxt.formats, hasLength(41));
    expect(sxt.fps, 24);
    expect(sxt.media.every((m) => m.status.usableInCalculations), isTrue);
  });

  test('ARRIRAW solo se admite en XR y SXR', () {
    final arriraw = format('REC-41');
    expect(arriraw.label, 'Open Gate ARRIRAW 3.4K · ARRIRAW');
    expect(sxt.mediaFor(arriraw).map((m) => m.capacityGb), [2000, 1000, 512]);
    expect(arriraw.minutesByMedia[medium(2000).id], 118);
    // ProRes HD 422 cabe en todos.
    expect(sxt.mediaFor(format('REC-01')), hasLength(6));
  });

  test('el plan reproduce el ejemplo de la hoja 16', () {
    final plan = RecordingPlan.compute(
      format: format('REC-41'),
      medium: medium(2000),
      minutesPerDay: 60,
      days: 1,
      dockMbPerSec: 2500,
      destinationMbPerSec: 400,
      copies: 2,
      verify: true,
    );
    expect(plan.minutesPerMag, 118);
    expect(plan.gbPerDay, closeTo(1015, 1));
    expect(plan.totalTb, closeTo(1.02, 0.01));
    expect(plan.magsPerDay, 1);
    expect(plan.offloadMbPerSec, 400);
    expect(plan.offloadHoursPerDay, closeTo(1.41, 0.01));
    expect(plan.storageTb, closeTo(2.03, 0.01));
  });

  test('el plan cuenta cargadores y volcado sin verificación', () {
    final plan = RecordingPlan.compute(
      format: format('REC-41'),
      medium: medium(512),
      minutesPerDay: 90,
      days: 20,
      destinationMbPerSec: 3000,
      copies: 3,
      verify: false,
    );
    expect(plan.minutesPerMag, 29);
    expect(plan.magsPerDay, 4);
    // Manda el dock (2500 MB/s), más lento que el destino.
    expect(plan.offloadMbPerSec, 2500);
    expect(
      plan.offloadHoursPerDay,
      closeTo(282 * 90 * 60 / 2500 / 3600, 0.001),
    );
    expect(plan.storageTb, closeTo(282 * 90 * 60 / 1000 * 20 * 3 / 1000, 0.01));
  });

  test('ficha y formatos de la ALEXA SXT', () {
    final camera = cameras.singleWhere((c) => c.externalId == 'arri_alexa_sxt');
    expect(camera.sensorWidthMm, 28.25);
    expect(camera.sensorHeightMm, 18.17);
    expect(camera.mountType, 'PL');
    expect(camera.provenance!.status, CatalogDataStatus.confirmado);
    expect(camera.sensorModes, hasLength(14));
    final openGate = camera.sensorModes.singleWhere(
      (m) => m['name'] == 'Open Gate · ARRIRAW 3.4K',
    );
    expect(openGate['widthMm'], 28.25);
    expect(openGate['fpsMax'], 90);
    expect(openGate['codec'], 'ARRIRAW');
  });

  test('las cámaras que faltaban tienen ficha y modos con gate', () {
    for (final (id, modes) in [
      ('arri_alexa35_xtreme', 8),
      ('blackmagic_pyxis_6k_pl', 8),
      ('blackmagic_ursa_cine_17k_65', 22),
    ]) {
      final camera = cameras.singleWhere((c) => c.externalId == id);
      expect(camera.provenance!.status, CatalogDataStatus.confirmado);
      expect(
        camera.sensorModes.length,
        greaterThanOrEqualTo(modes),
        reason: id,
      );
    }
  });

  test('set NAPALM: cinco focales T1.3 con círculo típico y peor caso', () {
    final napalm = lenses
        .where((l) => l.externalId.startsWith('zeiss_super_speed_napalm_'))
        .toList();
    expect(napalm.map((l) => l.focalLength), [18, 25, 35, 50, 85]);
    expect(napalm.map((l) => l.series).toSet(), {'Super Speed MKII (NAPALM)'});
    for (final (focal, typical, worst) in [
      (18, 33.0, 32.0),
      (25, 37.0, 36.0),
      (35, 37.0, 36.0),
      (50, 41.0, 40.0),
      (85, 60.0, 54.0),
    ]) {
      final lens = napalm.singleWhere((l) => l.focalLength == focal);
      expect(lens.imageCircleMm, typical, reason: '$focal mm');
      expect(lens.specs?['imageCircleWorstMm'], worst, reason: '$focal mm');
      expect(lens.minTStop, 1.3);
      expect(lens.isAnamorphic, isFalse);
      expect(lens.squeezeRatio, isNull);
      expect(lens.provenance!.status, CatalogDataStatus.observado);
      expect(lens.provenance!.status.usableInCalculations, isTrue);
    }
  });

  test('todas las Super Speed tienen su apertura real', () {
    final superSpeeds = lenses.where(
      (l) => l.model.toLowerCase().contains('super speed'),
    );
    expect(superSpeeds, isNotEmpty);
    for (final lens in superSpeeds) {
      final expected =
          lens.model.contains('MKI') && !lens.model.contains('MKII')
          ? 1.4
          : 1.3;
      expect(lens.minTStop, expected, reason: lens.externalId);
      // La familia heredada tenía focales que no existen en Super Speed.
      expect([18, 25, 35, 50, 65, 85], contains(lens.focalLength));
    }
  });
}
