import 'dart:convert';

/// En qué punto de la decisión está una pieza del equipo.
enum BibleEquipmentStatus {
  /// Preproducción temprana: es la idea, puede cambiar (p. ej. por
  /// presupuesto).
  tentative('Tentativa', 'Tentativo'),
  definitive('Definitiva', 'Definitivo');

  const BibleEquipmentStatus(this.feminine, this.masculine);

  final String feminine;
  final String masculine;

  static BibleEquipmentStatus parse(Object? name) => values.firstWhere(
    (s) => s.name == name,
    orElse: () => BibleEquipmentStatus.tentative,
  );
}

/// Una pieza del equipo en la biblia: la cámara A, el juego de lentes…
///
/// Guarda el nombre y los datos de la ficha tal como eran al elegirla, para
/// que la pantalla y el PDF no dependan de volver a consultar el catálogo.
class BibleEquipmentItem {
  /// «A», «B»… en cámaras; libre en el resto.
  final String role;

  /// Identificador en el catálogo de Equipo; nulo si se escribió a mano.
  final int? catalogId;
  final String name;
  final BibleEquipmentStatus status;
  final String note;

  /// Datos de la ficha: «Sensor» → «27.99×19.22 mm».
  final Map<String, String> facts;

  /// Alternativa por si la principal no puede ser.
  final int? altCatalogId;
  final String altName;
  final String altNote;

  const BibleEquipmentItem({
    this.role = '',
    this.catalogId,
    this.name = '',
    this.status = BibleEquipmentStatus.tentative,
    this.note = '',
    this.facts = const {},
    this.altCatalogId,
    this.altName = '',
    this.altNote = '',
  });

  bool get isEmpty => name.trim().isEmpty && altName.trim().isEmpty;
  bool get hasAlternative => altName.trim().isNotEmpty;

  BibleEquipmentItem copyWith({
    String? role,
    BibleEquipmentStatus? status,
    String? note,
    String? altNote,
  }) => BibleEquipmentItem(
    role: role ?? this.role,
    catalogId: catalogId,
    name: name,
    status: status ?? this.status,
    note: note ?? this.note,
    facts: facts,
    altCatalogId: altCatalogId,
    altName: altName,
    altNote: altNote ?? this.altNote,
  );

  /// Cambia la pieza principal; conserva papel, estado y alternativa.
  BibleEquipmentItem withMain({
    required int? catalogId,
    required String name,
    Map<String, String> facts = const {},
  }) => BibleEquipmentItem(
    role: role,
    catalogId: catalogId,
    name: name,
    status: status,
    note: note,
    facts: facts,
    altCatalogId: altCatalogId,
    altName: altName,
    altNote: altNote,
  );

  BibleEquipmentItem withAlternative({int? catalogId, String name = ''}) =>
      BibleEquipmentItem(
        role: role,
        catalogId: this.catalogId,
        name: this.name,
        status: status,
        note: note,
        facts: facts,
        altCatalogId: catalogId,
        altName: name,
        altNote: name.isEmpty ? '' : altNote,
      );

  Map<String, dynamic> toJson() => {
    if (role.isNotEmpty) 'role': role,
    if (catalogId != null) 'id': catalogId,
    'name': name,
    'status': status.name,
    if (note.isNotEmpty) 'note': note,
    if (facts.isNotEmpty) 'facts': facts,
    if (altCatalogId != null) 'altId': altCatalogId,
    if (altName.isNotEmpty) 'alt': altName,
    if (altNote.isNotEmpty) 'altNote': altNote,
  };

  static List<BibleEquipmentItem> listFrom(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return [
          for (final e in decoded)
            if (e is Map)
              BibleEquipmentItem(
                role: e['role']?.toString() ?? '',
                catalogId: (e['id'] as num?)?.toInt(),
                name: e['name']?.toString() ?? '',
                status: BibleEquipmentStatus.parse(e['status']),
                note: e['note']?.toString() ?? '',
                facts: {
                  if (e['facts'] is Map)
                    for (final f in (e['facts'] as Map).entries)
                      f.key.toString(): f.value.toString(),
                },
                altCatalogId: (e['altId'] as num?)?.toInt(),
                altName: e['alt']?.toString() ?? '',
                altNote: e['altNote']?.toString() ?? '',
              ),
        ];
      }
    } catch (_) {}
    return [];
  }

  static String encode(List<BibleEquipmentItem> items) =>
      jsonEncode([for (final item in items) item.toJson()]);
}
