import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/utils/export_file_saver.dart';
import '../../core/utils/pdf_export_fonts.dart';

import 'look_bible_model.dart';
class LookBiblePdfService {
  LookBiblePdfService._();

  static Future<pw.Document> build({
    required String projectName,
    required String? director,
    required LookBibleData data,
  }) async {
    final doc = pw.Document();
    final fonts = await PdfExportFonts.load();
    final font = fonts.regular;
    final fontBold = fonts.bold;

    final moodboardImages = <pw.MemoryImage>[];
    for (final path in data.moodboardImagePaths) {
      final file = File(path);
      if (await file.exists()) {
        moodboardImages.add(pw.MemoryImage(await file.readAsBytes()));
      }
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Text(
                  'IRIS DP',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 11,
                    color: PdfColors.grey,
                  ),
                ),
                pw.Spacer(),
                pw.Text(
                  'LOOK BIBLE',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 11,
                    color: PdfColors.grey,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 60),
            pw.Text(
              projectName,
              style: pw.TextStyle(font: fontBold, fontSize: 36),
            ),
            if (director != null && director.isNotEmpty)
              pw.Text(
                'Dir. $director',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 16,
                  color: PdfColors.grey700,
                ),
              ),
            pw.SizedBox(height: 48),
            if (data.visualConcept?.trim().isNotEmpty == true) ...[
              pw.Text(
                'CONCEPTO VISUAL',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 10,
                  color: PdfColors.grey,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                data.visualConcept!,
                style: pw.TextStyle(font: font, fontSize: 14, lineSpacing: 6),
              ),
              pw.SizedBox(height: 32),
            ],
            if (data.colorHexPalette.isNotEmpty) ...[
              pw.Text(
                'PALETA DE COLOR',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 10,
                  color: PdfColors.grey,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.colorHexPalette.map((hex) {
                  return pw.Container(
                    width: 60,
                    height: 60,
                    decoration: pw.BoxDecoration(
                      color: _hexToPdfColor(hex),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 32),
            ],
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (data.lutName?.trim().isNotEmpty == true)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'LUT',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            color: PdfColors.grey,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          data.lutName!,
                          style: pw.TextStyle(font: font, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                if (data.filmReferences.isNotEmpty)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'REFERENCIAS',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            color: PdfColors.grey,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        ...data.filmReferences.map(
                          (r) => pw.Text(
                            '· $r',
                            style: pw.TextStyle(font: font, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (data.contrastStyle?.trim().isNotEmpty == true) ...[
              pw.SizedBox(height: 24),
              pw.Text(
                'CONTRASTE',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 10,
                  color: PdfColors.grey,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                data.contrastStyle!,
                style: pw.TextStyle(font: font, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );

    if (moodboardImages.isNotEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'MOODBOARD',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 10,
                  color: PdfColors.grey,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: moodboardImages
                    .map(
                      (img) => pw.Image(
                        img,
                        width: 180,
                        height: 120,
                        fit: pw.BoxFit.cover,
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      );
    }

    final actBlocks = <({String title, String? body})>[
      (title: 'ACTO I', body: data.actOneNotes),
      (title: 'ACTO II', body: data.actTwoNotes),
      (title: 'ACTO III', body: data.actThreeNotes),
    ].where((b) => b.body?.trim().isNotEmpty == true).toList();

    if (data.lightingPhilosophy?.trim().isNotEmpty == true ||
        actBlocks.isNotEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (data.lightingPhilosophy?.trim().isNotEmpty == true) ...[
                pw.Text(
                  'FILOSOFÍA DE LUZ',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  data.lightingPhilosophy!,
                  style: pw.TextStyle(font: font, fontSize: 14, lineSpacing: 6),
                ),
                pw.SizedBox(height: 32),
              ],
              for (final block in actBlocks) ...[
                pw.Text(
                  block.title,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  block.body!,
                  style: pw.TextStyle(font: font, fontSize: 12, lineSpacing: 5),
                ),
                pw.SizedBox(height: 20),
              ],
            ],
          ),
        ),
      );
    }

    return doc;
  }

  static Future<List<int>> buildBytes({
    required String projectName,
    required String? director,
    required LookBibleData data,
  }) async {
    final doc = await build(
      projectName: projectName,
      director: director,
      data: data,
    );
    return doc.save();
  }

  static PdfColor _hexToPdfColor(String hex) {
    final clean = hex.replaceAll('#', '');
    final value = int.tryParse(clean, radix: 16) ?? 0xFFFFFF;
    final r = ((value >> 16) & 0xFF) / 255;
    final g = ((value >> 8) & 0xFF) / 255;
    final b = (value & 0xFF) / 255;
    return PdfColor(r, g, b);
  }

  static Future<String?> exportAndSave({
    required String projectName,
    required String? director,
    required LookBibleData data,
  }) {
    final slug = projectName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(' ', '_')
        .toLowerCase();
    return ExportFileSaver.saveGenerated(
      dialogTitle: 'Exportar Look Bible',
      fileName: 'look_bible_${slug.isEmpty ? 'proyecto' : slug}.pdf',
      extension: 'pdf',
      build: () async {
        final bytes = await buildBytes(
          projectName: projectName,
          director: director,
          data: data,
        );
        return Uint8List.fromList(bytes);
      },
    );
  }
}
