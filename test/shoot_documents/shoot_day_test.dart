import 'dart:io';

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
import 'package:iris_dp/features/shoot_documents/shoot_day_screen.dart';
import 'package:iris_dp/features/technical_script/technical_script_export.dart';
import 'package:iris_dp/features/technical_script/technical_script_settings.dart';
import 'package:iris_dp/shared/pdf_export/technical_script_pdf.dart';

class _FakeWeather implements WeatherProvider {
  int asked = 0;

  @override
  Future<WeatherSnapshot?> forecast({
    required double latitude,
    required double longitude,
    required String date,
  }) async {
    asked++;
    return WeatherSnapshot(
      fetchedAt: DateTime(2026, 10, 6, 10, 40),
      date: date,
      utcOffsetSeconds: 7200,
      temperatureMin: 13,
      temperatureMax: 22,
      weatherCode: 61,
      precipitationSum: 1.2,
      precipitationProbabilityMax: 60,
      windMax: 22,
      gustsMax: 41,
    );
  }

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

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int projectId;
  late int siteId;
  late int dayId;
  late List<int> shotIds;

  Future<void> seed({bool located = true, DateTime? date}) async {
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Kebab Khaled'),
    );
    siteId = await db.insertSite(
      LocationSitesCompanion.insert(
        projectId: projectId,
        name: 'CALLE RAVAL',
        latitude: Value(located ? 41.3874 : null),
        longitude: Value(located ? 2.1686 : null),
        placeLabel: Value(located ? 'Barcelona, Cataluña, España' : null),
      ),
    );
    Future<int> scene(int n, String place) => db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: n,
        name: place,
        locationCanonical: 'EXT. $place - NOCHE',
        locationPureName: place,
        sortOrder: Value(n),
      ),
    );
    final calle = await scene(1, 'CALLE RAVAL');
    final kebab = await scene(6, 'KEBAB KHALED');
    Future<int> shot(int sceneId, int n, String framing) => db.insertShot(
      ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: n,
        sortOrder: Value(n - 1),
        framing: Value(framing),
      ),
    );
    shotIds = [
      await shot(calle, 1, 'PP de **ALI**'),
      await shot(calle, 2, 'PG frontal'),
      await shot(kebab, 1, 'P seguimiento'),
    ];
    dayId = await db.insertShootDocument(
      ShootDocumentsCompanion.insert(
        projectId: projectId,
        name: 'Jornada 1',
        kind: const Value(kShootDayKind),
        shootDate: Value(_iso(date ?? DateTime.now())),
        locationSiteId: Value(siteId),
      ),
    );
  }

  Future<void> addToDay(List<int> order) async {
    for (var i = 0; i < order.length; i++) {
      final shot = (await db.getShotById(order[i]))!;
      await db.insertShootDocumentBlock(
        ShootDocumentBlocksCompanion.insert(
          documentId: dayId,
          sortOrder: Value(i),
          blockType: 'shot',
          sceneId: Value(shot.sceneId),
          shotId: Value(shot.id),
        ),
      );
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  test('el documento de la jornada sigue el orden de rodaje y conserva el '
      'número de plano del guion técnico', () async {
    await seed(date: DateTime(2026, 10, 12));
    // Se rueda primero el kebab, luego la calle al revés.
    await addToDay([shotIds[2], shotIds[1], shotIds[0]]);

    final doc = (await buildShootDayScriptDoc(
      db,
      dayId,
      const TechnicalScriptSettings(),
    ))!;

    expect(doc.title, 'GUION TÉCNICO DE RODAJE · KEBAB KHALED');
    expect(doc.columns.first.label, 'ORDEN');
    expect(doc.sections.map((s) => s.title), [
      '6. EXT. KEBAB KHALED - NOCHE',
      '1. EXT. CALLE RAVAL - NOCHE',
    ]);
    final rows = doc.sections.expand((s) => s.rows).toList();
    expect(rows.map((r) => r.cells['orden']), ['1', '2', '3']);
    expect(rows.map((r) => r.cells['esc']), ['6', '1', '1']);
    expect(rows.map((r) => r.cells['plano']), ['1', '2', '1']);

    final subtitle = doc.subtitle!.split('\n');
    expect(subtitle[0], 'Jornada 1 · lunes 12 de octubre de 2026');
    expect(subtitle[1], 'CALLE RAVAL · Barcelona, Cataluña, España');
    // A esa distancia no hay previsión, pero el sol se calcula.
    expect(subtitle.any((l) => l.startsWith('Amanecer')), isTrue);
    expect(subtitle.any((l) => l.startsWith('Hora azul')), isTrue);

    // El PDF se genera con la franja de jornada arriba.
    final bytes = await TechnicalScriptPdfExporter.buildBytes(doc);
    expect(bytes.length, greaterThan(2000));
    final out = Platform.environment['EXPORT_OUT'];
    if (out != null) File('$out/jornada.pdf').writeAsBytesSync(bytes);
  });

  test('una misma escena partida en el día sale en dos tablas', () async {
    await seed(date: DateTime(2026, 10, 12));
    await addToDay([shotIds[0], shotIds[2], shotIds[1]]);
    final doc = (await buildShootDayScriptDoc(
      db,
      dayId,
      const TechnicalScriptSettings(),
    ))!;
    expect(doc.sections.map((s) => s.title), [
      '1. EXT. CALLE RAVAL - NOCHE',
      '6. EXT. KEBAB KHALED - NOCHE',
      '1. EXT. CALLE RAVAL - NOCHE',
    ]);
  });

  testWidgets('pantalla de la jornada: sol, previsión y orden de rodaje', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await seed();
      await addToDay([shotIds[2], shotIds[0]]);
    });
    final weather = _FakeWeather();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          weatherProviderProvider.overrideWithValue(weather),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: ShootDayScreen(projectId: projectId, documentId: dayId),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    expect(tester.takeException(), isNull);
    expect(find.text('Jornada 1'), findsOneWidget);
    expect(find.text('Barcelona, Cataluña, España'), findsOneWidget);
    // El sol sale sin conexión.
    expect(find.textContaining(RegExp(r'Amanecer \d')), findsOneWidget);
    expect(find.text('Sin previsión descargada.'), findsOneWidget);

    await tester.tap(find.text('Descargar'));
    await settle();
    expect(weather.asked, 1);
    expect(find.textContaining('Lluvia débil · 13–22 °C'), findsOneWidget);
    expect(find.textContaining('Previsión descargada el'), findsOneWidget);

    // Quitar el viento del documento.
    await tester.tap(find.text('Viento'));
    await settle();
    expect(find.textContaining('rachas'), findsNothing);

    // Orden de rodaje, con el número de plano del guion técnico.
    expect(find.text('Esc. 6 · Plano 1 · P seguimiento'), findsOneWidget);
    expect(find.text('Esc. 1 · Plano 1 · PP de ALI'), findsOneWidget);
    final first = tester.getTopLeft(
      find.text('Esc. 6 · Plano 1 · P seguimiento'),
    );
    final second = tester.getTopLeft(find.text('Esc. 1 · Plano 1 · PP de ALI'));
    expect(first.dy, lessThan(second.dy));

    await tester.tap(find.byTooltip('Quitar de la jornada').first);
    await settle();
    expect(find.text('Esc. 6 · Plano 1 · P seguimiento'), findsNothing);
    // El plano sigue en el guion técnico.
    expect(await db.getShotById(shotIds[2]), isNotNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('una localización sin ubicar se ubica con el buscador', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() => seed(located: false));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          weatherProviderProvider.overrideWithValue(_FakeWeather()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: ShootDayScreen(projectId: projectId, documentId: dayId),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    expect(find.textContaining('Sin ubicar en el mapa'), findsOneWidget);
    expect(find.textContaining(RegExp(r'Amanecer \d')), findsNothing);

    await tester.tap(find.text('Ubicar'));
    await settle();
    await tester.tap(find.byTooltip('Buscar'));
    await settle();
    await tester.tap(find.text('Barcelona, Cataluña, España'));
    await settle();

    final site = await db.getSiteById(siteId);
    expect(site!.latitude, closeTo(41.39, 0.01));
    expect(site.placeLabel, 'Barcelona, Cataluña, España');
    expect(find.textContaining(RegExp(r'Amanecer \d')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
