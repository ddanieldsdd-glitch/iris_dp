import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/weather/sun_calculator.dart';

void main() {
  test('Barcelona, 21 de junio: sale por el noreste, se pone por el '
      'noroeste y a mediodía sube unos 72°', () {
    final day = SunCalculator.dayPath(
      year: 2026,
      month: 6,
      day: 21,
      latitude: 41.39,
      longitude: 2.17,
    );
    expect(day.sunriseAzimuth, closeTo(57, 2));
    expect(day.sunsetAzimuth, closeTo(303, 2));
    expect(day.noonAltitude, closeTo(72, 1));
    expect(compassPoint(day.sunriseAzimuth!), 'NE');
    expect(compassPoint(day.sunsetAzimuth!), 'NO');
    expect(day.noonShadow, closeTo(0.32, 0.03));
    expect(day.path.length, greaterThan(25));
  });

  test('en diciembre sale por el sureste y sube poco', () {
    final day = SunCalculator.dayPath(
      year: 2026,
      month: 12,
      day: 21,
      latitude: 41.39,
      longitude: 2.17,
    );
    expect(compassPoint(day.sunriseAzimuth!), 'SE');
    expect(day.noonAltitude, closeTo(25, 1.5));
  });
}
