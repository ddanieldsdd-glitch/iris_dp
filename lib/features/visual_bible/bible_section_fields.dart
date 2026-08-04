import 'dart:convert';

import 'visual_bible_model.dart';

/// Tipo de sub-apartado dentro de una sección de la biblia.
enum BibleSectionFieldType {
  text,
  narrative,
  references,
  blocks,
}

/// Sub-apartado configurable (nombre, orden, hint).
class BibleSectionField {
  final String key;
  final String label;
  final String? hint;
  final int maxLines;
  final BibleSectionFieldType type;

  const BibleSectionField({
    required this.key,
    required this.label,
    this.hint,
    this.maxLines = 3,
    this.type = BibleSectionFieldType.text,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        if (hint != null) 'hint': hint,
        'maxLines': maxLines,
        'type': type.name,
      };

  factory BibleSectionField.fromJson(Map<String, dynamic> json) {
    return BibleSectionField(
      key: json['key'] as String,
      label: json['label'] as String,
      hint: json['hint'] as String?,
      maxLines: json['maxLines'] as int? ?? 3,
      type: BibleSectionFieldType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => BibleSectionFieldType.text,
      ),
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
    );
  }
}

/// Serialización de sub-apartados en `BibleSectionDefinitions.contentJson`.
abstract final class BibleSectionFieldsConfig {
  static const _fieldsKey = 'fields';

  static List<BibleSectionField> defaultsFor(String sectionId) =>
      switch (sectionId) {
        BibleSectionId.direction => const [
            BibleSectionField(
              key: 'narrative',
              label: 'Intención narrativa',
              hint:
                  '¿Cuál es la intención global de la fotografía respecto a la historia?',
              maxLines: 4,
              type: BibleSectionFieldType.narrative,
            ),
            BibleSectionField(
              key: 'tone',
              label: 'Tono',
              hint: 'Melancólico, tenso, íntimo, épico…',
              maxLines: 3,
            ),
            BibleSectionField(
              key: 'creativeIntention',
              label: 'Intención',
              hint: 'Qué queremos transmitir emocionalmente con la imagen…',
              maxLines: 4,
            ),
            BibleSectionField(
              key: 'stagingApproach',
              label: 'Puesta en escena',
              hint:
                  'Cómo se organizan los personajes y el espacio en el encuadre…',
              maxLines: 4,
            ),
            BibleSectionField(
              key: 'pointOfView',
              label: 'Punto de vista',
              hint: 'Observador distante, POV subjetivo, cámara onírica…',
              maxLines: 3,
            ),
            BibleSectionField(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
            ),
          ],
        BibleSectionId.optics => const [
            BibleSectionField(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
            ),
            BibleSectionField(key: 'opticSettings', label: 'Filosofía y kit de lentes'),
            BibleSectionField(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
            ),
          ],
        BibleSectionId.format => const [
            BibleSectionField(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
            ),
            BibleSectionField(key: 'formatSettings', label: 'Aspect ratio y entrega'),
            BibleSectionField(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
            ),
          ],
        BibleSectionId.texture => const [
            BibleSectionField(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
            ),
            BibleSectionField(key: 'textureSettings', label: 'Estilo de textura'),
            BibleSectionField(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
            ),
          ],
        BibleSectionId.concept => const [
            BibleSectionField(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
            ),
            BibleSectionField(
              key: 'visualConcept',
              label: 'Concepto de imagen',
              maxLines: 4,
            ),
            BibleSectionField(
              key: 'filmReferences',
              label: 'Referencias cinematográficas',
              maxLines: 2,
            ),
            BibleSectionField(
              key: 'actNotes',
              label: 'Intención visual por acto',
            ),
            BibleSectionField(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
            ),
          ],
        BibleSectionId.camera => const [
            BibleSectionField(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
            ),
            BibleSectionField(key: 'cameraBody', label: 'Cámara y formato'),
            BibleSectionField(key: 'philosophy', label: 'Filosofía de cámara'),
            BibleSectionField(
              key: 'movements',
              label: 'Movimientos de cámara',
            ),
            BibleSectionField(
              key: 'specsReference',
              label: 'Fichas técnicas de referencia',
            ),
            BibleSectionField(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
            ),
          ],
        BibleSectionId.exposure => const [
            BibleSectionField(key: 'narrative', label: 'Intención narrativa', type: BibleSectionFieldType.narrative),
            BibleSectionField(key: 'globalExposure', label: 'Exposición global'),
            BibleSectionField(key: 'blocks', label: 'Bloques de exposición', type: BibleSectionFieldType.blocks),
            BibleSectionField(key: 'references', label: 'Referencias visuales', type: BibleSectionFieldType.references),
          ],
        BibleSectionId.lighting => const [
            BibleSectionField(key: 'narrative', label: 'Intención narrativa', type: BibleSectionFieldType.narrative),
            BibleSectionField(key: 'philosophy', label: 'Filosofía de iluminación'),
            BibleSectionField(key: 'miredConverter', label: 'Conversor Mired / Kelvin / Gel'),
            BibleSectionField(key: 'diagrams', label: 'Diagramas de iluminación', type: BibleSectionFieldType.blocks),
            BibleSectionField(key: 'references', label: 'Referencias visuales', type: BibleSectionFieldType.references),
          ],
        BibleSectionId.colorImage => const [
            BibleSectionField(key: 'narrative', label: 'Intención narrativa', type: BibleSectionFieldType.narrative),
            BibleSectionField(key: 'lut', label: 'LUT y color science'),
            BibleSectionField(key: 'blocks', label: 'Paletas por bloque', type: BibleSectionFieldType.blocks),
            BibleSectionField(key: 'references', label: 'Referencias visuales', type: BibleSectionFieldType.references),
          ],
        _ => const [
            BibleSectionField(
              key: 'narrative',
              label: 'Intención narrativa',
              type: BibleSectionFieldType.narrative,
              maxLines: 4,
            ),
            BibleSectionField(
              key: 'references',
              label: 'Referencias visuales',
              type: BibleSectionFieldType.references,
            ),
          ],
      };

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
      if (raw is! List) return defaultsFor(sectionId);
      return raw
          .whereType<Map<String, dynamic>>()
          .map(BibleSectionField.fromJson)
          .toList();
    } catch (_) {
      return defaultsFor(sectionId);
    }
  }

  static String encode(List<BibleSectionField> fields) =>
      jsonEncode({_fieldsKey: fields.map((f) => f.toJson()).toList()});

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

/// Lectura/escritura de campos de dirección en VisualBibleData.
abstract final class DirectionFieldBinding {
  static String? read(VisualBibleData data, String key) => switch (key) {
        'tone' => data.tone,
        'creativeIntention' => data.creativeIntention,
        'stagingApproach' => data.stagingApproach,
        'pointOfView' => data.pointOfView,
        _ => null,
      };

  static void write(VisualBibleData data, String key, String? value) {
    switch (key) {
      case 'tone':
        data.tone = value;
      case 'creativeIntention':
        data.creativeIntention = value;
      case 'stagingApproach':
        data.stagingApproach = value;
      case 'pointOfView':
        data.pointOfView = value;
    }
  }
}
