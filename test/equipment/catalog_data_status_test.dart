import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/shared/equipment/catalog_data_status.dart';

void main() {
  group('CatalogDataStatus.parse', () {
    test('reconoce los diez estados del master', () {
      for (final status in CatalogDataStatus.values) {
        expect(CatalogDataStatus.parse(status.label), status);
        expect(
          CatalogDataStatus.parse(' ${status.label.toLowerCase()} '),
          status,
        );
      }
    });

    test('traduce los estados de la lista de material', () {
      expect(
        CatalogDataStatus.parse('VERIFICADO'),
        CatalogDataStatus.confirmado,
      );
      expect(
        CatalogDataStatus.parse('VERIFICADO PARCIAL'),
        CatalogDataStatus.confirmado,
      );
      expect(
        CatalogDataStatus.parse('CONTRADICTORIO'),
        CatalogDataStatus.conflicto,
      );
      expect(CatalogDataStatus.parse('PARCIAL'), CatalogDataStatus.secundario);
    });

    test('lo desconocido o vacío queda pendiente, nunca se promociona', () {
      expect(CatalogDataStatus.parse(null), CatalogDataStatus.pendiente);
      expect(CatalogDataStatus.parse(''), CatalogDataStatus.pendiente);
      expect(
        CatalogDataStatus.parse('heredado_v0 / pendiente_verificación'),
        CatalogDataStatus.pendiente,
      );
      expect(
        CatalogDataStatus.parse('NO VERIFICADO'),
        CatalogDataStatus.pendiente,
      );
    });
  });

  test('solo los datos con fuente entran en cálculos', () {
    const usable = {
      CatalogDataStatus.confirmado,
      CatalogDataStatus.contrastado,
      CatalogDataStatus.secundario,
      CatalogDataStatus.calculado,
      CatalogDataStatus.observado,
    };
    for (final status in CatalogDataStatus.values) {
      expect(
        status.usableInCalculations,
        usable.contains(status),
        reason: status.label,
      );
    }
    expect(CatalogDataStatus.confirmado.calcUse, CatalogCalcUse.high);
    expect(CatalogDataStatus.secundario.calcUse, CatalogCalcUse.medium);
    expect(CatalogDataStatus.conflicto.calcUse, CatalogCalcUse.conflict);
    expect(CatalogDataStatus.noPublicado.calcUse, CatalogCalcUse.none);
  });

  group('CatalogProvenance', () {
    test('con verificación parcial, un campo no listado sigue pendiente', () {
      final provenance = CatalogProvenance.fromJson({
        'dataStatus': 'VERIFICADO PARCIAL',
        'confidence': 'ALTA',
        'verifiedFields': 'sensor_ancho_mm; sensor_alto_mm; mount',
        'sourceUrl': 'https://www.arri.com/',
      });
      expect(provenance.verifiedFields, hasLength(3));
      expect(
        provenance.statusForField('sensor_ancho_mm'),
        CatalogDataStatus.confirmado,
      );
      expect(
        provenance.statusForField('iso_base'),
        CatalogDataStatus.pendiente,
      );
    });

    test('sin lista de campos, el estado cubre toda la ficha', () {
      const provenance = CatalogProvenance(
        status: CatalogDataStatus.contrastado,
      );
      expect(
        provenance.statusForField('image_circle_mm'),
        CatalogDataStatus.contrastado,
      );
    });

    test('ida y vuelta por JSON y por columnas', () {
      const original = CatalogProvenance(
        status: CatalogDataStatus.confirmado,
        confidence: 'ALTA',
        verifiedFields: ['image_circle_mm'],
        sourceLabel: 'ARRI brochure',
        sourceUrl: 'https://www.arri.com/',
        verifiedAt: '2026-08-11',
      );
      final fromJson = CatalogProvenance.fromJson(original.toJson());
      final fromColumns = CatalogProvenance.fromColumns(
        dataStatus: original.status.label,
        confidence: original.confidence,
        verifiedFieldsJson: original.verifiedFieldsJson,
        sourceLabel: original.sourceLabel,
        sourceUrl: original.sourceUrl,
        verifiedAt: original.verifiedAt,
      );
      for (final copy in [fromJson, fromColumns]) {
        expect(copy.status, original.status);
        expect(copy.confidence, 'ALTA');
        expect(copy.verifiedFields, ['image_circle_mm']);
        expect(copy.sourceLabel, 'ARRI brochure');
        expect(copy.verifiedAt, '2026-08-11');
      }
    });
  });

  test('las fichas guardan procedencia y modelo óptico', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final lensId = await db
        .into(db.lenses)
        .insert(
          LensesCompanion.insert(
            brand: 'ARRI',
            model: 'Signature Prime 47mm',
            focalLength: 47,
            minTStop: 1.8,
            formatCoverage: 'LF',
            imageCircleMm: const Value(46.3),
            dataStatus: const Value('CONFIRMADO'),
            sourceLabel: const Value('ARRI brochure'),
            projectionType: const Value('ESFÉRICA'),
            portholingStatus: const Value('NO PUBLICADO'),
            specsJson: const Value('{"aovH":"42.6°"}'),
          ),
        );
    final lens = await (db.select(
      db.lenses,
    )..where((l) => l.id.equals(lensId))).getSingle();
    expect(lens.projectionType, 'ESFÉRICA');
    expect(lens.specsJson, contains('42.6'));
    expect(
      CatalogProvenance.fromColumns(
        dataStatus: lens.dataStatus,
        sourceLabel: lens.sourceLabel,
      ).status,
      CatalogDataStatus.confirmado,
    );

    final cameraId = await db
        .into(db.cameras)
        .insert(
          CamerasCompanion.insert(
            brand: 'ARRI',
            model: 'ALEXA 35',
            sensorWidthMm: 27.99,
            sensorHeightMm: 19.22,
          ),
        );
    final camera = await (db.select(
      db.cameras,
    )..where((c) => c.id.equals(cameraId))).getSingle();
    expect(
      CatalogDataStatus.parse(camera.dataStatus),
      CatalogDataStatus.pendiente,
    );
  });
}
