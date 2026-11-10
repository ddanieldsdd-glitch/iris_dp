import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';

/// En qué se estaba trabajando dentro de un proyecto: lo comparten el guion
/// técnico y las plantas para abrirse donde se dejó.
@immutable
class ProjectFocus {
  final int? sceneId;
  final int? shotId;

  /// El último set abierto. Se conserva aunque el plano actual no tenga.
  final int? setupId;

  const ProjectFocus({this.sceneId, this.shotId, this.setupId});

  @override
  bool operator ==(Object other) =>
      other is ProjectFocus &&
      other.sceneId == sceneId &&
      other.shotId == shotId &&
      other.setupId == setupId;

  @override
  int get hashCode => Object.hash(sceneId, shotId, setupId);
}

/// Los identificadores son de la base de este equipo: se guarda aquí y no
/// viaja con los ajustes.
class ProjectFocusNotifier extends StateNotifier<ProjectFocus> {
  final int projectId;

  /// Termina cuando ya se ha leído lo guardado.
  late final Future<void> ready = _load();

  ProjectFocusNotifier(this.projectId) : super(const ProjectFocus()) {
    ready;
  }

  String get _key => 'iris_focus_$projectId';

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null || !mounted || state != const ProjectFocus()) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      state = ProjectFocus(
        sceneId: map['scene'] as int?,
        shotId: map['shot'] as int?,
        setupId: map['setup'] as int?,
      );
    } catch (e) {
      debugPrint('No se pudo leer dónde se dejó el proyecto: $e');
    }
  }

  void _set(ProjectFocus next) {
    if (next == state) return;
    state = next;
    _save(next);
  }

  Future<void> _save(ProjectFocus focus) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'scene': focus.sceneId,
          'shot': focus.shotId,
          'setup': focus.setupId,
        }),
      );
    } catch (e) {
      debugPrint('No se pudo guardar dónde se dejó el proyecto: $e');
    }
  }

  void focusShot(Shot shot) => _set(
    ProjectFocus(
      sceneId: shot.sceneId,
      shotId: shot.id,
      setupId: shot.lightSetupId ?? state.setupId,
    ),
  );

  void focusScene(int sceneId) {
    if (sceneId == state.sceneId) return;
    _set(ProjectFocus(sceneId: sceneId, setupId: state.setupId));
  }

  void focusSetup(int setupId) => _set(
    ProjectFocus(
      sceneId: state.sceneId,
      shotId: state.shotId,
      setupId: setupId,
    ),
  );
}

final projectFocusProvider =
    StateNotifierProvider.family<ProjectFocusNotifier, ProjectFocus, int>(
      (ref, projectId) => ProjectFocusNotifier(projectId),
    );
