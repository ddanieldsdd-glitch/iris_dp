import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/places/place_search.dart';
import 'package:iris_dp/core/places/static_map.dart';
import 'package:iris_dp/core/weather/weather_service.dart';
import 'package:iris_dp/features/locations/site_place.dart';

/// Ubicar una localización de rodaje: un negocio como «Kebab Khaled» no
/// salía en el buscador, que solo conocía ciudades.
void main() {
  const kebab = '''
[{"lat":"41.3781500","lon":"2.1732300","name":"Kebab Khaled",
  "display_name":"Kebab Khaled, 12, Carrer de Sant Pau, el Raval, Barcelona, Cataluña, España",
  "address":{"amenity":"Kebab Khaled","house_number":"12","road":"Carrer de Sant Pau",
    "suburb":"el Raval","city":"Barcelona","state":"Cataluña","country":"España"}}]
''';

  test('un negocio sale con su nombre y su dirección', () {
    final place = parseNominatim(kebab).single;
    expect(place.name, 'Kebab Khaled');
    expect(place.address, 'Carrer de Sant Pau, 12, Barcelona');
    expect(place.latitude, closeTo(41.37815, 1e-9));
    expect(place.label, 'Kebab Khaled · Carrer de Sant Pau, 12, Barcelona');
  });

  test('una dirección sin nombre toma la calle', () {
    final place = parseNominatim('''
[{"lat":"41.0","lon":"2.0","name":"","display_name":"12, Carrer de Sant Pau, Barcelona",
  "address":{"house_number":"12","road":"Carrer de Sant Pau","city":"Barcelona"}}]
''').single;
    expect(place.name, 'Carrer de Sant Pau, 12');
    expect(
      place.label,
      'Carrer de Sant Pau, 12 · Carrer de Sant Pau, 12, Barcelona',
    );
  });

  test('lo que no es una lista no rompe', () {
    expect(parseNominatim('{"error":"x"}'), isEmpty);
  });

  group('enlaces de Google Maps', () {
    test('el sitio marcado manda sobre la vista', () {
      final p = coordinatesFromMapsLink(
        'https://www.google.com/maps/place/Kebab+Khaled/@41.3780,2.1720,17z/'
        'data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d41.37815!4d2.17323',
      )!;
      expect(p.latitude, closeTo(41.37815, 1e-9));
      expect(p.longitude, closeTo(2.17323, 1e-9));
    });

    test('la vista, la búsqueda y ll', () {
      expect(
        coordinatesFromMapsLink(
          'https://www.google.com/maps/@41.38,2.17,15z',
        )!.latitude,
        41.38,
      );
      expect(
        coordinatesFromMapsLink(
          'https://www.google.com/maps/search/?api=1&query=41.1,-3.5',
        )!.longitude,
        -3.5,
      );
      expect(
        coordinatesFromMapsLink(
          'https://maps.google.com/?ll=40.4,-3.7',
        )!.latitude,
        40.4,
      );
    });

    test('lo que no es de mapas no se lee', () {
      expect(coordinatesFromMapsLink('https://example.com/@41.3,2.1'), isNull);
      expect(coordinatesFromMapsLink('Kebab Khaled'), isNull);
    });

    test('reconoce los enlaces cortos', () {
      expect(isShortMapsLink('https://maps.app.goo.gl/AbC123'), isTrue);
      expect(isShortMapsLink('https://goo.gl/maps/xyz'), isTrue);
      expect(isShortMapsLink('https://www.google.com/maps/@1,2,3z'), isFalse);
      expect(isShortMapsLink('maps.app.goo.gl'), isFalse);
    });

    test('un enlace corto se abre hasta el largo', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'maps.app.goo.gl') {
          return http.Response(
            '',
            302,
            headers: {
              'location':
                  'https://www.google.com/maps/place/X/data=!3d41.37815!4d2.17323',
            },
          );
        }
        return http.Response('', 200);
      });
      final p = await resolveShortMapsLink(
        'https://maps.app.goo.gl/AbC123',
        client: client,
      );
      expect(p!.longitude, closeTo(2.17323, 1e-9));
    });
  });

  test('el buscador junta negocios y ciudades sin repetir', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'nominatim.openstreetmap.org') {
        expect(request.headers['User-Agent'], kPlacesUserAgent);
        return http.Response.bytes(utf8.encode(kebab), 200);
      }
      return http.Response.bytes(
        utf8.encode(
          '{"results":[{"name":"Barcelona","admin1":"Cataluña",'
          '"country":"España","latitude":41.38,"longitude":2.17}]}',
        ),
        200,
      );
    });
    final places = await OpenMeteoWeather(
      client: client,
    ).searchPlaces('Kebab Khaled Barcelona');
    expect([for (final p in places) p.name], ['Kebab Khaled', 'Barcelona']);
  });

  test('si OpenStreetMap falla, salen las ciudades', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'nominatim.openstreetmap.org') {
        throw http.ClientException('sin red');
      }
      return http.Response.bytes(
        utf8.encode(
          '{"results":[{"name":"Barcelona","latitude":41.38,"longitude":2.17}]}',
        ),
        200,
      );
    });
    final places = await OpenMeteoWeather(client: client).searchPlaces('Bcn');
    expect(places.single.name, 'Barcelona');
  });

  group('mapa', () {
    Uint8List tile() => Uint8List.fromList(
      img.encodePng(
        img.Image(width: 256, height: 256)..clear(img.ColorRgb8(200, 220, 200)),
      ),
    );

    test('compone las teselas con la chincheta en el centro', () async {
      final asked = <String>[];
      final client = MockClient((request) async {
        asked.add(request.url.path);
        return http.Response.bytes(tile(), 200);
      });
      final png = await StaticMap(client: client).render(41.37815, 2.17323);
      final image = img.decodePng(png!)!;
      expect(image.width, StaticMap.width);
      expect(image.height, StaticMap.height);
      expect(asked, isNotEmpty);
      expect(asked.every((a) => a.startsWith('/${StaticMap.zoom}/')), isTrue);
      // En el centro, el rojo de la chincheta.
      final center = image.getPixel(
        StaticMap.width ~/ 2 + 6,
        StaticMap.height ~/ 2,
      );
      expect(center.r, greaterThan(200));
      expect(center.g, lessThan(100));
    });

    test('sin teselas no hay mapa', () async {
      final client = MockClient((_) async => http.Response('', 404));
      expect(await StaticMap(client: client).render(41.0, 2.0), isNull);
    });

    test('el punto 0,0 cae en el centro del mundo', () {
      final p = StaticMap.worldPixel(0, 0, zoom: 1);
      expect(p.x, closeTo(256, 1e-6));
      expect(p.y, closeTo(256, 1e-6));
    });
  });

  group('lo que se enseña de la localización', () {
    LocationSite site({double? lat, double? lon, String? label}) =>
        LocationSite(
          id: 1,
          projectId: 1,
          name: 'KEBAB KHALED',
          sortOrder: 0,
          latitude: lat,
          longitude: lon,
          placeLabel: label,
        );

    test('unas coordenadas pegadas no se repiten', () {
      final lines = sitePlaceLines(
        site(lat: 41.37815, lon: 2.17323, label: 'Punto 41.37815, 2.17323'),
      );
      expect(lines.title, 'Punto exacto');
      expect(lines.detail, '41.37815, 2.17323');
    });

    test('un negocio enseña su dirección', () {
      final lines = sitePlaceLines(
        site(
          lat: 41.37815,
          lon: 2.17323,
          label: 'Kebab Khaled · Carrer de Sant Pau, 12, Barcelona',
        ),
      );
      expect(lines.title, 'Kebab Khaled');
      expect(lines.detail, 'Carrer de Sant Pau, 12, Barcelona');
    });

    test('una ciudad enseña sus coordenadas', () {
      final lines = sitePlaceLines(
        site(lat: 41.38, lon: 2.17, label: 'Barcelona, Cataluña, España'),
      );
      expect(lines.title, 'Barcelona, Cataluña, España');
      expect(lines.detail, '41.38000, 2.17000');
    });
  });
}
