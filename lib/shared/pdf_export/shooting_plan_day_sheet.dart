import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'shoot_day_brief.dart';

/// Lo que puede llevar el índice de la planta de cada jornada.
enum PlanIndexPart {
  order('Orden de rodaje'),
  places('Mapa, QR y enlaces'),
  facts('Citación, sol y tiempo');

  final String label;

  const PlanIndexPart(this.label);
}

/// El resumen de una jornada en el índice de la planta: el índice y el
/// orden de rodaje compacto a la izquierda; la citación, el sol y el
/// tiempo, y dónde se rueda con mapa, QR y enlaces, a la derecha. Todo en
/// una hoja.
abstract final class ShootingPlanDaySheet {
  static const _ink = BriefPdf.ink;
  static const _soft = BriefPdf.soft;
  static const _rowHeight = 11.0;
  static const _indexLineHeight = 15.0;

  /// Ancho de la columna de la derecha.
  static const sideWidth = 290.0;

  /// Las paradas: las calculadas o, si no hay, el lugar de la jornada.
  static List<BriefStop> stopsOf(ShootDayBrief brief) {
    if (brief.stops.isNotEmpty) return brief.stops;
    if (brief.placeName.isEmpty && !brief.located) return const [];
    return [
      BriefStop(
        name: brief.placeName,
        detail: brief.placeDetail,
        time: brief.window,
        latitude: brief.latitude,
        longitude: brief.longitude,
        map: brief.map,
      ),
    ];
  }

  /// Lo que ocupa a lo alto la columna de la izquierda, más o menos, con
  /// [indexLines] líneas de índice encima.
  static double leftHeight(
    ShootDayBrief brief,
    Set<PlanIndexPart> parts, {
    int indexLines = 0,
  }) =>
      (indexLines == 0 ? 0 : 28 + indexLines * _indexLineHeight) +
      (parts.contains(PlanIndexPart.order) && brief.rows.isNotEmpty
          ? 26 + brief.rows.length * _rowHeight
          : 0);

  /// Lo que ocupa a lo alto la columna de la derecha con mapas de
  /// [mapHeight].
  static double sideHeight(
    ShootDayBrief brief,
    Set<PlanIndexPart> parts, {
    double mapHeight = 70,
  }) {
    var h = parts.contains(PlanIndexPart.facts) ? 64.0 : 0.0;
    if (parts.contains(PlanIndexPart.places)) {
      h += 18 + stopsOf(brief).length * (math.max(mapHeight, 34) + 8);
    }
    return h;
  }

  /// El mapa más grande que cabe en [height] con todas las paradas; cero
  /// si no cabe ninguno y las paradas van sin mapa.
  static double mapHeightFor(
    ShootDayBrief brief,
    Set<PlanIndexPart> parts,
    double height,
  ) {
    for (final h in [80.0, 66.0, 54.0, 44.0]) {
      if (sideHeight(brief, parts, mapHeight: h) <= height) return h;
    }
    return 0;
  }

  /// Cabe en [height] con [indexLines] líneas de índice.
  static bool fits(
    ShootDayBrief brief,
    Set<PlanIndexPart> parts,
    double height, {
    int indexLines = 0,
  }) =>
      leftHeight(brief, parts, indexLines: indexLines) <= height &&
      sideHeight(brief, parts, mapHeight: 0) <= height;

