import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/database/app_database.dart';
import '../../core/utils/export_cancel.dart';
import '../../core/utils/pdf_export_fonts.dart';
import '../../core/utils/pdf_safe_image.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../features/camera_plan/plan_renderer.dart';
import '../../features/export_center/export_selection.dart';
import '../../features/technical_script/technical_script_export.dart'
    show formatShootDate;
import '../rich_text/script_markup.dart';
import '../technical_script_export/technical_script_doc.dart';

/// Un plano listo para pintar.
class ShootingPlanBlock {
  final String sceneLabel;
  final int shotNumber;
  final String slug;
  final String? exposure;
  final int? order;
  final List<String> alsoIn;
  final String? framing;
  final String? lens;
  final String? support;
  final String? angle;
  final String? stop;
  final String? action;
  final String? notes;
  final Uint8List? plan;

  /// El storyboard y todas las referencias del plano.
  final List<Uint8List> frames;

  const ShootingPlanBlock({
    required this.sceneLabel,
    required this.shotNumber,
    required this.slug,
    this.exposure,
    this.order,
    this.alsoIn = const [],
    this.framing,
    this.lens,
    this.support,
    this.angle,
    this.stop,
    this.action,
    this.notes,
    this.plan,
    this.frames = const [],
  });
}

/// Planta general de un set, para el cierre.
class ShootingPlanOverview {
  final String title;
  final String? scenes;
  final Uint8List? plan;

  const ShootingPlanOverview(this.title, {this.scenes, this.plan});
}

/// Un tramo del índice con sus planos.
class ShootingPlanEntry {
  final String label;
  final List<ShootingPlanBlock> blocks;

  const ShootingPlanEntry(this.label, this.blocks);
}

/// Una jornada del documento; sin [heading] si no sale de un plan de rodaje.
class ShootingPlanDay {
  final String? heading;

  /// «Orden de grabación · Esc 4, 5, 6, 7 y 8».
  final String order;
  final List<ShootingPlanEntry> entries;

  const ShootingPlanDay(this.order, this.entries, {this.heading});
}

/// Reparto en páginas, sin pintar nada: cada bloque ocupa media página, así
/// que el índice conoce sus números antes de dibujarse.
class ShootingPlanLayout {
  /// Líneas del índice en la portada y en las páginas que le siguen.
  static const firstIndexLines = 18;
  static const nextIndexLines = 29;
  static const blocksPerPage = 2;

  /// Bloques de cada página de planos, en orden.
  final List<List<ShootingPlanBlock>> pages;

  /// Jornada de cada página de planos.
  final List<ShootingPlanDay> pageDays;

  /// Primera página, numerada desde 1, de cada entrada del índice.
  final Map<ShootingPlanEntry, int> entryPages;
  final int indexPages;

  /// Primera página del cierre.
  final int overviewPage;

  ShootingPlanLayout._(
    this.pages,
    this.pageDays,
    this.entryPages,
    this.indexPages,
    this.overviewPage,
  );

  /// Líneas del índice: títulos de jornada, entradas y cierre.
  static int lineCount(List<ShootingPlanDay> days, {required bool overviews}) =>
      days.fold<int>(
        overviews ? 1 : 0,
        (n, d) => n + d.entries.length + (d.heading == null ? 0 : 1),
      );

  static int pagesForIndex(int lines) {
    if (lines <= firstIndexLines) return 1;
    final rest = lines - firstIndexLines;
    return 1 + (rest + nextIndexLines - 1) ~/ nextIndexLines;
  }

