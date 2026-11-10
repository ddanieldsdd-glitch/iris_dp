import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Un trozo de texto con su sitio en la página. Según el PDF es una letra o
/// una palabra.
class PdfGlyph {
  final String text;
  final double left;
  final double right;
  final double top;

  const PdfGlyph(this.text, this.left, this.right, this.top);
}

/// Los trozos de texto del PDF, por página.
List<List<PdfGlyph>> readPdfGlyphs(Uint8List bytes) {
  final doc = PdfDocument(inputBytes: bytes);
  try {
    final extractor = PdfTextExtractor(doc);
    return [
      for (var page = 0; page < doc.pages.count; page++)
        [
          for (final line in extractor.extractTextLines(
            startPageIndex: page,
            endPageIndex: page,
          ))
            for (final word in line.wordCollection)
              PdfGlyph(
                word.text,
                word.bounds.left,
                word.bounds.right,
                word.bounds.top,
              ),
        ],
    ];
  } finally {
    doc.dispose();
  }
}
