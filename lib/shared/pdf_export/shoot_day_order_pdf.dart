import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/database/app_database.dart';
import '../../core/utils/pdf_export_fonts.dart';
import '../../features/shoot_documents/shoot_day_timeline.dart';
import '../../features/shoot_documents/shoot_plan.dart';
import '../../features/technical_script/technical_script_export.dart'
    show formatShootDate, shootDayWeather;
import '../rich_text/script_markup.dart';

/// Una fila del horario: una franja o una escena con sus planos.
class ShootDayOrderRow {
  final String time;
  final String title;
  final String detail;
  final bool scene;

  /// «1 · PMC de Ali · 10:15 – 10:50».
  final List<String> shots;

  const ShootDayOrderRow({
    required this.time,
    required this.title,
    this.detail = '',
    this.scene = false,
    this.shots = const [],
  });
}

/// La hoja de una jornada.
class ShootDayOrderSheet {
  final String name;

  /// «día 2 de 4».
  final String position;
  final String date;
  final String window;
  final String place;
  final String note;
  final List<String> weather;
  final List<ShootDayOrderRow> rows;

  const ShootDayOrderSheet({
    required this.name,
    required this.position,
    required this.date,
    this.window = '',
    this.place = '',
    this.note = '',
    this.weather = const [],
    this.rows = const [],
  });
}

/// Orden del día: una hoja por jornada con la cita, el lugar y el horario
/// entero, para imprimir o mandar al equipo.
abstract final class ShootDayOrderPdf {
  /// Las hojas de las jornadas [dayIds] (todas las del proyecto si está
  /// vacío), en el orden del plan.
  static Future<List<ShootDayOrderSheet>> load(
    AppDatabase db,
    int projectId, {
    Set<int> dayIds = const {},
  }) async {
    final days = sortShootDays(await db.getShootDocumentsForProject(projectId));
    final scenes = {
      for (final s in await db.watchScenesForProject(projectId).first) s.id: s,
    };
    final shots = {
      for (final s in await db.getShotsForProject(projectId)) s.id: s,
    };
    final sites = await db.watchSitesForProject(projectId).first;
    final siteById = {for (final s in sites) s.id: s};
    final siteByUid = {
      for (final s in sites)
        if (s.uid != null) s.uid!: s,
    };
    final sheets = <ShootDayOrderSheet>[];
    for (final (i, day) in days.indexed) {
      if (dayIds.isNotEmpty && !dayIds.contains(day.id)) continue;
      final blocks = await db.getBlocksForShootDocument(day.id);
      final site = siteById[day.locationSiteId];
      final rows = <ShootDayOrderRow>[];
      for (final entry in buildShootDayEntries(blocks, shots)) {
        switch (entry) {
          case ShootStripEntry(:final block, :final strip):
            rows.add(
              ShootDayOrderRow(
                time: shootTimeRange(strip.from, strip.to),
                title: ShootStrip.titleOf(block),
                detail: [
                  ?siteByUid[strip.siteUid]?.name,
                  if ((block.noteBody ?? '').trim().isNotEmpty)
                    block.noteBody!.trim(),
                ].join(' · '),
              ),
            );
          case ShootSceneEntry():
            final scene = scenes[entry.sceneId];
            final schedule = SceneSchedule.of(entry.blocks.first);
            rows.add(
              ShootDayOrderRow(
                scene: true,
                time: shootTimeRange(schedule.from, schedule.to),
                title: scene == null
                    ? 'Escena'
                    : 'Esc. ${scene.label} · ${scene.intExt}. '
                          '${scene.locationPureName} · ${scene.dayNight}',
                detail: schedule.note.trim(),
                shots: [
                  for (final b in entry.shotBlocks(shots))
                    _shotLine(shots[b.shotId]!, ShotTime.of(b)),
                ],
              ),
            );
        }
      }
      sheets.add(
        ShootDayOrderSheet(
          name: day.name,
          position: 'día ${i + 1} de ${days.length}',
          date: formatShootDate(day.shootDate),
          window: shootTimeRange(day.shootFromTime, day.shootToTime),
          place: site?.name ?? '',
          note: (day.description ?? '').trim(),
          weather: shootDayWeather(day, site).lines,
          rows: rows,
        ),
      );
    }
    return sheets;
  }

