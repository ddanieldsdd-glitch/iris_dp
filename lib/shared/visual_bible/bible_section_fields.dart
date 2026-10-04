import 'dart:convert';

import 'bible_stitch_module_registry.dart';

int _parseMaxLines(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 3;
  return 3;
}

/// Tipo de sub-apartado dentro de una sección de la biblia.
enum BibleSectionFieldType {
  text,
  narrative,
  references,
  image,
  blocks,

  /// Lista de puntos. El valor es un array JSON de textos.
  list,

  /// Pares etiqueta/valor. El valor es un array JSON de `{label, value}`.
  specs,

  /// Paleta de color. El valor es un array JSON de `{hex, name}`.
  palette,

  /// Imágenes del moodboard. El valor es un array JSON de ids.
  gallery,

  /// Referencias razonadas. El valor es `{preset, items}` en JSON.
  referenceDeck,

  /// Tarjetas con título y desarrollo. El valor es un array JSON de
  /// `{title, body}`.
  cards,

  /// División por actos. El valor es un array JSON de
  /// `{kicker, title, body}`, donde `kicker` es la fase del acto.
  acts,

  /// Etiquetas. El valor es un array JSON de textos.
  tags,
}

/// Codifica el valor de los puntos `list` y `specs` dentro de `values[key]`.
abstract final class BibleSectionPointValue {
  static List<String> decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return [raw];
  }

  static String? encodeList(List<String> items) =>
      items.isEmpty ? null : jsonEncode(items);

  static List<(String, String)> decodeSpecs(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return [
          for (final e in decoded)
            if (e is Map)
              (e['label']?.toString() ?? '', e['value']?.toString() ?? ''),
        ];
      }
    } catch (_) {}
    return [];
  }

  static String? encodeSpecs(List<(String, String)> rows) => rows.isEmpty
      ? null
      : jsonEncode([
          for (final (label, value) in rows) {'label': label, 'value': value},
        ]);
}

/// Sub-apartado configurable (nombre, orden, hint).
class BibleSectionField {
  final String key;
  final String label;
  final String? hint;
  final int maxLines;
  final BibleSectionFieldType type;

  /// Widget del catálogo con el que se pinta, cuando el tipo admite varios
  /// (p. ej. paleta maestra o compacta). Se fija al crear el punto.
  final String? widget;

  const BibleSectionField({
    required this.key,
    required this.label,
    this.hint,
    this.maxLines = 3,
    this.type = BibleSectionFieldType.text,
    this.widget,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        if (hint != null) 'hint': hint,
        'maxLines': maxLines,
        'type': type.name,
        if (widget != null) 'widget': widget,
      };

  factory BibleSectionField.fromJson(Map<String, dynamic> json) {
    return BibleSectionField(
      key: json['key'] as String,
      label: json['label'] as String,
      hint: json['hint'] as String?,
      maxLines: _parseMaxLines(json['maxLines']),
      type: BibleSectionFieldType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => BibleSectionFieldType.text,
      ),
      widget: json['widget'] as String?,
    );
  }

  BibleSectionField copyWith({
    String? label,
    String? hint,
    int? maxLines,
    BibleSectionFieldType? type,
  }) {
    return BibleSectionField(
      key: key,
      label: label ?? this.label,
      hint: hint ?? this.hint,
      maxLines: maxLines ?? this.maxLines,
      type: type ?? this.type,
      widget: widget,
    );
  }
}

/// Serialización de sub-apartados en `BibleSectionDefinitions.contentJson`.
abstract final class BibleSectionFieldsConfig {
  static const _fieldsKey = 'fields';
  static const _valuesKey = 'values';
  static const _layoutVersionKey = 'layoutVersion';

  /// Versión de la lista de puntos. Las migraciones que añaden puntos de
  /// fábrica solo se aplican a contenidos guardados con una versión menor,
  /// para no reinsertar lo que el usuario quitó.
  static const layoutVersion = 2;

  static List<BibleSectionField> defaultsFor(String sectionId) =>
      BibleStitchModuleRegistry.defaultFieldsFor(sectionId);

  static List<BibleSectionField> parse(String? contentJson, String sectionId) {
    if (contentJson == null || contentJson.isEmpty) {
      return defaultsFor(sectionId);
    }
    try {
      final decoded = jsonDecode(contentJson);
      if (decoded is! Map<String, dynamic>) {
        return defaultsFor(sectionId);
      }
      final raw = decoded[_fieldsKey];
      if (raw is! List) {
        if (sectionId.startsWith('custom_')) {
          return freeformDefaults(sectionId);
        }
        return defaultsFor(sectionId);
      }
      final parsed = raw
          .whereType<Map<String, dynamic>>()
          .map(BibleSectionField.fromJson)
          .toList();
      final version = decoded[_layoutVersionKey];
      return BibleStitchModuleRegistry.normalizeFields(
        sectionId,
        parsed,
        layoutVersion: version is num ? version.toInt() : 1,
      );
    } catch (_) {
      return defaultsFor(sectionId);
    }
  }