  factory ShootingPlanLayout.of(
    List<ShootingPlanDay> days, {
    required bool overviews,
  }) {
    final indexPages = pagesForIndex(lineCount(days, overviews: overviews));
    final pages = <List<ShootingPlanBlock>>[];
    final pageDays = <ShootingPlanDay>[];
    final entryPages = <ShootingPlanEntry, int>{};
    for (final day in days) {
      var room = 0;
      for (final entry in day.entries) {
        if (entry.blocks.isEmpty) continue;
        for (final (i, block) in entry.blocks.indexed) {
          if (room == 0) {
            pages.add([]);
            pageDays.add(day);
            room = blocksPerPage;
          }
          pages.last.add(block);
          room--;
          if (i == 0) entryPages[entry] = indexPages + pages.length;
        }
      }
    }
    return ShootingPlanLayout._(
      pages,
      pageDays,
      entryPages,
      indexPages,
      indexPages + pages.length + 1,
    );
  }
}

/// Planta de cámara y luz de rodaje: portada con índice enlazado y un bloque
/// por plano, con la estética negra del SHOT PLAN.
class ShootingPlanPdf {
  static const _margin = 24.0;
  static const _barHeight = 30.0;
  static const _gap = 10.0;
  static const _footer = 14.0;
  static const _format = PdfPageFormat(841.89, 595.28);
  static const _planWidth = 420.0;

  /// Espacio útil de una página apaisada con su barra.
  static double get _bodyHeight =>
      _format.height - _margin * 2 - _barHeight - _gap - _footer;
  static double get _bodyWidth => _format.width - _margin * 2;
  static double get _blockHeight => (_bodyHeight - _gap) / 2;

  /// Página real en la que se pintó cada entrada, para los tests.
  @visibleForTesting
  static Map<String, int>? debugEntryPages;

  /// Prepara lo exportado y compone el PDF.
  static Future<Uint8List> build({
    required AppDatabase db,
    required Project project,
    required List<ExportDaySection> sections,
    bool withLight = true,
    bool withBeams = true,
    bool withOverviews = true,
    String? coverImagePath,
    String? planBackdropPath,
  }) async {
    final renderer = await PlanRenderer.load(db, project.id);
    final days = <ShootingPlanDay>[];
    for (final section in sections) {
      final entries = <ShootingPlanEntry>[];
      for (final tract in section.scenes) {
        if (tract.shots.isEmpty) continue;
        entries.add(
          ShootingPlanEntry(
            scriptIndexLabel(
              sceneLabel: tract.scene.label,
              intExt: tract.scene.intExt,
              location: tract.scene.locationPureName,
              dayNight: tract.scene.dayNight,
              shots: [for (final s in tract.shots) '${s.shot.number}'],
            ),
            await ExportCancel.mapPooled(
              tract.shots,
              (item) => _block(
                db,
                renderer,
                tract.scene,
                item,
                withLight,
                withBeams,
                planBackdropPath,
              ),
            ),
          ),
        );
      }
      if (entries.isEmpty) continue;
      final day = section.day;
      days.add(
        ShootingPlanDay(
          orderLine(section),
          entries,
          heading: day == null
              ? null
              : [
                  day.name,
                  if (day.shootDate != null) formatShootDate(day.shootDate),
                ].join(' · '),
        ),
      );
    }
    return compose(
      projectName: project.name,
      days: days,
      overviews: withOverviews
          ? await _overviews(
              renderer,
              sections,
              withLight,
              withBeams,
              planBackdropPath,
            )
          : const [],
      withLight: withLight,
      coverImage: await PdfSafeImage.loadFromPathMaxEdge(
        coverImagePath,
        maxEdge: 1800,
      ),
    );
  }

  /// «Orden de grabación · Esc 4, 5, 6, 7 y 8». Una escena repartida en dos
  /// tramos seguidos sale una vez.
  static String orderLine(ExportDaySection section) {
    final labels = <String>[];
    for (final tract in section.scenes) {
      if (tract.shots.isEmpty) continue;
      if (labels.isEmpty || labels.last != tract.scene.label) {
        labels.add(tract.scene.label);
      }
    }
    final head = labels.length < 2
        ? labels.join()
        : '${labels.sublist(0, labels.length - 1).join(', ')} y ${labels.last}';
    return 'Orden de grabación · Esc $head';
  }

