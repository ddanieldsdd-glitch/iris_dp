import '../database/app_database.dart';
import 'project_content_bundle.dart';

/// Tipo de cambio pendiente entre cache local y Supabase.
enum SyncPlanAction {
  pushNewLocal,
  importFromCloud,
  updateLocalFromCloud,
  updateCloudFromLocal,
  deleteLocal,
  deleteCloud,
  conflict,
  pushContentLocal,
  pullContentCloud,
  contentConflict,
}

/// Elección del usuario para resolver un ítem.
enum SyncResolutionChoice {
  useLocal,
  useCloud,
  skip,
}

/// Diferencia de un campo concreto.
class SyncFieldDiff {
  final String field;
  final String label;
  final String? localValue;
  final String? cloudValue;

  const SyncFieldDiff({
    required this.field,
    required this.label,
    this.localValue,
    this.cloudValue,
  });
}

/// Un ítem del plan de sincronización (revisable por el usuario).
class SyncPlanItem {
  final SyncPlanAction action;
  final String title;
  final String description;
  final int? localProjectId;
  final String? cloudId;
  final Project? localProject;
  final Map<String, dynamic>? cloudRow;
  final List<SyncFieldDiff> diffs;
  final ContentSyncSummary? localContentSummary;
  final ContentSyncSummary? cloudContentSummary;
  SyncResolutionChoice choice;

  SyncPlanItem({
    required this.action,
    required this.title,
    required this.description,
    this.localProjectId,
    this.cloudId,
    this.localProject,
    this.cloudRow,
    this.diffs = const [],
    this.localContentSummary,
    this.cloudContentSummary,
    SyncResolutionChoice? choice,
  }) : choice = choice ?? _defaultChoice(action);

  bool get isContentSync =>
      action == SyncPlanAction.pushContentLocal ||
      action == SyncPlanAction.pullContentCloud ||
      action == SyncPlanAction.contentConflict;

  static SyncResolutionChoice _defaultChoice(SyncPlanAction action) {
    return switch (action) {
      SyncPlanAction.pushNewLocal ||
      SyncPlanAction.updateCloudFromLocal ||
      SyncPlanAction.deleteCloud ||
      SyncPlanAction.pushContentLocal =>
        SyncResolutionChoice.useLocal,
      SyncPlanAction.importFromCloud ||
      SyncPlanAction.updateLocalFromCloud ||
      SyncPlanAction.deleteLocal ||
      SyncPlanAction.pullContentCloud =>
        SyncResolutionChoice.useCloud,
      SyncPlanAction.conflict ||
      SyncPlanAction.contentConflict =>
        SyncResolutionChoice.useLocal,
    };
  }

  bool get requiresReview =>
      action == SyncPlanAction.conflict ||
      action == SyncPlanAction.contentConflict ||
      diffs.length > 1 ||
      (isContentSync &&
          localContentSummary != null &&
          cloudContentSummary != null &&
          !localContentSummary!.isEmpty &&
          !cloudContentSummary!.isEmpty);

  SyncPlanItem copyWith({SyncResolutionChoice? choice}) => SyncPlanItem(
        action: action,
        title: title,
        description: description,
        localProjectId: localProjectId,
        cloudId: cloudId,
        localProject: localProject,
        cloudRow: cloudRow,
        diffs: diffs,
        localContentSummary: localContentSummary,
        cloudContentSummary: cloudContentSummary,
        choice: choice ?? this.choice,
      );
}

/// Plan completo antes de aplicar cambios.
class SyncPlan {
  final List<SyncPlanItem> items;

  const SyncPlan({required this.items});

  bool get isEmpty => items.isEmpty;

  bool get hasConflicts =>
      items.any((i) =>
          i.action == SyncPlanAction.conflict ||
          i.action == SyncPlanAction.contentConflict);

  int get pendingCount => items.where((i) => i.choice != SyncResolutionChoice.skip).length;
}
