import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/equipment/rentals/pdf_layout_reader.dart';
import 'package:iris_dp/features/equipment/rentals/rental_import_models.dart';
import 'package:iris_dp/features/equipment/rentals/reservation_pdf_parser.dart';

/// Reproduce cómo llegan los PDF reales: letra a letra, sin datos reales.
List<PdfGlyph> text(String s, double x, double y, {bool bold = false}) {
  final out = <PdfGlyph>[];
  var at = x;
  for (final c in s.split('')) {
    out.add(PdfGlyph(c, at, at + 6, y));
    if (bold) out.add(PdfGlyph(c, at - 0.7, at + 5.3, y + 0.5));
    at += 6.4;
  }
  return out;
}

const _footer = '+34 000 000 000 https://material.appsescac.com/';

List<PdfGlyph> header() => [
  ...text('RESERVA: S100', 30, 90),
  ...text('ID: 1.234', 270, 90),
  ...text('Estado: Presupuesto', 400, 90),
  ...text('TFM Prueba', 160, 108),
  ...text('Responsable', 30, 138, bold: true),
  ...text('Nombre Persona', 106, 139),
  ...text('Recogida:', 30, 268, bold: true),
  ...text('12-11-2026 10:00', 89, 269),
  ...text('Devolución:', 297, 268, bold: true),
  ...text('18-11-2026 14:00', 368, 269),
  ...text('Nombre producto', 32, 322, bold: true),
  ...text('Descripción', 300, 322, bold: true),
  ...text('Lote', 470, 322, bold: true),
  ...text('Cantidad', 500, 322, bold: true),
  ...text('Check', 560, 322, bold: true),
];

void main() {
  test('cabecera, secciones, kits, cantidades y subtotales', () {
    final r = ReservationPdfParser.parse([
      [
        ...header(),
        ...text('CÁMARA', 32, 350, bold: true),
        ...text('CAMARA X', 32, 375),
        ...text('x1 CUERPO (Nº SERIE ABC.123-9)', 224, 375),
        ...text('1,00', 506, 375),
        ...text('2x BARRAS DE 19mm', 224, 390),
        ...text('1x Rotula grande', 224, 405),
        ...text('D400', 224, 420),
        ...text('Subtotal 1,00 €', 473, 445),
        ...text('ÓPTICAS', 32, 475, bold: true),
        ...text('ZEISS', 32, 500),
        ...text('Zeiss 16mm [Nº 6671678]', 224, 500),
        ...text('1,00', 506, 500),
        ...text('Zeiss 24mm [Nº 6888301]', 224, 515),
        ...text('FILTRO 4x4 IRND 0.3', 32, 545),
        ...text('1,00', 506, 545),
        ...text(_footer, 170, 756),
      ],
      [
        ...text('CONTINUA EN LA PAGINA', 32, 60),
        ...text('3,00', 503, 60),
        ...text('Observaciones', 30, 100, bold: true),
        ...text('Yo, Nombre con DNI 00000000T', 30, 200),
        ...text(_footer, 170, 756),
      ],
    ]);

    expect(r.number, 'S100');
    expect(r.externalId, '1.234');
    expect(r.sourceStatus, 'Presupuesto');
    expect(r.documentTitle, 'TFM Prueba');
    expect(r.responsible, 'Nombre Persona');
    expect(r.pickupAt, '2026-11-12T10:00');
    expect(r.returnAt, '2026-11-18T14:00');
    expect(r.suggestedHouse, 'ESCAC');
    expect(r.contact, _footer);

    final camara = r.items.first;
    expect(camara.section, 'CÁMARA');
    expect(camara.name, 'CAMARA X');
    expect(camara.quantity, 1);
    expect(camara.children.map((c) => c.name), [
      'CUERPO',
      'BARRAS DE 19mm',
      'Rotula grande D400',
    ]);
    expect(camara.children[0].serial, 'ABC.123-9');
    expect(camara.children[1].quantity, 2);

    final zeiss = r.items[1];
    expect(zeiss.section, 'ÓPTICAS');
    expect(zeiss.children.map((c) => c.serial), ['6671678', '6888301']);
    expect(zeiss.children.first.quantity, isNull);

    // «4x4» no es una cantidad.
    expect(r.items[2].name, 'FILTRO 4x4 IRND 0.3');
    expect(r.items[2].quantity, 1);
    // Sigue en la página siguiente.
    expect(r.items[3].quantity, 3);
  });

  test('nada de lo que sigue a Observaciones se guarda', () {
    final r = ReservationPdfParser.parse([
      [
        ...header(),
        ...text('ITEM', 32, 350),
        ...text('1,00', 506, 350),
        ...text('Observaciones', 30, 400, bold: true),
        ...text('Yo, Nombre con DNI 00000000T', 30, 450),
        ...text('OTRO ITEM', 32, 500),
        ...text('5,00', 506, 500),
      ],
    ]);
    expect(r.items.map((i) => i.name), ['ITEM']);
    final everything = [
      for (final i in r.items) i.rawText,
      r.responsible,
      r.documentTitle,
      r.contact,
    ].join(' ');
    expect(everything, isNot(contains('00000000T')));
  });

  test('maletas, separador, variantes de cantidad y faltas', () {
    final r = ReservationPdfParser.parse([
      [
        ...header(),
        ...text('KIT LUZ', 32, 350),
        ...text('Maleta 1 (Luz grande):', 224, 350),
        ...text('2,00', 503, 350),
        ...text('1 x Foco', 224, 365),
        ...text('X1 Cable', 224, 380),
        ...text('---', 224, 395),
        ...text('Maleta 2:', 224, 410),
        ...text('- Parasol (x3)', 224, 425),
        ...text('1x MALETA (LES FALTA: 2x correas)', 224, 440),
        ...text('Retales de tela', 32, 470),
      ],
    ]);
    final kit = r.items.first;
    expect(kit.quantity, 2);
    expect(kit.children.map((c) => c.groupLabel), [
      'Maleta 1 (Luz grande)',
      'Maleta 1 (Luz grande)',
      'Maleta 2',
      'Maleta 2',
    ]);
    expect(kit.children.map((c) => c.quantity), [1, 1, 3, 1]);
    expect(kit.children.last.name, 'MALETA');
    expect(kit.children.last.note, 'Falta: 2x correas');
    expect(r.items.last.kind, 'note');
    expect(r.items.last.name, 'Retales de tela');
  });

  test('sin tabla: texto plano y todo por revisar', () {
    final r = ReservationPdfParser.parse([
      [...text('2x Foco grande', 30, 100), ...text('Cable largo', 30, 120)],
    ]);
    expect(r.recognizedTable, isFalse);
    expect(r.items.first.quantity, 2);
    expect(r.items.every((i) => !i.quantityCertain), isTrue);
  });

  test('sin texto: aviso claro', () {
    expect(
      () => ReservationPdfParser.parse([<PdfGlyph>[]]),
      throwsA(isA<RentalListUnreadable>()),
    );
  });
}
