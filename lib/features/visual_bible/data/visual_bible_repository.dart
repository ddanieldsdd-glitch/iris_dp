import '../../../core/database/app_database.dart';
import '../../../core/database/dao/visual_bible_dao.dart';
import '../../../core/templates/user_template_service.dart';
import '../export/bible_section_export_reader.dart';
import '../moodboard_reference_meta.dart';
import '../visual_bible_model.dart';

/// Bundle de datos para exportación PDF de la biblia.
typedef VisualBibleExportBundle = ({
  VisualBibleData data,
  List<ColorBlockModel> blocks,
  List<ExposureBlockModel> exposureBlocks,
  List<LightingSetupModel> lightingSetups,
  List<CameraTestModel> cameraTests,
  List<MoodboardImageModel> moodboard,
  List<NarrativeCardModel> narrativeCards,
  Map<String, String?> sectionContentJsonById,

  /// Secciones visibles en el orden de la barra lateral de la biblia.
  List<BibleExportSectionRef> sectionOrder,
  String? primaryCameraLabel,
});

/// Puerta de entrada de Visual Bible a persistencia local.
class VisualBibleRepository {
  VisualBibleRepository(this._dao);

  final VisualBibleDao _dao;

  AppDatabase get db => _dao.database;

  Future<
    ({
      VisualBibleData data,
      Project? project,
      bool created,
      bool needsOnboarding,
    })
  >
  bootstrap(int projectId) async {
    final hadBible = await _dao.getForProject(projectId) != null;
    var bible = await _dao.ensureForProject(projectId);
    if (!hadBible) {
      await UserTemplateService.maybeApplyBibleTemplateOnCreate(
        db: _dao.database,
        projectId: projectId,
        bibleId: bible.id,
      );
      bible = (await _dao.getForProject(projectId)) ?? bible;
    }
    // Por ahora no se pregunta cómo empezar (plantilla, desde cero o
    // explorar): toda biblia nueva lleva la estructura estándar de IRIS.
    if (!bible.structureInitialized && bible.engineVersion != 'v2') {
      await initializeStandard(bible.id);
      bible = (await _dao.getForProject(projectId)) ?? bible;
    }
    final project = await _dao.getProject(projectId);
    return (
      data: VisualBibleData.fromRow(bible),
      project: project,
      created: !hadBible,
      needsOnboarding: !bible.structureInitialized,
    );
  }

  /// Estructura estándar de IRIS (todas las pantallas built-in). Si la
  /// biblia ya tiene pantallas, solo la marca como iniciada.
  Future<void> initializeStandard(int bibleId) async {
    await _dao.database.ensureBibleSectionLayout(bibleId);
    await _dao.database.initializeEmptyBible(bibleId);
  }

  Future<void> initializeEmpty(int bibleId) =>
      _dao.database.initializeEmptyBible(bibleId);

  Future<void> resetStructureToEmpty(int bibleId) =>
      _dao.database.resetBibleStructureToEmpty(bibleId);

  Future<int> save(VisualBibleData data) async {
    final id = await _dao.upsert(data.toCompanion());
    data.id = id;
    return id;
  }

  Future<VisualBibleExportBundle> loadExportBundle({
    required int projectId,
    VisualBibleData? cached,
  }) async {
    final bible = await _dao.ensureForProject(projectId);
    final data = cached ?? VisualBibleData.fromRow(bible);
    final colorRows = await _dao.watchColorBlocks(bible.id).first;
    final exposureRows = await _dao.watchExposureBlocks(bible.id).first;
    final lightingRows = await _dao.watchLightingSetups(bible.id).first;
    final testRows = await _dao.watchCameraTests(bible.id).first;
    final moodRows = await _dao.watchMoodboardImages(projectId).first;
    final sectionRows = await _dao.watchSectionDefinitions(bible.id).first;
    final groupRows = await _dao.database
        .watchBibleSectionGroups(bible.id)
        .first;
    final groupOrder = {
      for (var i = 0; i < groupRows.length; i++) groupRows[i].id: i,
    };
    final orderedSections = sectionRows.where((row) => !row.isHidden).toList()
      ..sort((a, b) {
        final byGroup = (groupOrder[a.groupId] ?? groupRows.length).compareTo(
          groupOrder[b.groupId] ?? groupRows.length,
        );
        return byGroup != 0 ? byGroup : a.sortOrder.compareTo(b.sortOrder);
      });
    final narrativeRows = await _dao.database
        .watchNarrativeCardsForSection(bible.id, BibleSectionId.lighting)
        .first;
    final camera = await _dao.database.resolveProjectCamera(projectId);
    final primaryCameraLabel = camera != null
        ? '${camera.brand} ${camera.model}'
        : null;
    final moodboardModels = moodRows.map(MoodboardImageModel.fromRow).toList();
    // Incluye migración lazy prefs → Drift para que el PDF vea tags/notas.
    final moodboardMeta = await MoodboardReferenceMetaStore.loadMany(
      _dao.database,
      moodboardModels.map((m) => m.id),
    );
    return (
      data: data,
      blocks: colorRows.map(ColorBlockModel.fromRow).toList(),
      exposureBlocks: exposureRows.map(ExposureBlockModel.fromRow).toList(),
      lightingSetups: lightingRows.map(LightingSetupModel.fromRow).toList(),
      cameraTests: testRows.map(CameraTestModel.fromRow).toList(),
      moodboard: [
        for (final model in moodboardModels)
          model.copyWith(meta: moodboardMeta[model.id] ?? model.meta),
      ],
      narrativeCards: narrativeRows.map(NarrativeCardModel.fromRow).toList(),
      sectionContentJsonById: {
        for (final row in sectionRows) row.id: row.contentJson,
      },
      sectionOrder: [
        for (final row in orderedSections)
          BibleExportSectionRef(
            id: row.id,
            label: row.label,
            isCustom: row.template == 'freeform',
          ),
      ],
      primaryCameraLabel: primaryCameraLabel,
    );
  }

  Stream<VisualBible?> watchBible(int projectId) =>
      _dao.watchForProject(projectId);

  Stream<List<BibleSectionGroup>> watchSectionGroups(int bibleId) =>
      _dao.watchSectionGroups(bibleId);

  Future<void> upsertSectionDefinition(BibleSectionDefinition row) =>
      _dao.upsertSectionDefinition(row);

  Stream<List<BibleSectionDefinition>> watchSectionDefinitions(int bibleId) =>
      _dao.watchSectionDefinitions(bibleId);
}
