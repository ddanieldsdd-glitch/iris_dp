import '../../../core/database/app_database.dart';
import '../../../shared/visual_bible/bible_section_ids.dart';
import '../../../shared/visual_bible/narrative_card_kind.dart';
import '../moodboard_reference_meta.dart';
import '../visual_bible_model.dart';

/// Criterios de etiquetas de luz (moodboard meta ↔ carta narrativa).
class MoodboardLightingTags {
  final String? lightingLook;
  final String? lightSource;
  final String? lightTexture;
  final String? colorMood;

  const MoodboardLightingTags({
    this.lightingLook,
    this.lightSource,
    this.lightTexture,
    this.colorMood,
  });

  factory MoodboardLightingTags.fromMeta(MoodboardReferenceMeta meta) {
    return MoodboardLightingTags(
      lightingLook: _trim(meta.lightingLook),
      lightSource: _trim(meta.lightSource),
      lightTexture: _trim(meta.lightTexture),
      colorMood: _trim(meta.colorMood),
    );
  }

  factory MoodboardLightingTags.fromCard(NarrativeCardModel card) {
    return MoodboardLightingTags(
      lightingLook: _trim(card.lightingLook),
      lightSource: _trim(card.lightSource),
      lightTexture: _trim(card.lightTexture),
      colorMood: _trim(card.colorMood),
    );
  }

  bool get hasAny =>
      lightingLook != null ||
      lightSource != null ||
      lightTexture != null ||
      colorMood != null;

  /// Coincide si la imagen cumple todos los criterios no nulos de la carta.
  bool matchesImage(MoodboardLightingTags image) {
    if (!hasAny) return false;
    if (lightingLook != null &&
        !_eq(lightingLook, image.lightingLook)) {
      return false;
    }
    if (lightSource != null && !_eq(lightSource, image.lightSource)) {
      return false;
    }
    if (lightTexture != null && !_eq(lightTexture, image.lightTexture)) {
      return false;
    }
    if (colorMood != null && !_eq(colorMood, image.colorMood)) {
      return false;
    }
    return true;
  }

  /// Puntuación de coincidencia (dimensiones alineadas).
  int scoreAgainst(MoodboardLightingTags image) {
    var score = 0;
    if (lightingLook != null && _eq(lightingLook, image.lightingLook)) score++;
    if (lightSource != null && _eq(lightSource, image.lightSource)) score++;
    if (lightTexture != null && _eq(lightTexture, image.lightTexture)) score++;
    if (colorMood != null && _eq(colorMood, image.colorMood)) score++;
    return score;
  }

  static String? _trim(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  static bool _eq(String? a, String? b) =>
      a != null && b != null && a.toLowerCase() == b.toLowerCase();
}

/// Filtros multi-valor de un contenedor de comportamiento de luz.
///
/// Cada dimensión con valores no vacíos exige que la imagen tenga uno de ellos.
/// Las dimensiones vacías se ignoran (el contenedor no filtra por ellas).
class LightingBehaviorTagFilter {
  final List<String> lightingLooks;
  final List<String> lightSources;
  final List<String> lightTextures;
  final List<String> colorMoods;

  const LightingBehaviorTagFilter({
    this.lightingLooks = const [],
    this.lightSources = const [],
    this.lightTextures = const [],
    this.colorMoods = const [],
  });

  factory LightingBehaviorTagFilter.fromCard(NarrativeCardModel card) {
    final raw = card.meta['tagFilters'];
    if (raw is Map) {
      return LightingBehaviorTagFilter(
        lightingLooks: _stringList(raw['lightingLook']),
        lightSources: _stringList(raw['lightSource']),
        lightTextures: _stringList(raw['lightTexture']),
        colorMoods: _stringList(raw['colorMood']),
      );
    }
    // Legacy: criterios single-value en meta de carta.
    return LightingBehaviorTagFilter(
      lightingLooks: [
        if (MoodboardLightingTags._trim(card.lightingLook) case final v?) v,
      ],
      lightSources: [
        if (MoodboardLightingTags._trim(card.lightSource) case final v?) v,
      ],
      lightTextures: [
        if (MoodboardLightingTags._trim(card.lightTexture) case final v?) v,
      ],
      colorMoods: [
        if (MoodboardLightingTags._trim(card.colorMood) case final v?) v,
      ],
    );
  }

  bool get hasAny =>
      lightingLooks.isNotEmpty ||
      lightSources.isNotEmpty ||
      lightTextures.isNotEmpty ||
      colorMoods.isNotEmpty;

  List<String> get allSelectedLabels => [
        ...lightingLooks,
        ...lightSources,
        ...lightTextures,
        ...colorMoods,
      ];

  Map<String, dynamic> toMetaMap() => {
        if (lightingLooks.isNotEmpty) 'lightingLook': lightingLooks,
        if (lightSources.isNotEmpty) 'lightSource': lightSources,
        if (lightTextures.isNotEmpty) 'lightTexture': lightTextures,
        if (colorMoods.isNotEmpty) 'colorMood': colorMoods,
      };

