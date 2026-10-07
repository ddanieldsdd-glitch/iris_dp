import 'dart:convert';

import 'package:http/http.dart' as http;

import 'weather_models.dart';

/// De dónde sale la previsión y la búsqueda de lugares. Detrás de una
/// interfaz para poder cambiar de proveedor sin tocar las pantallas.
abstract class WeatherProvider {
  /// Previsión del día [date] ("aaaa-mm-dd") en el lugar. Nulo si el
  /// proveedor no da previsión para ese día (demasiado lejos o pasado).
  Future<WeatherSnapshot?> forecast({
    required double latitude,
    required double longitude,
    required String date,
  });

  Future<List<PlaceResult>> searchPlaces(String query);
}

/// Días hacia delante para los que Open-Meteo da previsión.
const kForecastHorizonDays = 16;

/// ¿Hay previsión para [date] vista desde [today]?
bool isWithinForecast(DateTime date, DateTime today) {
  final d = DateTime(date.year, date.month, date.day);
  final t = DateTime(today.year, today.month, today.day);
  final days = d.difference(t).inDays;
  return days >= 0 && days < kForecastHorizonDays;
}

/// Open-Meteo: sin clave. Gratis para uso no comercial; si la app se
/// comercializa hace falta su plan de pago u otro proveedor.
class OpenMeteoWeather implements WeatherProvider {
  OpenMeteoWeather({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 12);

  @override
  Future<WeatherSnapshot?> forecast({
    required double latitude,
    required double longitude,
    required String date,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
      'hourly':
          'temperature_2m,precipitation_probability,precipitation,'
          'weather_code,wind_speed_10m,wind_gusts_10m,is_day',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,'
          'precipitation_sum,precipitation_probability_max,'
          'wind_speed_10m_max,wind_gusts_10m_max',
      'timezone': 'auto',
      'start_date': date,
      'end_date': date,
    });
    final response = await _client.get(uri).timeout(_timeout);
    // Fuera del alcance de la previsión responde con un 400.
    if (response.statusCode != 200) return null;
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map) return null;
    return WeatherSnapshot.fromOpenMeteo(
      Map<String, dynamic>.from(json),
      date: date,
      fetchedAt: DateTime.now(),
    );
  }

  @override
  Future<List<PlaceResult>> searchPlaces(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': q,
      'count': '8',
      'language': 'es',
      'format': 'json',
    });
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return const [];
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    final results = json is Map ? json['results'] : null;
    if (results is! List) return const [];
    return [
      for (final r in results)
        if (r is Map && r['latitude'] is num && r['longitude'] is num)
          PlaceResult(
            name: '${r['name']}',
            region: r['admin1'] as String?,
            country: r['country'] as String?,
            latitude: (r['latitude'] as num).toDouble(),
            longitude: (r['longitude'] as num).toDouble(),
          ),
    ];
  }
}
