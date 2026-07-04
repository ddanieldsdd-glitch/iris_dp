import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('syncLocationsFromScenes creates locations, default sets and links scenes',
      () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Loc Test'),
    );

    await db.insertScene(ScenesCompanion.insert(
      projectId: projectId,
      number: 1,
      name: 'EXT CALLE DÍA',
      locationCanonical: 'EXT. CALLE - DÍA',
      locationPureName: 'CALLE PUEBLO',
      sortOrder: const Value(1),
    ));
    await db.insertScene(ScenesCompanion.insert(
      projectId: projectId,
      number: 2,
      name: 'INT CASA DÍA',
      locationCanonical: 'INT. SALÓN - DÍA',
      locationPureName: 'CASA DE MARÍA',
      sortOrder: const Value(2),
    ));

    final created = await db.syncLocationsFromScenes(projectId);
    expect(created, 2);

    final sites = await db.watchSitesForProject(projectId).first;
    expect(sites.length, 2);

    final locations = await db.watchLocationsForProject(projectId).first;
    expect(locations.length, 2);

    final scenes = await db.watchScenesForProject(projectId).first;
    expect(scenes.every((s) => s.locationSiteId != null), isTrue);
    expect(scenes.every((s) => s.locationId != null), isTrue);
  });

  test('sync creates default set plus additional sets for distinct scene names',
      () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Bosque Sync'),
    );

    final siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'BOSQUE'),
    );
    await db.ensureDefaultSetForSite(
      projectId: projectId,
      site: (await db.getSiteById(siteId))!,
    );

    await db.insertScene(ScenesCompanion.insert(
      projectId: projectId,
      number: 1,
      name: 'EXT ENTRADA',
      locationCanonical: 'EXT. ENTRADA - DÍA',
      locationPureName: 'ENTRADA',
      locationSiteId: Value(siteId),
      sortOrder: const Value(1),
    ));
    await db.insertScene(ScenesCompanion.insert(
      projectId: projectId,
      number: 2,
      name: 'EXT RÍO',
      locationCanonical: 'EXT. RÍO - DÍA',
      locationPureName: 'RÍO',
      locationSiteId: Value(siteId),
      sortOrder: const Value(2),
    ));

    await db.syncLocationsFromScenes(projectId);

    final sets = await db.watchSetsForSite(siteId).first;
    expect(sets.length, 3);
    expect(
      sets.map((s) => s.locationName.toLowerCase()).toSet(),
      {'bosque', 'entrada', 'río'},
    );
  });

  test('ensureDefaultSetForSite creates base set when site has none', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Default Set'),
    );
    final siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'COCINA'),
    );
    final site = (await db.getSiteById(siteId))!;

    final set = await db.ensureDefaultSetForSite(
      projectId: projectId,
      site: site,
    );

    expect(set.locationName, 'COCINA');
    expect(await db.countSetsForSite(siteId), 1);
  });

  test('creating a site via ensureSite always yields a default set', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Ensure Site'),
    );

    final site = await db.ensureSite(
      projectId: projectId,
      siteName: 'HOSPITAL',
    );
    final sets = await db.watchSetsForSite(site.id).first;

    expect(sets.length, 1);
    expect(sets.single.locationName, 'HOSPITAL');
  });

  test('ensureSiteAndSet supports multiple sets under one location', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Bosque'),
    );

    await db.ensureSiteAndSet(
      projectId: projectId,
      siteName: 'BOSQUE',
      setName: 'ENTRADA DEL BOSQUE',
    );
    await db.ensureSiteAndSet(
      projectId: projectId,
      siteName: 'BOSQUE',
      setName: 'RÍO',
    );
    await db.ensureSiteAndSet(
      projectId: projectId,
      siteName: 'BOSQUE',
      setName: 'PUEBLO DEL BOSQUE',
    );

    final sites = await db.watchSitesForProject(projectId).first;
    expect(sites.length, 1);
    expect(sites.first.name, 'BOSQUE');

    final sets = await db.watchSetsForSite(sites.first.id).first;
    expect(sets.length, 4);
  });

  test('moveSceneToSet reassigns scene to another set in same site', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Move Test'),
    );

    await db.ensureSiteAndSet(
      projectId: projectId,
      siteName: 'BOSQUE',
      setName: 'ENTRADA',
    );
    await db.ensureSiteAndSet(
      projectId: projectId,
      siteName: 'BOSQUE',
      setName: 'RÍO',
    );

    final sites = await db.watchSitesForProject(projectId).first;
    final siteId = sites.single.id;
    final sets = await db.watchSetsForSite(siteId).first;
    final entradaId = sets.singleWhere((s) => s.locationName == 'ENTRADA').id;
    final rioId = sets.singleWhere((s) => s.locationName == 'RÍO').id;

    final sceneId = await db.insertScene(ScenesCompanion.insert(
      projectId: projectId,
      number: 1,
      name: 'EXT BOSQUE DÍA',
      locationCanonical: 'EXT. BOSQUE - DÍA',
      locationPureName: 'ENTRADA',
      locationId: Value(entradaId),
      locationSiteId: Value(siteId),
      sortOrder: const Value(1),
    ));

    final scene = (await db.watchScenesForProject(projectId).first)
        .singleWhere((s) => s.id == sceneId);
    final rioSet = (await db.watchSetsForSite(siteId).first)
        .singleWhere((s) => s.id == rioId);

    await db.moveSceneToSet(scene: scene, targetSet: rioSet);

    final updated = (await db.watchScenesForProject(projectId).first)
        .singleWhere((s) => s.id == sceneId);
    expect(updated.locationId, rioId);
    expect(updated.locationSiteId, siteId);
    expect(updated.locationPureName, 'RÍO');
    expect(updated.locationColor, null);
  });

  test('site images persist for location base gallery', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Site Gallery'),
    );
    final siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'BOSQUE'),
    );
    await db.ensureDefaultSetForSite(
      projectId: projectId,
      site: (await db.getSiteById(siteId))!,
    );

    await db.insertSiteImage(SiteImagesCompanion.insert(
      siteId: siteId,
      imagePath: '/tmp/overview.jpg',
      kind: const Value('overview'),
    ));

    final images = await db.watchImagesForSite(siteId).first;
    expect(images.length, 1);
    expect(images.first.kind, 'overview');
  });
}
