import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lo que se sube a la nube vuelve igual al descargarlo.
void main() {
  late AppDatabase db;
  late int projectId;
  late int sceneId;

  /// Columnas de `Shots` que no viajan tal cual: ids locales y referencias,
  /// que el bundle lleva como claves (`sceneKey`, `lightSetupKey`,
  /// `shotSetKey`, `route`).
  const shotColumnsAsKeys = {
    'id',
    'scene_id',
    'project_id',
    'light_setup_id',
    'location_base_plan_id',
    'route_json',
  };

  String camel(String snake) => snake.replaceAllMapped(
    RegExp(r'_([a-z])'),
    (m) => m.group(1)!.toUpperCase(),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'lala'));
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'INT. CASA - DÍA',
        locationCanonical: 'INT. CASA - DÍA',
        locationPureName: 'CASA',
      ),
    );
  });

  Future<int> importIntoNewProject(Map<String, dynamic> bundle) async {
    final target = await db.insertProject(
      ProjectsCompanion.insert(name: 'descargado'),
    );
    await ProjectContentBundle.importBundle(db, target, bundle);
    return target;
  }

  test('un plano vuelve con todos sus datos', () async {
    // Las rutas existen en este equipo: al importar se conservan.
    final dir = Directory.systemTemp.createTempSync('iris_roundtrip');
    addTearDown(() => dir.deleteSync(recursive: true));
    String file(String name) =>
        (File('${dir.path}/$name')..writeAsBytesSync([1])).path;
    final ref = file('ref.png');
    final plan = file('planta.png');
    final sb = file('sb.png');
    await db
        .into(db.shots)
        .insert(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: 3,
            framing: const Value('PMC'),
            lens: const Value('50mm'),
            angle: const Value('picado'),
            movement: const Value('DOLLY'),
            fStop: const Value('T2.8'),
            shutterAngle: const Value('172.8'),
            fps: const Value(48),
            action: const Value('Entra por la puerta'),
            notes: const Value('Nota'),
            notesHighlight: const Value('#FFCC00'),
            description: const Value('Plano de llegada'),
            referenceImagePath: Value(ref),
            cameraPlanImagePath: Value(plan),
            charactersJson: const Value('["Ana"]'),
            durationSeconds: const Value(12),
            scriptAnchorIndex: const Value(140),
            autoNumbering: const Value(false),
            sortOrder: const Value(2),
            lightOverridesJson: const Value('{"off":[1]}'),
            storyboardImagePath: Value(sb),
            cellStylesJson: const Value('{"lens":"bold"}'),
            coverImage: const Value('reference'),
          ),
        );

    final bundle = await ProjectContentBundle.export(db, projectId);
    final target = await importIntoNewProject(bundle);

    final original = (await (db.select(
      db.shots,
    )..where((s) => s.projectId.equals(projectId))).getSingle()).toJson();
    final imported = (await (db.select(
      db.shots,
    )..where((s) => s.projectId.equals(target))).getSingle()).toJson();

    for (final column in db.shots.$columns) {
      if (shotColumnsAsKeys.contains(column.name)) continue;
      final key = camel(column.name);
      expect(imported[key], original[key], reason: 'Shots.${column.name}');
    }
  });

  test('toda columna nueva de Shots viaja o se declara como clave', () async {
    await db
        .into(db.shots)
        .insert(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: 1,
          ),
        );
    final bundle = await ProjectContentBundle.export(db, projectId);
    final exported = Map<String, dynamic>.from(
      (bundle['shots'] as List).single as Map,
    );
    // Los campos opcionales se omiten si están vacíos; aquí basta con que el
    // test de arriba los recorra. Este falla si alguien añade una columna a
    // Shots sin pensar en la sincronización.
    const optional = {
      'shutter_angle',
      'fps',
      'description',
      'auto_numbering',
      'camera_plan_image_path',
      'export_layout_json',
      'cover_image',
      'plan_view_json',
    };
    for (final column in db.shots.$columns) {
      if (shotColumnsAsKeys.contains(column.name)) continue;
      if (optional.contains(column.name)) continue;
      expect(
        exported.containsKey(camel(column.name)),
        isTrue,
        reason:
            'Shots.${column.name} no viaja en el bundle: añádela a '
            'ProjectContentBundle o a shotColumnsAsKeys.',
      );
    }
    // Sin valor, no cambian la huella de los proyectos que no los usan.
    for (final key in optional) {
      expect(exported.containsKey(camel(key)), isFalse, reason: key);
    }
  });

  test('un plano sin escena se deja fuera en vez de romper', () async {
    await db
        .into(db.shots)
        .insert(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: 1,
          ),
        );
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('DELETE FROM scenes WHERE id = ?', [sceneId]);

    final bundle = await ProjectContentBundle.export(db, projectId);

    expect(bundle['shots'], isEmpty);
  });

  test(
    'un esquema de luz de la biblia conserva su localización y su set',
    () async {
      final siteId = await db
          .into(db.locationSites)
          .insert(
            LocationSitesCompanion.insert(projectId: projectId, name: 'Casa'),
          );
      final setId = await db
          .into(db.locationBasePlans)
          .insert(
            LocationBasePlansCompanion.insert(
              projectId: projectId,
              locationName: 'Salón',
              siteId: Value(siteId),
            ),
          );
      final bibleId = (await db.ensureVisualBibleForProject(projectId)).id;
      await db
          .into(db.lightingSetups)
          .insert(
            LightingSetupsCompanion.insert(
              bibleId: bibleId,
              setupName: 'Noche',
              diagramJson: '{}',
              locationSiteId: Value(siteId),
              locationBasePlanId: Value(setId),
            ),
          );

      final bundle = await ProjectContentBundle.export(db, projectId);
      final target = await importIntoNewProject(bundle);

      final targetBible = (await db.ensureVisualBibleForProject(target)).id;
      final setup = await (db.select(
        db.lightingSetups,
      )..where((s) => s.bibleId.equals(targetBible))).getSingle();
      final site = await (db.select(
        db.locationSites,
      )..where((s) => s.id.equals(setup.locationSiteId!))).getSingle();
      final set = await (db.select(
        db.locationBasePlans,
      )..where((s) => s.id.equals(setup.locationBasePlanId!))).getSingle();

      expect(site.projectId, target);
      expect(site.name, 'Casa');
      expect(set.projectId, target);
      expect(set.locationName, 'Salón');
    },
  );

  test('una ruta de otro equipo se queda hasta que la descarga la cambie',
      () async {
    await db
        .into(db.shots)
        .insert(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: 1,
            storyboardImagePath: const Value('/Users/otro/no-existe/sb.png'),
          ),
        );
    final bundle = await ProjectContentBundle.export(db, projectId);
    final target = await importIntoNewProject(bundle);

    final shot = await (db.select(
      db.shots,
    )..where((s) => s.projectId.equals(target))).getSingle();
    // Si se vaciara, la huella diría que aquí se borró y el borrado subiría.
    expect(shot.storyboardImagePath, '/Users/otro/no-existe/sb.png');
    expect(shot.uid, isNotNull);
  });

  test('en las listas de bocetos se guardan los sitios y los setup:', () async {
    final dir = Directory.systemTemp.createTempSync('iris_lists');
    addTearDown(() => dir.deleteSync(recursive: true));
    final here = (File('${dir.path}/aqui.png')..writeAsBytesSync([1])).path;
    await db
        .into(db.shots)
        .insert(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: 1,
            // jsonEncode: en Windows la ruta lleva «\», que hay que escapar.
            cameraPlanImagePath: Value(
              jsonEncode(['/Users/otro/falta.png', 'setup:12', here]),
            ),
          ),
        );
    final bundle = await ProjectContentBundle.export(db, projectId);
    final target = await importIntoNewProject(bundle);

    final shot = await (db.select(
      db.shots,
    )..where((s) => s.projectId.equals(target))).getSingle();
    expect(shot.cameraPlanImagePath, jsonEncode(['', 'setup:12', here]));
  });
  group('grupos de sets (v9)', () {
    test('grupos, cambios de entorno, orden de rodaje y modo vuelven igual',
        () async {
      final siteId = await db.insertSite(
        LocationSitesCompanion.insert(
          projectId: projectId,
          name: 'Calle Raval',
          setOrderMode: const Value('narrative'),
        ),
      );
      final groupId = await db.insertSetGroup(
        SetGroupsCompanion.insert(
          projectId: projectId,
          locationSiteId: Value(siteId),
          name: 'Fondo fachada kebab',
          planJson: const Value('{"version":2,"elements":[]}'),
          sortOrder: const Value(2),
        ),
      );
      await db.insertLightSetup(
        LightSetupsCompanion.insert(
          projectId: projectId,
          locationSiteId: Value(siteId),
          name: 'Setup A',
          groupId: Value(groupId),
          envOverridesJson: const Value('{"pared":{"hidden":true}}'),
          shootOrder: const Value(4),
        ),
      );
      await db.insertLightSetup(
        LightSetupsCompanion.insert(projectId: projectId, name: 'Suelto'),
      );

      final bundle = await ProjectContentBundle.export(db, projectId);
      expect(bundle['version'], 9);
      final target = await importIntoNewProject(bundle);

      final site = await (db.select(
        db.locationSites,
      )..where((s) => s.projectId.equals(target))).getSingle();
      expect(site.setOrderMode, 'narrative');

      final original = (await db.getSetGroupsForProject(projectId)).single;
      final group = (await db.getSetGroupsForProject(target)).single;
      expect(group.uid, original.uid);
      expect(group.name, 'Fondo fachada kebab');
      expect(group.planJson, original.planJson);
      expect(group.sortOrder, 2);
      expect(group.locationSiteId, site.id);

      final setups = await db.getLightSetupsForProject(target);
      final a = setups.firstWhere((s) => s.name == 'Setup A');
      final loose = setups.firstWhere((s) => s.name == 'Suelto');
      expect(a.groupId, group.id);
      expect(a.envOverridesJson, '{"pared":{"hidden":true}}');
      expect(a.shootOrder, 4);
      expect(loose.groupId, isNull);
      expect(loose.envOverridesJson, isNull);
      expect(loose.shootOrder, isNull);
    });

    test('sin grupos el bundle no lleva los campos nuevos', () async {
      await db.insertSite(
        LocationSitesCompanion.insert(projectId: projectId, name: 'Calle'),
      );
      await db.insertLightSetup(
        LightSetupsCompanion.insert(projectId: projectId, name: 'Setup A'),
      );
      final bundle = await ProjectContentBundle.export(db, projectId);
      // Así la huella de los proyectos que no los usan no cambia.
      expect(bundle.containsKey('setGroups'), isFalse);
      final setup = (bundle['lightSetups'] as List).single as Map;
      expect(setup.containsKey('setGroupKey'), isFalse);
      expect(setup.containsKey('envOverridesJson'), isFalse);
      expect(setup.containsKey('shootOrder'), isFalse);
      final site = (bundle['locationSites'] as List).single as Map;
      expect(site.containsKey('setOrderMode'), isFalse);
    });

    test('un bundle v8 se sigue importando', () async {
      final bundle = <String, dynamic>{
        'version': 8,
        'locationSites': [
          {'uid': 'site-uid', 'siteKey': 'site:0:Calle', 'name': 'Calle'},
        ],
        'lightSetups': [
          {
            'uid': 'setup-uid',
            'lightSetupKey': 'lightSetup:0',
            'siteKey': 'site:0:Calle',
            'name': 'Setup A',
            'planJson': null,
            'sortOrder': 0,
            'kind': 'planta',
          },
        ],
      };
      final target = await importIntoNewProject(bundle);
      expect(await db.getSetGroupsForProject(target), isEmpty);
      final setup = (await db.getLightSetupsForProject(target)).single;
      expect(setup.name, 'Setup A');
      expect(setup.groupId, isNull);
      expect(setup.envOverridesJson, isNull);
      expect(setup.shootOrder, isNull);
      expect(setup.locationSiteId, isNotNull);
    });
  });
}
