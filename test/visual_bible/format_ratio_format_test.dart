import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/optics_lab/optics_calculator.dart';
import 'package:iris_dp/shared/visual_bible/format_ratio_format.dart';

void main() {
  group('FormatRatioFormat', () {
    test('preset conocido devuelve string canónico', () {
      expect(FormatRatioFormat.format(2.39), '2.39:1');
      expect(FormatRatioFormat.format(1.0), '1:1');
    });

    test('ratio no-preset usa dos decimales', () {
      expect(FormatRatioFormat.format(1.5), '1.50:1');
    });

    test('parseAspectRatio lee strings generados por format', () {
      for (final r in [1.5, 2.39, 1.66, 1.78]) {
        final label = FormatRatioFormat.format(r);
        final parsed = OpticsCalculator.parseAspectRatio(label);
        expect(parsed, closeTo(r, 0.02), reason: label);
      }
    });
  });
}
