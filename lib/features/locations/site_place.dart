import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/user_error.dart';
import '../../core/weather/sun_calculator.dart';
import '../../core/weather/weather_models.dart';
import '../../core/weather/weather_service.dart';

/// Lee unas coordenadas pegadas, como las copia Google Maps:
/// "41.3851, 2.1734". Nulo si el texto no son dos números válidos.
({double latitude, double longitude})? parseCoordinates(String text) {
  final match = RegExp(
    r'^\s*\(?\s*(-?\d{1,2}(?:[.,]\d+)?)\s*[,;\s]\s*(-?\d{1,3}(?:[.,]\d+)?)\s*\)?\s*$',
  ).firstMatch(text);
  if (match == null) return null;
  // "41,38 2,17" usa la coma de decimal; "41.38, 2.17" la usa de separador,
  // y ahí la expresión ya ha partido por ella.
  final lat = double.tryParse(match.group(1)!.replaceAll(',', '.'));
  final lon = double.tryParse(match.group(2)!.replaceAll(',', '.'));
  if (lat == null || lon == null) return null;
  if (lat.abs() > 90 || lon.abs() > 180) return null;
  return (latitude: lat, longitude: lon);
}

String formatCoordinates(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

String _hm(DateTime? utc) {
  if (utc == null) return '—';
  final t = utc.toLocal();
  return '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

/// Sol de un día en un punto, ya en texto para enseñar o guardar.
class SunDaySummary {
  final String sunrise;
  final String sunset;
  final String blueMorning;
  final String goldenMorning;
  final String goldenEvening;
  final String blueEvening;
  final String daylight;

  const SunDaySummary({
    required this.sunrise,
    required this.sunset,
    required this.blueMorning,
    required this.goldenMorning,
    required this.goldenEvening,
    required this.blueEvening,
    required this.daylight,
  });

  factory SunDaySummary.of(DateTime day, double latitude, double longitude) {
    final sun = SunCalculator.forDate(
      year: day.year,
      month: day.month,
      day: day.day,
      latitude: latitude,
      longitude: longitude,
    );
    String span(DateTime? a, DateTime? b) =>
        a == null || b == null ? '—' : '${_hm(a)} – ${_hm(b)}';
    var daylight = '—';
    if (sun.sunrise != null && sun.sunset != null) {
      final minutes = sun.sunset!.difference(sun.sunrise!).inMinutes;
      daylight = '${minutes ~/ 60} h ${minutes % 60} min';
    }
    return SunDaySummary(
      sunrise: _hm(sun.sunrise),
      sunset: _hm(sun.sunset),
      blueMorning: span(sun.dawn, sun.blueHourMorningEnd),
      goldenMorning: span(sun.blueHourMorningEnd, sun.goldenHourMorningEnd),
      goldenEvening: span(sun.goldenHourEveningStart, sun.blueHourEveningStart),
      blueEvening: span(sun.blueHourEveningStart, sun.dusk),
      daylight: daylight,
    );
  }
}

/// Abre el buscador y guarda el lugar elegido en la localización.
Future<void> pickSitePlace(
  BuildContext context,
  WidgetRef ref,
  LocationSite site, {
  String? initialQuery,
}) async {
  final db = ref.read(databaseProvider);
  final place = await showDialog<PlaceResult>(
    context: context,
    builder: (_) => PlaceSearchDialog(initialQuery: initialQuery ?? site.name),
  );
  if (place == null) return;
  await db.setSitePlace(
    site.id,
    latitude: place.latitude,
    longitude: place.longitude,
    placeLabel: place.label,
  );
}

Future<void> openSiteInMaps(double latitude, double longitude) => launchUrl(
  Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
  ),
  mode: LaunchMode.externalApplication,
);

/// Dónde está una localización: se busca por nombre o se pegan las
/// coordenadas. Con [full], además el sol de un día a elegir.
class SitePlaceCard extends ConsumerStatefulWidget {
  final LocationSite site;
  final bool full;

  const SitePlaceCard({super.key, required this.site, this.full = true});

  @override
  ConsumerState<SitePlaceCard> createState() => _SitePlaceCardState();
}

class _SitePlaceCardState extends ConsumerState<SitePlaceCard> {
  DateTime _day = DateTime.now();

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(_day.year - 2),
      lastDate: DateTime(_day.year + 5),
    );
    if (picked != null) setState(() => _day = picked);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final site = widget.site;
    final lat = site.latitude;
    final lon = site.longitude;
    final located = lat != null && lon != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                located ? Icons.place_outlined : Icons.location_off_outlined,
                size: 18,
                color: located ? palette.accent : palette.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      located
                          ? (site.placeLabel ?? 'Ubicación')
                          : 'Sin ubicar en el mapa',
                      style: AppTypography.bodyLarge(palette),
                    ),
                    Text(
                      located
                          ? formatCoordinates(lat, lon)
                          : 'Sirve para el sol y la previsión de las '
                                'jornadas de rodaje.',
                      style: AppTypography.caption(palette),
                    ),
                  ],
                ),
              ),
              if (located) ...[
                TextButton(
                  onPressed: () => openSiteInMaps(lat, lon),
                  child: const Text('Abrir en Maps'),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(databaseProvider)
                      .setSitePlace(
                        site.id,
                        latitude: null,
                        longitude: null,
                        placeLabel: null,
                      ),
                  child: const Text('Quitar'),
                ),
              ],
              TextButton(
                onPressed: () => pickSitePlace(context, ref, site),
                child: Text(located ? 'Cambiar' : 'Ubicar'),
              ),
            ],
          ),
          if (located && widget.full) ...[
            const SizedBox(height: AppSpacing.sm),
            _SunOfDay(
              day: _day,
              summary: SunDaySummary.of(_day, lat, lon),
              onPickDay: _pickDay,
            ),
          ],
        ],
      ),
    );
  }
}