  /// Imagen encaja si coincide en **al menos una** familia activa (OR entre ejes;
  /// OR dentro de cada eje). Así no se ocultan stills parcialmente etiquetadas.
  bool matchesMeta(MoodboardReferenceMeta meta) {
    if (!hasAny) return false;
    if (lightingLooks.isNotEmpty &&
        _listContains(lightingLooks, meta.lightingLook)) {
      return true;
    }
    if (lightSources.isNotEmpty &&
        _listContains(lightSources, meta.lightSource)) {
      return true;
    }
    if (lightTextures.isNotEmpty &&
        _listContains(lightTextures, meta.lightTexture)) {
      return true;
    }
    if (colorMoods.isNotEmpty && _listContains(colorMoods, meta.colorMood)) {
      return true;
    }
    return false;
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static bool _listContains(List<String> options, String? value) {
    final v = MoodboardLightingTags._trim(value);
    if (v == null) return false;
    return options.any((o) => MoodboardLightingTags._eq(o, v));
  }
}

/// Vincula stills del moodboard con cartas de Iluminación vía etiquetas.
abstract final class MoodboardLightingLinkService {
  static bool imageHasLightingTags(MoodboardReferenceMeta meta) =>
      MoodboardLightingTags.fromMeta(meta).hasAny;

  static bool visibleInLightingPool({
    required MoodboardImageModel image,
    required MoodboardReferenceMeta meta,
  }) {
    if (image.assignedSections.contains(BibleSectionId.lighting)) return true;
    return imageHasLightingTags(meta);
  }

  static bool matchesFilter({
    required MoodboardReferenceMeta meta,
    String? lightingLook,
    String? lightSource,
    String? lightTexture,
    String? colorMood,
  }) {
    final img = MoodboardLightingTags.fromMeta(meta);
    if (lightingLook != null &&
        !MoodboardLightingTags._eq(lightingLook, img.lightingLook)) {
      return false;
    }
    if (lightSource != null &&
        !MoodboardLightingTags._eq(lightSource, img.lightSource)) {
      return false;
    }
    if (lightTexture != null &&
        !MoodboardLightingTags._eq(lightTexture, img.lightTexture)) {
      return false;
    }
    if (colorMood != null &&
        !MoodboardLightingTags._eq(colorMood, img.colorMood)) {
      return false;
    }
    return true;
  }

  /// Cartas de estilo/refs cuyos criterios de etiqueta encajan con la imagen.
  static List<NarrativeCardModel> matchingCards({
    required List<NarrativeCardModel> cards,
    required MoodboardReferenceMeta meta,
  }) {
    final imageTags = MoodboardLightingTags.fromMeta(meta);
    if (!imageTags.hasAny) return const [];

    final out = <NarrativeCardModel>[];
    for (final card in cards) {
      if (card.sectionId != BibleSectionId.lighting) continue;
      if (card.kind != NarrativeCardKind.style &&
          card.kind != NarrativeCardKind.filmRef &&
          card.kind != NarrativeCardKind.overview) {
        continue;
      }
      final multi = LightingBehaviorTagFilter.fromCard(card);
      if (multi.hasAny) {
        if (multi.matchesMeta(meta)) out.add(card);
        continue;
      }
      final criteria = MoodboardLightingTags.fromCard(card);
      if (criteria.matchesImage(imageTags)) out.add(card);
    }
    return out;
  }

  /// Stills del pool que coinciden con el filtro de un contenedor.
  static List<MoodboardImageModel> imagesMatchingContainer({
    required List<MoodboardImageModel> pool,
    required NarrativeCardModel container,
  }) {
    final filter = LightingBehaviorTagFilter.fromCard(container);
    if (!filter.hasAny) {
      return pool
          .where((img) => img.assignedCardIds.contains(container.id))
          .toList();
    }
    final matched = <MoodboardImageModel>[];
    final seen = <int>{};
    for (final img in pool) {
      if (img.assignedCardIds.contains(container.id) ||
          filter.matchesMeta(img.meta)) {
        if (seen.add(img.id)) matched.add(img);
      }
    }
    return matched;
  }

  /// Asigna la imagen a las cartas que coinciden por etiquetas.
  static Future<int> linkImageToMatchingCards({
    required AppDatabase db,
    required int bibleId,
    required int imageId,
    required MoodboardReferenceMeta meta,
  }) async {
    final cards = await db
        .watchNarrativeCardsForSection(bibleId, BibleSectionId.lighting)
        .first;
    final models = cards.map(NarrativeCardModel.fromRow).toList();
    final matches = matchingCards(cards: models, meta: meta);
    if (matches.isEmpty) return 0;

    for (final card in matches) {
      await db.assignMoodboardImageToCard(
        imageId: imageId,
        cardId: card.id,
        sectionId: BibleSectionId.lighting,
      );
    }
    return matches.length;
  }

  /// Escanea imágenes de iluminación y vincula las que encajan con cartas.
  static Future<int> linkAllTaggedImages({
    required AppDatabase db,
    required int projectId,
    required int bibleId,
  }) async {
    final rows = await db.watchMoodboardImagesForSection(
      projectId,
      BibleSectionId.lighting,
    ).first;
    if (rows.isEmpty) return 0;

    final metaById = await MoodboardReferenceMetaStore.loadMany(
      db,
      rows.map((r) => r.id),
    );
    var linked = 0;
    for (final row in rows) {
      final meta = metaById[row.id] ?? const MoodboardReferenceMeta();
      linked += await linkImageToMatchingCards(
        db: db,
        bibleId: bibleId,
        imageId: row.id,
        meta: meta,
      );
    }
    return linked;
  }
}