  static Map<String, String> parseValues(String? contentJson) {
    if (contentJson == null || contentJson.isEmpty) return {};
    try {
      final decoded = jsonDecode(contentJson);
      if (decoded is! Map<String, dynamic>) return {};
      final raw = decoded[_valuesKey];
      if (raw is! Map) return {};
      return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    } catch (_) {
      return {};
    }
  }

  static String encode(
    List<BibleSectionField> fields, {
    Map<String, String>? values,
  }) =>
      jsonEncode({
        _layoutVersionKey: layoutVersion,
        _fieldsKey: fields.map((f) => f.toJson()).toList(),
        if (values != null && values.isNotEmpty) _valuesKey: values,
      });

  /// Puntos que el usuario añadió: los que no son propios de la pantalla.
  static bool isUserPoint(String sectionId, BibleSectionField field) =>
      BibleStitchModuleRegistry.module(sectionId, field.key) == null;

  /// «Restablecer pantalla»: los puntos de fábrica en su orden original y,
  /// detrás, los que añadió el usuario, en el orden en que estaban.
  static List<BibleSectionField> resetKeepingUserPoints(
    String sectionId,
    List<BibleSectionField> current,
  ) =>
      [
        ...defaultsFor(sectionId),
        for (final field in current)
          if (isUserPoint(sectionId, field)) field,
      ];

