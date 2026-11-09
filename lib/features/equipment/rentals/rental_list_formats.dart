import 'dart:typed_data';

import 'pdf_layout_reader.dart';
import 'rental_import_models.dart';
import 'reservation_pdf_parser.dart';

/// Un formato de lista de material. Para admitir otro (Excel, Word…) basta
/// con añadir aquí su lector: la revisión y el guardado no cambian.
class RentalListFormat {
  final List<String> extensions;
  final ParsedReservation Function(Uint8List bytes) read;

  const RentalListFormat(this.extensions, this.read);
}

final rentalListFormats = <RentalListFormat>[
  RentalListFormat(const [
    'pdf',
  ], (bytes) => ReservationPdfParser.parse(readPdfGlyphs(bytes))),
];

List<String> get rentalListExtensions => [
  for (final f in rentalListFormats) ...f.extensions,
];

ParsedReservation readRentalList(String fileName, Uint8List bytes) {
  final dot = fileName.lastIndexOf('.');
  final extension = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  for (final f in rentalListFormats) {
    if (f.extensions.contains(extension)) return f.read(bytes);
  }
  throw RentalListUnreadable(
    'Todavía no se pueden leer listas .$extension. '
    'Formatos admitidos: ${rentalListExtensions.join(', ')}.',
  );
}
