import 'dart:convert';

/// Estado de un dato del catálogo, según la hoja `77_Estados_Dato` del
/// master de material técnico.
enum CatalogDataStatus {
  confirmado('CONFIRMADO', 'Dato explícito en fuente primaria'),
  contrastado('CONTRASTADO', 'Confirmado por fuentes independientes'),
  observado('OBSERVADO', 'Resultado de prueba o medición'),
  calculado('CALCULADO', 'Derivado de entradas válidas'),
  secundario('SECUNDARIO', 'Fuente no primaria pero trazable'),
  noPublicado('NO PUBLICADO', 'No localizado en fuente primaria'),
  noAplica('NO APLICA', 'El campo no corresponde a este material'),
  indeterminado('INDETERMINADO', 'Faltan entradas para concluir'),
  conflicto('CONFLICTO', 'Fuentes incompatibles sin resolver'),
  pendiente('PENDIENTE', 'Investigación aún no realizada');

  const CatalogDataStatus(this.label, this.meaning);

  final String label;
  final String meaning;

  /// Cómo puede entrar este dato en un cálculo (`80_Resultados_Permitidos`).
  CatalogCalcUse get calcUse => switch (this) {
        confirmado || contrastado => CatalogCalcUse.high,
        secundario || calculado => CatalogCalcUse.medium,
        observado => CatalogCalcUse.observed,
        conflicto => CatalogCalcUse.conflict,
        noAplica => CatalogCalcUse.notApplicable,
        noPublicado || indeterminado || pendiente => CatalogCalcUse.none,
      };

  bool get usableInCalculations =>
      calcUse == CatalogCalcUse.high || calcUse == CatalogCalcUse.medium;

  /// Lee un estado del master o de la lista de material (v1.7 / v1.8).
  /// Lo que no se reconoce queda como [pendiente]: nunca se promociona.
  static CatalogDataStatus parse(String? raw) {
    final text = (raw ?? '').trim().toUpperCase();
    if (text.isEmpty) return pendiente;
    for (final status in values) {
      if (text == status.label) return status;
    }
    return switch (text) {
      'VERIFICADO' ||
      'VERIFICADO PARCIAL' ||
      'CORREGIDO Y VERIFICADO PARCIAL' =>
        confirmado,
      'CONTRADICTORIO' => conflicto,
      'PARCIAL' => secundario,
      'NO VERIFICADO' || 'NO DETERMINABLE' => pendiente,
      _ => pendiente,
    };
  }
}

/// Uso permitido de un dato como entrada de cálculo.
enum CatalogCalcUse { high, medium, observed, conflict, notApplicable, none }

/// Procedencia de una ficha del catálogo: estado, confianza y fuente.
class CatalogProvenance {
  final CatalogDataStatus status;

  /// ALTA / MEDIA / BAJA, tal como viene de la lista de material.
  final String? confidence;

  /// Campos cubiertos por [status]. Vacío significa «toda la ficha».
  final List<String> verifiedFields;
  final String? sourceLabel;
  final String? sourceUrl;

  /// Fecha de verificación en ISO 8601 (`yyyy-MM-dd`).
  final String? verifiedAt;

  const CatalogProvenance({
    required this.status,
    this.confidence,
    this.verifiedFields = const [],
    this.sourceLabel,
    this.sourceUrl,
    this.verifiedAt,
  });

  static const pending = CatalogProvenance(status: CatalogDataStatus.pendiente);

  /// Estado de un campo concreto. Con verificación parcial, un campo que no
  /// está en [verifiedFields] sigue pendiente.
  CatalogDataStatus statusForField(String field) {
    if (verifiedFields.isEmpty || verifiedFields.contains(field)) return status;
    return CatalogDataStatus.pendiente;
  }

  factory CatalogProvenance.fromJson(Map<String, dynamic> json) =>
      CatalogProvenance(
        status: CatalogDataStatus.parse(json['dataStatus']?.toString()),
        confidence: _text(json['confidence']),
        verifiedFields: parseFields(json['verifiedFields']),
        sourceLabel: _text(json['sourceLabel']),
        sourceUrl: _text(json['sourceUrl']),
        verifiedAt: _text(json['verifiedAt']),
      );

  /// Reconstruye la procedencia desde las columnas de Drift.
  factory CatalogProvenance.fromColumns({
    String? dataStatus,
    String? confidence,
    String? verifiedFieldsJson,
    String? sourceLabel,
    String? sourceUrl,
    String? verifiedAt,
  }) =>
      CatalogProvenance(
        status: CatalogDataStatus.parse(dataStatus),
        confidence: _text(confidence),
        verifiedFields: parseFields(verifiedFieldsJson),
        sourceLabel: _text(sourceLabel),
        sourceUrl: _text(sourceUrl),
        verifiedAt: _text(verifiedAt),
      );

  Map<String, dynamic> toJson() => {
        'dataStatus': status.label,
        if (confidence != null) 'confidence': confidence,
        if (verifiedFields.isNotEmpty) 'verifiedFields': verifiedFields,
        if (sourceLabel != null) 'sourceLabel': sourceLabel,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        if (verifiedAt != null) 'verifiedAt': verifiedAt,
      };

  String? get verifiedFieldsJson =>
      verifiedFields.isEmpty ? null : jsonEncode(verifiedFields);

  /// Acepta una lista, un array JSON o el texto `a; b; c` del Excel.
  static List<String> parseFields(Object? raw) {
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where(_notEmpty).toList();
    }
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) return const [];
    if (text.startsWith('[')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) return parseFields(decoded);
      } catch (_) {}
    }
    return text.split(';').map((e) => e.trim()).where(_notEmpty).toList();
  }

  static bool _notEmpty(String value) => value.isNotEmpty;

  static String? _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
