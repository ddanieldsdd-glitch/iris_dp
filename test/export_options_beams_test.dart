import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/export_center/export_options.dart';

void main() {
  test('los haces salen por defecto, también en opciones antiguas', () {
    expect(const ExportOptions().planBeams, isTrue);
    expect(ExportOptions.fromJson(const {}).planBeams, isTrue);
  });

  test('sin haces se recuerda', () {
    final options = const ExportOptions().copyWith(planBeams: false);
    expect(ExportOptions.fromJson(options.toJson()).planBeams, isFalse);
  });
}
