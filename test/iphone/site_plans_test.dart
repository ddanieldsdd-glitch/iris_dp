import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/locations/location_site_plans.dart';

/// Plantas de la localización: las suyas y las de sus sets, y enlazar una
/// planta libre.
void main() {
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  testWidgets('iPhone 390: lista y enlaza una planta libre', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390, 844) * 3;
    addTearDown(tester.view.reset);

    late LocationSite site;
    await tester.runAsync(() async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Plantas'),
      );
      final siteId = await db.insertSite(
        LocationSitesCompanion.insert(projectId: projectId, name: 'BOSQUE'),
      );
      site = (await db.watchSitesForProject(projectId).first).single;
      expect(site.id, siteId);
      await db.insertLightSetup(LightSetupsCompanion.insert(
        projectId: projectId,
        name: 'Noche americana',
        locationSiteId: Value(siteId),
      ));
      await db.insertLightSetup(LightSetupsCompanion.insert(
        projectId: projectId,
        name: 'Boceto libre',
      ));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SitePlansSection(projectId: site.projectId, site: site),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Noche americana'), findsOneWidget);
    expect(find.text('Boceto libre'), findsNothing);

    await tester.tap(find.text('Enlazar planta libre'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text('Boceto libre'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Boceto libre'), findsOneWidget);
    expect(find.text('Enlazar planta libre'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
