import 'dart:convert';

/// Tipos de plantilla guardadas por el usuario.
enum UserTemplateType {
  bibleLayout,
  shootDocument,
}

extension UserTemplateTypeX on UserTemplateType {
  String get storageKey => switch (this) {
        UserTemplateType.bibleLayout => 'bible_layout',
        UserTemplateType.shootDocument => 'shoot_document',
      };

  static UserTemplateType? fromStorageKey(String key) => switch (key) {
        'bible_layout' => UserTemplateType.bibleLayout,
        'shoot_document' => UserTemplateType.shootDocument,
        _ => null,
      };
}

/// Cuándo aplicar automáticamente una plantilla al crear proyecto/documento.
enum TemplateAutoApplyMode {
  always,
  ask,
  perProject,
  never,
}

extension TemplateAutoApplyModeX on TemplateAutoApplyMode {
  String get storageKey => name;

  static TemplateAutoApplyMode fromStorageKey(String? key) =>
      TemplateAutoApplyMode.values.firstWhere(
        (m) => m.name == key,
        orElse: () => TemplateAutoApplyMode.ask,
      );

  String get label => switch (this) {
        TemplateAutoApplyMode.always => 'Siempre (plantilla predeterminada)',
        TemplateAutoApplyMode.ask => 'Preguntar al crear',
        TemplateAutoApplyMode.perProject => 'Por proyecto',
        TemplateAutoApplyMode.never => 'Nunca (manual)',
      };
}

/// Payload serializable de estructura de biblia visual.
class BibleLayoutTemplatePayload {
  final List<BibleLayoutGroupPayload> groups;
  final List<BibleLayoutSectionPayload> sections;

  const BibleLayoutTemplatePayload({
    required this.groups,
    required this.sections,
  });

  Map<String, dynamic> toJson() => {
        'groups': groups.map((g) => g.toJson()).toList(),
        'sections': sections.map((s) => s.toJson()).toList(),
      };

  factory BibleLayoutTemplatePayload.fromJson(Map<String, dynamic> json) {
    return BibleLayoutTemplatePayload(
      groups: (json['groups'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(BibleLayoutGroupPayload.fromJson)
          .toList(),
      sections: (json['sections'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(BibleLayoutSectionPayload.fromJson)
          .toList(),
    );
  }

  String encode() => jsonEncode(toJson());

  static BibleLayoutTemplatePayload decode(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      return const BibleLayoutTemplatePayload(groups: [], sections: []);
    }
    return BibleLayoutTemplatePayload.fromJson(decoded);
  }
}

class BibleLayoutGroupPayload {
  final String id;
  final String label;
  final int sortOrder;
  final bool isBuiltIn;

  const BibleLayoutGroupPayload({
    required this.id,
    required this.label,
    required this.sortOrder,
    this.isBuiltIn = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'sortOrder': sortOrder,
        'isBuiltIn': isBuiltIn,
      };

  factory BibleLayoutGroupPayload.fromJson(Map<String, dynamic> json) =>
      BibleLayoutGroupPayload(
        id: json['id'] as String,
        label: json['label'] as String,
        sortOrder: json['sortOrder'] as int? ?? 0,
        isBuiltIn: json['isBuiltIn'] as bool? ?? true,
      );
}

class BibleLayoutSectionPayload {
  final String id;
  final String groupId;
  final String label;
  final String iconKey;
  final int sortOrder;
  final bool isBuiltIn;
  final bool isHidden;
  final String template;
  final String? contentJson;

  const BibleLayoutSectionPayload({
    required this.id,
    required this.groupId,
    required this.label,
    required this.iconKey,
    required this.sortOrder,
    this.isBuiltIn = true,
    this.isHidden = false,
    this.template = 'standard',
    this.contentJson,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'label': label,
        'iconKey': iconKey,
        'sortOrder': sortOrder,
        'isBuiltIn': isBuiltIn,
        'isHidden': isHidden,
        'template': template,
        if (contentJson != null) 'contentJson': contentJson,
      };

  factory BibleLayoutSectionPayload.fromJson(Map<String, dynamic> json) =>
      BibleLayoutSectionPayload(
        id: json['id'] as String,
        groupId: json['groupId'] as String,
        label: json['label'] as String,
        iconKey: json['iconKey'] as String? ?? 'article',
        sortOrder: json['sortOrder'] as int? ?? 0,
        isBuiltIn: json['isBuiltIn'] as bool? ?? true,
        isHidden: json['isHidden'] as bool? ?? false,
        template: json['template'] as String? ?? 'standard',
        contentJson: json['contentJson'] as String?,
      );
}

/// Bloque plantilla de documento de rodaje (sin IDs de escena/plano).
class ShootDocumentBlockBlueprint {
  final String blockType;
  final int sortOrder;
  final String? customLabel;
  final String? noteBody;
  final String? visibilityJson;
  final String? contentOverridesJson;

  const ShootDocumentBlockBlueprint({
    required this.blockType,
    required this.sortOrder,
    this.customLabel,
    this.noteBody,
    this.visibilityJson,
    this.contentOverridesJson,
  });

  Map<String, dynamic> toJson() => {
        'blockType': blockType,
        'sortOrder': sortOrder,
        if (customLabel != null) 'customLabel': customLabel,
        if (noteBody != null) 'noteBody': noteBody,
        if (visibilityJson != null) 'visibilityJson': visibilityJson,
        if (contentOverridesJson != null)
          'contentOverridesJson': contentOverridesJson,
      };

  factory ShootDocumentBlockBlueprint.fromJson(Map<String, dynamic> json) =>
      ShootDocumentBlockBlueprint(
        blockType: json['blockType'] as String,
        sortOrder: json['sortOrder'] as int? ?? 0,
        customLabel: json['customLabel'] as String?,
        noteBody: json['noteBody'] as String?,
        visibilityJson: json['visibilityJson'] as String?,
        contentOverridesJson: json['contentOverridesJson'] as String?,
      );
}

class ShootDocumentTemplatePayload {
  final String layoutPreset;
  final String? defaultVisibilityJson;
  final bool includeCoverInPdf;
  final List<ShootDocumentBlockBlueprint> blocks;

  const ShootDocumentTemplatePayload({
    this.layoutPreset = 'freeform',
    this.defaultVisibilityJson,
    this.includeCoverInPdf = true,
    this.blocks = const [],
  });

  Map<String, dynamic> toJson() => {
        'layoutPreset': layoutPreset,
        if (defaultVisibilityJson != null)
          'defaultVisibilityJson': defaultVisibilityJson,
        'includeCoverInPdf': includeCoverInPdf,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  factory ShootDocumentTemplatePayload.fromJson(Map<String, dynamic> json) =>
      ShootDocumentTemplatePayload(
        layoutPreset: json['layoutPreset'] as String? ?? 'freeform',
        defaultVisibilityJson: json['defaultVisibilityJson'] as String?,
        includeCoverInPdf: json['includeCoverInPdf'] as bool? ?? true,
        blocks: (json['blocks'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ShootDocumentBlockBlueprint.fromJson)
            .toList(),
      );

  String encode() => jsonEncode(toJson());

  static ShootDocumentTemplatePayload decode(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      return const ShootDocumentTemplatePayload();
    }
    return ShootDocumentTemplatePayload.fromJson(decoded);
  }
}

/// ID especial para la plantilla base IRIS.
const kBuiltinBibleLayoutTemplateId = '__iris_builtin__';
const kBuiltinShootDocTemplateId = '__iris_builtin__';
