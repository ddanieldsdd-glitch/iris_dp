import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'shoot_day_brief.dart';
import 'shoot_day_material.dart';

/// La hoja de material de una jornada en la planta: la luz a la izquierda
/// y la cámara a la derecha, con lo que falta por reservar marcado.
abstract final class ShootingPlanMaterialSheet {
  static const _ink = BriefPdf.ink;
  static const _soft = BriefPdf.soft;
  static const _missing = PdfColor.fromInt(0xFFC62828);
  static const _short = PdfColor.fromInt(0xFFE65100);
  static const _ok = PdfColor.fromInt(0xFF2E7D32);

  static pw.Widget build(
    ShootDayMaterial material, {
    required double width,
    required double height,
  }) {
    final camera = [
      if (material.bodies.isNotEmpty) ..._section('CÁMARAS', material.bodies),
      if (material.lenses.isNotEmpty) ..._section('ÓPTICAS', material.lenses),
      if (material.supports.isNotEmpty)
        ..._section('SOPORTES Y MOVIMIENTO', material.supports, count: false),
      if (material.speeds.isNotEmpty)
        ..._section('VELOCIDAD Y OBTURACIÓN', material.speeds, count: false),
    ];
    final light = [
      if (material.lights.isNotEmpty)
        ..._section('LUZ', material.lights)
      else
        ..._section('LUZ', const [], empty: 'Sin focos en las plantas.'),
    ];
    final column = (width - 24) / 2;
    return pw.SizedBox(
      width: width,
      height: height,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            _summary(material),
            style: const pw.TextStyle(fontSize: 8, color: _soft),
          ),
          pw.SizedBox(height: 8),
          pw.Expanded(
            // Una jornada con mucho material encoge hasta caber.
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.topLeft,
              child: pw.SizedBox(
                width: width,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: column,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: light,
                      ),
                    ),
                    pw.SizedBox(width: 24),
                    pw.SizedBox(
                      width: column,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: camera.isEmpty
                            ? _section(
                                'CÁMARA',
                                const [],
                                empty: 'Los planos no dicen óptica ni soporte.',
                              )
                            : camera,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _summary(ShootDayMaterial material) {
    final head =
        'La luz cuenta lo máximo que se usa a la vez en un set: el material '
        'va de set en set. La cámara sale de la ficha de cada plano.';
    if (!material.checked) {
      return '$head Sin reservas de alquiler que cruzar.';
    }
    final missing = material.missingCount;
    return '$head Cruzado con las reservas de ese día: '
        '${missing == 0 ? 'todo reservado' : '$missing sin reservar del todo'}.';
  }

  static List<pw.Widget> _section(
    String title,
    List<MaterialLine> lines, {
    bool count = true,
    String? empty,
  }) => [
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 3),
      child: pw.Text(
        title,
        style: const pw.TextStyle(
          fontSize: 7,
          color: _soft,
          letterSpacing: 1.3,
        ),
      ),
    ),
    pw.Divider(color: _ink, thickness: 1, height: 4),
    if (lines.isEmpty && empty != null)
      pw.Text(empty, style: const pw.TextStyle(fontSize: 8, color: _soft)),
    for (final line in lines) _line(line, count: count),
  ];

  static pw.Widget _line(MaterialLine line, {required bool count}) {
    final (badge, color) = switch (line.stock) {
      MaterialStock.unchecked => ('', _soft),
      MaterialStock.reserved => ('Reservado', _ok),
      MaterialStock.short => (
        'Faltan ${line.quantity - line.reserved}',
        _short,
      ),
      MaterialStock.missing => ('Sin reservar', _missing),
    };
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: BriefPdf.line, width: 0.4),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Una casilla para marcarlo a mano al cargar.
          pw.Container(
            width: 7,
            height: 7,
            margin: const pw.EdgeInsets.only(top: 1.5, right: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _ink, width: 0.6),
            ),
          ),
          pw.SizedBox(
            width: 22,
            child: pw.Text(
              count ? '${line.quantity}' : '',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  line.name,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (line.detail.isNotEmpty)
                  pw.Text(
                    line.detail,
                    style: const pw.TextStyle(fontSize: 7, color: _soft),
                  ),
              ],
            ),
          ),
          if (badge.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 6),
              child: pw.Text(
                badge,
                style: pw.TextStyle(
                  fontSize: 7.5,
                  color: color,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
