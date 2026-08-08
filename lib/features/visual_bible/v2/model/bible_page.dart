import 'bible_block.dart';
import 'bible_page_mode.dart';

import 'bible_json_parse.dart';

/// Página (antes: section) del documento modular.
class BiblePage {
  final String id;
  final String groupId;
  final String label;
  final String? iconKey;
  final int sortOrder;
  final bool isHidden;

  /// ID de theme override (null = hereda documento).
  final String? themeId;

  /// Receta de layout profesional (Stitch) cuando [pageMode] == recipe.
  final String? layoutRecipeId;

  /// recipe = layout profesional; freeform = grid modular.
  final BiblePageMode pageMode;

  final List<BibleBlock> blocks;

  /// Origen legacy (sectionId) para migración reversible.
  final String? legacySectionId;
  final String? legacyTemplate;

  const BiblePage({
    required this.id,
    required this.groupId,
    required this.label,
    this.iconKey,
    this.sortOrder = 0,
    this.isHidden = false,
    this.themeId,
    this.layoutRecipeId,
    this.pageMode = BiblePageMode.recipe,
    this.blocks = const [],
    this.legacySectionId,
    this.legacyTemplate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'groupId': groupId,
    'label': label,
    if (iconKey != null) 'iconKey': iconKey,
    'sortOrder': sortOrder,
    'isHidden': isHidden,
    if (themeId != null) 'themeId': themeId,
    if (layoutRecipeId != null) 'layoutRecipeId': layoutRecipeId,
    'pageMode': pageMode.wireName,
    'blocks': blocks.map((b) => b.toJson()).toList(),
    if (legacySectionId != null) 'legacySectionId': legacySectionId,
    if (legacyTemplate != null) 'legacyTemplate': legacyTemplate,
  };

  factory BiblePage.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'] as List? ?? const [];
    return BiblePage(
      id: json['id']?.toString() ?? '',
      groupId: json['groupId']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      iconKey: json['iconKey']?.toString(),
      sortOrder: bibleJsonIntOr(json['sortOrder'], 0),
      isHidden: json['isHidden'] as bool? ?? false,
      themeId: json['themeId']?.toString(),
      layoutRecipeId: json['layoutRecipeId']?.toString(),
      pageMode: BiblePageModeJson.fromWire(json['pageMode']?.toString()),
      blocks: rawBlocks
          .whereType<Map>()
          .map((e) => BibleBlock.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      legacySectionId: json['legacySectionId']?.toString(),
      legacyTemplate: json['legacyTemplate']?.toString(),
    );
  }

  BiblePage copyWith({
    String? id,
    String? groupId,
    String? label,
    String? iconKey,
    int? sortOrder,
    bool? isHidden,
    String? themeId,
    String? layoutRecipeId,
    BiblePageMode? pageMode,
    List<BibleBlock>? blocks,
    String? legacySectionId,
    String? legacyTemplate,
  }) {
    return BiblePage(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      label: label ?? this.label,
      iconKey: iconKey ?? this.iconKey,
      sortOrder: sortOrder ?? this.sortOrder,
      isHidden: isHidden ?? this.isHidden,
      themeId: themeId ?? this.themeId,
      layoutRecipeId: layoutRecipeId ?? this.layoutRecipeId,
      pageMode: pageMode ?? this.pageMode,
      blocks: blocks ?? this.blocks,
      legacySectionId: legacySectionId ?? this.legacySectionId,
      legacyTemplate: legacyTemplate ?? this.legacyTemplate,
    );
  }
}

/// Grupo de navegación del documento.
class BibleDocumentGroup {
  final String id;
  final String label;
  final int sortOrder;

  const BibleDocumentGroup({
    required this.id,
    required this.label,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'sortOrder': sortOrder,
  };

  factory BibleDocumentGroup.fromJson(Map<String, dynamic> json) {
    return BibleDocumentGroup(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      sortOrder: bibleJsonIntOr(json['sortOrder'], 0),
    );
  }
}
