import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/pdf_export_fonts.dart';
import '../../features/camera_plan/camera_plan_constants.dart';
import '../../features/camera_plan/camera_plan_element_model.dart';
import '../../features/camera_plan/light_beam.dart';
import '../../features/camera_plan/plan_elevation.dart';
import '../../features/camera_plan/plan_gear_list.dart';
import '../../features/camera_plan/rig/plan_scene3d.dart';
import '../../features/camera_plan/rig/rig_report.dart';

/// Datos del cajetín de la hoja.
class RigSheetInfo {
  final String project;
  final String location;
  final String gaffer;
  final String department;
  final DateTime date;
  final String revision;

  const RigSheetInfo({
    required this.project,
    this.location = '',
    this.gaffer = '',
    this.department = 'Eléctricos',
    required this.date,
    this.revision = 'A',
  });
}

/// Hoja A3 apaisada al estilo de las de WYSIWYG o Halfway: planta, alzado
/// frontal y perfil a escala, leyenda de aparatos con vatios y amperios,
/// estructura (truss, motores, torres, telas), avisos de rigging y
/// cajetín. Sale de la misma escena que el 3D ([PlanScene3d]) y del mismo
/// alzado que la pantalla de alzados ([PlanElevation]).
abstract final class RigSheetPdf {
  /// Medidas de la hoja, en milímetros.
  static const double pageW = 420;
  static const double pageH = 297;

  /// Escalas de plano habituales, de más detalle a menos.
  static const scales = [20, 25, 50, 75, 100, 125, 150, 200, 250, 300, 500];

  static Future<Uint8List> build(
    List<PlanElement> elements, {
    required double metersPerUnit,
    required RigSheetInfo info,
  }) async {
    final fonts = await PdfExportFonts.load();
    final doc = pw.Document(
      theme: PdfExportFonts.theme(regular: fonts.regular, bold: fonts.bold),
      title: info.project,
      creator: 'IRIS',
    );
    final sheet = _Sheet(elements, metersPerUnit, info);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a3.landscape,
        margin: pw.EdgeInsets.zero,
        build: (_) => sheet.page(),
      ),
    );
    return doc.save();
  }

  /// La escala más detallada a la que `spanM` cabe en `mm`.
  static int scaleFor(double spanXM, double spanYM, double wMm, double hMm) {
    for (final s in scales) {
      if (spanXM * 1000 / s <= wMm && spanYM * 1000 / s <= hMm) return s;
    }
    return scales.last;
  }
}

/// Un texto de la hoja: en milímetros desde arriba a la izquierda.
class _Label {
  final double x;
  final double y;
  final String text;
  final double size;
  final bool bold;
  final PdfColor color;

  /// Ancho de su caja y alineación dentro de ella.
  final double width;
  final pw.TextAlign align;

  const _Label(
    this.x,
    this.y,
    this.text, {
    this.size = 7,
    this.bold = false,
    this.color = _ink,
    this.width = 120,
    this.align = pw.TextAlign.left,
  });
}

const _ink = PdfColor.fromInt(0xFF1E2933);
const _muted = PdfColor.fromInt(0xFF5A6672);
const _accent = PdfColor.fromInt(0xFFC56A12);
const _danger = PdfColor.fromInt(0xFFB5401F);
const _glass = PdfColor.fromInt(0xFF7FB6D6);

class _Sheet {
  final List<PlanElement> elements;
  final double mpu;
  final RigSheetInfo info;
  final Map<String, dynamic> scene;
  final labels = <_Label>[];
  late final LightLegend legend = LightLegend.of(elements);
  late final Map<PlanElement, int> units = lightUnitNumbers(elements);

  _Sheet(this.elements, this.mpu, this.info)
    : scene = PlanScene3d.build(elements, metersPerUnit: mpu);

  static const k = PdfPageFormat.mm;

  // Zonas de la hoja, en mm desde arriba a la izquierda.
  static const plan = (x: 12.0, y: 24.0, w: 266.0, h: 148.0);
  static const front = (x: 12.0, y: 190.0, w: 150.0, h: 90.0);
  static const side = (x: 170.0, y: 190.0, w: 108.0, h: 90.0);
  static const column = (x: 288.0, w: 120.0);