  /// Sin marcas de formato. Los saltos sueltos del guion son del ancho de su
  /// columna: aquí se quitan y solo quedan los de párrafo.
  static String? _plain(String? raw) {
    final text = scriptMarkupToPlain(
      raw,
    ).trim().replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ');
    return text.isEmpty ? null : text;
  }

  /// «180°/24fps», con lo que tenga el plano.
  static String? _exposure(Shot shot) {
    final shutter = shot.shutterAngle?.trim() ?? '';
    final parts = [
      if (shutter.isNotEmpty) shutter.endsWith('°') ? shutter : '$shutter°',
      if (shot.fps != null) '${shot.fps}fps',
    ];
    return parts.isEmpty ? null : parts.join('/');
  }

  /// Las imágenes del plano: primero su storyboard y luego todas sus
  /// referencias, sin repetir.
  static Future<List<Uint8List>> _frames(AppDatabase db, Shot shot) async {
    final paths = <String>{
      ?shot.storyboardImagePath,
      ...referenceImagesOf(shot, await db.getReferencesForShot(shot.id)),
    };
    if (paths.isEmpty) {
      final fallback = referenceImageOf(shot);
      if (fallback != null) paths.add(fallback);
    }
    final images = await Future.wait([
      for (final path in paths)
        PdfSafeImage.loadFromPathMaxEdge(
          path,
          maxEdge: paths.length == 1 ? 900 : 640,
        ),
    ]);
    return images.nonNulls.toList();
  }

  static Future<ShootingPlanBlock> _block(
    AppDatabase db,
    PlanRenderer renderer,
    Scene scene,
    ExportShot item,
    bool withLight,
    bool withBeams,
    String? backdrop,
  ) async {
    final shot = item.shot;
    final slug = [
      scene.intExt.trim(),
      scene.locationPureName.trim(),
      scene.dayNight.trim(),
    ].where((s) => s.isNotEmpty).join(' ');
    return ShootingPlanBlock(
      sceneLabel: scene.label,
      shotNumber: shot.number,
      slug: slug.isEmpty ? scene.locationCanonical : slug,
      exposure: _exposure(shot),
      order: item.order,
      alsoIn: item.alsoIn,
      framing: _plain(shot.framing),
      lens: _plain(shot.lens),
      support: _plain(shot.movement),
      angle: _plain(shot.angle),
      stop: _plain(shot.fStop),
      action: _plain(shot.action),
      notes: _plain(shot.notes),
      plan: await renderer.shot(
        shot,
        light: withLight,
        beams: withBeams,
        size: Size(_planWidth, _blockHeight),
        pixelRatio: 4,
        backdrop: backdrop,
      ),
      frames: await _frames(db, shot),
    );
  }

  /// La planta general de cada esquema de luz exportado, una vez.
  static Future<List<ShootingPlanOverview>> _overviews(
    PlanRenderer renderer,
    List<ExportDaySection> sections,
    bool withLight,
    bool withBeams,
    String? backdrop,
  ) async {
    final data = renderer.data;
    final scenesOf = <int, List<String>>{};
    for (final section in sections) {
      for (final tract in section.scenes) {
        for (final item in tract.shots) {
          final id = data.setup(item.shot.lightSetupId)?.id;
          if (id == null) continue;
          final labels = scenesOf.putIfAbsent(id, () => []);
          if (!labels.contains(tract.scene.label)) {
            labels.add(tract.scene.label);
          }
        }
      }
    }
    return [
      for (final entry in scenesOf.entries)
        if (data.setup(entry.key) case final setup?)
          ShootingPlanOverview(
            [
              if (data.set(setup.locationBasePlanId) case final set?)
                set.locationName,
              setup.name,
            ].join(' · '),
            scenes: 'Esc ${entry.value.join(', ')}',
            plan: await renderer.setup(
              setup,
              light: withLight,
              beams: withBeams,
              size: Size(_bodyWidth, _bodyHeight - 22),
              pixelRatio: 3,
              backdrop: backdrop,
            ),
          ),
    ];
  }

