import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/visual_bible/bible_lighting_data.dart';
import '../../../shared/visual_bible/bible_section_ids.dart';
import '../../../shared/visual_bible/moodboard_association.dart';
import '../../../shared/visual_bible/narrative_card_kind.dart';
import '../visual_bible_model.dart';

/// Seed / sync de cartas narrativas de Iluminación.
abstract final class LightingNarrativeCardsService {
  /// Sembrados en curso, por biblia. Los tres mazos de la pantalla piden el
  /// sembrado a la vez al abrirse: sin esto, cada uno creaba sus fichas y
  /// cada set acababa con tres.
  static final Map<int, Future<void>> _seeding = {};

  /// Asegura overview + styles (desde textureCards) + location_light por set.
  static Future<void> ensureSeeded({
    required AppDatabase db,
    required int bibleId,
    required int projectId,
    Map<String, dynamic>? lightingData,
  }) {
    final running = _seeding[bibleId];
    if (running != null) return running;
    final run = () async {
      try {
        await mergeDuplicates(db, bibleId);
        await _seed(
          db: db,
          bibleId: bibleId,
          projectId: projectId,
          lightingData: lightingData,
        );
      } finally {
        _seeding.remove(bibleId);
      }
    }();
    _seeding[bibleId] = run;
    return run;
  }

  /// Funde las fichas repetidas de una biblia: varias de «visión general» o
  /// varias de la misma localización. Se queda la que tiene más contenido,
  /// le pasa las imágenes y el texto que le falte de las otras, y borra el
  /// resto. Devuelve cuántas ha quitado.
  static Future<int> mergeDuplicates(AppDatabase db, int bibleId) async {
    final cards =
        await (db.select(db.visualBibleNarrativeCards)
              ..where(
                (c) =>
                    c.bibleId.equals(bibleId) &
                    c.sectionId.equals(BibleSectionId.lighting),
              )
              ..orderBy([(c) => OrderingTerm.asc(c.id)]))
            .get();
    final groups = <String, List<VisualBibleNarrativeCard>>{};
    for (final card in cards) {
      final key = switch (card.kind) {
        NarrativeCardKind.overview => 'overview',
        NarrativeCardKind.locationLight when card.locationBasePlanId != null =>
          'plan:${card.locationBasePlanId}',
        _ => null,
      };
      if (key != null) groups.putIfAbsent(key, () => []).add(card);
    }
    final repeated = [
      for (final group in groups.values)
        if (group.length > 1) group,
    ];
    if (repeated.isEmpty) return 0;

    final images = await db.select(db.moodboardImages).get();
    final imagesByCard = <int, List<MoodboardImage>>{};
    for (final image in images) {
      for (final id in MoodboardAssociation.decodeCardIds(
        image.assignedCardIds,
      )) {
        imagesByCard.putIfAbsent(id, () => []).add(image);
      }
    }
    int weight(VisualBibleNarrativeCard c) =>
        (c.body?.trim().length ?? 0) +
        (c.metaJson?.length ?? 0) +
        (c.coverMoodboardImageId != null ? 1000 : 0) +
        (imagesByCard[c.id]?.length ?? 0) * 500;

    var removed = 0;
    await db.transaction(() async {
      for (final group in repeated) {
        // La más completa; a igualdad, la más antigua.
        final keeper = group.reduce(
          (a, b) => weight(b) > weight(a) ? b : a,
        );
        var body = keeper.body;
        var cover = keeper.coverMoodboardImageId;
        var meta = keeper.metaJson;
        for (final other in group) {
          if (other.id == keeper.id) continue;
          if ((body ?? '').trim().isEmpty) body = other.body;
          cover ??= other.coverMoodboardImageId;
          if ((meta ?? '').isEmpty) meta = other.metaJson;
          for (final image in imagesByCard[other.id] ?? const []) {
            final fresh = await (db.select(
              db.moodboardImages,
            )..where((m) => m.id.equals(image.id))).getSingle();
            final ids =
                MoodboardAssociation.decodeCardIds(fresh.assignedCardIds)
                  ..remove(other.id);
            if (!ids.contains(keeper.id)) ids.add(keeper.id);
            await (db.update(
              db.moodboardImages,
            )..where((m) => m.id.equals(image.id))).write(
              MoodboardImagesCompanion(assignedCardIds: Value(jsonEncode(ids))),
            );
          }
          await (db.delete(
            db.visualBibleNarrativeCards,
          )..where((c) => c.id.equals(other.id))).go();
          removed++;
        }
        await (db.update(
          db.visualBibleNarrativeCards,
        )..where((c) => c.id.equals(keeper.id))).write(
          VisualBibleNarrativeCardsCompanion(
            body: Value(body),
            coverMoodboardImageId: Value(cover),
            metaJson: Value(meta),
          ),
        );
      }
    });
    return removed;
  }

