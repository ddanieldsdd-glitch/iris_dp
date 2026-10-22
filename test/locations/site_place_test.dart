import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/core/weather/weather_models.dart';
import 'package:iris_dp/core/weather/weather_service.dart';
import 'package:iris_dp/features/locations/site_place.dart';

class _FakeWeather implements WeatherProvider {
  @override
  Future<WeatherSnapshot?> forecast({
    required double latitude,
    required double longitude,
    required String date,
  }) async => null;

  @override
  Future<List<PlaceResult>> searchPlaces(String query) async => const [
    PlaceResult(
      name: 'Barcelona',
      region: 'Cataluña',
      country: 'España',
      latitude: 41.3874,
      longitude: 2.1686,
    ),
  ];
}

void main() {
  test('parseCoordinates lee lo que copia Google Maps', () {
    final a = parseCoordinates('41.3851, 2.1734')!;
    expect(a.latitude, closeTo(41.3851, 1e-9));
    expect(a.longitude, closeTo(2.1734, 1e-9));
    expect(parseCoordinates('41.3851,2.1734')!.longitude, closeTo(2.1734, 1e-9));
    expect(parseCoordinates('(41.3851 2.1734)')!.latitude, closeTo(41.3851, 1e-9));
    final south = parseCoordinates('-33.4489, -70.6693')!;
    expect(south.latitude, closeTo(-33.4489, 1e-9));
    expect(south.longitude, closeTo(-70.6693, 1e-9));
    // Coma decimal, separadas por espacio.
    expect(parseCoordinates('41,3851 2,1734')!.latitude, closeTo(41.3851, 1e-9));
    expect(parseCoordinates('41, 2')!.longitude, 2);
  });

  test('parseCoordinates rechaza lo que no son coordenadas', () {
    expect(parseCoordinates('Barcelona'), isNull);
    expect(parseCoordinates('Calle Raval 12'), isNull);
    expect(parseCoordinates('41.38'), isNull);
    expect(parseCoordinates('95.0, 2.0'), isNull);
    expect(parseCoordinates('41.0, 190.0'), isNull);
    expect(parseCoordinates(''), isNull);
  });

  group('en la base', () {
    late AppDatabase db;
    late int projectId;
    late int siteId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      projectId = await db
          .into(db.projects)
          .insert(ProjectsCompanion.insert(name: 'P'));
      siteId = await db
          .into(db.locationSites)
          .insert(
            LocationSitesCompanion.insert(projectId: projectId, name: 'RAVAL'),
          );
    });
    tearDown(() => db.close());

    test('cambiar la ubicación borra la previsión de sus jornadas', () async {
      final otherSite = await db
          .into(db.locationSites)
          .insert(
            LocationSitesCompanion.insert(projectId: projectId, name: 'OTRA'),
          );
      Future<int> day(int site) => db
          .into(db.shootDocuments)
          .insert(
            ShootDocumentsCompanion.insert(
              projectId: projectId,
              name: 'J',
              locationSiteId: Value(site),
              weatherSnapshotJson: const Value('{"x":1}'),
            ),
          );
      final mine = await day(siteId);
      final other = await day(otherSite);

      await db.setSitePlace(
        siteId,
        latitude: 41.0,
        longitude: 2.0,
        placeLabel: 'Punto',
      );

      final docs = {
        for (final d in await db.select(db.shootDocuments).get()) d.id: d,
      };
      expect(docs[mine]!.weatherSnapshotJson, isNull);
      expect(docs[other]!.weatherSnapshotJson, isNotNull);
      expect((await db.getSiteById(siteId))!.latitude, 41.0);
    });

    testWidgets('ubicar, ver el sol y quitar', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            weatherProviderProvider.overrideWithValue(_FakeWeather()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: StreamBuilder<List<LocationSite>>(
                stream: db.watchSitesForProject(projectId),
                builder: (_, snap) => snap.hasData
                    ? SitePlaceCard(site: snap.data!.first)
                    : const SizedBox(),
              ),
            ),
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await settle();
      expect(find.text('Sin ubicar en el mapa'), findsOneWidget);
      expect(find.text('Amanecer'), findsNothing);

      await tester.tap(find.text('Ubicar'));
      await settle();
      await tester.tap(find.byTooltip('Buscar'));
      await settle();
      await tester.tap(find.text('Barcelona, Cataluña, España'));
      await settle();

      expect(find.text('Barcelona, Cataluña, España'), findsOneWidget);
      expect(find.text('41.38740, 2.16860'), findsOneWidget);
      expect(find.text('Amanecer'), findsOneWidget);
      expect(find.text('Hora dorada (tarde)'), findsOneWidget);

      // Coordenadas pegadas: el punto exacto, sin pasar por el buscador.
      await tester.tap(find.text('Cambiar'));
      await settle();
      await tester.enterText(find.byType(TextField), '41.3800, 2.1700');
      await settle();
      await tester.tap(find.textContaining('Usar el punto'));
      await settle();
      expect(find.text('41.38000, 2.17000'), findsWidgets);

      await tester.tap(find.text('Quitar'));
      await settle();
      expect(find.text('Sin ubicar en el mapa'), findsOneWidget);
      expect((await db.select(db.locationSites).get()).first.latitude, isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
