import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../database/database_provider.dart';

/// Set activo del proyecto (site + set) para filtrar refs y pre-rellenar secciones.
class ProjectShootContext {
  final int? activeSiteId;
  final int? activeSetId;

  const ProjectShootContext({this.activeSiteId, this.activeSetId});

  ProjectShootContext copyWith({int? activeSiteId, int? activeSetId}) {
    return ProjectShootContext(
      activeSiteId: activeSiteId ?? this.activeSiteId,
      activeSetId: activeSetId ?? this.activeSetId,
    );
  }
}

class ProjectShootContextNotifier extends StateNotifier<ProjectShootContext> {
  ProjectShootContextNotifier(this._projectId) : super(const ProjectShootContext()) {
    _load();
  }

  final int _projectId;

  static String _siteKey(int projectId) => 'iris_active_site_$projectId';
  static String _setKey(int projectId) => 'iris_active_set_$projectId';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ProjectShootContext(
      activeSiteId: prefs.getInt(_siteKey(_projectId)),
      activeSetId: prefs.getInt(_setKey(_projectId)),
    );
  }

  Future<void> setActiveSite(int? siteId) async {
    final prefs = await SharedPreferences.getInstance();
    if (siteId == null) {
      await prefs.remove(_siteKey(_projectId));
    } else {
      await prefs.setInt(_siteKey(_projectId), siteId);
    }
    state = state.copyWith(activeSiteId: siteId);
  }

  Future<void> setActiveSet(int? setId) async {
    final prefs = await SharedPreferences.getInstance();
    if (setId == null) {
      await prefs.remove(_setKey(_projectId));
    } else {
      await prefs.setInt(_setKey(_projectId), setId);
    }
    state = state.copyWith(activeSetId: setId);
  }

  Future<void> setActive({int? siteId, int? setId}) async {
    await setActiveSite(siteId);
    await setActiveSet(setId);
  }
}

final projectShootContextProvider =
    StateNotifierProvider.family<ProjectShootContextNotifier, ProjectShootContext, int>(
  (ref, projectId) => ProjectShootContextNotifier(projectId),
);

/// Resuelve nombres del set activo para UI.
final activeShootLocationProvider =
    FutureProvider.family<({LocationSite? site, LocationBasePlan? set}), int>(
  (ref, projectId) async {
    final ctx = ref.watch(projectShootContextProvider(projectId));
    final db = ref.watch(databaseProvider);
    LocationSite? site;
    LocationBasePlan? set;
    if (ctx.activeSiteId != null) {
      final sites = await db.watchSitesForProject(projectId).first;
      site = sites.where((s) => s.id == ctx.activeSiteId).firstOrNull;
    }
    if (ctx.activeSetId != null) {
      final sets = await db.watchLocationsForProject(projectId).first;
      set = sets.where((s) => s.id == ctx.activeSetId).firstOrNull;
    }
    return (site: site, set: set);
  },
);