  static pw.Widget _label(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 7, color: _soft, letterSpacing: 1.3),
    ),
  );

  /// El resumen: [index] (las líneas del índice, si van aquí) encima del
  /// orden, y la columna de datos y lugares a la derecha.
  static pw.Widget build(
    ShootDayBrief brief,
    Set<PlanIndexPart> parts, {
    required double height,
    required double width,
    List<pw.Widget> index = const [],
  }) {
    // Con sitio de sobra, el orden en letra más grande.
    final extra = height - leftHeight(brief, parts, indexLines: index.length);
    final rows = brief.rows.length;
    final scale = rows == 0
        ? 1.0
        : (1 + extra / (rows * _rowHeight)).clamp(1.0, 1.45);
    final left = <pw.Widget>[
      if (index.isNotEmpty) ...[
        pw.Text('ÍNDICE', style: const pw.TextStyle(fontSize: 16)),
        pw.SizedBox(height: 6),
        ...index,
        pw.SizedBox(height: 10),
      ],
      if (parts.contains(PlanIndexPart.order) && brief.rows.isNotEmpty) ...[
        _label('ORDEN DE RODAJE'),
        pw.Divider(color: _ink, thickness: 1, height: 4),
        for (final row in brief.rows) _orderRow(row, scale: scale),
      ],
    ];
    final side = <pw.Widget>[
      if (parts.contains(PlanIndexPart.facts)) ..._facts(brief),
      if (parts.contains(PlanIndexPart.places) &&
          stopsOf(brief).isNotEmpty) ...[
        _label(stopsOf(brief).length > 1 ? 'PARADAS' : 'LUGAR'),
        BriefPdf.stops(
          stopsOf(brief),
          mapHeight: mapHeightFor(
            brief,
            parts,
            height - (parts.contains(PlanIndexPart.facts) ? 64 : 0),
          ),
        ),
      ],
    ];
    return pw.SizedBox(
      height: height,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Una jornada muy larga encoge su orden hasta caber.
          pw.Expanded(
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.topLeft,
              child: pw.SizedBox(
                width: side.isEmpty ? width : width - sideWidth - 18,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: left,
                ),
              ),
            ),
          ),
          if (side.isNotEmpty) ...[
            pw.SizedBox(width: 18),
            pw.SizedBox(
              width: sideWidth,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: side,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Citación, horario, sol y tiempo: casillas pequeñas en dos líneas.
  static List<pw.Widget> _facts(ShootDayBrief brief) {
    pw.Widget fact(String name, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(right: 12, bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            name,
            style: const pw.TextStyle(
              fontSize: 6,
              color: _soft,
              letterSpacing: 1,
            ),
          ),
          pw.Text(
            value.isEmpty ? '—' : value,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    return [
      pw.Wrap(
        children: [
          fact('CITACIÓN', brief.call),
          fact('SE RUEDA', brief.window),
          for (final (name, time) in brief.sun.take(4))
            fact(name.toUpperCase(), time),
        ],
      ),
      if (brief.weatherLine.isNotEmpty)
        pw.Text(
          brief.weatherLine,
          maxLines: 1,
          style: const pw.TextStyle(fontSize: 7.5, color: _soft),
        ),
      pw.SizedBox(height: 8),
    ];
  }

  /// Una línea del orden: hora, qué es y, en las escenas, sus planos.
  static pw.Widget _orderRow(BriefRow row, {double scale = 1}) {
    final color = row.scene ? _ink : BriefPdf.stripColor(row.kind);
    final from = row.time.split('–').first.trim();
    final shots = [
      for (final shot in row.shots)
        ['${shot.number}', if (shot.framing.isNotEmpty) shot.framing].join(' '),
    ].join('  ·  ');
    final size = 7 * scale;
    return pw.Container(
      height: _rowHeight * scale,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: BriefPdf.line, width: 0.4),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Container(width: 2, height: 8 * scale, color: color),
          pw.SizedBox(width: 4),
          pw.SizedBox(
            width: 30 * scale,
            child: pw.Text(
              from.isEmpty ? '—' : from,
              style: pw.TextStyle(
                fontSize: size,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(
            width: 170 * scale,
            child: pw.Text(
              row.title,
              maxLines: 1,
              style: pw.TextStyle(
                fontSize: size,
                color: color,
                fontWeight: row.scene ? pw.FontWeight.bold : null,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              shots.isNotEmpty ? shots : row.detail,
              maxLines: 1,
              style: pw.TextStyle(fontSize: size - 0.5, color: _soft),
            ),
          ),
        ],
      ),
    );
  }
}

/// La hoja de resumen de una jornada cuando no cabe en la portada.
pw.Widget shootingPlanDaySummaryTitle(String heading) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 8),
  child: pw.Text(
    heading,
    maxLines: 1,
    style: pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.black,
    ),
  ),
);
