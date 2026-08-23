import 'dart:convert';

import 'bible_stitch_module_registry.dart';
import 'bible_subsection_kind_catalog.dart';
import 'bible_subsection_kind_profiles.dart';
import 'bible_widget_size.dart';

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
}

/// Sub-apartado configurable (nombre, orden, hint, kind y tamaño S/M/L).
class BibleSectionField {
  final String key;
  final String label;
  final String? hint;
  final int maxLines;
  final BibleSectionFieldType type;

  /// Tipo canónico del widget (catálogo de sub-apartados).
  final BibleSubsectionKindId? kind;

  /// Tamaño semántico S/M/L (ancho en grid).
  final BibleWidgetSize size;

  /// Binding de datos (p.ej. slot Stitch `filmRefs` para un `cardDeck`).
  final String? binding;

  const BibleSectionField({
    required this.key,
    required this.label,
    this.hint,
    this.maxLines = 3,
    this.type = BibleSectionFieldType.text,
    this.kind,
    this.size = BibleWidgetSize.large,
    this.binding,
  });

  /// Kind resuelto: explícito, módulo Stitch o inferido por tipo.
  BibleSubsectionKindId resolvedKind(String sectionId) {
    if (kind != null) return kind!;
    final module = BibleStitchModuleRegistry.module(sectionId, key);
    if (module?.subsectionKind != null) return module!.subsectionKind!;
    return BibleSubsectionKindCatalog.fromFieldType(type).id;
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        if (hint != null) 'hint': hint,
        'maxLines': maxLines,
        'type': type.name,
        if (kind != null) 'kind': kind!.name,
        if (size != BibleWidgetSize.large) 'size': size.storageKey,
        if (binding != null && binding != key) 'binding': binding,
      };

  factory BibleSectionField.fromJson(Map<String, dynamic> json) {
    final type = BibleSectionFieldType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => BibleSectionFieldType.text,
    );
    final kindKey = json['kind']?.toString();
    final parsedKind = BibleSubsectionKindCatalog.byStorageKey(kindKey)?.id;
    return BibleSectionField(
      key: json['key'] as String,
      label: json['label'] as String,
      hint: json['hint'] as String?,
      maxLines: _parseMaxLines(json['maxLines']),
      type: type,
      kind: parsedKind,
      size: BibleWidgetSize.fromStorage(json['size']?.toString()),
      binding: json['binding']?.toString(),
    );
  }

  BibleSectionField copyWith({
    String? label,
    String? hint,
    int? maxLines,
    BibleSectionFieldType? type,
    BibleSubsectionKindId? kind,
    BibleWidgetSize? size,
    String? binding,
  }) {
    return BibleSectionField(
      key: key,
      label: label ?? this.label,
      hint: hint ?? this.hint,
      maxLines: maxLines ?? this.maxLines,
      type: type ?? this.type,
      kind: kind ?? this.kind,
      size: size ?? this.size,
      binding: binding ?? this.binding,
    );
  }
}

/// Serialización de sub-apartados en `BibleSectionDefinitions.contentJson`.
abstract final class BibleSectionFieldsConfig {
  static const _fieldsKey = 'fields';
  static const _valuesKey = 'values';

  static List<BibleSectionField> defaultsFor(String sectionId) =>
      BibleStitchModuleRegistry.defaultFieldsFor(sectionId)
          .map((f) => _enrichField(sectionId, f))
          .toList();

  /// Enriquece kind/size/binding desde el registry Stitch y perfiles S/M/L.
  static BibleSectionField enrichField(
    String sectionId,
    BibleSectionField field,
  ) =>
      _enrichField(sectionId, field);

  static BibleSectionField _enrichField(
    String sectionId,
    BibleSectionField field,
  ) {
    final module = BibleStitchModuleRegistry.module(sectionId, field.key);
    final resolvedKind = field.kind ??
        module?.subsectionKind ??
        BibleSubsectionKindCatalog.fromFieldType(field.type).id;
    final resolvedSize = BibleSubsectionKindProfiles.clampSize(
      resolvedKind,
      field.size,
    );
    final resolvedBinding = field.binding ?? module?.key ?? field.key;
    if (field.kind == resolvedKind &&
        field.size == resolvedSize &&
        field.binding == resolvedBinding) {
      return field;
    }
    return field.copyWith(
      kind: resolvedKind,
      size: resolvedSize,
      binding: resolvedBinding,
    );
  }

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
          .map((f) => _enrichField(sectionId, f))
          .toList();
      return BibleStitchModuleRegistry.normalizeFields(sectionId, parsed);
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
        _fieldsKey: fields.map((f) => f.toJson()).toList(),
        if (values != null && values.isNotEmpty) _valuesKey: values,
      });

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
        BibleSectionFieldType.text => 'Campo de texto',
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