  static Future<void> _seed({
    required AppDatabase db,
    required int bibleId,
    required int projectId,
    Map<String, dynamic>? lightingData,
  }) async {
    final data = BibleLightingData.migrate(
      Map<String, dynamic>.from(lightingData ?? {}),
    );
    final existing =
        await (db.select(db.visualBibleNarrativeCards)
              ..where(
                (c) =>
                    c.bibleId.equals(bibleId) &
                    c.sectionId.equals(BibleSectionId.lighting),
              )
              ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
            .get();

    if (!existing.any((c) => c.kind == NarrativeCardKind.overview)) {
      await db.insertNarrativeCard(
        VisualBibleNarrativeCardsCompanion.insert(
          bibleId: bibleId,
          sectionId: BibleSectionId.lighting,
          kind: NarrativeCardKind.overview,
          title: (data['heroTitle'] as String?)?.trim().isNotEmpty == true
              ? (data['heroTitle'] as String).trim()
              : 'Tratamiento de luz',
          body: Value(
            (data['narrativeStory'] as String?)?.trim().isNotEmpty == true
                ? (data['narrativeStory'] as String).trim()
                : null,
          ),
          metaJson: Value(
            jsonEncode({
              if ((data['heroBadge'] as String?)?.trim().isNotEmpty == true)
                'heroBadge': data['heroBadge'],
              if ((data['heroSubtitle'] as String?)?.trim().isNotEmpty == true)
                'heroSubtitle': data['heroSubtitle'],
            }),
          ),
          sortOrder: const Value(-1),
        ),
      );
    }

    final hasStyles = existing.any((c) => c.kind == NarrativeCardKind.style);
    if (!hasStyles) {
      final cards = data[BibleLightingData.textureCardsKey];
      if (cards is List) {
        var order = 0;
        for (final raw in cards) {
          if (raw is! Map) continue;
          final title = (raw['title'] ?? raw['tag'] ?? 'Estilo de luz')
              .toString()
              .trim();
          final note = (raw['note'] ?? raw['meta'] ?? '').toString().trim();
          await db.insertNarrativeCard(
            VisualBibleNarrativeCardsCompanion.insert(
              bibleId: bibleId,
              sectionId: BibleSectionId.lighting,
              kind: NarrativeCardKind.style,
              title: title.isEmpty ? 'Estilo de luz' : title,
              body: Value(note.isEmpty ? null : note),
              sortOrder: Value(order++),
            ),
          );
        }
      }
    }

    final plans = await (db.select(db.locationBasePlans)
          ..where((p) => p.projectId.equals(projectId)))
        .get();
    await _ensureLocationLightCards(db, bibleId, plans, existing);
  }

  static Future<void> _ensureLocationLightCards(
    AppDatabase db,
    int bibleId,
    List<LocationBasePlan> projectPlans,
    List<VisualBibleNarrativeCard> existing,
  ) async {
    if (projectPlans.isEmpty) return;

    final existingPlanIds = existing
        .where((c) => c.kind == NarrativeCardKind.locationLight)
        .map((c) => c.locationBasePlanId)
        .whereType<int>()
        .toSet();

    final refs = await db.watchLocationRefsForBible(bibleId).first;
    final noteByPlan = <int, String>{};
    for (final r in refs) {
      final pid = r.locationBasePlanId;
      if (pid != null &&
          r.lightingNote != null &&
          r.lightingNote!.trim().isNotEmpty) {
        noteByPlan[pid] = r.lightingNote!.trim();
      }
    }

    var order = existing
            .where((c) => c.kind == NarrativeCardKind.locationLight)
            .map((c) => c.sortOrder)
            .fold<int>(0, (a, b) => a > b ? a : b) +
        1;

    for (final plan in projectPlans) {
      if (existingPlanIds.contains(plan.id)) continue;
      final note = noteByPlan[plan.id];
      await db.insertNarrativeCard(
        VisualBibleNarrativeCardsCompanion.insert(
          bibleId: bibleId,
          sectionId: BibleSectionId.lighting,
          kind: NarrativeCardKind.locationLight,
          title: plan.locationName,
          body: Value(note),
          locationBasePlanId: Value(plan.id),
          metaJson: Value(
            note == null ? null : jsonEncode({'summary': note}),
          ),
          sortOrder: Value(order++),
        ),
      );
    }
  }

  /// Persiste summary de la card en LocationRef.lightingNote.
  static Future<void> syncSummaryToLocationRef({
    required AppDatabase db,
    required NarrativeCardModel card,
  }) async {
    if (card.kind != NarrativeCardKind.locationLight) return;
    final planId = card.locationBasePlanId;
    if (planId == null) return;

    final plan = await (db.select(db.locationBasePlans)
          ..where((p) => p.id.equals(planId)))
        .getSingleOrNull();
    if (plan == null) return;

    final summary = card.summary;
    final byPlanId = await (db.select(db.visualBibleLocationRefs)
          ..where(
            (r) =>
                r.bibleId.equals(card.bibleId) &
                r.locationBasePlanId.equals(planId),
          ))
        .get();
    final existing = byPlanId.isNotEmpty
        ? byPlanId
        : await (db.select(db.visualBibleLocationRefs)
              ..where(
                (r) =>
                    r.bibleId.equals(card.bibleId) &
                    r.locationName.equals(plan.locationName),
              ))
            .get();

    if (existing.isEmpty) {
      await db.upsertLocationRef(
        VisualBibleLocationRefsCompanion.insert(
          bibleId: card.bibleId,
          locationName: plan.locationName,
          locationBasePlanId: Value(planId),
          locationSiteId: Value(plan.siteId),
          lightingNote: Value(summary),
        ),
      );
      return;
    }

    // Una sola fila: preferir match por planId; si solo hay por nombre, la primera.
    final row = existing.first;
    await db.upsertLocationRef(
      VisualBibleLocationRefsCompanion(
        id: Value(row.id),
        bibleId: Value(row.bibleId),
        locationName: Value(row.locationName),
        locationBasePlanId: Value(row.locationBasePlanId ?? planId),
        locationSiteId: Value(row.locationSiteId ?? plan.siteId),
        lightingNote: Value(summary),
        colorNote: Value(row.colorNote),
        stagingNote: Value(row.stagingNote),
        referenceImages: Value(row.referenceImages),
        linkedShotIds: Value(row.linkedShotIds),
        solarOrientation: Value(row.solarOrientation),
        availableLightHours: Value(row.availableLightHours),
        existingPracticals: Value(row.existingPracticals),
        estimatedColorTempKelvin: Value(row.estimatedColorTempKelvin),
      ),
    );
  }

  /// Actualiza summary de la card location_light desde lightingNote de Localización.
  static Future<void> syncLocationNoteToCard({
    required AppDatabase db,
    required int bibleId,
    required int locationBasePlanId,
    required String? lightingNote,
  }) async {
    final card = await db.getNarrativeCardForLocationLight(
      bibleId,
      locationBasePlanId,
    );
    if (card == null) return;
    final model = NarrativeCardModel.fromRow(card);
    model.summary = lightingNote;
    await db.updateNarrativeCard(
      card.copyWith(metaJson: Value(jsonEncode(model.meta))),
    );
  }
}
