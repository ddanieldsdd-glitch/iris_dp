import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/content_sync_base_store.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/core/sync/sync_plan.dart';
import 'package:iris_dp/core/sync/sync_plan_applier.dart';
import 'package:iris_dp/core/sync/sync_plan_builder.dart';
import 'package:iris_dp/shared/visual_bible/bible_image_links.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_mock_client.dart';

/// Sincronizar no puede perder lo que hay en este dispositivo.
void main() {
  late AppDatabase db;
  late int projectId;
  late int bibleId;

  Future<int> addStill(String path, {String? title}) => db
      .into(db.moodboardImages)
      .insert(
        MoodboardImagesCompanion.insert(
          projectId: projectId,
          imagePath: path,
          bibleId: Value(bibleId),
          sortOrder: Value(path.hashCode % 1000),
          metaJson: Value(title == null ? null : jsonEncode({'title': title})),
          assignedCardIds: const Value('[3]'),
        ),
      );

  Future<String?> content(int bible, String sectionId) async =>
      (await (db.select(db.bibleSectionDefinitions)..where(
                (d) => d.bibleId.equals(bible) & d.id.equals(sectionId),
              ))
              .getSingle())
          .contentJson;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'lala', cloudId: const Value('cloud-1')),
    );
    bibleId = (await db.ensureVisualBibleForProject(projectId)).id;
    await db.ensureBibleSectionLayout(bibleId);
  });

  group('descargar un proyecto', () {
    test('conserva los datos de los stills y rehace los enlaces', () async {
      // Un still de relleno para que los ids nuevos no coincidan con los
      // anteriores.
      await addStill('/tmp/relleno.png');
      final batman = await addStill('/tmp/batman.png', title: 'The Batman');
      final idol = await addStill('/tmp/idol.png', title: 'The Idol');

      await (db.update(db.bibleSectionDefinitions)..where(
            (d) =>
                d.bibleId.equals(bibleId) &
                d.id.equals(BibleSectionId.direction),
          ))
          .write(
            BibleSectionDefinitionsCompanion(
              contentJson: Value(
                jsonEncode({
                  'fields': [
                    {'key': 'tone', 'label': 'Tono', 'type': 'text'},
                    {'key': 'field_actos', 'label': 'Actos', 'type': 'acts'},
                    {'key': 'field_pal', 'label': 'Paleta', 'type': 'palette'},
                    {'key': 'field_gal', 'label': 'Stills', 'type': 'gallery'},
                  ],
                  'values': {
                    'directionData': jsonEncode({
                      'refsMetadata': [
                        {
                          'title': 'Llegada',
                          'imageIds': [batman],
                          'imageId': batman,
                        },
                      ],
                      'pointImages': {
                        'tone': [idol],
                      },
                      // Un número cualquiera que coincide con un id: no es
                      // un enlace y no se toca.
                      'sortOrder': batman,
                    }),
                    'field_actos': jsonEncode([
                      {
                        'title': 'Orden',
                        'body': '',
                        'images': [idol],
                      },
                    ]),
                    'field_pal': jsonEncode({
                      'colors': [
                        {'hex': '#112233', 'name': ''},
                      ],
                      'images': [batman],
                      'show': ['palette', 'images'],
                    }),
                    'field_gal': jsonEncode(['$batman', '$idol']),
                  },
                }),
              ),
            ),
          );
      await db
          .into(db.visualBibleNarrativeCards)
          .insert(
            VisualBibleNarrativeCardsCompanion.insert(
              bibleId: bibleId,
              sectionId: 'lighting',
              kind: 'style',
              title: 'niebla',
              coverMoodboardImageId: Value(idol),
            ),
          );
      await db
          .into(db.bibleSectionEvidence)
          .insert(
            BibleSectionEvidenceCompanion.insert(
              bibleId: bibleId,
              sectionId: 'camera',
              imagePath: '/tmp/prueba.png',
              caption: const Value('Prueba de ISO'),
            ),
          );

      final bundle = jsonDecode(
        jsonEncode(await ProjectContentBundle.export(db, projectId)),
      );
      await ProjectContentBundle.importBundle(
        db,
        projectId,
        Map<String, dynamic>.from(bundle as Map),
      );

      final newBible = (await db.getVisualBibleForProject(projectId))!.id;
      final stills = await (db.select(
        db.moodboardImages,
      )..where((m) => m.projectId.equals(projectId))).get();
      final byPath = {for (final s in stills) s.imagePath: s};
      final newBatman = byPath['/tmp/batman.png']!;
      final newIdol = byPath['/tmp/idol.png']!;

      expect(newBatman.id, isNot(batman), reason: 'los ids cambian');
      expect(jsonDecode(newBatman.metaJson!)['title'], 'The Batman');
      expect(newIdol.assignedCardIds, '[3]');
      expect(newBatman.bibleId, newBible);

      final doc = jsonDecode((await content(newBible, 'direction'))!) as Map;
      final values = doc['values'] as Map;
      final direction = jsonDecode(values['directionData'] as String) as Map;
      expect(direction['refsMetadata'][0]['imageIds'], [newBatman.id]);
      expect(direction['refsMetadata'][0]['imageId'], newBatman.id);
      expect(direction['pointImages']['tone'], [newIdol.id]);
      expect(direction['sortOrder'], batman);
      expect(jsonDecode(values['field_actos'] as String)[0]['images'], [
        newIdol.id,
      ]);
      expect(jsonDecode(values['field_pal'] as String)['images'], [
        newBatman.id,
      ]);
      expect(jsonDecode(values['field_gal'] as String), [
        '${newBatman.id}',
        '${newIdol.id}',
      ]);

      final cards = await (db.select(
        db.visualBibleNarrativeCards,
      )..where((c) => c.bibleId.equals(newBible))).get();
      expect(cards.single.title, 'niebla');
      expect(cards.single.coverMoodboardImageId, newIdol.id);
      expect(
        await db.select(db.visualBibleNarrativeCards).get(),
        hasLength(1),
        reason: 'no quedan tarjetas de la biblia anterior',
      );

      final evidence = await (db.select(
        db.bibleSectionEvidence,
      )..where((e) => e.bibleId.equals(newBible))).get();
      expect(evidence.single.caption, 'Prueba de ISO');
    });

    test('si la importación falla, el contenido anterior sigue ahí', () async {
      await addStill('/tmp/batman.png', title: 'The Batman');
      final bundle = await ProjectContentBundle.export(db, projectId);
      // Una fila imposible de insertar a mitad de la importación.
      (bundle['moodboardImages'] as List).add({'imagePath': null});

      await expectLater(
        ProjectContentBundle.importBundle(db, projectId, bundle),
        throwsA(anything),
      );

      final stills = await db.select(db.moodboardImages).get();
      expect(stills.single.metaJson, contains('The Batman'));
      expect(await db.getVisualBibleForProject(projectId), isNotNull);
    });

    test('los datos de un still cuentan como cambio', () async {
      final id = await addStill('/tmp/batman.png', title: 'The Batman');
      final before = await ProjectContentBundle.computeLocalHash(db, projectId);
      await (db.update(db.moodboardImages)..where((m) => m.id.equals(id)))
          .write(const MoodboardImagesCompanion(metaJson: Value('{"title":"X"}')));
      final after = await ProjectContentBundle.computeLocalHash(db, projectId);
      expect(after, isNot(before));
    });
  });

  test('un enlace sin imagen nueva se deja como está', () {
    const json = '{"values":{"x":"{\\"imageIds\\":[9]}"}}';
    expect(BibleImageLinks.remap(json, {1: 2}), json);
    expect(BibleImageLinks.remap(json, const {}), json);
  });

  group('qué se hace con el contenido', () {
    Future<List<SyncPlanItem>> plan({
      required String cloudHash,
      String updatedAt = '2030-01-01T00:00:00.000Z',
    }) async {
      final client = createSupabaseMockClient(
        snapshotsTableMissing: false,
        cloudProjects: [
          {
            'id': 'cloud-1',
            'workspace_id': 'ws',
            'name': 'lala',
            'director_display': null,
            'description': null,
            'client_name': null,
            'status': 'preproduction',
            'sort_order': 0,
            'updated_at': '2020-01-01T00:00:00.000Z',
          },
        ],
        snapshots: [
          {
            'project_id': 'cloud-1',
            'content_hash': cloudHash,
            'content': {'summary': <String, dynamic>{}},
            'updated_at': updatedAt,
          },
        ],
      );
      final built = await SyncPlanBuilder(db, client).build('ws');
      return built.items.where((i) => i.isContentSync).toList();
    }

    test('cambios solo aquí se suben, aunque la nube tenga hora posterior', () async {
      await ContentSyncBaseStore.save(db, projectId,
        const ContentSyncBase(localHash: 'antes', cloudHash: 'nube-1'),
      );
      final items = await plan(cloudHash: 'nube-1');
      expect(items.single.action, SyncPlanAction.pushContentLocal);
    });

    test('cambios solo en la nube se descargan', () async {
      final local = await ProjectContentBundle.computeLocalHash(db, projectId);
      await ContentSyncBaseStore.save(db, projectId,
        ContentSyncBase(localHash: local, cloudHash: 'nube-1'),
      );
      final items = await plan(cloudHash: 'nube-2');
      expect(items.single.action, SyncPlanAction.pullContentCloud);
    });

    test('cambios en los dos sitios piden decidir y proponen lo local', () async {
      await ContentSyncBaseStore.save(db, projectId,
        const ContentSyncBase(localHash: 'antes', cloudHash: 'nube-1'),
      );
      final items = await plan(cloudHash: 'nube-2');
      expect(items.single.action, SyncPlanAction.contentConflict);
      expect(items.single.choice, SyncResolutionChoice.useLocal);
    });

    test('sin punto de partida nunca se descarga sola', () async {
      final items = await plan(cloudHash: 'nube-1');
      expect(items.single.action, SyncPlanAction.contentConflict);
    });

    test('nada cambia: no hay nada que hacer', () async {
      final local = await ProjectContentBundle.computeLocalHash(db, projectId);
      await ContentSyncBaseStore.save(db, projectId,
        ContentSyncBase(localHash: local, cloudHash: 'nube-1'),
      );
      expect(await plan(cloudHash: 'nube-1'), isEmpty);
    });
  });

  test('actualizar nombre o estado desde la nube no toca el contenido', () async {
    final still = await addStill('/tmp/batman.png', title: 'The Batman');
    final client = createSupabaseMockClient(snapshotsTableMissing: false);
    final project = await db.getProject(projectId);

    await SyncPlanApplier(db, client).apply(
      SyncPlan(
        items: [
          SyncPlanItem(
            action: SyncPlanAction.updateLocalFromCloud,
            title: 'lala',
            description: '',
            localProjectId: projectId,
            cloudId: 'cloud-1',
            localProject: project,
            cloudRow: {
              'id': 'cloud-1',
              'name': 'lala (renombrado)',
              'status': 'preproduction',
              'sort_order': 0,
              'updated_at': '2030-01-01T00:00:00.000Z',
            },
          ),
        ],
      ),
      'ws',
    );

    expect((await db.getProject(projectId))!.name, 'lala (renombrado)');
    final stills = await db.select(db.moodboardImages).get();
    expect(stills.single.id, still);
    expect(stills.single.metaJson, contains('The Batman'));
  });
}
