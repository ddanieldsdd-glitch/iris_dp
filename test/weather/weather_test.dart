import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:iris_dp/core/weather/sun_calculator.dart';
import 'package:iris_dp/core/weather/weather_models.dart';
import 'package:iris_dp/core/weather/weather_service.dart';

Matcher _around(DateTime expected, {int minutes = 4}) => predicate<DateTime?>(
  (actual) =>
      actual != null && actual.difference(expected).inMinutes.abs() <= minutes,
  'a menos de $minutes min de $expected',
);

void main() {
  group('sol', () {
    // Barcelona. Horas de referencia de los almanaques, en UTC.
    const lat = 41.3874;
    const lon = 2.1686;

    test('solsticio de verano en Barcelona', () {
      final sun = SunCalculator.forDate(
        year: 2026,
        month: 6,
        day: 21,
        latitude: lat,
        longitude: lon,
      );
      expect(sun.sunrise, _around(DateTime.utc(2026, 6, 21, 4, 18)));
      expect(sun.sunset, _around(DateTime.utc(2026, 6, 21, 19, 28)));
      expect(sun.solarNoon, _around(DateTime.utc(2026, 6, 21, 11, 53)));
    });

    test('solsticio de invierno en Barcelona', () {
      final sun = SunCalculator.forDate(
        year: 2026,
        month: 12,
        day: 21,
        latitude: lat,
        longitude: lon,
      );
      expect(sun.sunrise, _around(DateTime.utc(2026, 12, 21, 7, 14)));
      expect(sun.sunset, _around(DateTime.utc(2026, 12, 21, 16, 25)));
    });

    test('las horas azul y dorada van en orden alrededor del sol', () {
      final sun = SunCalculator.forDate(
        year: 2026,
        month: 10,
        day: 12,
        latitude: lat,
        longitude: lon,
      );
      final order = [
        sun.dawn!,
        sun.blueHourMorningEnd!,
        sun.sunrise!,
        sun.goldenHourMorningEnd!,
        sun.solarNoon!,
        sun.goldenHourEveningStart!,
        sun.sunset!,
        sun.blueHourEveningStart!,
        sun.dusk!,
      ];
      for (var i = 1; i < order.length; i++) {
        expect(order[i].isAfter(order[i - 1]), isTrue, reason: 'paso $i');
      }
    });

    test('donde el sol no se pone ese día, no hay ocaso', () {
      final sun = SunCalculator.forDate(
        year: 2026,
        month: 6,
        day: 21,
        latitude: 78.2,
        longitude: 15.6,
      );
      expect(sun.sunrise, isNull);
      expect(sun.sunset, isNull);
      expect(sun.solarNoon, isNotNull);
    });
  });

  group('previsión', () {
    const body = {
      'utc_offset_seconds': 7200,
      'hourly': {
        'time': ['2026-10-12T00:00', '2026-10-12T01:00', '2026-10-12T22:00'],
        'temperature_2m': [14.2, 13.8, 17.5],
        'precipitation_probability': [5, 10, 60],
        'precipitation': [0, 0, 1.2],
        'weather_code': [0, 1, 61],
        'wind_speed_10m': [8.1, 7.4, 22.0],
        'wind_gusts_10m': [15.0, 14.2, 41.3],
        'is_day': [0, 0, 0],
      },
      'daily': {
        'time': ['2026-10-12'],
        'weather_code': [61],
        'temperature_2m_max': [22.4],
        'temperature_2m_min': [13.1],
        'precipitation_sum': [1.2],
        'precipitation_probability_max': [60],
        'wind_speed_10m_max': [22.0],
        'wind_gusts_10m_max': [41.3],
      },
    };

    test('lee la respuesta del proveedor y sobrevive a guardarse', () {
      final snapshot = WeatherSnapshot.fromOpenMeteo(
        body,
        date: '2026-10-12',
        fetchedAt: DateTime.utc(2026, 10, 6, 10, 40),
      )!;
      expect(snapshot.temperatureMax, 22.4);
      expect(snapshot.temperatureMin, 13.1);
      expect(weatherCodeLabel(snapshot.weatherCode), 'Lluvia débil');
      expect(snapshot.hours.length, 3);
      expect(snapshot.hours.last.hour, 22);
      expect(snapshot.hours.last.gusts, 41.3);
      expect(snapshot.hours.first.isDay, isFalse);

      final restored = WeatherSnapshot.decode(snapshot.encode())!;
      expect(restored.utcOffsetSeconds, 7200);
      expect(restored.hours.last.precipitationProbability, 60);
      expect(restored.fetchedAt, DateTime.utc(2026, 10, 6, 10, 40));
    });

    test('la franja de rodaje filtra las horas, también de noche', () {
      final snapshot = WeatherSnapshot.fromOpenMeteo(
        body,
        date: '2026-10-12',
        fetchedAt: DateTime.utc(2026, 10, 6),
      )!;
      expect(snapshot.hoursBetween(0, 1).map((h) => h.hour), [0, 1]);
      // De 22 a 1: cruza la medianoche.
      expect(snapshot.hoursBetween(22, 1).map((h) => h.hour), [0, 1, 22]);
      expect(snapshot.hoursBetween(null, null).length, 3);
    });

    test(
      'pide un solo día al proveedor y devuelve nulo si no hay previsión',
      () async {
        late Uri asked;
        final ok = OpenMeteoWeather(
          client: MockClient((request) async {
            asked = request.url;
            return http.Response(jsonEncode(body), 200);
          }),
        );
        final snapshot = await ok.forecast(
          latitude: 41.3874,
          longitude: 2.1686,
          date: '2026-10-12',
        );
        expect(snapshot, isNotNull);
        expect(asked.host, 'api.open-meteo.com');
        expect(asked.queryParameters['start_date'], '2026-10-12');
        expect(asked.queryParameters['end_date'], '2026-10-12');
        expect(asked.queryParameters['timezone'], 'auto');

        final tooFar = OpenMeteoWeather(
          client: MockClient((_) async => http.Response('{"error":true}', 400)),
        );
        expect(
          await tooFar.forecast(latitude: 0, longitude: 0, date: '2027-01-01'),
          isNull,
        );
      },
    );

    test('solo hay previsión de hoy a 16 días', () {
      final today = DateTime(2026, 10, 6);
      expect(isWithinForecast(DateTime(2026, 10, 6), today), isTrue);
      expect(isWithinForecast(DateTime(2026, 10, 21), today), isTrue);
      expect(isWithinForecast(DateTime(2026, 10, 22), today), isFalse);
      expect(isWithinForecast(DateTime(2026, 10, 5), today), isFalse);
    });

    test('el buscador de lugares devuelve nombre y coordenadas', () async {
      final service = OpenMeteoWeather(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'results': [
                {
                  'name': 'Barcelona',
                  'admin1': 'Cataluña',
                  'country': 'España',
                  'latitude': 41.38879,
                  'longitude': 2.15899,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      final places = await service.searchPlaces('barcelona');
      expect(places.single.label, 'Barcelona, Cataluña, España');
      expect(places.single.latitude, closeTo(41.39, 0.01));
      expect(await service.searchPlaces('b'), isEmpty);
    });
  });
}
