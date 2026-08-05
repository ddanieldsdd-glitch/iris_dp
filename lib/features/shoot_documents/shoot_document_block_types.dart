import 'dart:convert';

/// Tipos de bloque en un documento de rodaje.
abstract final class ShootBlockType {
  static const sectionHeader = 'section_header';
  static const characterList = 'character_list';
  static const sceneHeader = 'scene_header';
  static const scriptExcerpt = 'script_excerpt';
  static const shot = 'shot';
  static const note = 'note';
  static const image = 'image';
  static const pageBreak = 'page_break';
  static const spacer = 'spacer';

  static const all = [
    sectionHeader,
    characterList,
    sceneHeader,
    scriptExcerpt,
    shot,
    note,
    image,
    pageBreak,
    spacer,
  ];

  static String label(String type) => switch (type) {
        sectionHeader => 'Cabecera de sección',
        characterList => 'Lista de personajes',
        sceneHeader => 'Cabecera de escena',
        scriptExcerpt => 'Fragmento de guion',
        shot => 'Plano',
        note => 'Nota',
        image => 'Imagen de referencia',
        pageBreak => 'Salto de página',
        spacer => 'Espacio',
        _ => type,
      };

  static String iconName(String type) => switch (type) {
        sectionHeader => 'title',
        characterList => 'people',
        sceneHeader => 'movie_filter',
        scriptExcerpt => 'menu_book',
        shot => 'videocam',
        note => 'sticky_note_2',
        image => 'image',
        pageBreak => 'insert_page_break',
        spacer => 'height',
        _ => 'widgets',
      };
}

/// Presets de layout del documento (solo afectan vista).
abstract final class ShootLayoutPreset {
  static const freeform = 'freeform';
  static const scriptLeftShotsRight = 'script_left_shots_right';
  static const stacked = 'stacked';
  static const shotsOnly = 'shots_only';

  static String label(String preset) => switch (preset) {
        freeform => 'Libre (apilado)',
        scriptLeftShotsRight => 'Guion + planos',
        stacked => 'Apilado denso',
        shotsOnly => 'Solo planos',
        _ => preset,
      };
}

/// Visibilidad de campos en bloques y export PDF.
class ShootBlockVisibility {
  final bool showThumbnail;
  final bool showCharacters;
  final bool showDuration;
  final bool showCamera;
  final bool showAction;
  final bool showScript;

  const ShootBlockVisibility({
    this.showThumbnail = true,
    this.showCharacters = true,
    this.showDuration = true,
    this.showCamera = true,
    this.showAction = true,
    this.showScript = true,
  });

  static const defaults = ShootBlockVisibility();

  ShootBlockVisibility copyWith({
    bool? showThumbnail,
    bool? showCharacters,
    bool? showDuration,
    bool? showCamera,
    bool? showAction,
    bool? showScript,
  }) =>
      ShootBlockVisibility(
        showThumbnail: showThumbnail ?? this.showThumbnail,
        showCharacters: showCharacters ?? this.showCharacters,
        showDuration: showDuration ?? this.showDuration,
        showCamera: showCamera ?? this.showCamera,
        showAction: showAction ?? this.showAction,
        showScript: showScript ?? this.showScript,
      );

  Map<String, dynamic> toJson() => {
        'showThumbnail': showThumbnail,
        'showCharacters': showCharacters,
        'showDuration': showDuration,
        'showCamera': showCamera,
        'showAction': showAction,
        'showScript': showScript,
      };

  factory ShootBlockVisibility.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return ShootBlockVisibility(
      showThumbnail: json['showThumbnail'] as bool? ?? true,
      showCharacters: json['showCharacters'] as bool? ?? true,
      showDuration: json['showDuration'] as bool? ?? true,
      showCamera: json['showCamera'] as bool? ?? true,
      showAction: json['showAction'] as bool? ?? true,
      showScript: json['showScript'] as bool? ?? true,
    );
  }
}

ShootBlockVisibility decodeBlockVisibility(String? json) {
  if (json == null || json.trim().isEmpty) return ShootBlockVisibility.defaults;
  try {
    return ShootBlockVisibility.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
  } catch (_) {
    return ShootBlockVisibility.defaults;
  }
}

String? encodeBlockVisibility(ShootBlockVisibility visibility) =>
    jsonEncode(visibility.toJson());

ShootBlockVisibility decodeDocumentVisibility(String? json) =>
    decodeBlockVisibility(json);

String? encodeDocumentVisibility(ShootBlockVisibility visibility) =>
    encodeBlockVisibility(visibility);

Map<String, dynamic> decodeContentOverrides(String? json) {
  if (json == null || json.trim().isEmpty) return {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return {};
    return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return {};
  }
}

String? encodeContentOverrides(Map<String, dynamic> overrides) {
  if (overrides.isEmpty) return null;
  return jsonEncode(overrides);
}
