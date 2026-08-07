import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/dao/visual_bible_dao.dart';
import '../data/visual_bible_repository.dart';
import '../visual_bible_model.dart';

final visualBibleDaoProvider = Provider<VisualBibleDao>((ref) {
  return VisualBibleDao(ref.watch(databaseProvider));
});

final visualBibleRepositoryProvider = Provider<VisualBibleRepository>((ref) {
  return VisualBibleRepository(ref.watch(visualBibleDaoProvider));
});

/// Estado de sesión de la pantalla Visual Bible (piloto Fase 8).
class VisualBibleSessionState {
  final VisualBibleData data;
  final Project? project;

  const VisualBibleSessionState({
    required this.data,
    this.project,
  });
}

final visualBibleBootstrapProvider =
    FutureProvider.family<VisualBibleSessionState, int>((ref, projectId) async {
  final repo = ref.watch(visualBibleRepositoryProvider);
  final result = await repo.bootstrap(projectId);
  return VisualBibleSessionState(data: result.data, project: result.project);
});
