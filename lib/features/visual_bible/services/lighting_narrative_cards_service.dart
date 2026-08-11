import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/visual_bible/bible_lighting_data.dart';
import '../../../shared/visual_bible/bible_section_ids.dart';
import '../../../shared/visual_bible/narrative_card_kind.dart';
import '../visual_bible_model.dart';

/// Seed / sync de cartas narrativas de Iluminación.
abstract final class LightingNarrativeCardsService {
  /// Asegura overview + styles (desde textureCards) + location_light por set.
  static Future<void> ensureSeeded({
    required AppDatabase db,
    required int bibleId,
    required int projectId,
    Map<String, dynamic>? lightingData,
  }) async {
    final data = BibleLightingData.migrate(
      Map<String, dynamic>.from(lightingData ?? {}),
    );
    final existing = await db
        .watchNarrativeCardsForSection(bibleId, BibleSectionId.lighting)
        .first;

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
    final existing = await (db.select(db.visualBibleLocationRefs)
          ..where(
            (r) =>
                r.bibleId.equals(card.bibleId) &
                (r.locationBasePlanId.equals(planId) |
                    r.locationName.equals(plan.locationName)),
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

    for (final row in existing) {
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
