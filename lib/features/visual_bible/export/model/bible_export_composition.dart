import '../../data/visual_bible_repository.dart';
import '../../v2/model/bible_block.dart';
import '../../visual_bible_export_config.dart';

const int kBibleExportCompositionSchemaVersion = 1;
const String kBibleExportAnnotationTargetType = 'visual_bible_export_page';

enum BibleExportPageType { cover, generated, blank, custom }

enum BibleExportPageFormat { a4Portrait, a4Landscape }

class BibleExportPageMargins {
  final double top;
  final double right;
  final double bottom;
  final double left;

  const BibleExportPageMargins({
    this.top = 36,
    this.right = 36,
    this.bottom = 36,
    this.left = 36,
  });

  Map<String, dynamic> toJson() => {
    'top': top,
    'right': right,
    'bottom': bottom,
    'left': left,
  };

  factory BibleExportPageMargins.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BibleExportPageMargins();
    return BibleExportPageMargins(
      top: (json['top'] as num?)?.toDouble() ?? 36,
      right: (json['right'] as num?)?.toDouble() ?? 36,
      bottom: (json['bottom'] as num?)?.toDouble() ?? 36,
      left: (json['left'] as num?)?.toDouble() ?? 36,
    );
  }
}

/// Referencia estable a la página original. Permite restaurarla sin escribir
/// sobre el documento v2 ni sobre las tablas legacy.
class BibleExportSourceReference {
  final int? bibleId;
  final String pageId;
  final String? sectionId;
  final int documentSchemaVersion;
  final DateTime documentUpdatedAt;

  const BibleExportSourceReference({
    required this.bibleId,
    required this.pageId,
    this.sectionId,
    required this.documentSchemaVersion,
    required this.documentUpdatedAt,
  });

  Map<String, dynamic> toJson() => {
    'bibleId': bibleId,
    'pageId': pageId,
    if (sectionId != null) 'sectionId': sectionId,
    'documentSchemaVersion': documentSchemaVersion,
    'documentUpdatedAt': documentUpdatedAt.toIso8601String(),
  };

  factory BibleExportSourceReference.fromJson(Map<String, dynamic> json) {
    return BibleExportSourceReference(
      bibleId: (json['bibleId'] as num?)?.toInt(),
      pageId: json['pageId']?.toString() ?? '',
      sectionId: json['sectionId']?.toString(),
      documentSchemaVersion:
          (json['documentSchemaVersion'] as num?)?.toInt() ?? 1,
      documentUpdatedAt:
          DateTime.tryParse(json['documentUpdatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class BibleExportPage {
  final String id;
  final String label;
  final BibleExportPageType type;
  final int sortOrder;
  final BibleExportPageFormat format;
  final BibleExportPageMargins margins;
  final BibleExportSourceReference? source;
  final List<BibleBlock> blocks;
  final Map<String, dynamic> metadata;

  const BibleExportPage({
    required this.id,
    required this.label,
    required this.type,
    this.sortOrder = 0,
    this.format = BibleExportPageFormat.a4Portrait,
    this.margins = const BibleExportPageMargins(),
    this.source,
    this.blocks = const [],
    this.metadata = const {},
  });

  String get annotationTargetId => id;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'type': type.name,
    'sortOrder': sortOrder,
    'format': format.name,
    'margins': margins.toJson(),
    if (source != null) 'source': source!.toJson(),
    'blocks': blocks.map((block) => block.toJson()).toList(),
    'metadata': metadata,
  };

  factory BibleExportPage.fromJson(Map<String, dynamic> json) {
    return BibleExportPage(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      type: BibleExportPageType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => BibleExportPageType.custom,
      ),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      format: BibleExportPageFormat.values.firstWhere(
        (value) => value.name == json['format'],
        orElse: () => BibleExportPageFormat.a4Portrait,
      ),
      margins: BibleExportPageMargins.fromJson(
        json['margins'] is Map
            ? Map<String, dynamic>.from(json['margins'] as Map)
            : null,
      ),
      source: json['source'] is Map
          ? BibleExportSourceReference.fromJson(
              Map<String, dynamic>.from(json['source'] as Map),
            )
          : null,
      blocks: (json['blocks'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => BibleBlock.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  BibleExportPage copyWith({
    String? id,
    String? label,
    BibleExportPageType? type,
    int? sortOrder,
    BibleExportPageFormat? format,
    BibleExportPageMargins? margins,
    BibleExportSourceReference? source,
    List<BibleBlock>? blocks,
    Map<String, dynamic>? metadata,
  }) {
    return BibleExportPage(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      sortOrder: sortOrder ?? this.sortOrder,
      format: format ?? this.format,
      margins: margins ?? this.margins,
      source: source ?? this.source,
      blocks: blocks ?? this.blocks,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Borrador no destructivo consumido por el futuro editor y renderer PDF.
class BibleExportComposition {
  final String id;
  final int projectId;
  final int? bibleId;
  final int schemaVersion;
  final int revision;
  final VisualBibleExportConfig config;
  final List<BibleExportPage> pages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  const BibleExportComposition({
    required this.id,
    required this.projectId,
    this.bibleId,
    this.schemaVersion = kBibleExportCompositionSchemaVersion,
    this.revision = 0,
    required this.config,
    this.pages = const [],
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  BibleExportPage? pageById(String pageId) {
    for (final page in pages) {
      if (page.id == pageId) return page;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'bibleId': bibleId,
    'schemaVersion': schemaVersion,
    'revision': revision,
    'config': config.toJson(),
    'pages': pages.map((page) => page.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'metadata': metadata,
  };

  factory BibleExportComposition.fromJson(Map<String, dynamic> json) {
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    if (schemaVersion > kBibleExportCompositionSchemaVersion) {
      throw FormatException(
        'Unsupported BibleExportComposition schema $schemaVersion',
      );
    }
    return BibleExportComposition(
      id: json['id']?.toString() ?? '',
      projectId: (json['projectId'] as num?)?.toInt() ?? 0,
      bibleId: (json['bibleId'] as num?)?.toInt(),
      schemaVersion: schemaVersion,
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      config: VisualBibleExportConfig.fromJson(
        json['config'] is Map
            ? Map<String, dynamic>.from(json['config'] as Map)
            : const {},
      ),
      pages: (json['pages'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => BibleExportPage.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  BibleExportComposition copyWith({
    String? id,
    int? projectId,
    int? bibleId,
    int? schemaVersion,
    int? revision,
    VisualBibleExportConfig? config,
    List<BibleExportPage>? pages,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return BibleExportComposition(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      bibleId: bibleId ?? this.bibleId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      revision: revision ?? this.revision,
      config: config ?? this.config,
      pages: pages ?? this.pages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Alias documental: el builder consume explícitamente el bundle existente.
typedef BibleExportSourceBundle = VisualBibleExportBundle;
