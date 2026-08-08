import '../../../../core/database/app_database.dart';
import '../../bible_preset_bundle.dart';
import '../../bible_preset_service.dart';
import '../sync/bible_domain_sync_service.dart';
import '../templates/bible_template_apply_service.dart';
import '../templates/bible_template_package.dart';
import '../templates/bible_v2_professional_templates.dart';
import '../model/bible_document.dart';
import '../persistence/bible_document_store.dart';

/// Aplica plantillas profesionales: estructura Stitch + documento V2 sincronizado.
abstract final class BibleProfessionalTemplateService {
  /// Plantilla legacy (Stitch) + sync documento.
  static Future<void> applyLegacyPreset({
    required AppDatabase db,
    required int projectId,
    required int bibleId,
    required BiblePresetBundle bundle,
    bool applySampleSeed = false,
  }) async {
    await BiblePresetService.applyBundle(
      db: db,
      projectId: projectId,
      bibleId: bibleId,
      bundle: bundle,
      applySampleSeed: applySampleSeed,
    );
    await BibleDomainSyncService.syncFromLegacy(
      db: db,
      projectId: projectId,
      bibleId: bibleId,
    );
  }

  /// Plantilla V2 profesional (recetas + bloques) + estructura legacy embebida.
  static Future<BibleDocument> applyProfessionalPackage({
    required AppDatabase db,
    required int projectId,
    required int bibleId,
    required BibleTemplatePackage package,
    bool applySampleSeed = false,
    bool includeContent = true,
  }) async {
    final store = BibleDocumentStore(db);
    final legacy = package.legacyBundle;
    if (legacy != null) {
      await applyLegacyPreset(
        db: db,
        projectId: projectId,
        bibleId: bibleId,
        bundle: legacy,
        applySampleSeed: applySampleSeed,
      );
      final synced = await store.loadForBible(bibleId);
      if (synced != null) return synced;
    }

    if (package.document != null) {
      final apply = BibleTemplateApplyService(store);
      return apply.applyPackage(
        package: package,
        bibleId: bibleId,
        projectId: projectId,
        includeContent: includeContent,
        includeImages: applySampleSeed,
      );
    }

    return BibleDomainSyncService.syncFromLegacy(
      db: db,
      projectId: projectId,
      bibleId: bibleId,
    );
  }

  static List<BibleTemplatePackage> get galleryPackages =>
      BibleV2ProfessionalTemplates.all;
}
