import 'sun_calculator.dart';
import 'weather_models.dart';

/// Texto de la meteorología de una jornada, para la pantalla y para el
/// documento: una línea por tipo de dato, solo de lo que se ha pedido ver.
List<String> weatherSummaryLines({
  required WeatherOptions options,
  required SunTimes? sun,
  required WeatherSnapshot? forecast,

  /// Diferencia horaria del lugar, en segundos, para escribir las horas.
  required int utcOffsetSeconds,

  /// Franja de rodaje, en horas del día; nulas = día entero.
  int? fromHour,
  int? toHour,

  /// La jornada cae dentro del alcance de la previsión.
  bool forecastAvailable = true,
}) {
  final lines = <String>[];
  String clock(DateTime? utc) {
    if (utc == null) return '—';
    final local = utc.add(Duration(seconds: utcOffsetSeconds));
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String number(double? v, {int decimals = 0}) =>
      v == null ? '—' : v.toStringAsFixed(decimals).replaceAll('.', ',');

  if (forecast != null) {
    final parts = <String>[
      if (options.sky) weatherCodeLabel(forecast.weatherCode),
      if (options.temperature)
        '${number(forecast.temperatureMin)}–'
            '${number(forecast.temperatureMax)} °C',
      if (options.rain)
        'Lluvia ${forecast.precipitationProbabilityMax ?? '—'} %'
            '${(forecast.precipitationSum ?? 0) > 0 ? ' (${number(forecast.precipitationSum, decimals: 1)} mm)' : ''}',
      if (options.wind)
        'Viento ${number(forecast.windMax)} km/h, '
            'rachas ${number(forecast.gustsMax)}',
    ];
    if (parts.isNotEmpty) lines.add(parts.join(' · '));
  } else if (options.sky ||
      options.temperature ||
      options.rain ||
      options.wind) {
    lines.add(
      forecastAvailable
          ? 'Sin previsión descargada.'
          : 'Aún no hay previsión: se publica $kForecastNoticeDays días '
                'antes de la jornada.',
    );
  }

  if (sun != null && options.sun) {
    lines.add(
      'Amanecer ${clock(sun.sunrise)} · Atardecer ${clock(sun.sunset)}',
    );
  }
  if (sun != null && options.blueAndGolden) {
    lines.add(
      'Hora azul ${clock(sun.dawn)}–${clock(sun.blueHourMorningEnd)} y '
      '${clock(sun.blueHourEveningStart)}–${clock(sun.dusk)} · '
      'Hora dorada ${clock(sun.blueHourMorningEnd)}–'
      '${clock(sun.goldenHourMorningEnd)} y '
      '${clock(sun.goldenHourEveningStart)}–'
      '${clock(sun.blueHourEveningStart)}',
    );
  }

  if (forecast != null &&
      options.hourly &&
      fromHour != null &&
      toHour != null) {
    final hours = forecast.hoursBetween(fromHour, toHour).toList();
    // De noche (franja que cruza las doce) se leen primero las de la tarde.
    if (fromHour > toHour) {
      hours.sort(
        (a, b) =>
            ((a.hour - fromHour) % 24).compareTo((b.hour - fromHour) % 24),
      );
    }
    for (final h in hours) {
      final parts = <String>[
        if (options.temperature) '${number(h.temperature)} °C',
        if (options.sky) weatherCodeLabel(h.weatherCode),
        if (options.rain) 'lluvia ${h.precipitationProbability ?? '—'} %',
        if (options.wind) 'viento ${number(h.wind)} km/h',
      ];
      if (parts.isEmpty) continue;
      lines.add('${h.hour.toString().padLeft(2, '0')} h: ${parts.join(', ')}');
    }
  }
  return lines;
}

/// Días de antelación con que aparece la previsión, para el aviso.
const kForecastNoticeDays = 16;