class _SunOfDay extends StatelessWidget {
  final DateTime day;
  final SunDaySummary summary;
  final VoidCallback onPickDay;

  const _SunOfDay({
    required this.day,
    required this.summary,
    required this.onPickDay,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget item(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption(palette)),
        Text(value, style: AppTypography.bodyMedium(palette)),
      ],
    );
    final date =
        '${day.day.toString().padLeft(2, '0')}/'
        '${day.month.toString().padLeft(2, '0')}/${day.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Sol el', style: AppTypography.caption(palette)),
            TextButton.icon(
              onPressed: onPickDay,
              icon: const Icon(Icons.event_outlined, size: 16),
              label: Text(date),
            ),
            Expanded(
              child: Text(
                'Horas en el reloj de este ordenador.',
                textAlign: TextAlign.end,
                style: AppTypography.caption(palette),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: [
            item('Amanecer', summary.sunrise),
            item('Atardecer', summary.sunset),
            item('Horas de luz', summary.daylight),
            item('Hora azul (mañana)', summary.blueMorning),
            item('Hora dorada (mañana)', summary.goldenMorning),
            item('Hora dorada (tarde)', summary.goldenEvening),
            item('Hora azul (tarde)', summary.blueEvening),
          ],
        ),
      ],
    );
  }
}

/// Busca un lugar por su nombre, o acepta unas coordenadas pegadas.
class PlaceSearchDialog extends ConsumerStatefulWidget {
  final String initialQuery;
  const PlaceSearchDialog({super.key, required this.initialQuery});

  @override
  ConsumerState<PlaceSearchDialog> createState() => _PlaceSearchDialogState();
}

class _PlaceSearchDialogState extends ConsumerState<PlaceSearchDialog> {
  final _query = TextEditingController();
  List<PlaceResult> _results = const [];
  bool _searching = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    // El nombre de la localización suele ser un lugar; sirve de partida.
    _query.text = widget.initialQuery;
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final text = _query.text.trim();
    final point = parseCoordinates(text);
    if (point != null) {
      Navigator.pop(context, _pointResult(point.latitude, point.longitude));
      return;
    }
    if (text.length < 2 || _searching) return;
    setState(() {
      _searching = true;
      _notice = null;
    });
    try {
      final results = await ref
          .read(weatherProviderProvider)
          .searchPlaces(text);
      if (!mounted) return;
      setState(() {
        _results = results;
        _notice = results.isEmpty
            ? 'No se ha encontrado ese lugar. Prueba con la ciudad o pega '
                  'las coordenadas.'
            : null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _notice =
              'No se pudo buscar. Comprueba la conexión. '
              '${userFriendlyError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  PlaceResult _pointResult(double latitude, double longitude) => PlaceResult(
    name: 'Punto ${formatCoordinates(latitude, longitude)}',
    latitude: latitude,
    longitude: longitude,
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final point = parseCoordinates(_query.text);
    return AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(
        '¿Dónde está la localización?',
        style: AppTypography.titleMedium(palette),
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Escribe la ciudad o el pueblo, o pega las coordenadas del '
              'punto exacto (en Google Maps: botón derecho sobre el sitio).',
              style: AppTypography.caption(palette),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _query,
              autofocus: true,
              style: AppTypography.bodyLarge(palette),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Ej. Barcelona, o 41.3851, 2.1734',
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Buscar',
                        icon: const Icon(Icons.search, size: 18),
                        onPressed: _search,
                      ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_notice != null)
              Text(_notice!, style: AppTypography.bodyMedium(palette)),
            SizedBox(
              height: 240,
              child: Material(
                type: MaterialType.transparency,
                child: ListView(
                  children: [
                    if (point != null)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.my_location, size: 18),
                        title: Text(
                          'Usar el punto '
                          '${formatCoordinates(point.latitude, point.longitude)}',
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          _pointResult(point.latitude, point.longitude),
                        ),
                      ),
                    for (final place in _results)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined, size: 18),
                        title: Text(place.label),
                        subtitle: Text(
                          formatCoordinates(place.latitude, place.longitude),
                        ),
                        onTap: () => Navigator.pop(context, place),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
        ),
      ],
    );
  }
}
