import 'bible_json_parse.dart';
import '../bible_v2_policy.dart';
import '../theme/bible_theme.dart';
import 'bible_page.dart';

/// Documento modular de Biblia (Page → Layout → Block).
class BibleDocument {
  final int? bibleId;
  final int projectId;
  final int schemaVersion;
  final String themeId;
  final List<BibleTheme> themes;
  final List<BibleDocumentGroup> groups;
  final List<BiblePage> pages;
  final Map<String, dynamic> exportSettings;
  final Map<String, dynamic> navigation;
  final DateTime updatedAt;

  const BibleDocument({
    this.bibleId,
    required this.projectId,
    this.schemaVersion = kBibleDocumentSchemaVersion,
    this.themeId = BibleThemeIds.cinematic,
    this.themes = const [],
    this.groups = const [],
    this.pages = const [],
    this.exportSettings = const {},
    this.navigation = const {},
    required this.updatedAt,
  });

  BibleTheme get resolvedTheme {
    final custom = themes.where((t) => t.id == themeId);
    if (custom.isNotEmpty) return custom.first;
    return BibleTheme.builtin(themeId);
  }

  BiblePage? pageById(String id) {
    for (final p in pages) {
      if (p.id == id) return p;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'bibleId': bibleId,
    'projectId': projectId,
    'themeId': themeId,
    'themes': themes.map((t) => t.toJson()).toList(),
    'groups': groups.map((g) => g.toJson()).toList(),
    'pages': pages.map((p) => p.toJson()).toList(),
    'exportSettings': exportSettings,
    'navigation': navigation,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory BibleDocument.fromJson(Map<String, dynamic> json) {
    return BibleDocument(
      schemaVersion: bibleJsonIntOr(json['schemaVersion'], kBibleDocumentSchemaVersion),
      bibleId: bibleJsonInt(json['bibleId']),
      projectId: bibleJsonIntOr(json['projectId'], 0),
      themeId: json['themeId']?.toString() ?? BibleThemeIds.cinematic,
      themes: (json['themes'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => BibleTheme.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      groups: (json['groups'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => BibleDocumentGroup.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pages: (json['pages'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => BiblePage.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      exportSettings: json['exportSettings'] is Map
          ? Map<String, dynamic>.from(json['exportSettings'] as Map)
          : const {},
      navigation: json['navigation'] is Map
          ? Map<String, dynamic>.from(json['navigation'] as Map)
          : const {},
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  /// Documento vacío para proyectos V2 nuevos (sin páginas ni bloques).
  factory BibleDocument.empty({
    required int projectId,
    required int bibleId,
    String themeId = BibleThemeIds.cinematic,
  }) {
    return BibleDocument(
      bibleId: bibleId,
      projectId: projectId,
      themeId: themeId,
      pages: const [],
      updatedAt: DateTime.now().toUtc(),
    );
  }

  BibleDocument copyWith({
    int? bibleId,
    int? projectId,
    int? schemaVersion,
    String? themeId,
    List<BibleTheme>? themes,
    List<BibleDocumentGroup>? groups,
    List<BiblePage>? pages,
    Map<String, dynamic>? exportSettings,
    Map<String, dynamic>? navigation,
    DateTime? updatedAt,
  }) {
    return BibleDocument(
      bibleId: bibleId ?? this.bibleId,
      projectId: projectId ?? this.projectId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      themeId: themeId ?? this.themeId,
      themes: themes ?? this.themes,
      groups: groups ?? this.groups,
      pages: pages ?? this.pages,
      exportSettings: exportSettings ?? this.exportSettings,
      navigation: navigation ?? this.navigation,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
