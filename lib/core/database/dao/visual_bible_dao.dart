import '../app_database.dart';

/// Acceso a datos de Visual Bible (facade sobre AppDatabase).
class VisualBibleDao {
  VisualBibleDao(this._db);

  final AppDatabase _db;

  AppDatabase get database => _db;

  Future<VisualBible?> getForProject(int projectId) =>
      _db.getVisualBibleForProject(projectId);

  Stream<VisualBible?> watchForProject(int projectId) =>
      _db.watchVisualBibleForProject(projectId);

  Future<VisualBible> ensureForProject(int projectId) =>
      _db.ensureVisualBibleForProject(projectId);

  Future<int> upsert(VisualBiblesCompanion row) => _db.upsertVisualBible(row);

  Future<Project?> getProject(int projectId) => _db.getProject(projectId);

  Stream<List<VisualBibleColorBlock>> watchColorBlocks(int bibleId) =>
      _db.watchColorBlocksForBible(bibleId);

  Stream<List<ExposureBlock>> watchExposureBlocks(int bibleId) =>
      _db.watchExposureBlocksForBible(bibleId);

  Stream<List<LightingSetup>> watchLightingSetups(int bibleId) =>
      _db.watchLightingSetupsForBible(bibleId);

  Stream<List<CameraTest>> watchCameraTests(int bibleId) =>
      _db.watchCameraTestsForBible(bibleId);

  Stream<List<MoodboardImage>> watchMoodboardImages(int projectId) =>
      _db.watchMoodboardImages(projectId);

  Stream<List<BibleSectionGroup>> watchSectionGroups(int bibleId) =>
      _db.watchBibleSectionGroups(bibleId);

  Stream<List<BibleSectionDefinition>> watchSectionDefinitions(int bibleId) =>
      _db.watchBibleSectionDefinitions(bibleId);

  Future<void> upsertSectionDefinition(BibleSectionDefinition row) =>
      _db.upsertBibleSectionDefinition(row);
}
