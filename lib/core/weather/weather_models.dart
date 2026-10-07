import 'dart:convert';

/// Previsión de una hora del día.
class WeatherHour {
  final int hour;
  final double? temperature;
  final int? weatherCode;
  final double? precipitation;
  final int? precipitationProbability;
  final double? wind;
  final double? gusts;
  final bool? isDay;

  const WeatherHour({
    required this.hour,
    this.temperature,
    this.weatherCode,
    this.precipitation,
    this.precipitationProbability,
    this.wind,
    this.gusts,
    this.isDay,
  });

  Map<String, dynamic> toJson() => {
    'hour': hour,
    'temperature': temperature,
    'weatherCode': weatherCode,
    'precipitation': precipitation,
    'precipitationProbability': precipitationProbability,
    'wind': wind,
    'gusts': gusts,
    'isDay': isDay,
  };

  factory WeatherHour.fromJson(Map<String, dynamic> j) => WeatherHour(
    hour: (j['hour'] as num).toInt(),
    temperature: (j['temperature'] as num?)?.toDouble(),
    weatherCode: (j['weatherCode'] as num?)?.toInt(),
    precipitation: (j['precipitation'] as num?)?.toDouble(),
    precipitationProbability: (j['precipitationProbability'] as num?)?.toInt(),
    wind: (j['wind'] as num?)?.toDouble(),
    gusts: (j['gusts'] as num?)?.toDouble(),
    isDay: j['isDay'] as bool?,
  );
}

/// Previsión de un día en un lugar, tal como se descargó. Se guarda con la
/// jornada para que el documento salga igual sin conexión.
class WeatherSnapshot {
  final DateTime fetchedAt;

  /// Fecha del día previsto, "aaaa-mm-dd".
  final String date;

  /// Diferencia horaria del lugar ese día, en segundos.
  final int utcOffsetSeconds;
  final double? temperatureMin;
  final double? temperatureMax;
  final int? weatherCode;
  final double? precipitationSum;
  final int? precipitationProbabilityMax;
  final double? windMax;
  final double? gustsMax;
  final List<WeatherHour> hours;

  const WeatherSnapshot({
    required this.fetchedAt,
    required this.date,
    required this.utcOffsetSeconds,
    this.temperatureMin,
    this.temperatureMax,
    this.weatherCode,
    this.precipitationSum,
    this.precipitationProbabilityMax,
    this.windMax,
    this.gustsMax,
    this.hours = const [],
  });

  /// Horas dentro de la franja de rodaje [fromHour]–[toHour]; todas si no
  /// hay franja.
  List<WeatherHour> hoursBetween(int? fromHour, int? toHour) {
    if (fromHour == null || toHour == null) return hours;
    return [
      for (final h in hours)
        if (fromHour <= toHour
            ? h.hour >= fromHour && h.hour <= toHour
            // Franja que cruza la medianoche (rodaje de noche).
            : h.hour >= fromHour || h.hour <= toHour)
          h,
    ];
  }

  Map<String, dynamic> toJson() => {
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'date': date,
    'utcOffsetSeconds': utcOffsetSeconds,
    'temperatureMin': temperatureMin,
    'temperatureMax': temperatureMax,
    'weatherCode': weatherCode,
    'precipitationSum': precipitationSum,
    'precipitationProbabilityMax': precipitationProbabilityMax,
    'windMax': windMax,
    'gustsMax': gustsMax,
    'hours': [for (final h in hours) h.toJson()],
  };

  String encode() => jsonEncode(toJson());

