import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Páginas de un PDF ya hecho: para numerar lo que va detrás de él.
int countPdfPages(Uint8List bytes) {
  final doc = sf.PdfDocument(inputBytes: bytes);
  try {
    return doc.pages.count;
  } finally {
    doc.dispose();
  }
}
