/// Slot editable dentro de una receta de layout profesional.
class PageLayoutSlot {
  final String id;
  final String kind;
  final String label;
  final int col;
  final int row;
  final int colSpan;
  final int rowSpan;
  final bool editable;

  const PageLayoutSlot({
    required this.id,
    required this.kind,
    required this.label,
    this.col = 0,
    this.row = 0,
    this.colSpan = 12,
    this.rowSpan = 2,
    this.editable = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'label': label,
    'col': col,
    'row': row,
    'colSpan': colSpan,
    'rowSpan': rowSpan,
    'editable': editable,
  };

  factory PageLayoutSlot.fromJson(Map<String, dynamic> json) {
    return PageLayoutSlot(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'text',
      label: json['label']?.toString() ?? '',
      col: (json['col'] as num?)?.toInt() ?? 0,
      row: (json['row'] as num?)?.toInt() ?? 0,
      colSpan: (json['colSpan'] as num?)?.toInt() ?? 12,
      rowSpan: (json['rowSpan'] as num?)?.toInt() ?? 2,
      editable: json['editable'] as bool? ?? true,
    );
  }
}

/// Receta de composición editorial para una pantalla de Biblia.
class PageLayoutRecipe {
  final String id;
  final String label;
  final String description;
  final String? sectionId;
  final List<PageLayoutSlot> slots;
  final String preferredThemeId;

  const PageLayoutRecipe({
    required this.id,
    required this.label,
    required this.description,
    this.sectionId,
    required this.slots,
    this.preferredThemeId = 'cinematic',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'description': description,
    if (sectionId != null) 'sectionId': sectionId,
    'slots': slots.map((s) => s.toJson()).toList(),
    'preferredThemeId': preferredThemeId,
  };

  factory PageLayoutRecipe.fromJson(Map<String, dynamic> json) {
    return PageLayoutRecipe(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      sectionId: json['sectionId']?.toString(),
      slots: (json['slots'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PageLayoutSlot.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      preferredThemeId: json['preferredThemeId']?.toString() ?? 'cinematic',
    );
  }
}