  late int planScale, frontScale, sideScale;

  pw.Widget page() {
    final front = PlanElevation.of(
      elements,
      metersPerUnit: mpu,
      side: ElevationSide.front,
    );
    final profile = PlanElevation.of(
      elements,
      metersPerUnit: mpu,
      side: ElevationSide.side,
    );
    _layoutTexts(front, profile);
    return pw.Stack(
      children: [
        pw.CustomPaint(
          size: const PdfPoint(RigSheetPdf.pageW * k, RigSheetPdf.pageH * k),
          painter: (g, size) {
            _frame(g);
            _plan(g);
            _elevation(g, front, _Sheet.front, frontScale);
            _elevation(g, profile, _Sheet.side, sideScale);
            _legendSymbols(g);
          },
        ),
        for (final l in labels)
          pw.Positioned(
            left: (l.align == pw.TextAlign.left ? l.x : l.x - l.width) * k,
            top: l.y * k - l.size * 0.85,
            child: pw.SizedBox(
              width: l.width * k,
              child: pw.Text(
                l.text,
                textAlign: l.align,
                maxLines: 2,
                style: pw.TextStyle(
                  fontSize: l.size,
                  color: l.color,
                  fontWeight: l.bold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Dibujo, en mm desde arriba a la izquierda ───────────────────────────

  PdfPoint p(double x, double y) =>
      PdfPoint(x * k, (RigSheetPdf.pageH - y) * k);

  void line(
    PdfGraphics g,
    double x1,
    double y1,
    double x2,
    double y2, {
    PdfColor color = _ink,
    double width = 0.25,
    List<num>? dash,
  }) {
    g
      ..setStrokeColor(color)
      ..setLineWidth(width * k);
    if (dash != null) g.setLineDashPattern([for (final d in dash) d * k]);
    final a = p(x1, y1), b = p(x2, y2);
    g
      ..moveTo(a.x, a.y)
      ..lineTo(b.x, b.y)
      ..strokePath();
    if (dash != null) g.setLineDashPattern();
  }

  void poly(
    PdfGraphics g,
    List<(double, double)> pts, {
    PdfColor? stroke = _ink,
    PdfColor? fill,
    double width = 0.25,
    bool closed = false,
    double fillOpacity = 1,
  }) {
    if (pts.length < 2) return;
    void trace() {
      final first = p(pts.first.$1, pts.first.$2);
      g.moveTo(first.x, first.y);
      for (final q in pts.skip(1)) {
        final pt = p(q.$1, q.$2);
        g.lineTo(pt.x, pt.y);
      }
      if (closed) g.closePath();
    }

    if (fill != null) {
      g.saveContext();
      if (fillOpacity < 1) {
        g.setGraphicState(PdfGraphicState(opacity: fillOpacity));
      }
      g.setFillColor(fill);
      trace();
      g.fillPath();
      g.restoreContext();
    }
    if (stroke != null) {
      g
        ..setStrokeColor(stroke)
        ..setLineWidth(width * k);
      trace();
      g.strokePath();
    }
  }

  void rect(
    PdfGraphics g,
    double x,
    double y,
    double w,
    double h, {
    PdfColor? stroke = _ink,
    PdfColor? fill,
    double width = 0.25,
  }) => poly(
    g,
    [(x, y), (x + w, y), (x + w, y + h), (x, y + h)],
    stroke: stroke,
    fill: fill,
    width: width,
    closed: true,
  );

  void circle(
    PdfGraphics g,
    double x,
    double y,
    double r, {
    PdfColor? stroke = _ink,
    PdfColor? fill,
    double width = 0.25,
  }) {
    final c = p(x, y);
    if (fill != null) {
      g
        ..setFillColor(fill)
        ..drawEllipse(c.x, c.y, r * k, r * k)
        ..fillPath();
    }
    if (stroke != null) {
      g
        ..setStrokeColor(stroke)
        ..setLineWidth(width * k)
        ..drawEllipse(c.x, c.y, r * k, r * k)
        ..strokePath();
    }
  }

  void _frame(PdfGraphics g) {
    rect(g, 8, 8, 404, 281, width: 0.5);
    rect(g, 10, 10, 400, 277, width: 0.2);
    line(g, 284, 10, 284, 287);
    line(g, 10, 180, 284, 180);
    line(g, 166, 180, 166, 287);
  }

  // ── Planta ──────────────────────────────────────────────────────────────

  late final ({double minX, double maxX, double minY, double maxY}) bounds =
      _bounds();

  ({double minX, double maxX, double minY, double maxY}) _bounds() {
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    void take(List<dynamic> xy) {
      final x = (xy[0] as num).toDouble(), y = (xy[1] as num).toDouble();
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }

    for (final w in _list('walls')) {
      for (final q in (w['points'] as List)) {
        take(q as List);
      }
    }
    for (final h in _list('halls')) {
      for (final q in (h['outline'] as List)) {
        take(q as List);
      }
    }
    for (final t in _list('trusses')) {
      take(t['from'] as List);
      take(t['to'] as List);
    }
    for (final key in ['pillars', 'rigging', 'people', 'cameras']) {
      for (final i in _list(key)) {
        take(i['at'] as List);
      }
    }
    for (final f in _list('fixtures')) {
      take(f['pos'] as List);
    }
    for (final d in _list('drapes')) {
      for (final s in (d['samples'] as List).cast<Map>()) {
        take(s['p'] as List);
      }
    }
    if (minX > maxX) return (minX: -5, maxX: 5, minY: -5, maxY: 5);
    return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  List<Map> _list(String key) => (scene[key] as List? ?? const []).cast<Map>();

  late final double _planMm = 1000 / planScale;
  late final double _planOx =
      plan.x + (plan.w - (bounds.maxX - bounds.minX) * _planMm) / 2;
  late final double _planOy =
      plan.y + (plan.h - (bounds.maxY - bounds.minY) * _planMm) / 2;

  /// Un punto del modelo (metros, y arriba) en la hoja.
  (double, double) pm(List<dynamic> xy) => (
    _planOx + ((xy[0] as num) - bounds.minX) * _planMm,
    _planOy + (bounds.maxY - (xy[1] as num)) * _planMm,
  );

  void _plan(PdfGraphics g) {
    final s = _planMm;
    // Paredes y su vidrio.
    for (final w in _list('walls')) {
      final pts = [for (final q in (w['points'] as List)) pm(q as List)];
      poly(g, pts, width: 0.15 * s.clamp(2, 12));
      final cum = <double>[0];
      final raw = (w['points'] as List).cast<List>();
      for (var i = 1; i < raw.length; i++) {
        cum.add(
          cum.last +
              math.sqrt(
                math.pow((raw[i][0] as num) - (raw[i - 1][0] as num), 2) +
                    math.pow((raw[i][1] as num) - (raw[i - 1][1] as num), 2),
              ),
        );
      }
      List<dynamic> at(double s0) {
        var i = 1;
        while (i < cum.length - 1 && cum[i] < s0) {
          i++;
        }
        final t = cum[i] == cum[i - 1]
            ? 0.0
            : ((s0 - cum[i - 1]) / (cum[i] - cum[i - 1])).clamp(0.0, 1.0);
        return [
          (raw[i - 1][0] as num) +
              ((raw[i][0] as num) - (raw[i - 1][0] as num)) * t,
          (raw[i - 1][1] as num) +
              ((raw[i][1] as num) - (raw[i - 1][1] as num)) * t,
        ];
      }

      for (final o in (w['openings'] as List).cast<Map>()) {
        final a = pm(at((o['from'] as num).toDouble()));
        final b = pm(at((o['to'] as num).toDouble()));
        line(
          g,
          a.$1,
          a.$2,
          b.$1,
          b.$2,
          color: PdfColors.white,
          width: 0.15 * s.clamp(2, 12) + 0.1,
        );
        line(
          g,
          a.$1,
          a.$2,
          b.$1,
          b.$2,
          color: o['glass'] == true ? _glass : _muted,
          width: 0.3,
        );
      }
    }
    // Telas: la onda de cortina.
    for (final d in _list('drapes')) {
      final samples = (d['samples'] as List).cast<Map>();
      final pts = [for (final q in samples) pm(q['p'] as List)];
      final color = PdfColor.fromHex(d['color'] as String);
      final wave = <(double, double)>[];
      for (var i = 0; i < pts.length - 1; i++) {
        final a = pts[i], b = pts[i + 1];
        final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len == 0) continue;
        final steps = math.max(2, (len / 0.4).ceil());
        for (var j = 0; j < steps; j++) {
          final t = j / steps;
          final phase = (i + t) * math.pi * 1.2;
          final o = 0.6 * math.sin(phase);
          wave.add((
            a.$1 + dx * t - dy / len * o,
            a.$2 + dy * t + dx / len * o,
          ));
        }
      }
      poly(g, wave, stroke: color, width: 0.4);
    }
    // Pilares.
    for (final pl in _list('pillars')) {
      final c = pm(pl['at'] as List);
      final r = math.max((pl['sizeM'] as num) * s / 2, 0.5);
      if (pl['shape'] == 'round') {
        circle(g, c.$1, c.$2, r, stroke: null, fill: _ink);
      } else {
        rect(g, c.$1 - r, c.$2 - r, r * 2, r * 2, stroke: null, fill: _ink);
      }
    }
    // Truss: dos cordones, diagonales y juntas.
    for (final t in _list('trusses')) {
      final a = pm(t['from'] as List), b = pm(t['to'] as List);
      final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 0.1) continue;
      final ux = dx / len, uy = dy / len, nx = -uy, ny = ux;
      final half = math.max(((t['sizeCm'] as num) - 1) / 200 * s, 0.6);
      (double, double) q(double along, double across) =>
          (a.$1 + ux * along + nx * across, a.$2 + uy * along + ny * across);
      for (final side in [-half, half]) {
        final s0 = q(0, side), s1 = q(len, side);
        line(g, s0.$1, s0.$2, s1.$1, s1.$2, width: 0.25);
      }
      final n = math.max(1, (len / (half * 2)).round());
      final zig = <(double, double)>[
        for (var j = 0; j <= n; j++) q(len * j / n, j.isEven ? -half : half),
      ];
      poly(g, zig, width: 0.12);
      var along = 0.0;
      for (final piece in (t['pieces'] as List).cast<num>()) {
        final j0 = q(along, -half * 1.6), j1 = q(along, half * 1.6);
        line(g, j0.$1, j0.$2, j1.$1, j1.$2, width: 0.2);
        along += piece * s;
      }
      final e0 = q(len, -half * 1.6), e1 = q(len, half * 1.6);
      line(g, e0.$1, e0.$2, e1.$1, e1.$2, width: 0.2);
    }
    // Motores y torres, con el color de su carga.
    for (final r in _list('rigging')) {
      final c = pm(r['at'] as List);
      final load = (r['loadKg'] as num?)?.toDouble();
      final wll = (r['wllKg'] as num?)?.toDouble() ?? 500;
      final over = load != null && load > wll;
      final stroke = over ? _danger : _ink;
      if (r['type'] == 'motor') {
        circle(
          g,
          c.$1,
          c.$2,
          1.4,
          stroke: stroke,
          fill: PdfColors.white,
          width: 0.3,
        );
        line(g, c.$1 - 0.7, c.$2 + 0.6, c.$1 - 0.7, c.$2 - 0.6, color: stroke);
        line(g, c.$1 + 0.7, c.$2 + 0.6, c.$1 + 0.7, c.$2 - 0.6, color: stroke);
        line(g, c.$1 - 0.7, c.$2 - 0.6, c.$1, c.$2 + 0.2, color: stroke);
        line(g, c.$1 + 0.7, c.$2 - 0.6, c.$1, c.$2 + 0.2, color: stroke);
      } else {
        rect(
          g,
          c.$1 - 1.4,
          c.$2 - 1.4,
          2.8,
          2.8,
          stroke: stroke,
          fill: PdfColors.white,
          width: 0.3,
        );
        line(g, c.$1 - 1.4, c.$2 - 1.4, c.$1 + 1.4, c.$2 + 1.4, color: stroke);
        line(g, c.$1 + 1.4, c.$2 - 1.4, c.$1 - 1.4, c.$2 + 1.4, color: stroke);
      }
    }
    // Focos: un círculo del color de su luz, con su eje.
    for (final f in _list('fixtures')) {
      final c = pm(f['pos'] as List), aim = pm(f['aim'] as List);
      final color = _cct((f['cct'] as num).toDouble());
      final dx = aim.$1 - c.$1, dy = aim.$2 - c.$2;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len > 1) {
        final reach = math.min(len, 9.0);
        line(
          g,
          c.$1,
          c.$2,
          c.$1 + dx / len * reach,
          c.$2 + dy / len * reach,
          color: color,
          width: 0.2,
          dash: [0.8, 0.6],
        );
      }
      circle(g, c.$1, c.$2, 1.3, stroke: _ink, fill: color, width: 0.2);
    }
    // Personas.
    for (final pe in _list('people')) {
      final c = pm(pe['at'] as List);
      circle(g, c.$1, c.$2, 1.2, width: 0.25);
    }
    // Norte y barra de escala.
    final nx = plan.x + plan.w - 8, ny = plan.y - 4;
    circle(g, nx, ny, 3.5, width: 0.25);
    poly(
      g,
      [
        (nx, ny - 3),
        (nx + 1.2, ny + 1.5),
        (nx, ny + 0.7),
        (nx - 1.2, ny + 1.5),
      ],
      stroke: null,
      fill: _ink,
      closed: true,
    );
    final bar = 5 * s;
    rect(g, plan.x + 4, plan.y + plan.h + 2, bar, 1, stroke: null, fill: _ink);
    rect(g, plan.x + 4 + bar, plan.y + plan.h + 2, bar, 1, width: 0.2);
  }

  /// Los textos de la planta: van en la capa de texto, que se monta antes
  /// de dibujar.
  void _planLabels() {
    final byId = <String, PlanElement>{
      for (final (i, el) in elements.indexed) PlanScene3d.idOf(el, i): el,
    };
    for (final f in _list('fixtures')) {
      final unit = units[byId[f['id']]];
      if (unit == null) continue;
      final c = pm(f['pos'] as List);
      labels.add(_Label(c.$1 + 1.6, c.$2 - 1.2, 'U$unit', size: 5, width: 10));
    }
    final nx = plan.x + plan.w - 8, ny = plan.y - 4;
    labels.add(
      _Label(
        nx + 3,
        ny - 4.5,
        'N',
        size: 7,
        bold: true,
        width: 6,
        align: pw.TextAlign.right,
      ),
    );
    final bar = 5 * _planMm;
    labels
      ..add(_Label(plan.x + 4, plan.y + plan.h + 6, '0', size: 6, width: 4))
      ..add(
        _Label(
          plan.x + 4 + bar * 2 - 2,
          plan.y + plan.h + 6,
          '10 m',
          size: 6,
          width: 10,
        ),
      );
  }

  // ── Alzados ─────────────────────────────────────────────────────────────

  void _elevation(
    PdfGraphics g,
    PlanElevation e,
    ({double x, double y, double w, double h}) box,
    int scale,
  ) {
    final s = 1000 / scale;
    final x0 = box.x + (box.w - (e.right - e.left) * s) / 2;
    final floor = box.y + box.h - 6;
    (double, double) at(double across, double z) =>
        (x0 + (across - e.left) * s, floor - z * s);
    line(g, box.x + 2, floor, box.x + box.w - 2, floor, width: 0.5);
    for (final item in e.items) {
      final a = at(item.from, item.bottom), b = at(item.to, item.top);
      final x = a.$1, y = b.$2, w = b.$1 - a.$1, h = a.$2 - b.$2;
      switch (item.kind) {
        case ElevationKind.wall:
          rect(
            g,
            x,
            y,
            w,
            h,
            fill: const PdfColor.fromInt(0xFFEEF1F3),
            width: 0.2,
          );
        case ElevationKind.opening:
          rect(g, x, y, w, h, fill: PdfColors.white, width: 0.15);
        case ElevationKind.drape:
          final pts = [
            for (final (across, top, _) in item.profile) at(across, top),
            for (final (across, _, bottom) in item.profile.reversed)
              at(across, bottom),
          ];
          poly(
            g,
            pts,
            fill: const PdfColor(0.55, 0.11, 0.17, 0.5),
            width: 0.2,
            closed: true,
          );
        case ElevationKind.truss:
          rect(g, x, y, w, h, width: 0.25);
          if (w > h * 2) {
            final n = math.max(1, (w / h).round());
            poly(g, [
              for (var j = 0; j <= n; j++)
                (x + w * j / n, j.isEven ? y + h : y),
            ], width: 0.12);
          }
        case ElevationKind.rigPoint:
          rect(g, x, y, w, h, fill: PdfColors.white, width: 0.25);
        case ElevationKind.light:
          final c = at(item.centre, (item.bottom + item.top) / 2);
          final color = _cct(item.cct);
          final aim = item.aim;
          if (aim != null && item.beamDeg < 179) {
            final half = item.beamDeg / 2 * math.pi / 180;
            // Cada borde del haz llega a su alcance o al suelo, lo que
            // antes.
            final z = (item.bottom + item.top) / 2;
            (double, double) edge(double a) {
              var reach = item.reachM;
              if (math.sin(a) < -0.01) {
                reach = math.min(reach, z / -math.sin(a));
              }
              return (
                c.$1 + math.cos(a) * reach * s,
                c.$2 - math.sin(a) * reach * s,
              );
            }

            poly(
              g,
              [c, edge(aim - half), edge(aim + half)],
              stroke: color,
              fill: color,
              fillOpacity: 0.15,
              width: 0.15,
              closed: true,
            );
          }
          circle(g, c.$1, c.$2, 1, stroke: _ink, fill: color, width: 0.2);
        case ElevationKind.actor:
          final head = at(item.centre, item.top - 0.12);
          circle(g, head.$1, head.$2, 0.12 * s, width: 0.2);
          final hip = at(item.centre, 0.9),
              neck = at(item.centre, item.top - 0.24);
          line(g, neck.$1, neck.$2, hip.$1, hip.$2, width: 0.2);
          for (final dx in [-0.18, 0.18]) {
            final foot = at(item.centre + dx, 0);
            line(g, hip.$1, hip.$2, foot.$1, foot.$2, width: 0.2);
          }
        case ElevationKind.camera:
          rect(g, x, y, w, h, fill: _ink, width: 0.2);
        case ElevationKind.prop:
          rect(g, x, y, w, h, width: 0.2);
      }
    }
    // Cotas de altura a la izquierda: las de los truss y la más alta.
    for (final z in _heights(e)) {
      final y = floor - z * s;
      line(g, box.x + 1, y, box.x + 5, y, width: 0.2);
    }
  }

  static Set<double> _heights(PlanElevation e) => {
    for (final i in e.items)
      if (i.kind == ElevationKind.truss) i.bottom,
    if (e.items.isNotEmpty) e.items.map((i) => i.top).reduce(math.max),
  };

  void _elevationLabels(
    PlanElevation e,
    ({double x, double y, double w, double h}) box,
    int scale,
  ) {
    final floor = box.y + box.h - 6;
    for (final z in _heights(e)) {
      labels.add(
        _Label(
          box.x + 1,
          floor - z * 1000 / scale - 0.8,
          '+${_m(z)}',
          size: 5,
          width: 14,
        ),
      );
    }
  }

  // ── Leyenda, estructura, avisos y cajetín ───────────────────────────────

  final _legendRows = <(double, PdfColor)>[];

  void _legendSymbols(PdfGraphics g) {
    for (final (y, color) in _legendRows) {
      circle(g, column.x + 3, y, 1.5, stroke: _ink, fill: color, width: 0.2);
    }
    // Cajetín.
    const top = 236.0;
    rect(g, 284, top, 126, 51, width: 0.4);
    for (final y in [top + 13, top + 22, top + 31, top + 40]) {
      line(g, 284, y, 410, y, width: 0.15);
    }
    line(g, 347, top + 13, 347, top + 40, width: 0.15);
  }

  void _layoutTexts(PlanElevation front, PlanElevation profile) {
    final b = bounds;
    planScale = RigSheetPdf.scaleFor(
      b.maxX - b.minX + 2,
      b.maxY - b.minY + 2,
      plan.w,
      plan.h,
    );
    frontScale = RigSheetPdf.scaleFor(
      front.right - front.left + 1,
      front.height,
      _Sheet.front.w - 8,
      _Sheet.front.h - 10,
    );
    sideScale = RigSheetPdf.scaleFor(
      profile.right - profile.left + 1,
      profile.height,
      side.w - 8,
      side.h - 10,
    );
    void title(double x, double y, String text, int scale) => labels
      ..add(_Label(x, y, text, size: 10, bold: true, width: 120))
      ..add(
        _Label(x, y + 4, 'ESCALA 1:$scale', size: 6, color: _muted, width: 60),
      );
    title(plan.x, 16, 'PLANTA DE LUZ Y RIGGING', planScale);
    _planLabels();
    title(_Sheet.front.x, 184, 'ALZADO FRONTAL', frontScale);
    title(side.x, 184, 'PERFIL LATERAL', sideScale);
    _elevationLabels(front, _Sheet.front, frontScale);
    _elevationLabels(profile, side, sideScale);

    // Leyenda.
    var y = 16.0;
    final x = column.x;
    labels.add(_Label(x, y, 'LEYENDA', size: 10, bold: true));
    y += 6;
    labels
      ..add(_Label(x + 8, y, 'APARATO', size: 5.5, color: _muted, width: 60))
      ..add(
        _Label(
          x + 88,
          y,
          'UDS',
          size: 5.5,
          color: _muted,
          width: 10,
          align: pw.TextAlign.right,
        ),
      )
      ..add(
        _Label(
          x + 104,
          y,
          'W/UD',
          size: 5.5,
          color: _muted,
          width: 14,
          align: pw.TextAlign.right,
        ),
      )
      ..add(
        _Label(
          x + 120,
          y,
          'W TOT.',
          size: 5.5,
          color: _muted,
          width: 16,
          align: pw.TextAlign.right,
        ),
      );
    y += 5;
    for (final row in legend.rows.take(10)) {
      _legendRows.add((y - 1, _cct(_cctOf(row))));
      labels
        ..add(_Label(x + 8, y, row.name, size: 6.5, width: 74))
        ..add(
          _Label(
            x + 8,
            y + 3,
            row.unitsLabel,
            size: 5,
            color: _muted,
            width: 74,
          ),
        )
        ..add(
          _Label(
            x + 88,
            y,
            '${row.count}',
            size: 6.5,
            width: 10,
            align: pw.TextAlign.right,
          ),
        )
        ..add(
          _Label(
            x + 104,
            y,
            '${row.watts.round()}',
            size: 6.5,
            width: 14,
            align: pw.TextAlign.right,
          ),
        )
        ..add(
          _Label(
            x + 120,
            y,
            '${(row.watts * row.count).round()}',
            size: 6.5,
            width: 16,
            align: pw.TextAlign.right,
          ),
        );
      y += 7.5;
    }
    if (legend.rows.length > 10) {
      labels.add(
        _Label(
          x + 8,
          y,
          '… y ${legend.rows.length - 10} modelos más',
          size: 5.5,
          color: _muted,
        ),
      );
      y += 5;
    }
    final watts = legend.watts;
    labels
      ..add(_Label(x + 8, y + 1, 'TOTAL', size: 7, bold: true))
      ..add(
        _Label(
          x + 120,
          y + 1,
          formatWatts(watts),
          size: 7,
          bold: true,
          width: 30,
          align: pw.TextAlign.right,
        ),
      )
      ..add(
        _Label(
          x + 8,
          y + 5,
          'unos ${(watts / 230).toStringAsFixed(0)} A en monofásica · '
          '${(watts / 3 / 230).toStringAsFixed(0)} A por fase (trifásica 400 V)',
          size: 5.5,
          color: _muted,
          width: 112,
        ),
      );
    y += 13;

    // Estructura.
    final rigging = RigReport.rigging(elements, mpu);
    if (rigging.isNotEmpty) {
      labels.add(_Label(x, y, 'ESTRUCTURA', size: 8.5, bold: true));
      y += 5;
      for (final lineItem in rigging.take(14)) {
        labels
          ..add(_Label(x + 8, y, lineItem.label, size: 6, width: 96))
          ..add(
            _Label(
              x + 120,
              y,
              '${lineItem.count}',
              size: 6,
              width: 12,
              align: pw.TextAlign.right,
            ),
          );
        y += 4;
      }
      y += 3;
    }

    // Avisos.
    final warnings = RigReport.warnings(elements, mpu);
    if (warnings.isNotEmpty && y < 220) {
      labels.add(_Label(x, y, 'AVISOS', size: 8.5, bold: true, color: _danger));
      y += 5;
      for (final w in warnings.take(4)) {
        if (y > 228) break;
        labels.add(
          _Label(
            x + 2,
            y,
            '· ${w.text}',
            size: 5.5,
            color: w.serious ? _danger : _accent,
            width: 116,
          ),
        );
        y += 5;
      }
    }

    // Cajetín.
    const top = 236.0;
    void cell(
      double cx,
      double cy,
      String key,
      String value, {
      bool big = false,
    }) {
      labels
        ..add(_Label(cx, cy, key, size: 4.5, color: _muted, width: 60))
        ..add(
          _Label(
            cx,
            cy + (big ? 6 : 4.6),
            value,
            size: big ? 11 : 7,
            bold: big,
            width: big ? 120 : 60,
          ),
        );
    }

    cell(287, top + 3, 'PROYECTO', info.project, big: true);
    cell(287, top + 16, 'LOCALIZACIÓN', info.location);
    cell(350, top + 16, 'DEPARTAMENTO', info.department);
    cell(287, top + 25, 'GAFFER', info.gaffer);
    cell(
      350,
      top + 25,
      'FECHA',
      '${info.date.day.toString().padLeft(2, '0')}/'
          '${info.date.month.toString().padLeft(2, '0')}/${info.date.year}',
    );
    cell(
      287,
      top + 34,
      'ESCALAS',
      '1:$planScale · 1:$frontScale · 1:$sideScale',
    );
    cell(350, top + 34, 'HOJA', '1 / 1 · REV. ${info.revision}');
    labels
      ..add(
        _Label(
          287,
          top + 46,
          '${legend.rows.fold<int>(0, (a, r) => a + r.count)} aparatos · '
          '${formatWatts(watts)} · '
          '${_list('trusses').length} truss · ${_list('rigging').length} puntos',
          size: 6,
          width: 90,
        ),
      )
      ..add(
        _Label(
          408,
          top + 46,
          'IRIS',
          size: 11,
          bold: true,
          width: 20,
          align: pw.TextAlign.right,
        ),
      );
  }

  double _cctOf(LightLegendRow row) {
    for (final (el, _) in units.entries.map((e) => (e.key, e.value))) {
      final name = (el.props['name'] as String?) ?? el.lightType?.label;
      if (name == row.name) return LightBeam.of(el)?.cct ?? 3200;
    }
    return 3200;
  }

  static PdfColor _cct(double kelvin) {
    final c = LightBeam.colorForCct(kelvin);
    // Un poco más saturado que la luz real, para que se lea en papel.
    return PdfColor(
      (c.r * 0.85).clamp(0, 1),
      (c.g * 0.75).clamp(0, 1),
      (c.b * 0.6).clamp(0, 1),
    );
  }

  static String _m(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
}
