import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/visual_bible/services/lighting_narrative_cards_service.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:iris_dp/shared/visual_bible/narrative_card_kind.dart';

void main() {
  late AppDatabase db;
  late int projectId;
  late int bibleId;
  late int planId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
    bibleId = (await db.ensureVisualBibleForProject(projectId)).id;
    planId = (await db.ensureSiteAndSet(
      projectId: projectId,
      siteName: 'CALLE RAVAL',
      setName: 'CALLE RAVAL',
    )).set.id;
  });
  tearDown(() => db.close());

  Future<List<VisualBibleNarrativeCard>> locationCards() async =>
      (await db.select(db.visualBibleNarrativeCards).get())
          .where((c) => c.kind == NarrativeCardKind.locationLight)
          .toList();

  test('abrir la pantalla tres veces a la vez crea una ficha por set', () async {
    await Future.wait([
      for (var i = 0; i < 3; i++)
        LightingNarrativeCardsService.ensureSeeded(
          db: db,
          bibleId: bibleId,
          projectId: projectId,
        ),
    ]);
    expect((await locationCards()).length, 1);
    final all = await db.select(db.visualBibleNarrativeCards).get();
    expect(all.where((c) => c.kind == NarrativeCardKind.overview).length, 1);
  });

  test('las fichas repetidas se funden sin perder texto ni imágenes', () async {
    Future<int> card({String? body}) => db.insertNarrativeCard(
      VisualBibleNarrativeCardsCompanion.insert(
        bibleId: bibleId,
        sectionId: BibleSectionId.lighting,
        kind: NarrativeCardKind.locationLight,
        title: 'CALLE RAVAL',
        body: Value(body),
        locationBasePlanId: Value(planId),
      ),
    );
    final empty = await card();
    final written = await card(body: 'Sodio y sombras largas');
    final withImage = await card();
    final imageId = await db
        .into(db.moodboardImages)
        .insert(
          MoodboardImagesCompanion.insert(
            projectId: projectId,
            imagePath: 'x.png',
            assignedCardIds: Value(jsonEncode([withImage])),
          ),
        );

    final removed = await LightingNarrativeCardsService.mergeDuplicates(
      db,
      bibleId,
    );
    expect(removed, greaterThanOrEqualTo(2));
    final left = await locationCards();
    // Queda una sola, con el texto de una y la imagen de otra.
    expect(left.single.body, 'Sodio y sombras largas');
    // La imagen de la ficha borrada pasa a la que queda.
    final image = (await db.select(db.moodboardImages).get())
        .firstWhere((m) => m.id == imageId);
    expect(jsonDecode(image.assignedCardIds!), [left.single.id]);
    expect(left.single.id, anyOf(written, withImage));
    expect(left.any((c) => c.id == empty), isFalse);

    // Sin repetidas no toca nada.
    expect(await LightingNarrativeCardsService.mergeDuplicates(db, bibleId), 0);
  });
}
