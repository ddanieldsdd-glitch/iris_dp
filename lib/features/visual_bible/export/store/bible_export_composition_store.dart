import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/bible_export_composition.dart';

class BibleExportCompositionVersion {
  final int revision;
  final String? label;
  final DateTime savedAt;
  final BibleExportComposition composition;

  const BibleExportCompositionVersion({
    required this.revision,
    this.label,
    required this.savedAt,
    required this.composition,
  });

  Map<String, dynamic> toJson() => {
    'revision': revision,
    if (label != null) 'label': label,
    'savedAt': savedAt.toIso8601String(),
    'composition': composition.toJson(),
  };

  factory BibleExportCompositionVersion.fromJson(Map<String, dynamic> json) {
    return BibleExportCompositionVersion(
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString(),
      savedAt:
          DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      composition: BibleExportComposition.fromJson(
        Map<String, dynamic>.from(json['composition'] as Map),
      ),
    );
  }
}

/// Store local de borradores. Cada guardado añade una revisión inmutable y
/// restaurar una versión crea otra revisión, de modo que nunca borra historia.
class BibleExportCompositionStore {
  BibleExportCompositionStore(
    this.preferences, {
    this.maxVersions = 20,
    DateTime Function()? clock,
  }) : _clock = clock ?? _utcNow {
    if (maxVersions < 1) {
      throw ArgumentError.value(maxVersions, 'maxVersions', 'Must be positive');
    }
  }

  static const int storageSchemaVersion = 1;
  static const String _draftPrefix = 'iris_bible_export_composition_';
  static const String _indexPrefix = 'iris_bible_export_composition_index_';

  final SharedPreferences preferences;
  final int maxVersions;
  final DateTime Function() _clock;

  static DateTime _utcNow() => DateTime.now().toUtc();

  String _draftKey(int projectId, String compositionId) =>
      '$_draftPrefix${projectId}_$compositionId';

  String _indexKey(int projectId) => '$_indexPrefix$projectId';

  Future<BibleExportComposition> save(
    BibleExportComposition composition, {
    String? label,
  }) async {
    final versions = await loadVersions(composition.projectId, composition.id);
    final nextRevision = versions.isEmpty
        ? 1
        : versions
                  .map((version) => version.revision)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final now = _clock().toUtc();
    final saved = composition.copyWith(revision: nextRevision, updatedAt: now);
    versions.add(
      BibleExportCompositionVersion(
        revision: nextRevision,
        label: label,
        savedAt: now,
        composition: saved,
      ),
    );
    if (versions.length > maxVersions) {
      versions.removeRange(0, versions.length - maxVersions);
    }

    await preferences.setString(
      _draftKey(composition.projectId, composition.id),
      jsonEncode({
        'storageSchemaVersion': storageSchemaVersion,
        'versions': versions.map((version) => version.toJson()).toList(),
      }),
    );
    await _addToIndex(composition.projectId, composition.id);
    return saved;
  }

  Future<BibleExportComposition?> loadLatest(
    int projectId,
    String compositionId,
  ) async {
    final versions = await loadVersions(projectId, compositionId);
    return versions.isEmpty ? null : versions.last.composition;
  }

  Future<List<BibleExportCompositionVersion>> loadVersions(
    int projectId,
    String compositionId,
  ) async {
    final raw = preferences.getString(_draftKey(projectId, compositionId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return [];
      final envelope = Map<String, dynamic>.from(decoded);
      final storageVersion =
          (envelope['storageSchemaVersion'] as num?)?.toInt() ?? 1;
      if (storageVersion > storageSchemaVersion) return [];
      final versions =
          (envelope['versions'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (item) => BibleExportCompositionVersion.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where(
                (version) =>
                    version.composition.projectId == projectId &&
                    version.composition.id == compositionId,
              )
              .toList()
            ..sort((a, b) => a.revision.compareTo(b.revision));
      return versions;
    } catch (_) {
      return [];
    }
  }

  Future<BibleExportComposition> restoreVersion({
    required int projectId,
    required String compositionId,
    required int revision,
  }) async {
    final versions = await loadVersions(projectId, compositionId);
    final selected = versions.where((item) => item.revision == revision);
    if (selected.isEmpty) {
      throw StateError(
        'Composition $compositionId revision $revision not found',
      );
    }
    return save(
      selected.first.composition,
      label: 'Restaurada desde revisión $revision',
    );
  }

  Future<List<BibleExportComposition>> listLatest(int projectId) async {
    final ids = _readIndex(projectId);
    final drafts = <BibleExportComposition>[];
    for (final id in ids) {
      final draft = await loadLatest(projectId, id);
      if (draft != null) drafts.add(draft);
    }
    drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return drafts;
  }

  Future<void> delete(int projectId, String compositionId) async {
    await preferences.remove(_draftKey(projectId, compositionId));
    final ids = _readIndex(projectId)..remove(compositionId);
    await preferences.setString(_indexKey(projectId), jsonEncode(ids));
  }

  List<String> _readIndex(int projectId) {
    final raw = preferences.getString(_indexKey(projectId));
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((value) => value.toString())
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _addToIndex(int projectId, String compositionId) async {
    final ids = _readIndex(projectId);
    if (!ids.contains(compositionId)) ids.add(compositionId);
    await preferences.setString(_indexKey(projectId), jsonEncode(ids));
  }
}
