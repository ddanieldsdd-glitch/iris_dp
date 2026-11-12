import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/database/app_database.dart';
import '../../core/utils/pdf_export_fonts.dart';
import 'shoot_day_brief.dart';

/// Orden del día: una hoja por jornada para imprimir o mandar al equipo,
/// con la foto del sitio, cuándo y dónde (mapa, QR y enlaces), el tiempo
/// hora a hora, el sol y el horario con el storyboard de cada plano.
abstract final class ShootDayOrderPdf {
  /// Las jornadas [dayIds] (todas las del proyecto si está vacío), en el
  /// orden del plan.
  static Future<List<ShootDayBrief>> load(
    AppDatabase db,
    int projectId, {
    Set<int> dayIds = const {},
    bool thumbs = true,
    String? coverPath,
    String? fallbackCoverPath,
  }) => ShootDayBrief.load(
    db,
    projectId,
    dayIds: dayIds,
    thumbs: thumbs,
    coverPath: coverPath,
    fallbackCoverPath: fallbackCoverPath,
  );

  static Future<Uint8List> build(
    AppDatabase db,
    Project project, {
    Set<int> dayIds = const {},
    bool thumbs = true,
    String? coverPath,
    DateTime? now,
  }) async => compose(
    projectName: project.name,
    sheets: await load(
      db,
      project.id,
      dayIds: dayIds,
      thumbs: thumbs,
      coverPath: coverPath,
      fallbackCoverPath: project.coverImagePath,
    ),
    thumbs: thumbs,
    now: now,
  );

  /// Una hoja por jornada de [sheets] en [doc]: así otros documentos (la
  /// planta, el storyboard) pueden llevar el plan de rodaje delante.
  static void addSheets(
    pw.Document doc, {
    required pw.ThemeData theme,
    required String projectName,
    required List<ShootDayBrief> sheets,
    bool thumbs = true,
    pw.Widget Function(pw.Context context)? footer,

    /// Destino del índice en la primera hoja.
    String? anchor,
  }) {
    const small = pw.TextStyle(fontSize: 7.5, color: BriefPdf.soft);
    for (final sheet in sheets) {
      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 26),
          header: (context) => context.pageNumber == 1
              ? pw.SizedBox()
              : pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: BriefPdf.line, width: 0.6),
                    ),
                  ),
                  child: pw.Text(
                    '${projectName.toUpperCase()}  ·  ${sheet.dayName}  ·  '
                    '${sheet.date}',
                    style: small,
                  ),
                ),
          footer: footer == null
              ? null
              : (context) => pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6),
                  child: footer(context),
                ),
          build: (context) => [
            if (anchor != null && identical(sheet, sheets.first))
              pw.Anchor(name: anchor, child: pw.SizedBox()),
            BriefPdf.band(
              project: projectName,
              document: 'Orden del día',
              brief: sheet,
            ),
            pw.SizedBox(height: 14),
            BriefPdf.facts(sheet),
            pw.SizedBox(height: 10),
            BriefPdf.weather(sheet),
            if (sheet.note.isNotEmpty)
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 10),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: BriefPdf.ink, width: 0.8),
                ),
                child: pw.Text(
                  sheet.note,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            pw.SizedBox(height: 14),
            pw.Text(
              'HORARIO',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: BriefPdf.soft,
                letterSpacing: 1.4,
              ),
            ),
            pw.Divider(color: BriefPdf.ink, thickness: 1.2, height: 8),
            if (sheet.rows.isEmpty)
              pw.Text(
                'Esta jornada aún no tiene horario.',
                style: const pw.TextStyle(color: BriefPdf.soft),
              ),
            for (final row in sheet.rows)
              BriefPdf.row(row, thumbs: thumbs, thumbWidth: 96),
          ],
        ),
      );
    }
  }

  static Future<Uint8List> compose({
    required String projectName,
    required List<ShootDayBrief> sheets,
    bool thumbs = true,
    DateTime? now,
  }) async {
    final fonts = await PdfExportFonts.load();
    final theme = PdfExportFonts.theme(
      regular: fonts.regular,
      bold: fonts.bold,
    );
    final made = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${two(made.day)}/${two(made.month)}/${made.year} '
        '${two(made.hour)}:${two(made.minute)}';
    final doc = pw.Document(title: 'Orden del día · $projectName');
    const small = pw.TextStyle(fontSize: 7.5, color: BriefPdf.soft);

    addSheets(
      doc,
      theme: theme,
      projectName: projectName,
      sheets: sheets,
      thumbs: thumbs,
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$projectName · generado el $stamp', style: small),
          pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: small,
          ),
        ],
      ),
    );
    if (sheets.isEmpty) {
      doc.addPage(
        pw.Page(
          theme: theme,
          build: (_) => pw.Center(child: pw.Text('No hay jornadas.')),
        ),
      );
    }
    return doc.save();
  }
}