  static WeatherSnapshot? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return WeatherSnapshot(
        fetchedAt: DateTime.parse(j['fetchedAt'] as String),
        date: j['date'] as String,
        utcOffsetSeconds: (j['utcOffsetSeconds'] as num?)?.toInt() ?? 0,
        temperatureMin: (j['temperatureMin'] as num?)?.toDouble(),
        temperatureMax: (j['temperatureMax'] as num?)?.toDouble(),
        weatherCode: (j['weatherCode'] as num?)?.toInt(),
        precipitationSum: (j['precipitationSum'] as num?)?.toDouble(),
        precipitationProbabilityMax: (j['precipitationProbabilityMax'] as num?)
            ?.toInt(),
        windMax: (j['windMax'] as num?)?.toDouble(),
        gustsMax: (j['gustsMax'] as num?)?.toDouble(),
        hours: [
          for (final h in j['hours'] as List? ?? const [])
            WeatherHour.fromJson(Map<String, dynamic>.from(h as Map)),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  /// Lee la respuesta de Open-Meteo para un solo día.
  static WeatherSnapshot? fromOpenMeteo(
    Map<String, dynamic> json, {
    required String date,
    required DateTime fetchedAt,
  }) {
    final daily = json['daily'];
    final hourly = json['hourly'];
    if (daily is! Map || hourly is! Map) return null;

    T? first<T>(Object? list) =>
        list is List && list.isNotEmpty ? list.first as T? : null;
    double? firstDouble(String key) => first<num>(daily[key])?.toDouble();
    int? firstInt(String key) => first<num>(daily[key])?.toInt();

    final times = hourly['time'];
    final hours = <WeatherHour>[];
    if (times is List) {
      num? at(String key, int i) {
        final list = hourly[key];
        return list is List && i < list.length ? list[i] as num? : null;
      }

      for (var i = 0; i < times.length; i++) {
        final time = '${times[i]}';
        if (!time.startsWith(date)) continue;
        hours.add(
          WeatherHour(
            hour: int.tryParse(time.substring(11, 13)) ?? i,
            temperature: at('temperature_2m', i)?.toDouble(),
            weatherCode: at('weather_code', i)?.toInt(),
            precipitation: at('precipitation', i)?.toDouble(),
            precipitationProbability: at(
              'precipitation_probability',
              i,
            )?.toInt(),
            wind: at('wind_speed_10m', i)?.toDouble(),
            gusts: at('wind_gusts_10m', i)?.toDouble(),
            isDay: at('is_day', i) == null ? null : at('is_day', i) == 1,
          ),
        );
      }
    }
    if (hours.isEmpty && firstDouble('temperature_2m_max') == null) return null;

    return WeatherSnapshot(
      fetchedAt: fetchedAt,
      date: date,
      utcOffsetSeconds: (json['utc_offset_seconds'] as num?)?.toInt() ?? 0,
      temperatureMin: firstDouble('temperature_2m_min'),
      temperatureMax: firstDouble('temperature_2m_max'),
      weatherCode: firstInt('weather_code'),
      precipitationSum: firstDouble('precipitation_sum'),
      precipitationProbabilityMax: firstInt('precipitation_probability_max'),
      windMax: firstDouble('wind_speed_10m_max'),
      gustsMax: firstDouble('wind_gusts_10m_max'),
      hours: hours,
    );
  }
}

/// Estado del cielo de un código WMO, en castellano.
String weatherCodeLabel(int? code) => switch (code) {
  null => '—',
  0 => 'Despejado',
  1 => 'Poco nuboso',
  2 => 'Intervalos nubosos',
  3 => 'Cubierto',
  45 || 48 => 'Niebla',
  51 || 53 || 55 => 'Llovizna',
  56 || 57 => 'Llovizna helada',
  61 => 'Lluvia débil',
  63 => 'Lluvia',
  65 => 'Lluvia fuerte',
  66 || 67 => 'Lluvia helada',
  71 => 'Nevada débil',
  73 => 'Nevada',
  75 => 'Nevada fuerte',
  77 => 'Granizo fino',
  80 => 'Chubascos débiles',
  81 => 'Chubascos',
  82 => 'Chubascos fuertes',
  85 || 86 => 'Chubascos de nieve',
  95 => 'Tormenta',
  96 || 99 => 'Tormenta con granizo',
  _ => 'Variable',
};

/// Qué datos de meteorología salen en la jornada y en su documento.
class WeatherOptions {
  final bool sky;
  final bool temperature;
  final bool rain;
  final bool wind;
  final bool sun;
  final bool blueAndGolden;
  final bool hourly;

  const WeatherOptions({
    this.sky = true,
    this.temperature = true,
    this.rain = true,
    this.wind = true,
    this.sun = true,
    this.blueAndGolden = true,
    this.hourly = true,
  });

  WeatherOptions copyWith({
    bool? sky,
    bool? temperature,
    bool? rain,
    bool? wind,
    bool? sun,
    bool? blueAndGolden,
    bool? hourly,
  }) => WeatherOptions(
    sky: sky ?? this.sky,
    temperature: temperature ?? this.temperature,
    rain: rain ?? this.rain,
    wind: wind ?? this.wind,
    sun: sun ?? this.sun,
    blueAndGolden: blueAndGolden ?? this.blueAndGolden,
    hourly: hourly ?? this.hourly,
  );

  String encode() => jsonEncode({
    'sky': sky,
    'temperature': temperature,
    'rain': rain,
    'wind': wind,
    'sun': sun,
    'blueAndGolden': blueAndGolden,
    'hourly': hourly,
  });

  static WeatherOptions decode(String? raw) {
    if (raw == null || raw.isEmpty) return const WeatherOptions();
    try {
      final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return WeatherOptions(
        sky: j['sky'] as bool? ?? true,
        temperature: j['temperature'] as bool? ?? true,
        rain: j['rain'] as bool? ?? true,
        wind: j['wind'] as bool? ?? true,
        sun: j['sun'] as bool? ?? true,
        blueAndGolden: j['blueAndGolden'] as bool? ?? true,
        hourly: j['hourly'] as bool? ?? true,
      );
    } catch (_) {
      return const WeatherOptions();
    }
  }
}

/// Lugar encontrado por el buscador.
class PlaceResult {
  final String name;
  final String? region;
  final String? country;
  final double latitude;
  final double longitude;

  const PlaceResult({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region,
    this.country,
  });

  String get label => [
    name,
    if (region != null && region!.isNotEmpty && region != name) region,
    if (country != null && country!.isNotEmpty) country,
  ].join(', ');
}