  static String _shotLine(Shot shot, ShotTime time) {
    final framing = scriptMarkupToPlain(shot.framing).trim();
    final range = shootTimeRange(time.from, time.to);
    return [
      '${shot.number}',
      if (framing.isNotEmpty) framing,
      if (time.note.trim().isNotEmpty) time.note.trim(),
      if (range.isNotEmpty) range,
    ].join(' · ');
  }

  static Future<Uint8List> build(
    AppDatabase db,
    Project project, {
    Set<int> dayIds = const {},
    DateTime? now,
  }) async => compose(
    projectName: project.name,
    sheets: await load(db, project.id, dayIds: dayIds),
    now: now,
  );

  static const _ink = PdfColor.fromInt(0xFF1A1A1A);
  static const _soft = PdfColor.fromInt(0xFF666666);
  static const _line = PdfColor.fromInt(0xFFCCCCCC);
  static const _band = PdfColor.fromInt(0xFFF1F1EE);

  static Future<Uint8List> compose({
    required String projectName,
    required List<ShootDayOrderSheet> sheets,
    DateTime? now,
  }) async {
    final fonts = await PdfExportFonts.load();
    final theme = PdfExportFonts.theme(
      regular: fonts.regular,
      bold: fonts.bold,
    );
    final made = now ?? DateTime.now();
    final stamp =
        '${made.day.toString().padLeft(2, '0')}/'
        '${made.month.toString().padLeft(2, '0')}/${made.year} '
        '${made.hour.toString().padLeft(2, '0')}:'
        '${made.minute.toString().padLeft(2, '0')}';
    final doc = pw.Document(title: 'Orden del día · $projectName');
    const small = pw.TextStyle(fontSize: 8, color: _soft);

    for (final sheet in sheets) {
      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
          header: (context) => context.pageNumber == 1
              ? _header(projectName, sheet)
              : pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    '${sheet.name} · ${sheet.date} (sigue)',
                    style: small,
                  ),
                ),
          footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('$projectName · generado el $stamp', style: small),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: small,
              ),
            ],
          ),
          build: (context) => [
            if (sheet.rows.isEmpty)
              pw.Text(
                'Esta jornada aún no tiene horario.',
                style: const pw.TextStyle(color: _soft),
              ),
            for (final row in sheet.rows) _row(row),
          ],
        ),
      );
    }
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

  static pw.Widget _header(String project, ShootDayOrderSheet sheet) {
    const label = pw.TextStyle(fontSize: 8, color: _soft);
    pw.Widget fact(String name, String value) => value.isEmpty
        ? pw.SizedBox()
        : pw.Padding(
            padding: const pw.EdgeInsets.only(right: 18, top: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(name.toUpperCase(), style: label),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1.2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'ORDEN DEL DÍA',
                style: const pw.TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.5,
                  color: _soft,
                ),
              ),
              pw.Text(project.toUpperCase(), style: label),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${sheet.name} · ${sheet.position}',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(sheet.date, style: const pw.TextStyle(fontSize: 12)),
          pw.Wrap(
            children: [
              fact('Horario', sheet.window),
              fact('Lugar', sheet.place),
            ],
          ),
          if (sheet.weather.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Text(
                sheet.weather.join(' · '),
                style: const pw.TextStyle(fontSize: 9, color: _soft),
              ),
            ),
          if (sheet.note.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Text(
                sheet.note,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _row(ShootDayOrderRow row) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      decoration: pw.BoxDecoration(
        color: row.scene ? null : _band,
        border: const pw.Border(
          bottom: pw.BorderSide(color: _line, width: 0.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 78,
            child: pw.Text(
              row.time.isEmpty ? '—' : row.time,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  row.title,
                  style: pw.TextStyle(
                    fontSize: row.scene ? 10.5 : 9.5,
                    fontWeight: row.scene
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                ),
                if (row.detail.isNotEmpty)
                  pw.Text(
                    row.detail,
                    style: const pw.TextStyle(fontSize: 8.5, color: _soft),
                  ),
                for (final shot in row.shots)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2, left: 8),
                    child: pw.Text(
                      shot,
                      style: const pw.TextStyle(fontSize: 8.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
