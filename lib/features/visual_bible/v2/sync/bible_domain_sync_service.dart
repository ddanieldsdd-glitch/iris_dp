import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../core/database/app_database.dart';
import '../../visual_bible_model.dart';
import '../layout/page_layout_recipe_registry.dart';
import '../migration/legacy_to_document_migrator.dart';
import '../model/bible_document.dart';
import '../model/bible_page_mode.dart';
import '../persistence/bible_document_store.dart';

/// Sincroniza el documento V2 con el estado legacy en Drift (fuente única).
abstract final class BibleDomainSyncService {
  /// Lee grupos/secciones Drift y persiste un [BibleDocument] alineado.
  static Future<BibleDocument> syncFromLegacy({
    required AppDatabase db,
    required int projectId,
    required int bibleId,
    VisualBibleData? data,
  }) async {
    final store = BibleDocumentStore(db);
    final existing = await store.loadForBible(bibleId);

    // No regenerar layout V2 en cada autosave legacy si ya hay documento con páginas.
    if (existing != null && existing.pages.isNotEmpty) {
      final enriched = _applyRecipeMetadata(existing);
      await store.save(enriched);
      return enriched;
    }

    final groups = await (db.select(
      db.bibleSectionGroups,
    )..where((g) => g.bibleId.equals(bibleId))).get();
    final sections = await (db.select(
      db.bibleSectionDefinitions,
    )..where((d) => d.bibleId.equals(bibleId))).get();

    final bibleRow = data ?? await _loadData(db, projectId);

    final doc = LegacyToDocumentMigrator.migrate(
      projectId: projectId,
      bibleId: bibleId,
      groups: [
        for (final g in groups)
          LegacyBibleGroupSnapshot(
            id: g.id,
            label: g.label,
            sortOrder: g.sortOrder,
          ),
      ],
      sections: [
        for (final s in sections)
          LegacyBibleSectionSnapshot(
            id: s.id,
            groupId: s.groupId,
            label: s.label,
            iconKey: s.iconKey,
            sortOrder: s.sortOrder,
            isHidden: s.isHidden,
            template: s.template,
            contentJson: s.contentJson,
          ),
      ],
      data: bibleRow,
      lastPageId: existing?.navigation['lastPageId']?.toString(),
    );

    final enriched = _applyRecipeMetadata(doc);
    await store.save(enriched);
    return enriched;
  }

  static BibleDocument _applyRecipeMetadata(BibleDocument doc) {
    final pages = doc.pages.map((page) {
      if (page.pageMode == BiblePageMode.freeform) return page;
      final recipeId =
          page.layoutRecipeId ??
          PageLayoutRecipeRegistry.recipeIdForSection(
            page.legacySectionId ?? page.id,
          );
      if (recipeId == null) return page;
      final recipe = PageLayoutRecipeRegistry.byId(recipeId);
      return page.copyWith(
        layoutRecipeId: recipeId,
        pageMode: BiblePageMode.recipe,
        themeId: page.themeId ?? recipe?.preferredThemeId,
      );
    }).toList();
    return doc.copyWith(pages: pages);
  }

  static Future<VisualBibleData?> _loadData(
    AppDatabase db,
    int projectId,
  ) async {
    final row = await db.getVisualBibleForProject(projectId);
    if (row == null) return null;
    return VisualBibleData.fromRow(row);
  }

  /// Hash estable para invalidar borradores de export desactualizados.
  static String computeExportSourceHash({
    required VisualBibleData data,
    BibleDocument? document,
    int moodboardCount = 0,
    int colorBlockCount = 0,
    int lightingSetupCount = 0,
    int cameraTestCount = 0,
  }) {
    final payload = {
      'id': data.id,
      'tone': data.tone,
      'visualConcept': data.visualConcept,
      'lightingPhilosophy': data.lightingPhilosophy,
      'aspectRatio': data.aspectRatio,
      'documentUpdatedAt': document?.updatedAt.toIso8601String(),
      'pageCount': document?.pages.length ?? 0,
      'moodboardCount': moodboardCount,
      'colorBlockCount': colorBlockCount,
      'lightingSetupCount': lightingSetupCount,
      'cameraTestCount': cameraTestCount,
    };
    final raw = jsonEncode(payload);
    return sha256.convert(utf8.encode(raw)).toString();
  }
}
