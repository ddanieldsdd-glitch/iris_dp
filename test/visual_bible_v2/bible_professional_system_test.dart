import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/v2/bible_v2_policy.dart';
import 'package:iris_dp/features/visual_bible/v2/layout/page_layout_recipe_registry.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_page_mode.dart';
import 'package:iris_dp/features/visual_bible/v2/sync/bible_domain_sync_service.dart';
import 'package:iris_dp/features/visual_bible/v2/templates/bible_professional_template_service.dart';
import 'package:iris_dp/features/visual_bible/v2/templates/bible_v2_professional_templates.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('proyecto nuevo usa legacy con onboarding pendiente', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Nuevo'),
    );
    final bible = await db.ensureVisualBibleForProject(projectId);

    expect(bible.engineVersion, kBibleEngineLegacy);
    expect(bible.structureInitialized, isFalse);
    expect(await db.watchBibleSectionDefinitions(bible.id).first, isEmpty);
  });

  test('plantilla profesional aplica estructura y documento con recetas', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Cinematic'),
    );
    final bible = await db.ensureVisualBibleForProject(projectId);

    final doc = await BibleProfessionalTemplateService.applyProfessionalPackage(
      db: db,
      projectId: projectId,
      bibleId: bible.id,
      package: BibleV2ProfessionalTemplates.cinematic,
      applySampleSeed: false,
    );

    expect(doc.pages, isNotEmpty);
    expect(doc.pages.first.pageMode, BiblePageMode.recipe);
    expect(doc.pages.first.layoutRecipeId, isNotNull);

    final defs = await db.watchBibleSectionDefinitions(bible.id).first;
    expect(defs, isNotEmpty);
  });

  test('sync desde legacy asigna recetas por sección', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Sync'),
    );
    final bible = await db.ensureVisualBibleForProject(projectId);
    await db.ensureBibleSectionLayout(bible.id);

    final doc = await BibleDomainSyncService.syncFromLegacy(
      db: db,
      projectId: projectId,
      bibleId: bible.id,
    );

    final direction = doc.pages.where((p) => p.legacySectionId == 'direction');
    expect(direction, isNotEmpty);
    expect(
      direction.first.layoutRecipeId,
      PageLayoutRecipeRegistry.directionBento,
    );
  });

  test('hash de export cambia cuando cambia el documento', () {
    final hashA = BibleDomainSyncService.computeExportSourceHash(
      data: VisualBibleData(id: 1, projectId: 1),
      document: null,
    );
    final hashB = BibleDomainSyncService.computeExportSourceHash(
      data: VisualBibleData(id: 1, projectId: 1, tone: 'Noir'),
      document: null,
    );
    expect(hashA, isNot(equals(hashB)));
  });
}