  /// Compone el PDF con todo ya preparado.
  static Future<Uint8List> compose({
    required String projectName,
    required List<ShootingPlanDay> days,
    List<ShootingPlanOverview> overviews = const [],
    bool withLight = true,
    Uint8List? coverImage,
  }) async {
    final fonts = await PdfExportFonts.load();
    final theme = PdfExportFonts.theme(
      regular: fonts.regular,
      bold: fonts.bold,
    );
    final documentTitle = withLight
        ? 'PLANTA DE CÁMARA Y LUZ'
        : 'PLANTA DE CÁMARA';
    final layout = ShootingPlanLayout.of(days, overviews: overviews.isNotEmpty);
    final doc = pw.Document(title: '$documentTitle · $projectName');

    // Índice: portada y las páginas que necesite.
    final lines = <pw.Widget>[];
    var entryIndex = 0;
    final anchors = <ShootingPlanEntry, String>{};
    for (final day in days) {
      if (day.heading != null) lines.add(_indexDay(day.heading!));
      for (final entry in day.entries) {
        final name = 'entrada_${entryIndex++}';
        anchors[entry] = name;
        lines.add(_indexLine(entry.label, layout.entryPages[entry], name));
      }
    }
    if (overviews.isNotEmpty) {
      lines.add(
        _indexLine('PLANTAS DE ESCENAS', layout.overviewPage, 'plantas'),
      );
    }

    final subtitle = days.length == 1 ? days.single.heading : null;
    doc.addPage(
      pw.Page(
        theme: theme,
        pageFormat: _format,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _coverBand(
              coverImage,
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    documentTitle,
                    style: pw.TextStyle(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: PdfColors.grey400,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    projectName.toUpperCase(),
                    maxLines: 1,
                    style: pw.TextStyle(
                      fontSize: 30,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      subtitle,
                      maxLines: 1,
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(36, 16, 36, 0),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  for (final day in days.take(2))
                    pw.Text(
                      day.heading == null || days.length == 1
                          ? day.order
                          : '${day.heading} · ${day.order}',
                      maxLines: 1,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  pw.SizedBox(height: 12),
                  pw.Text('ÍNDICE', style: const pw.TextStyle(fontSize: 16)),
                  pw.SizedBox(height: 6),
                  ...lines.take(ShootingPlanLayout.firstIndexLines),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    for (
      var start = ShootingPlanLayout.firstIndexLines;
      start < lines.length;
      start += ShootingPlanLayout.nextIndexLines
    ) {
      final part = lines
          .skip(start)
          .take(ShootingPlanLayout.nextIndexLines)
          .toList();
      doc.addPage(
        pw.Page(
          theme: theme,
          pageFormat: _format,
          margin: const pw.EdgeInsets.all(_margin),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _bar(projectName, null, documentTitle),
              pw.SizedBox(height: _gap),
              ...part,
            ],
          ),
        ),
      );
    }

    // Planos: dos por página.
    final firstOf = {
      for (final day in days)
        for (final entry in day.entries)
          if (entry.blocks.isNotEmpty) entry.blocks.first: entry,
    };
    for (final (i, page) in layout.pages.indexed) {
      final day = layout.pageDays[i];
      final pageNumber = layout.indexPages + i + 1;
      doc.addPage(
        pw.Page(
          theme: theme,
          pageFormat: _format,
          margin: const pw.EdgeInsets.all(_margin),
          build: (context) => _sheet(
            projectName,
            day.heading,
            documentTitle,
            pageNumber,
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                for (final (b, block) in page.indexed) ...[
                  if (b > 0) pw.SizedBox(height: _gap),
                  _marked(context, firstOf[block], anchors, _blockView(block)),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Cierre: la planta general de cada set.
    for (final (i, overview) in overviews.indexed) {
      final pageNumber = layout.overviewPage + i;
      doc.addPage(
        pw.Page(
          theme: theme,
          pageFormat: _format,
          margin: const pw.EdgeInsets.all(_margin),
          build: (context) => _sheet(
            projectName,
            'Plantas de escenas',
            documentTitle,
            pageNumber,
            _overviewView(overview, anchored: i == 0),
          ),
        ),
      );
    }

    if (days.isEmpty) {
      doc.addPage(
        pw.Page(
          theme: theme,
          pageFormat: _format,
          build: (_) => pw.Text('Sin planos para exportar.'),
        ),
      );
    }
    return doc.save();
  }

  /// La banda de la portada: negra o con la imagen elegida, oscurecida para
  /// que el título se lea.
  static pw.Widget _coverBand(Uint8List? image, pw.Widget title) {
    const height = 170.0;
    final content = pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(36, 30, 36, 24),
      child: title,
    );
    if (image == null) {
      return pw.Container(
        height: height,
        color: PdfColors.black,
        child: content,
      );
    }
    return pw.SizedBox(
      height: height,
      child: pw.ClipRect(
        child: pw.Stack(
          fit: pw.StackFit.expand,
          children: [
            pw.Image(pw.MemoryImage(image), fit: pw.BoxFit.cover),
            pw.Opacity(
              opacity: 0.5,
              child: pw.Container(color: PdfColors.black),
            ),
            content,
          ],
        ),
      ),
    );
  }

  /// Destino de la línea del índice, si el bloque abre una entrada.
  static pw.Widget _marked(
    pw.Context context,
    ShootingPlanEntry? entry,
    Map<ShootingPlanEntry, String> anchors,
    pw.Widget child,
  ) {
    if (entry == null) return child;
    debugEntryPages?[entry.label] = context.pageNumber;
    return pw.Anchor(name: anchors[entry]!, child: child);
  }

  static pw.Widget _indexDay(String heading) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 5, bottom: 1),
    child: pw.Text(
      heading,
      maxLines: 1,
      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
    ),
  );

  static pw.Widget _indexLine(String label, int? page, String anchor) {
    final style = pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold);
    return pw.Link(
      destination: anchor,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(label, style: style, maxLines: 1),
            pw.Expanded(
              child: pw.Container(
                height: 1,
                margin: const pw.EdgeInsets.only(
                  left: 3,
                  right: 3,
                  bottom: 2.5,
                ),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(
                      width: 0.8,
                      style: pw.BorderStyle.dotted,
                    ),
                  ),
                ),
              ),
            ),
            pw.SizedBox(
              width: 22,
              child: pw.Text(
                '${page ?? ''}',
                textAlign: pw.TextAlign.right,
                style: style,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _bar(String project, String? day, String title) =>
      pw.Container(
        height: _barHeight,
        color: PdfColors.black,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                day == null ? project : '$project  ·  $day',
                maxLines: 1,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey300),
            ),
          ],
        ),
      );

  static pw.Widget _sheet(
    String project,
    String? day,
    String title,
    int pageNumber,
    pw.Widget body,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      _bar(project, day, title),
      pw.SizedBox(height: _gap),
      pw.SizedBox(height: _bodyHeight, child: body),
      pw.SizedBox(
        height: _footer,
        child: pw.Align(
          alignment: pw.Alignment.bottomRight,
          child: pw.Text(
            '$pageNumber',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
      ),
    ],
  );

  static pw.Widget _blockView(ShootingPlanBlock block) {
    final title = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
    final rightWidth = _bodyWidth - _planWidth - 12;
    final frameWidth = rightWidth * (block.frames.length > 2 ? 0.6 : 0.46);
    final text = [
      if (block.action != null) block.action!,
      if (block.notes != null) block.notes!,
    ].join('\n\n');
    return pw.SizedBox(
      height: _blockHeight,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            width: _planWidth,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            ),
            child: block.plan == null
                ? pw.Text(
                    'Sin planta',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  )
                : pw.Image(pw.MemoryImage(block.plan!), fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        'ESC ${block.sceneLabel} · PLANO ${block.shotNumber}',
                        maxLines: 1,
                        style: title,
                      ),
                    ),
                    if (block.exposure != null)
                      pw.Text(block.exposure!, style: title),
                  ],
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  [
                    if (block.order != null) 'Orden ${block.order}',
                    block.slug,
                  ].join('  ·  '),
                  maxLines: 1,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                if (block.alsoIn.isNotEmpty)
                  pw.Text(
                    'Se repite: también en ${block.alsoIn.join(', ')}',
                    maxLines: 1,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                pw.SizedBox(height: 6),
                _table(block),
                pw.SizedBox(height: 6),
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                              color: PdfColors.grey400,
                              width: 0.5,
                            ),
                          ),
                          child: pw.Text(
                            text,
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                        ),
                      ),
                      if (block.frames.isNotEmpty) ...[
                        pw.SizedBox(width: 6),
                        pw.Container(
                          width: frameWidth,
                          color: PdfColors.black,
                          child: _frameGrid(block.frames),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Las imágenes del plano en una rejilla que llena su casilla.
  static pw.Widget _frameGrid(List<Uint8List> frames) {
    final columns = frameGridColumns(frames.length);
    final rows = <List<Uint8List>>[
      for (var i = 0; i < frames.length; i += columns)
        frames.sublist(i, math.min(i + columns, frames.length)),
    ];
    pw.Widget cell(Uint8List? frame) => pw.Expanded(
      child: frame == null
          ? pw.SizedBox()
          : pw.Container(
              margin: const pw.EdgeInsets.all(0.75),
              alignment: pw.Alignment.center,
              child: pw.Image(pw.MemoryImage(frame), fit: pw.BoxFit.contain),
            ),
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < columns; i++)
                  cell(i < row.length ? row[i] : null),
              ],
            ),
          ),
      ],
    );
  }

  /// Columnas de la rejilla para [count] imágenes.
  @visibleForTesting
  static int frameGridColumns(int count) => switch (count) {
    <= 2 => 1,
    <= 6 => 2,
    _ => 3,
  };

  static pw.Widget _table(ShootingPlanBlock block) {
    final columns = <(String, String?)>[
      ('ENCUADRE', block.framing),
      ('LENTE', block.lens),
      ('SOPORTE / MOV.', block.support),
      ('ANGULACIÓN', block.angle),
      ('DIAFRAGMA', block.stop),
    ];
    pw.Widget cell(String text, {bool head = false}) => pw.Container(
      color: head ? PdfColors.black : null,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        maxLines: 2,
        style: pw.TextStyle(
          fontSize: head ? 6.5 : 8.5,
          color: head ? PdfColors.white : PdfColors.black,
          fontWeight: head ? pw.FontWeight.bold : null,
        ),
      ),
    );
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        pw.TableRow(
          children: [for (final c in columns) cell(c.$1, head: true)],
        ),
        pw.TableRow(children: [for (final c in columns) cell(c.$2 ?? '—')]),
      ],
    );
  }

  static pw.Widget _overviewView(
    ShootingPlanOverview overview, {
    required bool anchored,
  }) {
    final heading = pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            overview.title,
            maxLines: 1,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        ),
        if (overview.scenes != null)
          pw.Text(overview.scenes!, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        anchored ? pw.Anchor(name: 'plantas', child: heading) : heading,
        pw.SizedBox(height: 6),
        pw.Expanded(
          child: pw.Container(
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            ),
            child: overview.plan == null
                ? pw.Text(
                    'Sin planta',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  )
                : pw.Image(
                    pw.MemoryImage(overview.plan!),
                    fit: pw.BoxFit.contain,
                  ),
          ),
        ),
      ],
    );
  }
}