  /// Pone en una pantalla los puntos de una plantilla sin perder lo escrito.
  ///
  /// Los puntos son los de [templateJson] (los de fábrica si es nulo) y,
  /// detrás, los que el usuario añadió en [currentJson]. Los valores son los
  /// de [currentJson]: de la plantilla solo se toma el tipo de las fichas de
  /// referencias, nunca su contenido.
  static String? applyStructure({
    required String sectionId,
    required String? templateJson,
    required String? currentJson,
  }) {
    if (templateJson == null && currentJson == null) return null;

    final templateFields = parse(templateJson, sectionId);
    final templateKeys = {for (final f in templateFields) f.key};
    final fields = [
      ...templateFields,
      if (currentJson != null)
        for (final f in parse(currentJson, sectionId))
          if (isUserPoint(sectionId, f) && !templateKeys.contains(f.key)) f,
    ];

    final templateValues = parseValues(templateJson);
    final values = <String, String>{
      for (final f in templateFields)
        if (f.type == BibleSectionFieldType.referenceDeck)
          f.key: _emptyDeck(templateValues[f.key]),
      ...parseValues(currentJson),
    };

    // Se conserva cualquier otra clave del contenido actual (p. ej. los
    // bloques de una pantalla personalizada antigua).
    final result = <String, dynamic>{};
    if (currentJson != null && currentJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(currentJson);
        if (decoded is Map) result.addAll(Map<String, dynamic>.from(decoded));
      } catch (_) {}
    }
    result[_layoutVersionKey] = layoutVersion;
    result[_fieldsKey] = [for (final f in fields) f.toJson()];
    if (values.isEmpty) {
      result.remove(_valuesKey);
    } else {
      result[_valuesKey] = values;
    }
    return jsonEncode(result);
  }

  /// Los puntos de una pantalla sin lo escrito en ellos: lo que se guarda en
  /// una plantilla.
  static String? structureOnly(String sectionId, String? contentJson) =>
      applyStructure(
        sectionId: sectionId,
        templateJson: contentJson,
        currentJson: null,
      );

  static String _emptyDeck(String? raw) {
    Object? preset;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) preset = decoded['preset'];
      } catch (_) {}
    }
    return jsonEncode({'preset': preset ?? 'visual', 'items': const []});
  }

  /// Contenido con el que nace una pantalla personalizada: intención
  /// narrativa, un texto y referencias visuales razonadas.
  static String customScreenStarterJson(String label) => encode(
        [
          BibleSectionField(
            key: 'narrative',
            label: 'Intención narrativa',
            hint: 'Qué aporta «$label» a la película…',
            maxLines: 4,
            type: BibleSectionFieldType.narrative,
          ),
          const BibleSectionField(key: 'body', label: 'Contenido', maxLines: 8),
          const BibleSectionField(
            key: 'field_references',
            label: 'Referencias visuales',
            type: BibleSectionFieldType.referenceDeck,
          ),
        ],
        values: {'field_references': '{"preset":"visual","items":[]}'},
      );

  /// Campos por defecto para secciones personalizadas (libres).
  static List<BibleSectionField> freeformDefaults(String sectionLabel) => [
        BibleSectionField(
          key: 'narrative',
          label: 'Intención narrativa',
          hint: 'Orientativo: intención de «$sectionLabel» (ej. luz lateral suave, 5600K…)…',
          maxLines: 4,
          type: BibleSectionFieldType.narrative,
        ),
        const BibleSectionField(
          key: 'body',
          label: 'Contenido',
          hint: 'Orientativo: notas y criterios (no bloquean export si están vacíos)…',
          maxLines: 12,
        ),
        const BibleSectionField(
          key: 'references',
          label: 'Referencias visuales',
          hint: 'Stills orientativas que ilustran el texto…',
          type: BibleSectionFieldType.references,
        ),
      ];

  /// Packs estándar al crear / aplicar plantilla por estilo visual.
  static List<BibleSectionField> packForStyle(
    String styleKey, {
    String sectionLabel = 'Sección',
    String? sectionId,
  }) {
    if (sectionId != null && sectionId.isNotEmpty) {
      return BibleStitchModuleRegistry.packForStyle(
        styleKey,
        sectionId: sectionId,
        sectionLabel: sectionLabel,
      );
    }
    return packForStyleGeneric(styleKey, sectionLabel: sectionLabel);
  }

  /// Pack genérico (secciones custom / fallback sin registry Stitch).
  static List<BibleSectionField> packForStyleGeneric(
    String styleKey, {
    String sectionLabel = 'Sección',
  }) {
    switch (styleKey) {
      case 'technical':
        return [
          BibleSectionField(
            key: 'narrative',
            label: 'Intención técnica',
            hint: 'Qué problema técnico resuelve «$sectionLabel»…',
            maxLines: 3,
            type: BibleSectionFieldType.narrative,
          ),
          const BibleSectionField(
            key: 'specs',
            label: 'Specs / métricas',
            hint: 'Valores, ratios, equipos, límites…',
            maxLines: 6,
          ),
          const BibleSectionField(
            key: 'notes',
            label: 'Notas de rodaje',
            hint: 'Procedimiento, riesgos, checklist…',
            maxLines: 5,
          ),
          const BibleSectionField(
            key: 'references',
            label: 'Referencias visuales',
            type: BibleSectionFieldType.references,
          ),
        ];
      case 'minimalist':
        return [
          BibleSectionField(
            key: 'narrative',
            label: 'Intención',
            hint: 'Una idea clara para «$sectionLabel»…',
            maxLines: 3,
            type: BibleSectionFieldType.narrative,
          ),
          const BibleSectionField(
            key: 'body',
            label: 'Notas',
            hint: 'Lo esencial…',
            maxLines: 4,
          ),
          const BibleSectionField(
            key: 'references',
            label: 'Referencias',
            type: BibleSectionFieldType.image,
          ),
        ];
      case 'cinematic':
      default:
        return [
          BibleSectionField(
            key: 'narrative',
            label: 'Intención narrativa',
            hint: 'Atmósfera y emoción de «$sectionLabel»…',
            maxLines: 4,
            type: BibleSectionFieldType.narrative,
          ),
          const BibleSectionField(
            key: 'atmosphere',
            label: 'Atmósfera / look',
            hint: 'Luz, color, textura, ritmo…',
            maxLines: 5,
          ),
          const BibleSectionField(
            key: 'body',
            label: 'Desarrollo',
            hint: 'Cómo se materializa en imagen…',
            maxLines: 8,
          ),
          const BibleSectionField(
            key: 'references',
            label: 'Referencias moodboard',
            type: BibleSectionFieldType.references,
          ),
        ];
    }
  }

  static String newFieldKey() =>
      'field_${DateTime.now().millisecondsSinceEpoch}';

  static String labelForType(BibleSectionFieldType type) => switch (type) {
        BibleSectionFieldType.narrative => 'Intención narrativa',
        BibleSectionFieldType.references => 'Referencias moodboard',
        BibleSectionFieldType.image => 'Imágenes / referencias',
        BibleSectionFieldType.blocks => 'Bloques dinámicos',
        BibleSectionFieldType.text => 'Texto',
        BibleSectionFieldType.list => 'Lista de puntos',
        BibleSectionFieldType.specs => 'Datos técnicos',
        BibleSectionFieldType.palette => 'Paleta de color',
        BibleSectionFieldType.gallery => 'Imágenes',
        BibleSectionFieldType.referenceDeck => 'Referencias razonadas',
        BibleSectionFieldType.cards => 'Puntos con título',
        BibleSectionFieldType.acts => 'División por actos',
        BibleSectionFieldType.tags => 'Etiquetas',
      };

  static String labelFor(
    String? contentJson,
    String sectionId,
    String fieldKey,
    String fallback,
  ) {
    final fields = parse(contentJson, sectionId);
    return fields
            .where((f) => f.key == fieldKey)
            .map((f) => f.label)
            .firstOrNull ??
        fallback;
  }
}

extension BibleFieldIterable<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
