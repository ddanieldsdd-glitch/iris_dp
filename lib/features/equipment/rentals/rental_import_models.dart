/// Lo leído de una lista de material, antes de revisarlo y guardarlo. Es igual
/// venga de PDF, Excel o lo que sea: cada formato solo tiene que rellenarlo.
class ParsedRentalItem {
  final String kind;
  final String? section;
  final String? groupLabel;
  final String name;
  final double? quantity;
  final bool quantityCertain;
  final String? serial;
  final String? note;
  final String rawText;
  final List<ParsedRentalItem> children;

  const ParsedRentalItem({
    this.kind = 'item',
    this.section,
    this.groupLabel,
    required this.name,
    this.quantity,
    this.quantityCertain = true,
    this.serial,
    this.note,
    required this.rawText,
    this.children = const [],
  });
}

class ParsedReservation {
  final String? number;
  final String? externalId;
  final String? sourceStatus;
  final String? documentTitle;
  final String? responsible;

  /// Hora de pared, `yyyy-MM-ddTHH:mm`.
  final String? pickupAt;
  final String? returnAt;
  final String? suggestedHouse;
  final String? contact;
  final List<ParsedRentalItem> items;

  /// Falso si no se reconoció una tabla: todo hay que revisarlo.
  final bool recognizedTable;

  const ParsedReservation({
    this.number,
    this.externalId,
    this.sourceStatus,
    this.documentTitle,
    this.responsible,
    this.pickupAt,
    this.returnAt,
    this.suggestedHouse,
    this.contact,
    required this.items,
    this.recognizedTable = true,
  });

  int get itemCount => items.fold(0, (sum, i) => sum + 1 + i.children.length);
}

/// El PDF no lleva texto que se pueda leer (un escaneo, por ejemplo).
class RentalListUnreadable implements Exception {
  final String message;
  const RentalListUnreadable(this.message);

  @override
  String toString() => message;
}
