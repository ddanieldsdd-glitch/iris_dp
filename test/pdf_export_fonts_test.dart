import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/utils/pdf_export_fonts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Inter cubre el español y Noto Sans respalda el resto de glifos',
    () async {
      final fonts = await PdfExportFonts.load();
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          theme: PdfExportFonts.theme(regular: fonts.regular, bold: fonts.bold),
          build: (_) => pw.Column(
            children: [
              // Estilo con fuente explícita, como hacen los componentes.
              pw.Text(
                'Iluminación ñ ¿Qué? «cita» 2800–5600 K',
                style: pw.TextStyle(font: fonts.regular),
              ),
              // Ω no está en el archivo de Inter; lo dibuja Noto Sans.
              pw.Text(
                '5 Ω · 46,3 mm · 42,6°',
                style: pw.TextStyle(font: fonts.bold),
              ),
            ],
          ),
        ),
      );

      final document = sf.PdfDocument(inputBytes: await doc.save());
      addTearDown(document.dispose);
      final text = sf.PdfTextExtractor(
        document,
      ).extractText().replaceAll(RegExp(r'\s+'), ' ');
      expect(text, contains('Iluminación ñ ¿Qué? «cita» 2800–5600 K'));
      expect(text, contains('5 Ω · 46,3 mm · 42,6°'));
    },
  );
}
