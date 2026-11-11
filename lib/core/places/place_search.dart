import 'dart:convert';

import 'package:http/http.dart' as http;

import '../weather/weather_models.dart';

/// Cómo se presenta la app a los servicios de mapas. OpenStreetMap pide un
/// nombre que la identifique; no lleva nada del usuario.
const kPlacesUserAgent = 'IRIS-DP/1.0 (app de direccion de fotografia)';

/// Busca direcciones y negocios («Kebab Khaled Barcelona», «Carrer de
/// Sant Pau 12») en OpenStreetMap (Nominatim). Sin clave. Se usa solo al
/// pulsar «Buscar», como pide su política de uso.
class NominatimPlaces {
  NominatimPlaces({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 12);

  Future<List<PlaceResult>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '8',
      'accept-language': 'es',
    });
    final response = await _client
        .get(uri, headers: {'User-Agent': kPlacesUserAgent})
        .timeout(_timeout);
    if (response.statusCode != 200) return const [];
    return parseNominatim(utf8.decode(response.bodyBytes));
  }
}

/// Los resultados de Nominatim (`format=jsonv2`, con `addressdetails`).
List<PlaceResult> parseNominatim(String body) {
  final json = jsonDecode(body);
  if (json is! List) return const [];
  final out = <PlaceResult>[];
  for (final r in json) {
    if (r is! Map) continue;
    final lat = double.tryParse('${r['lat']}');
    final lon = double.tryParse('${r['lon']}');
    if (lat == null || lon == null) continue;
    final address = r['address'] is Map
        ? Map<String, dynamic>.from(r['address'] as Map)
        : const <String, dynamic>{};
    String? part(List<String> keys) {
      for (final k in keys) {
        final v = address[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    final road = part(['road', 'pedestrian', 'footway', 'square', 'path']);
    final number = part(['house_number']);
    final city = part(['city', 'town', 'village', 'municipality', 'hamlet']);
    final street = road == null
        ? null
        : number == null
        ? road
        : '$road, $number';
    final line = [?street, ?city].join(', ');
    final display = '${r['display_name'] ?? ''}'.trim();
    final rawName = '${r['name'] ?? ''}'.trim();
    final name = rawName.isNotEmpty
        ? rawName
        : street ?? display.split(',').first.trim();
    out.add(
      PlaceResult(
        name: name.isEmpty ? display : name,
        region: part(['state', 'province', 'region']),
        country: part(['country']),
        address: line.isEmpty ? display : line,
        latitude: lat,
        longitude: lon,
      ),
    );
  }
  return out;
}

/// Las coordenadas de un enlace de Google Maps pegado entero: el punto
/// marcado (`!3d…!4d…`), la vista (`@41.38,2.17,17z`) o la búsqueda
/// (`?q=41.38,2.17`, `?ll=`, `?query=`). Nulo si no las lleva.
({double latitude, double longitude})? coordinatesFromMapsLink(String text) {
  final t = Uri.decodeFull(text.trim());
  if (!t.contains('google.') &&
      !t.contains('goo.gl') &&
      !t.contains('maps.apple.com') &&
      !t.contains('waze.com')) {
    return null;
  }
  ({double latitude, double longitude})? pair(String? a, String? b) {
    final lat = double.tryParse(a ?? '');
    final lon = double.tryParse(b ?? '');
    if (lat == null || lon == null) return null;
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return (latitude: lat, longitude: lon);
  }

  // El sitio marcado manda sobre el centro de la vista.
  final pin = RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)').firstMatch(t);
  if (pin != null) return pair(pin.group(1), pin.group(2));
  final query = RegExp(
    r'[?&](?:q|ll|query|center|destination|daddr)=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)',
  ).firstMatch(t);
  if (query != null) return pair(query.group(1), query.group(2));
  final view = RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)').firstMatch(t);
  if (view != null) return pair(view.group(1), view.group(2));
  return null;
}

/// Si [text] es un enlace corto de Google Maps (`maps.app.goo.gl/…`,
/// `goo.gl/maps/…`), que no lleva coordenadas hasta abrirlo.
bool isShortMapsLink(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || !uri.hasScheme) return false;
  return uri.host == 'maps.app.goo.gl' ||
      (uri.host == 'goo.gl' && uri.path.startsWith('/maps'));
}

/// Abre un enlace corto siguiendo sus redirecciones hasta el enlace largo
/// y saca de él las coordenadas.
Future<({double latitude, double longitude})?> resolveShortMapsLink(
  String text, {
  http.Client? client,
}) async {
  final own = client ?? http.Client();
  try {
    var uri = Uri.parse(text.trim());
    for (var i = 0; i < 6; i++) {
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..headers['User-Agent'] = kPlacesUserAgent;
      final response = await own
          .send(request)
          .timeout(const Duration(seconds: 12));
      final location = response.headers['location'];
      await response.stream.drain<void>();
      if (location == null) {
        return coordinatesFromMapsLink(uri.toString());
      }
      final found = coordinatesFromMapsLink(location);
      if (found != null) return found;
      uri = uri.resolve(location);
    }
    return null;
  } finally {
    if (client == null) own.close();
  }
}
