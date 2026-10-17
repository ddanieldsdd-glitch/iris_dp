import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/pdf_export_fonts.dart';
import '../../core/weather/sun_calculator.dart';
import 'shot_sheet_data.dart';
import 'storyboard_export_style.dart';

/// Hoja de un plano en PDF, en los cuatro niveles de Artemis:
/// CLEAN (la imagen sola), BASIC (líneas de encuadre y abanico de focal),
/// DETAIL (barra de cámara, paleta y franja de datos) y SHOT PLAN (página
/// entera con guion técnico, planta de luz y cámara y sol).
class StoryboardShotSheetPdf {
  StoryboardShotSheetPdf._();

  static const _orange = PdfColor.fromInt(0xFFF5A300);
  static const _fanGrey = PdfColor.fromInt(0xFFA8A8A8);
  static const _teal = PdfColor.fromInt(0xFF4FC8C8);
  static const _night = PdfColor.fromInt(0xFF0B1424);

  /// Ancho de las páginas de imagen (CLEAN, BASIC, DETAIL): un A4 apaisado.
  static const _imagePageWidth = 842.0;

  static Future<Uint8List> buildBytes(
    ShotSheetData data,
    StoryboardExportStyle style,
  ) async {
    final doc = pw.Document();
    await addPage(doc, data, style);
    return doc.save();
  }

  /// Añade la hoja de [data] a [doc] (para exportar varios planos en un PDF).
  static Future<void> addPage(
    pw.Document doc,
    ShotSheetData data,
    StoryboardExportStyle style,
  ) async {
    final fonts = await PdfExportFonts.load();
    final theme = PdfExportFonts.theme(
      regular: fonts.regular,
      bold: fonts.bold,
    );
    doc.addPage(switch (style) {
      StoryboardExportStyle.clean => _imagePage(data, theme, basic: false),
      StoryboardExportStyle.basic => _imagePage(data, theme, basic: true),
      StoryboardExportStyle.detail => _detailPage(data, theme),
      StoryboardExportStyle.shotPlan => _shotPlanPage(data, theme),
    });
  }

  // ---------------------------------------------------------------------
  // CLEAN / BASIC
  // ---------------------------------------------------------------------

  /// Proporción de la imagen (ancho / alto); 16:9 si no hay imagen.
  static double _imageAspect(ShotSheetData data) {
    final bytes = data.imageBytes;
    if (bytes == null) return 16 / 9;
    try {
      final image = pw.MemoryImage(bytes);
      final w = image.width;
      final h = image.height;
      if (w != null && h != null && w > 0 && h > 0) return w / h;
    } catch (_) {}
    return 16 / 9;
  }

  static pw.Page _imagePage(
    ShotSheetData data,
    pw.ThemeData theme, {
    required bool basic,
  }) {
    const w = _imagePageWidth;
    final h = w / _imageAspect(data);
    return pw.Page(
      theme: theme,
      pageFormat: PdfPageFormat(w, h),
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(
        children: [
          _image(data, w, h),
          if (basic) _framelines(w, h, data.framelineAspect),
          if (basic)
            pw.Positioned(
              right: w * 0.012,
              bottom: w * 0.012,
              child: _lensBadge(data, width: w * 0.09),
            ),
        ],
      ),
    );
  }

