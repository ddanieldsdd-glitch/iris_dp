import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/equipment/lens_set_utils.dart';

Lense _lens({
  required int id,
  required String brand,
  required String model,
  String? series,
  double focal = 0,
  double? focalMin,
  double? focalMax,
}) =>
    Lense(
      id: id,
      brand: brand,
      model: model,
      focalLength: focal,
      focalMin: focalMin,
      focalMax: focalMax,
      minTStop: 2.0,
      formatCoverage: 'FF',
      isAnamorphic: false,
      vintage: false,
      lukaCompatible: false,
      isCustom: false,
      series: series,
    );

void main() {
  group('LensSetUtils', () {
    test('uses explicit series when available', () {
      final lens = _lens(
        id: 1,
        brand: 'Cooke',
        model: 'S4/i 32mm',
        series: 'S4/i',
        focal: 32,
      );
      expect(LensSetUtils.setName(lens), 'S4/i');
    });

    test('infers set from prime model name', () {
      final lens = _lens(
        id: 1,
        brand: 'Zeiss',
        model: 'Master Prime 32mm',
        focal: 32,
      );
      expect(LensSetUtils.setName(lens), 'Master Prime');
    });

    test('infers set from zoom model name', () {
      final lens = _lens(
        id: 1,
        brand: 'Fujinon',
        model: 'Premista 28-100mm T2.9',
        focalMin: 28,
        focalMax: 100,
      );
      expect(LensSetUtils.setName(lens), 'Premista');
    });

    test('set summary shows focal range and count', () {
      final lenses = [
        _lens(id: 1, brand: 'Zeiss', model: 'Master Prime 12mm', focal: 12),
        _lens(id: 2, brand: 'Zeiss', model: 'Master Prime 50mm', focal: 50),
        _lens(id: 3, brand: 'Zeiss', model: 'Master Prime 135mm', focal: 135),
      ];
      final summary = LensSetUtils.setSummary(lenses);
      expect(summary, contains('12–135 mm'));
      expect(summary, contains('3 lentes'));
    });
  });
}
