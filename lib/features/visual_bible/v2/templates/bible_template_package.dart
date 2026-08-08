import 'dart:convert';

import '../../bible_preset_bundle.dart';
import '../model/bible_document.dart';
import '../theme/bible_theme.dart';

/// Plantilla completa versionada (amplía [BiblePresetBundle]).
///
/// Compatible hacia atrás: si no hay `document`, se usa solo el bundle legacy.
class BibleTemplatePackage {
  final String id;
  final String name;
  final String description;
  final String author;
  final int version;
  final String category;
  final BiblePresetBundle? legacyBundle;
  final BibleDocument? document;
  final BibleTheme? theme;
  final Map<String, dynamic> exportSettings;
  final DateTime createdAt;

  const BibleTemplatePackage({
    required this.id,
    required this.name,
    required this.description,
    this.author = '',
    this.version = 1,
    this.category = 'custom',
    this.legacyBundle,
    this.document,
    this.theme,
    this.exportSettings = const {},
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'format': 'iris-bible',
    'formatVersion': 1,
    'id': id,
    'name': name,
    'description': description,
    'author': author,
    'version': version,
    'category': category,
    if (legacyBundle != null) 'legacyBundle': legacyBundle!.toJson(),
    if (document != null) 'document': document!.toJson(),
    if (theme != null) 'theme': theme!.toJson(),
    'exportSettings': exportSettings,
    'createdAt': createdAt.toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  factory BibleTemplatePackage.fromJson(Map<String, dynamic> json) {
    return BibleTemplatePackage(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      version: (json['version'] as num?)?.toInt() ?? 1,
      category: json['category']?.toString() ?? 'custom',
      legacyBundle: json['legacyBundle'] is Map
          ? BiblePresetBundle.fromJson(
              Map<String, dynamic>.from(json['legacyBundle'] as Map),
            )
          : null,
      document: json['document'] is Map
          ? BibleDocument.fromJson(
              Map<String, dynamic>.from(json['document'] as Map),
            )
          : null,
      theme: json['theme'] is Map
          ? BibleTheme.fromJson(Map<String, dynamic>.from(json['theme'] as Map))
          : null,
      exportSettings: json['exportSettings'] is Map
          ? Map<String, dynamic>.from(json['exportSettings'] as Map)
          : const {},
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  static BibleTemplatePackage? tryDecode(String raw) {
    try {
      return BibleTemplatePackage.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Duplica con nuevo id y version+1.
  BibleTemplatePackage duplicate({required String newId, String? newName}) {
    return BibleTemplatePackage(
      id: newId,
      name: newName ?? '$name (copia)',
      description: description,
      author: author,
      version: version + 1,
      category: category,
      legacyBundle: legacyBundle,
      document: document,
      theme: theme,
      exportSettings: exportSettings,
      createdAt: DateTime.now().toUtc(),
    );
  }

  /// Crea paquete desde documento actual.
  factory BibleTemplatePackage.fromDocument({
    required BibleDocument document,
    required String id,
    required String name,
    String description = '',
    String author = '',
    String category = 'custom',
  }) {
    return BibleTemplatePackage(
      id: id,
      name: name,
      description: description,
      author: author,
      version: 1,
      category: category,
      document: document,
      theme: document.resolvedTheme,
      exportSettings: document.exportSettings,
      createdAt: DateTime.now().toUtc(),
    );
  }
}