  static pw.Widget _image(
    ShotSheetData data,
    double w,
    double h, {
    pw.BoxFit fit = pw.BoxFit.fill,
  }) {
    final bytes = data.imageBytes;
    if (bytes == null) {
      return pw.Container(
        width: w,
        height: h,
        color: PdfColors.grey800,
        alignment: pw.Alignment.center,
        child: pw.Text(
          'Plano ${data.shotNumber} sin imagen',
          style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 14),
        ),
      );
    }
    return pw.Image(pw.MemoryImage(bytes), width: w, height: h, fit: fit);
  }

  /// Líneas de encuadre: el formato de rodaje dentro de la imagen, con lo
  /// que queda fuera ligeramente velado.
  static pw.Widget _framelines(double w, double h, double aspect) {
    var fw = w * 0.94;
    var fh = fw / aspect;
    if (fh > h * 0.94) {
      fh = h * 0.94;
      fw = fh * aspect;
    }
    final left = (w - fw) / 2;
    final bottom = (h - fh) / 2;
    return pw.Positioned(
      left: 0,
      top: 0,
      child: pw.CustomPaint(
        size: PdfPoint(w, h),
        painter: (canvas, size) {
          // Velo fuera del encuadre (par-impar: deja el hueco limpio).
          canvas
            ..saveContext()
            ..setGraphicState(const PdfGraphicState(opacity: 0.3))
            ..setFillColor(PdfColors.black)
            ..drawRect(0, 0, w, h)
            ..drawRect(left, bottom, fw, fh)
            ..fillPath(evenOdd: true)
            ..restoreContext()
            ..setStrokeColor(PdfColors.white)
            ..setLineWidth(1)
            ..drawRect(left, bottom, fw, fh)
            ..strokePath();
        },
      ),
    );
  }

  /// Abanico de focal y ángulo de visión con «24mm : 61°» debajo, sobre
  /// fondo oscuro (BASIC).
  static pw.Widget _lensBadge(ShotSheetData data, {required double width}) {
    return pw.Container(
      width: width,
      padding: pw.EdgeInsets.fromLTRB(4, width * 0.1, 4, 3),
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF141414),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          _fan(data.fovDegrees, width: width * 0.7),
          pw.SizedBox(height: 3),
          pw.Text(
            data.lensFovLabel,
            style: pw.TextStyle(color: _orange, fontSize: width * 0.14),
          ),
        ],
      ),
    );
  }

  /// Semicírculo gris con la cuña naranja del ángulo de visión.
  static pw.Widget _fan(int fovDegrees, {required double width}) {
    return pw.CustomPaint(
      size: PdfPoint(width, width / 2),
      painter: (canvas, size) {
        final cx = size.x / 2;
        final r = size.y;
        void sector(double from, double to) {
          canvas.moveTo(cx, 0);
          const steps = 48;
          for (var i = 0; i <= steps; i++) {
            final a = from + (to - from) * i / steps;
            canvas.lineTo(cx + r * math.cos(a), r * math.sin(a));
          }
          canvas.closePath();
        }

        canvas.setFillColor(_fanGrey);
        sector(0, math.pi);
        canvas.fillPath();
        final half = (fovDegrees.clamp(4, 176) / 2) * math.pi / 180;
        canvas.setFillColor(_orange);
        sector(math.pi / 2 - half, math.pi / 2 + half);
        canvas.fillPath();
      },
    );
  }

  // ---------------------------------------------------------------------
  // DETAIL
  // ---------------------------------------------------------------------

  static pw.Page _detailPage(ShotSheetData data, pw.ThemeData theme) {
    const w = _imagePageWidth;
    final imageH = w / _imageAspect(data);
    const barH = 22.0;
    const footerH = 112.0;
    final mono = pw.Font.courier();
    final monoBold = pw.Font.courierBold();
    const white = pw.TextStyle(color: PdfColors.white, fontSize: 9);

    return pw.Page(
      theme: theme,
      pageFormat: PdfPageFormat(w, barH + imageH + footerH),
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: barH,
            color: PdfColors.black,
            padding: const pw.EdgeInsets.symmetric(horizontal: 9),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(data.cameraLabel ?? '', style: white),
                ),
                pw.Text(_orientationLine(data), style: white),
                pw.Expanded(
                  child: pw.Text(
                    data.lensSeriesLabel ?? '',
                    style: white,
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(
            height: imageH,
            child: pw.Stack(
              children: [
                _image(data, w, imageH),
                pw.Positioned(
                  right: 0,
                  bottom: 0,
                  child: _paletteStrip(data, swatch: 13),
                ),
              ],
            ),
          ),
          pw.Container(
            height: footerH,
            color: PdfColors.white,
            padding: const pw.EdgeInsets.fromLTRB(9, 8, 9, 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: w * 0.42,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _latin1(data.projectName),
                        style: pw.TextStyle(font: monoBold, fontSize: 12),
                      ),
                      pw.SizedBox(height: 3),
                      _sceneLine(data, mono, monoBold, 9, PdfColors.black),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        _latin1(data.sceneSlug),
                        style: pw.TextStyle(font: mono, fontSize: 9),
                      ),
                      if (data.placeDescription != null) ...[
                        pw.SizedBox(height: 5),
                        pw.Text(
                          data.placeDescription!,
                          style: const pw.TextStyle(fontSize: 8.5),
                          maxLines: 2,
                        ),
                      ],
                      pw.Spacer(),
                      pw.Text(
                        'Shot ${data.shotIndex} of ${data.totalShots}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(
                  width: w * 0.16,
                  child: pw.Column(
                    children: [
                      pw.Text(
                        '${data.fovDegrees}°',
                        style: const pw.TextStyle(fontSize: 15),
                      ),
                      pw.SizedBox(height: 2),
                      _fan(data.fovDegrees, width: 58),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        '${data.focalMm}mm',
                        style: const pw.TextStyle(fontSize: 19),
                      ),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Expanded(child: _notesBox(data, fontSize: 8)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _takenLine(data),
                        style: const pw.TextStyle(fontSize: 7.5),
                        textAlign: pw.TextAlign.right,
                      ),
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

  /// «Sc. 2 TÍTULO DE LA ESCENA», en máquina de escribir.
  static pw.Widget _sceneLine(
    ShotSheetData data,
    pw.Font mono,
    pw.Font monoBold,
    double size,
    PdfColor color,
  ) => pw.RichText(
    text: pw.TextSpan(
      style: pw.TextStyle(font: mono, fontSize: size, color: color),
      children: [
        pw.TextSpan(
          text: 'Sc. ${data.sceneNumber} ',
          style: pw.TextStyle(font: monoBold),
        ),
        pw.TextSpan(text: _latin1(data.sceneTitle.toUpperCase())),
      ],
    ),
  );

  /// «Picado · Steadicam»: la angulación y el movimiento del guion técnico.
  /// La app no mide inclinación ni rumbo, así que no se inventan grados.
  static String _orientationLine(ShotSheetData data) =>
      [data.angle, data.movement].whereType<String>().join(' · ');

  static String _takenLine(ShotSheetData data) {
    final at = data.capturedAt;
    return at == null ? '' : 'Taken on: ${_formatDateTime(at)}';
  }

  static pw.Widget _paletteStrip(ShotSheetData data, {required double swatch}) {
    if (data.palette.isEmpty) return pw.SizedBox();
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        for (final argb in data.palette)
          pw.Container(
            width: swatch * 1.6,
            height: swatch,
            color: PdfColor.fromInt(argb),
          ),
      ],
    );
  }

  static pw.Widget _notesBox(ShotSheetData data, {required double fontSize}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Notes:',
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Expanded(
            child: pw.Text(
              data.notes ?? '',
              style: pw.TextStyle(fontSize: fontSize),
              overflow: pw.TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // SHOT PLAN
  // ---------------------------------------------------------------------

  static pw.Page _shotPlanPage(ShotSheetData data, pw.ThemeData theme) {
    final mono = pw.Font.courier();
    final monoBold = pw.Font.courierBold();
    const white = pw.TextStyle(color: PdfColors.white, fontSize: 8.5);
    const small = pw.TextStyle(fontSize: 8);

    return pw.Page(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (context) {
        const margin = pw.EdgeInsets.fromLTRB(26, 24, 26, 22);
        final width = context.page.pageFormat.width - margin.horizontal;
        final imageH = math.min(width / _imageAspect(data), 300.0);
        return pw.Container(
          color: PdfColors.white,
          padding: margin,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Cabecera negra: proyecto, escena y plano.
              pw.Container(
                color: PdfColors.black,
                padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            _latin1(data.projectName),
                            style: pw.TextStyle(
                              font: monoBold,
                              fontSize: 10,
                              color: PdfColors.white,
                            ),
                          ),
                          _sceneLine(
                            data,
                            mono,
                            monoBold,
                            8.5,
                            PdfColors.white,
                          ),
                          pw.Text(
                            _latin1(data.sceneSlug),
                            style: pw.TextStyle(
                              font: mono,
                              fontSize: 8.5,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Shot ${data.shotIndex} of ${data.totalShots}',
                          style: white.copyWith(fontWeight: pw.FontWeight.bold),
                        ),
                        if (data.placeDescription != null)
                          pw.SizedBox(
                            width: width * 0.4,
                            child: pw.Text(
                              data.placeDescription!,
                              style: white,
                              textAlign: pw.TextAlign.right,
                              maxLines: 2,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(data.cameraLabel ?? '', style: small),
                  ),
                  pw.Text(_orientationLine(data), style: small),
                  pw.Expanded(
                    child: pw.Text(
                      data.lensSeriesLabel ?? '',
                      style: small,
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Container(
                height: imageH,
                color: PdfColors.black,
                alignment: pw.Alignment.center,
                child: _image(data, width, imageH, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: _paletteStrip(data, swatch: 9),
                    ),
                  ),
                  _fan(data.fovDegrees, width: 30),
                  pw.SizedBox(width: 6),
                  pw.Text(
                    '${data.focalMm}mm / ${data.fovDegrees}°',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      _takenLine(data),
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.grey700,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          _technicalTable(data),
                          pw.SizedBox(height: 8),
                          pw.Expanded(child: _notesBox(data, fontSize: 8.5)),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Expanded(child: _planBox(data)),
                          pw.SizedBox(height: 8),
                          _sunBox(data, width: (width - 10) / 2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static pw.Widget _sectionTitle(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Text(
      text.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.grey700,
        letterSpacing: 0.6,
      ),
      maxLines: 1,
    ),
  );

  /// Encuadre, lente, angulación, movimiento y acción del guion técnico.
  static pw.Widget _technicalTable(ShotSheetData data) {
    final rows = <(String, String?)>[
      ('Encuadre', data.framing),
      ('Lente', data.lens),
      ('Angulación', data.angle),
      ('Movimiento', data.movement),
      if (data.stop != null) ('Diafragma', data.stop),
      ('Acción', data.action),
    ];
    const cell = pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Guion técnico · Plano ${data.shotNumber}'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(62),
            1: pw.FlexColumnWidth(),
          },
          children: [
            for (final (label, value) in rows)
              pw.TableRow(
                children: [
                  pw.Container(
                    color: PdfColors.grey100,
                    padding: cell,
                    child: pw.Text(
                      label,
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: cell,
                    child: pw.Text(
                      value ?? '—',
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        color: value == null ? PdfColors.grey500 : null,
                      ),
                      maxLines: label == 'Acción' ? 6 : 2,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  static pw.BoxDecoration _placeholderBorder() => pw.BoxDecoration(
    border: pw.Border.all(
      color: PdfColors.grey400,
      width: 0.6,
      style: pw.BorderStyle.dashed,
    ),
  );

  /// Planta de luz y cámara del plano, o el hueco para ella.
  static pw.Widget _planBox(ShotSheetData data) {
    final png = data.planPng;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Planta de luz y cámara'),
        pw.Expanded(
          child: pw.Container(
            decoration: png == null
                ? _placeholderBorder()
                : pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
                  ),
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.center,
            child: png != null
                ? pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain)
                : pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      data.hasPlanPlace
                          ? 'La planta de este plano aún está vacía.'
                          : 'Sin planta: elige el set del plano o de su '
                                'escena para dibujarla.',
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: PdfColors.grey500,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// Recorrido del sol visto desde arriba (norte arriba), salida, mediodía
  /// y puesta, y la curva de altura del día.
  static pw.Widget _sunBox(ShotSheetData data, {required double width}) {
    final sun = data.sun;
    if (sun == null) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('Sol'),
          pw.Container(
            height: 60,
            alignment: pw.Alignment.center,
            decoration: _placeholderBorder(),
            child: pw.Text(
              'Sitúa la localización en el mapa para ver el sol.',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey500,
              ),
            ),
          ),
        ],
      );
    }

    final times = sun.path.times;
    const timeStyle = pw.TextStyle(fontSize: 7.5);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          sun.placeLabel?.isNotEmpty == true
              ? 'Sol · ${sun.placeLabel}'
              : 'Sol',
        ),
        _sunPolar(sun, width: width, height: 128),
        pw.SizedBox(height: 3),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Rise ${sun.hhmm(times.sunrise)}', style: timeStyle),
            pw.Text('Mid. ${sun.hhmm(times.solarNoon)}', style: timeStyle),
            pw.Text('Set ${sun.hhmm(times.sunset)}', style: timeStyle),
          ],
        ),
        pw.SizedBox(height: 2),
        _sunElevation(sun, width: width, height: 38),
        pw.SizedBox(height: 2),
        pw.Text(
          sun.fromShootDay
              ? 'Sol del día de rodaje: ${_formatDate(sun.date)}'
              : 'Sin jornada de rodaje: sol de hoy, ${_formatDate(sun.date)}',
          style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
          textAlign: pw.TextAlign.right,
        ),
      ],
    );
  }

  static pw.Widget _sunPolar(
    ShotSheetSun sun, {
    required double width,
    required double height,
  }) {
    final cx = width / 2;
    final cy = height / 2;
    final r = height / 2 - 8;
    // (acimut, altura) → punto en la caja, con y hacia arriba.
    PdfPoint at(double az, double alt) {
      final d = r * (90 - alt.clamp(0, 90)) / 90;
      final a = az * math.pi / 180;
      return PdfPoint(cx + d * math.sin(a), cy + d * math.cos(a));
    }

    // Las etiquetas se apartan del centro para no tapar el recorrido.
    PdfPoint outward(PdfPoint p) {
      final dx = p.x - cx;
      final dy = p.y - cy;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < 1) return PdfPoint(p.x, p.y - 12);
      return PdfPoint(p.x + dx / d * 14, p.y + dy / d * 14 - 5);
    }

    final hourly = sun.hourly();
    final rise = sun.path.sunriseAzimuth;
    final set = sun.path.sunsetAzimuth;

    pw.Widget label(PdfPoint p, String text, {PdfColor? color}) {
      const lw = 28.0;
      const lh = 10.0;
      return pw.Positioned(
        left: (p.x - lw / 2).clamp(0.0, width - lw),
        top: (height - p.y - lh - 3).clamp(0.0, height - lh),
        child: pw.Container(
          width: lw,
          height: lh,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: color ?? PdfColors.black,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Text(
            text,
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.white),
          ),
        ),
      );
    }

    return pw.SizedBox(
      width: width,
      height: height,
      child: pw.Stack(
        children: [
          pw.CustomPaint(
            size: PdfPoint(width, height),
            painter: (canvas, size) {
              canvas
                ..setFillColor(_night)
                ..drawRect(0, 0, size.x, size.y)
                ..fillPath();
              // Horizonte y alturas de 30° y 60°, y los ejes.
              canvas
                ..setStrokeColor(const PdfColor(1, 1, 1, 0.25))
                ..setLineWidth(0.5);
              for (final alt in [0.0, 30.0, 60.0]) {
                final d = r * (90 - alt) / 90;
                canvas
                  ..drawEllipse(cx, cy, d, d)
                  ..strokePath();
              }
              canvas
                ..drawLine(cx, cy - r, cx, cy + r)
                ..drawLine(cx - r, cy, cx + r, cy)
                ..strokePath();
              // Salida y puesta: rayos desde el centro.
              canvas
                ..setStrokeColor(_teal)
                ..setLineWidth(0.8);
              for (final az in [rise, set]) {
                if (az == null) continue;
                final q = at(az, 0);
                canvas
                  ..drawLine(cx, cy, q.x, q.y)
                  ..strokePath();
              }
              // Recorrido del día.
              final path = sun.path.path;
              if (path.length > 1) {
                canvas
                  ..setStrokeColor(_orange)
                  ..setLineWidth(1.4);
                final first = at(path.first.azimuth, path.first.altitude);
                canvas.moveTo(first.x, first.y);
                for (final p in path.skip(1)) {
                  final q = at(p.azimuth, p.altitude);
                  canvas.lineTo(q.x, q.y);
                }
                canvas.strokePath();
              }
              canvas.setFillColor(_orange);
              for (final p in hourly) {
                final q = at(p.azimuth, p.altitude);
                canvas
                  ..drawEllipse(q.x, q.y, 1.6, 1.6)
                  ..fillPath();
              }
            },
          ),
          pw.Positioned(
            left: cx - 2.5,
            top: 0,
            child: pw.Text(
              'N',
              style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.white),
            ),
          ),
          for (final p in hourly)
            if (p.hour % 3 == 0 && p.altitude > 6)
              label(outward(at(p.azimuth, p.altitude)), '${p.hour}:00'),
          if (rise != null)
            label(at(rise, 0), sun.hhmm(sun.path.times.sunrise), color: _teal),
          if (set != null)
            label(at(set, 0), sun.hhmm(sun.path.times.sunset), color: _teal),
        ],
      ),
    );
  }

  /// Curva de altura del sol entre la salida y la puesta.
  static pw.Widget _sunElevation(
    ShotSheetSun sun, {
    required double width,
    required double height,
  }) {
    final rise = sun.path.times.sunrise;
    final set = sun.path.times.sunset;
    const top = 75.0;
    return pw.Stack(
      children: [
        pw.CustomPaint(
          size: PdfPoint(width, height),
          painter: (canvas, size) {
            canvas
              ..setFillColor(PdfColors.grey400)
              ..drawRect(0, 0, size.x, size.y)
              ..fillPath()
              ..setStrokeColor(const PdfColor(1, 1, 1, 0.6))
              ..setLineWidth(0.4);
            for (final alt in [30.0, 60.0]) {
              final y = size.y * alt / top;
              canvas
                ..drawLine(0, y, size.x, y)
                ..strokePath();
            }
            if (rise == null || set == null) return;
            final span = set.difference(rise).inMinutes;
            if (span <= 0) return;
            canvas
              ..setFillColor(_orange)
              ..moveTo(0, 0);
            const steps = 60;
            for (var i = 0; i <= steps; i++) {
              final t = rise.add(Duration(minutes: span * i ~/ steps));
              final alt = SunCalculator.position(
                t,
                sun.latitude,
                sun.longitude,
              ).altitude;
              canvas.lineTo(
                size.x * i / steps,
                size.y * alt.clamp(0, top) / top,
              );
            }
            canvas
              ..lineTo(size.x, 0)
              ..closePath()
              ..fillPath();
          },
        ),
        pw.Positioned(
          right: 3,
          top: 2,
          child: pw.Text(
            'Day L. ${sun.dayLength}',
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.white),
          ),
        ),
        pw.Positioned(
          left: 3,
          top: 2,
          child: pw.Text(
            '60°',
            style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.white),
          ),
        ),
      ],
    );
  }

  /// Courier del PDF solo dibuja latin-1: «DÍA» sí, «—» o «’» no.
  static String _latin1(String text) => String.fromCharCodes(
    PdfExportFonts.asciiFallback(text)
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('…', '...')
        .runes
        .where((r) => r <= 0xFF),
  );

  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static String _formatDate(DateTime dt) =>
      '${dt.day} ${_months[dt.month - 1]} ${dt.year}';

  static String _formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${_formatDate(dt)}, $h:$m';
  }
}
