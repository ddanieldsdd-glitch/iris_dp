import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/pdf_export_fonts.dart';
import '../../features/camera_plan/camera_plan_constants.dart';
import '../../features/camera_plan/camera_plan_element_model.dart';
import '../../features/camera_plan/light/modifiers.dart';
import '../../features/camera_plan/light/plan_grip.dart';
import '../../features/camera_plan/light/plan_light.dart';
import '../../features/camera_plan/light/street_lamp.dart';
import '../../features/camera_plan/light/wall_mount.dart';
import '../../features/camera_plan/plan_elevation.dart';
import '../../features/camera_plan/plan_gear_list.dart';
import '../../features/camera_plan/rig/plan_rig.dart';
import '../../features/camera_plan/rig/plan_scene3d.dart';
import '../../features/camera_plan/rig/rig_report.dart';
import 'rig_symbols.dart';

/// Datos del cajetín de la hoja.
class RigSheetInfo {
  final String project;
  final String location;

  /// Set y esquema de luz que dibuja la hoja.
  final String set;
  final String scheme;

  /// Escenas o planos que la usan («6, 7A») y jornada («Jornada 3 · 14/12»).
  final String scenes;
  final String shootDay;
  final String gaffer;
  final String department;
  final DateTime date;
  final String revision;

  const RigSheetInfo({
    required this.project,
    this.location = '',
    this.set = '',
    this.scheme = '',
    this.scenes = '',
    this.shootDay = '',
    this.gaffer = '',
    this.department = 'Eléctricos',
    required this.date,
    this.revision = 'A',
  });
}

/// Un esquema para [RigSheetPdf.buildAll].
class RigSheetJob {
  final List<PlanElement> elements;
  final double metersPerUnit;
  final RigSheetInfo info;

  const RigSheetJob(this.elements, this.metersPerUnit, this.info);
}

/// Cómo se reparten las vistas.
enum RigSheetLayout {
  /// La planta en una hoja y el alzado y el perfil en otra, como las hojas
  /// de *Dune II*: cada vista más grande.
  split,

  /// Todo en una hoja: planta arriba, alzado y perfil debajo.
  compact,
}

enum RigSheetPaper {
  a3('A3'),
  a4('A4');

  const RigSheetPaper(this.label);
  final String label;
}

/// Cuándo lleva cada foco su número junto al dibujo.
enum RigSheetNumbers {
  /// Con 60 focos o menos; con más, el color y la forma ya dicen el modelo.
  auto,
  all,
  none,
}

class RigSheetOptions {
  final RigSheetLayout layout;
  final RigSheetPaper paper;
  final RigSheetNumbers numbers;

  /// Añade la lista de focos: número, aparato, accesorios, montaje,
  /// altura, circuito y vatios de cada uno.
  final bool schedule;

  /// Los conos de luz: hacia dónde va el haz en la planta y en los alzados.
  final bool beams;

  /// La mancha de luz en el suelo de lo que cuelga mirando abajo.
  final bool pools;

  /// Personas y cámaras. En una hoja de luz suelen sobrar: lo que importa
  /// es la arquitectura y los aparatos.
  final bool people;

  const RigSheetOptions({
    this.layout = RigSheetLayout.split,
    this.paper = RigSheetPaper.a3,
    this.numbers = RigSheetNumbers.auto,
    this.schedule = true,
    this.beams = true,
    this.pools = true,
    this.people = false,
  });

  RigSheetOptions copyWith({
    RigSheetLayout? layout,
    RigSheetPaper? paper,
    RigSheetNumbers? numbers,
    bool? schedule,
    bool? beams,
    bool? pools,
    bool? people,
  }) => RigSheetOptions(
    layout: layout ?? this.layout,
    paper: paper ?? this.paper,
    numbers: numbers ?? this.numbers,
    schedule: schedule ?? this.schedule,
    beams: beams ?? this.beams,
    pools: pools ?? this.pools,
    people: people ?? this.people,
  );
}

/// Hoja de luz al estilo de las de *Dune II* o de WYSIWYG: planta, alzado
/// frontal y perfil a escala (LZ.1).
///
/// - Cada modelo de aparato tiene su dibujo (fresnel, recorte, panel,
///   tubo…) a escala, girado hacia donde apunta, y su color.
/// - La localización va de fondo en gris (muros, pilares, la nave y su
///   cubierta) y el decorado en un tono muy pálido; el rigging, en negro.
/// - Haces claros, cotas en rojo y rótulos en marcos y rebotes.
/// - Leyenda con el dibujo de cada modelo desde arriba y de lado,
///   cuántos hay y sus vatios; si no cabe, sigue en una hoja propia.
///
/// Sale de la misma escena que el 3D ([PlanScene3d]) y del mismo alzado que
/// la pantalla de alzados ([PlanElevation]).
abstract final class RigSheetPdf {
  /// Medidas de la hoja A3, en milímetros. En A4 se dibuja lo mismo
  /// reducido.
  static const double pageW = 420;
  static const double pageH = 297;

  /// Escalas de plano habituales, de más detalle a menos.
  static const scales = [20, 25, 50, 75, 100, 125, 150, 200, 250, 300, 500];

  static Future<Uint8List> build(
    List<PlanElement> elements, {
    required double metersPerUnit,
    required RigSheetInfo info,
    RigSheetOptions options = const RigSheetOptions(),
  }) async {
    final fonts = await PdfExportFonts.load();
    final doc = pw.Document(
      theme: PdfExportFonts.theme(regular: fonts.regular, bold: fonts.bold),
      title: info.project,
      creator: 'IRIS',
    );
    final data = _Data(elements, metersPerUnit, info, options);
    final kinds = data.pageKinds();
    for (final (i, (kind, from)) in kinds.indexed) {
      final page = _Page(data, kind, i + 1, kinds.length, from: from);
      doc.addPage(
        pw.Page(
          pageFormat: options.paper == RigSheetPaper.a3
              ? PdfPageFormat.a3.landscape
              : PdfPageFormat.a4.landscape,
          margin: pw.EdgeInsets.zero,
          build: (_) => page.build(),
        ),
      );
    }
    return doc.save();
  }

  /// Las hojas de varios esquemas en un solo PDF: cada uno con su planta,
  /// sus alzados y su lista, numeradas por esquema.
  static Future<Uint8List> buildAll(
    List<RigSheetJob> jobs, {
    RigSheetOptions options = const RigSheetOptions(),
    String title = 'Hojas de luz',
  }) async {
    final fonts = await PdfExportFonts.load();
    final doc = pw.Document(
      theme: PdfExportFonts.theme(regular: fonts.regular, bold: fonts.bold),
      title: title,
      creator: 'IRIS',
    );
    final format = options.paper == RigSheetPaper.a3
        ? PdfPageFormat.a3.landscape
        : PdfPageFormat.a4.landscape;
    for (final job in jobs) {
      final data = _Data(job.elements, job.metersPerUnit, job.info, options);
      final kinds = data.pageKinds();
      for (final (i, (kind, from)) in kinds.indexed) {
        final page = _Page(data, kind, i + 1, kinds.length, from: from);
        doc.addPage(
          pw.Page(
            pageFormat: format,
            margin: pw.EdgeInsets.zero,
            build: (_) => page.build(),
          ),
        );
      }
    }
    if (jobs.isEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (_) => pw.Center(
            child: pw.Text(
              'Lo elegido no tiene esquemas de luz con focos.',
              style: const pw.TextStyle(fontSize: 14),
            ),
          ),
        ),
      );
    }
    return doc.save();
  }

  /// Cuántas hojas salen.
  static int pageCount(
    List<PlanElement> elements, {
    required double metersPerUnit,
    RigSheetOptions options = const RigSheetOptions(),
  }) => _Data(
    elements,
    metersPerUnit,
    RigSheetInfo(project: '', date: DateTime(2000)),
    options,
  ).pageKinds().length;

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

/// La localización, de fondo.
const _struct = PdfColor.fromInt(0xFF9AA3AC);
const _structLight = PdfColor.fromInt(0xFFD3D8DD);

/// El decorado, como un fantasma.
const _decor = PdfColor.fromInt(0xFFF8DFE6);
const _decorLine = PdfColor.fromInt(0xFFE7B5C3);

/// Los haces.
const _beam = PdfColor.fromInt(0xFFF3C6D2);
const _beamLine = PdfColor.fromInt(0xFFE59AAF);

/// Cotas y rótulos de estructura.
const _dim = PdfColor.fromInt(0xFFC8102E);

typedef _Box = ({double x, double y, double w, double h});

enum _Kind { compact, plan, elevations, legend, schedule }

/// Lo que comparten todas las hojas.
class _Data {
  final List<PlanElement> elements;
  final double mpu;
  final RigSheetInfo info;
  final RigSheetOptions options;
  final Map<String, dynamic> scene;
  late final LightLegend legend = LightLegend.of(elements);
  late final Map<PlanElement, int> units = lightUnitNumbers(elements);
  late final Map<String, PlanElement> byId = {
    for (final (i, el) in elements.indexed) PlanScene3d.idOf(el, i): el,
  };
  late final PlanElevation front = PlanElevation.of(
    elements,
    metersPerUnit: mpu,
    side: ElevationSide.front,
  );
  late final PlanElevation profile = PlanElevation.of(
    elements,
    metersPerUnit: mpu,
    side: ElevationSide.side,
  );

  /// El color de cada modelo, en el orden de la leyenda.
  late final Map<String, (PdfColor, PdfColor)> modelColors = {
    for (final (i, row) in legend.rows.indexed) row.name: RigSymbols.colorAt(i),
  };

  /// En A4 todo se dibuja reducido.
  final double paperScale;

  _Data(this.elements, this.mpu, this.info, this.options)
    : scene = PlanScene3d.build(elements, metersPerUnit: mpu),
      paperScale = options.paper == RigSheetPaper.a3
          ? 1
          : PdfPageFormat.a4.width / PdfPageFormat.a3.width;

  bool get showNumbers => switch (options.numbers) {
    RigSheetNumbers.all => true,
    RigSheetNumbers.none => false,
    RigSheetNumbers.auto => units.length <= 60,
  };

  /// Filas de leyenda que caben en la columna de la derecha.
  static const legendRowsInColumn = 18;

  bool get legendOverflows => legend.rows.length > legendRowsInColumn;

  /// Filas de la lista de focos por hoja.
  static const scheduleRows = 40;

  /// Las hojas y, en las de la lista de focos, desde qué foco empiezan.
  List<(_Kind, int)> pageKinds() => [
    if (options.layout == RigSheetLayout.compact)
      (_Kind.compact, 0)
    else ...[
      (_Kind.plan, 0),
      (_Kind.elevations, 0),
    ],
    if (legendOverflows) (_Kind.legend, 0),
    if (options.schedule)
      for (var from = 0; from < units.length; from += scheduleRows)
        (_Kind.schedule, from),
  ];

  /// Los focos en orden de número, para la lista.
  late final List<(int, PlanElement)> numbered = [
    for (final MapEntry(key: el, value: n) in units.entries) (n, el),
  ]..sort((a, b) => a.$1.compareTo(b.$1));

  String modelOf(PlanElement el) => LightLegend.modelName(el);

  (PdfColor, PdfColor) colorOf(PlanElement el) =>
      modelColors[modelOf(el)] ?? RigSymbols.colorAt(0);

  List<Map> list(String key) => (scene[key] as List? ?? const []).cast<Map>();

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

    for (final w in list('walls')) {
      for (final q in (w['points'] as List)) {
        take(q as List);
      }
    }
    for (final h in list('halls')) {
      for (final q in (h['outline'] as List)) {
        take(q as List);
      }
    }
    for (final t in list('trusses')) {
      take(t['from'] as List);
      take(t['to'] as List);
    }
    for (final key in ['pillars', 'rigging', 'people', 'cameras', 'props']) {
      for (final i in list(key)) {
        take(i['at'] as List);
      }
    }
    for (final f in list('fixtures')) {
      take(f['pos'] as List);
    }
    for (final d in list('drapes')) {
      for (final s in (d['samples'] as List).cast<Map>()) {
        take(s['p'] as List);
      }
    }
    if (minX > maxX) return (minX: -5, maxX: 5, minY: -5, maxY: 5);
    return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  /// La familia y medidas con que se dibuja un foco.
  (RigFamily, RigSize) shapeOf(PlanElement el, {Map? fixture}) {
    final family = RigSymbols.familyOf(el.lightType);
    var size = RigSymbols.sizeOf(
      el.lightType,
      tubeM: (fixture?['lengthM'] as num?)?.toDouble(),
    );
    if (family == RigFamily.tube) {
      final axis = fixture?['axis'] as List?;
      final upright = axis == null || (axis[2] as num).abs() > 0.5;
      if (upright) {
        size = (length: 0.05, width: 0.06, height: size.width);
      }
    }
    return (family, size);
  }

  /// El foco de la escena 3D de cada elemento: su posición y hacia dónde
  /// apunta de verdad, también si cuelga de un truss.
  late final Map<PlanElement, Map> fixtureOf = {
    for (final f in list('fixtures'))
      if (byId[f['id']] case final el?) el: f,
  };

  /// Hacia dónde apunta un foco en un alzado (radianes desde la horizontal
  /// hacia la derecha, positivo hacia arriba), con la misma dirección que
  /// la planta y el 3D. `null` si mira hacia el que mira o al contrario.
  double? aimIn(ElevationItem item, ElevationSide side) {
    final f = fixtureOf[item.element];
    if (f == null) return item.aim;
    final pos = (f['pos'] as List).cast<num>();
    final aim = (f['aim'] as List).cast<num>();
    final dx = (aim[0] - pos[0]).toDouble();
    final dy = (aim[1] - pos[1]).toDouble();
    final dz = (aim[2] - pos[2]).toDouble();
    final across = side == ElevationSide.front ? dx : dy;
    final depth = side == ElevationSide.front ? dy : dx;
    final inView = math.sqrt(across * across + dz * dz);
    if (inView < 0.3 * math.sqrt(inView * inView + depth * depth)) {
      return null;
    }
    return math.atan2(dz, across);
  }

  /// La altura de un foco en un alzado: la del 3D (que sabe si cuelga de un
  /// truss), o la del alzado.
  double heightOf(ElevationItem item) {
    final f = fixtureOf[item.element];
    if (f == null) return (item.bottom + item.top) / 2;
    return ((f['pos'] as List)[2] as num).toDouble();
  }

  /// Un foco en pie: ni colgado, ni en pared, ni en un truss.
  bool onStand(PlanElement el) =>
      !PlanLight.isOverhead(el) &&
      !LightWallMount.isOn(el) &&
      TrussMagnet.trussUidOf(el) == null;
}

/// Una hoja.
class _Page {
  final _Data d;
  final _Kind kind;
  final int index;
  final int count;
  final labels = <_Label>[];

  /// Dónde va cada par de dibujos de la leyenda: x, y y un foco del modelo.
  final _legendIcons = <(double, double, PlanElement)>[];

  _Page(this.d, this.kind, this.index, this.count, {this.from = 0}) {
    switch (kind) {
      case _Kind.compact:
        planBox = (x: 12.0, y: 24.0, w: 266.0, h: 148.0);
        frontBox = (x: 12.0, y: 190.0, w: 150.0, h: 90.0);
        sideBox = (x: 170.0, y: 190.0, w: 108.0, h: 90.0);
      case _Kind.plan:
        planBox = (x: 12.0, y: 24.0, w: 266.0, h: 250.0);
      case _Kind.elevations:
        frontBox = (x: 12.0, y: 24.0, w: 266.0, h: 118.0);
        sideBox = (x: 12.0, y: 168.0, w: 266.0, h: 110.0);
      case _Kind.legend || _Kind.schedule:
        break;
    }
  }

  /// En una hoja de la lista de focos, el primero que lleva.
  final int from;

  _Box? planBox;
  _Box? frontBox;
  _Box? sideBox;
  int planScale = 100, frontScale = 100, sideScale = 100;

  static const column = (x: 288.0, w: 120.0);

  double get k => PdfPageFormat.mm * d.paperScale;

  /// La escala de verdad en el papel elegido (en A4, reducida).
  String scaleLabel(int scale) => '1:${(scale / d.paperScale).round()}';

  /// Margen a la derecha de un alzado para las cotas de altura.
  static const _dimsW = 34.0;

  /// Separación entre cotas de altura, para que sus números no se pisen.
  static const _dimStep = 4.8;

  pw.Widget build() {
    _layoutTexts();
    return pw.Stack(
      children: [
        pw.CustomPaint(
          size: PdfPoint(RigSheetPdf.pageW * k, RigSheetPdf.pageH * k),
          painter: (g, size) {
            _frame(g);
            if (planBox != null) _plan(g);
            if (frontBox case final box?) {
              _elevation(g, d.front, box, frontScale);
            }
            if (sideBox case final box?) {
              _elevation(g, d.profile, box, sideScale);
            }
            for (final (x, y, el) in _legendIcons) {
              _drawIcons(g, x, y, el);
            }
            for (final (y, el) in _scheduleIcons) {
              final (family, size) = d.shapeOf(el);
              symbol(
                g,
                20,
                y,
                0,
                RigSymbols.outline(family, size),
                0,
                d.colorOf(el),
                minMm: 3.6,
                maxMm: 3.6,
              );
              line(
                g,
                14,
                y + 2.6,
                278,
                y + 2.6,
                color: _structLight,
                width: 0.1,
              );
            }
            _titleFrame(g);
          },
        ),
        for (final l in labels)
          pw.Positioned(
            left: (l.align == pw.TextAlign.left ? l.x : l.x - l.width) * k,
            top: l.y * k - l.size * d.paperScale * 0.85,
            child: pw.SizedBox(
              width: l.width * k,
              child: pw.Text(
                l.text,
                textAlign: l.align,
                maxLines: 2,
                style: pw.TextStyle(
                  fontSize: l.size * d.paperScale,
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

  /// Un símbolo de aparato en (`cx`, `cy`), con el haz hacia `angle`
  /// (radianes en la hoja, `y` hacia abajo). Nunca más pequeño que
  /// `minMm`, para que se lea a cualquier escala.
  double symbol(
    PdfGraphics g,
    double cx,
    double cy,
    double angle,
    List<RigOutline> outlines,
    double mmPerM,
    (PdfColor, PdfColor) color, {
    double minMm = 2.4,
    double? maxMm,
  }) {
    var extent = 0.0;
    for (final o in outlines) {
      for (final (x, y) in o.points) {
        extent = math.max(extent, math.max(x.abs(), y.abs()) * 2);
      }
    }
    if (extent == 0) return 0;
    var f = math.max(mmPerM, minMm / extent);
    if (maxMm != null) f = math.min(f, maxMm / extent);
    final ca = math.cos(angle), sa = math.sin(angle);
    for (final o in outlines) {
      final pts = [
        for (final (x, y) in o.points)
          (cx + (x * ca - y * sa) * f, cy + (x * sa + y * ca) * f),
      ];
      if (o.fill) {
        poly(
          g,
          pts,
          stroke: color.$2,
          fill: color.$1,
          width: 0.18,
          closed: true,
        );
      } else {
        poly(g, pts, stroke: color.$2, width: 0.18);
      }
    }
    return extent * f;
  }

  /// Cota en rojo de (`x1`, `y1`) a (`x2`, `y2`), con sus marcas.
  void dimension(PdfGraphics g, double x1, double y1, double x2, double y2) {
    line(g, x1, y1, x2, y2, color: _dim, width: 0.15);
    final len = math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
    if (len < 0.5) return;
    final ux = (x2 - x1) / len, uy = (y2 - y1) / len;
    for (final (x, y) in [(x1, y1), (x2, y2)]) {
      // Marca a 45°, como en arquitectura.
      final tx = (ux - uy) * 0.9, ty = (uy + ux) * 0.9;
      line(g, x - tx, y - ty, x + tx, y + ty, color: _dim, width: 0.25);
    }
  }

  void _frame(PdfGraphics g) {
    rect(g, 8, 8, 404, 281, width: 0.5);
    rect(g, 10, 10, 400, 277, width: 0.2);
    switch (kind) {
      case _Kind.compact:
        line(g, 284, 10, 284, 287);
        line(g, 10, 180, 284, 180);
        line(g, 166, 180, 166, 287);
      case _Kind.elevations:
        line(g, 284, 10, 284, 287);
        line(g, 10, 150, 284, 150);
      case _Kind.plan || _Kind.schedule:
        line(g, 284, 10, 284, 287);
      case _Kind.legend:
        break;
    }
  }

  // ── Planta ──────────────────────────────────────────────────────────────

  double get _planMm => 1000 / planScale;
  double get _planOx =>
      planBox!.x + (planBox!.w - (d.bounds.maxX - d.bounds.minX) * _planMm) / 2;
  double get _planOy =>
      planBox!.y + (planBox!.h - (d.bounds.maxY - d.bounds.minY) * _planMm) / 2;

  /// Un punto del modelo (metros, y arriba) en la hoja.
  (double, double) pm(List<dynamic> xy) => (
    _planOx + ((xy[0] as num) - d.bounds.minX) * _planMm,
    _planOy + (d.bounds.maxY - (xy[1] as num)) * _planMm,
  );

  /// Un rectángulo girado del modelo: centro, ancho, fondo y giro en grados
  /// (como `rotation` de la planta: 0 mira hacia arriba).
  List<(double, double)> _box(List at, double w, double dpt, double yawDeg) {
    final rad = yawDeg * math.pi / 180;
    final fx = math.sin(rad), fy = math.cos(rad);
    final rx = math.cos(rad), ry = -math.sin(rad);
    final cx = (at[0] as num).toDouble(), cy = (at[1] as num).toDouble();
    return [
      for (final (a, b) in [(-1, -1), (1, -1), (1, 1), (-1, 1)])
        pm([
          cx + rx * w / 2 * a + fx * dpt / 2 * b,
          cy + ry * w / 2 * a + fy * dpt / 2 * b,
        ]),
    ];
  }

  void _plan(PdfGraphics g) {
    final s = _planMm;
    // La nave: su planta y la rejilla de la cubierta, de fondo.
    for (final h in d.list('halls')) {
      final grid = h['roofGrid'] as Map?;
      if (grid != null) {
        final o = (grid['origin'] as List).cast<num>();
        final sx = (grid['stepX'] as num).toDouble();
        final sy = (grid['stepY'] as num).toDouble();
        final nx = (grid['nx'] as num).toInt();
        final ny = (grid['ny'] as num).toInt();
        for (var i = 0; i <= nx; i++) {
          final a = pm([o[0] + i * sx, o[1]]);
          final b = pm([o[0] + i * sx, o[1] + ny * sy]);
          line(g, a.$1, a.$2, b.$1, b.$2, color: _structLight, width: 0.15);
        }
        for (var j = 0; j <= ny; j++) {
          final a = pm([o[0], o[1] + j * sy]);
          final b = pm([o[0] + nx * sx, o[1] + j * sy]);
          line(g, a.$1, a.$2, b.$1, b.$2, color: _structLight, width: 0.15);
        }
      }
      final outline = [for (final q in (h['outline'] as List)) pm(q as List)];
      poly(g, outline, stroke: _struct, width: 0.3, closed: true);
    }
    // El decorado: muebles y atrezo, muy pálidos.
    for (final pr in d.list('props')) {
      final w = (pr['widthM'] as num?)?.toDouble() ?? 0.5;
      final dp = (pr['depthM'] as num?)?.toDouble() ?? 0.5;
      poly(
        g,
        _box(pr['at'] as List, w, dp, (pr['yawDeg'] as num?)?.toDouble() ?? 0),
        stroke: _decorLine,
        fill: _decor,
        width: 0.12,
        closed: true,
      );
    }
    // Paredes y su vidrio, en gris.
    for (final w in d.list('walls')) {
      final pts = [for (final q in (w['points'] as List)) pm(q as List)];
      final thick = 0.12 * s.clamp(2, 12);
      poly(g, pts, stroke: _struct, width: thick);
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
          width: thick + 0.1,
        );
        line(
          g,
          a.$1,
          a.$2,
          b.$1,
          b.$2,
          color: o['glass'] == true ? _glass : _structLight,
          width: 0.3,
        );
      }
    }
    // Telas: la onda de cortina.
    for (final dr in d.list('drapes')) {
      final samples = (dr['samples'] as List).cast<Map>();
      final pts = [for (final q in samples) pm(q['p'] as List)];
      final color = PdfColor.fromHex(dr['color'] as String);
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
    // Pilares, de la localización.
    for (final pl in d.list('pillars')) {
      final c = pm(pl['at'] as List);
      final r = math.max((pl['sizeM'] as num) * s / 2, 0.5);
      if (pl['shape'] == 'round') {
        circle(g, c.$1, c.$2, r, stroke: null, fill: _struct);
      } else {
        rect(g, c.$1 - r, c.$2 - r, r * 2, r * 2, stroke: null, fill: _struct);
      }
    }
    _planBeams(g, s);
    // Marcos, rebotes, banderas y telas de grip: una barra fina.
    for (final gp in d.list('grip')) {
      final w = (gp['widthM'] as num?)?.toDouble() ?? 1;
      final pts = _box(
        gp['at'] as List,
        w,
        0.05,
        (gp['yawDeg'] as num?)?.toDouble() ?? 0,
      );
      poly(g, pts, stroke: _ink, fill: _ink, width: 0.35, closed: true);
    }
    // Truss: dos cordones, diagonales y juntas.
    for (final t in d.list('trusses')) {
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
    for (final r in d.list('rigging')) {
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
    // Personas, si se piden.
    if (d.options.people) {
      for (final pe in d.list('people')) {
        final c = pm(pe['at'] as List);
        circle(g, c.$1, c.$2, 1.2, width: 0.25);
      }
    }
    _planStreetLamps(g, s);
    _planFixtures(g, s);
    _planDimensions(g);
    // Norte y barra de escala.
    final box = planBox!;
    final nx = box.x + box.w - 8, ny = box.y - 4;
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
    rect(g, box.x + 4, box.y + box.h + 2, bar, 1, stroke: null, fill: _ink);
    rect(g, box.x + 4 + bar, box.y + box.h + 2, bar, 1, width: 0.2);
  }

  /// Los haces en planta, antes que los aparatos y el rigging: hacia donde
  /// apuntan, o la huella en el suelo si miran abajo.
  void _planBeams(PdfGraphics g, double s) {
    for (final f in d.list('fixtures')) {
      if (f['on'] == false) continue;
      final pos = (f['pos'] as List).cast<num>();
      final aim = (f['aim'] as List).cast<num>();
      final dx = (aim[0] - pos[0]).toDouble();
      final dy = (aim[1] - pos[1]).toDouble();
      final dz = (aim[2] - pos[2]).toDouble();
      final hd = math.sqrt(dx * dx + dy * dy);
      final beamDeg = (f['beamDeg'] as num).toDouble();
      final c = pm(pos);
      if (hd < 0.3 && dz < 0) {
        if (!d.options.pools) continue;
        final half = math.min(beamDeg, 120) / 2 * math.pi / 180;
        final r = math.min(-dz * math.tan(half), 2.5) * s;
        if (r > 1) {
          poly(
            g,
            [
              for (var i = 0; i < 24; i++)
                (
                  c.$1 + r * math.cos(i * math.pi / 12),
                  c.$2 + r * math.sin(i * math.pi / 12),
                ),
            ],
            stroke: _beamLine,
            fill: _beam,
            fillOpacity: 0.14,
            width: 0.1,
            closed: true,
          );
        }
        continue;
      }
      if (hd < 0.3 || beamDeg >= 179 || !d.options.beams) continue;
      final angle = math.atan2(-dy, dx);
      final half = math.min(beamDeg, 100) / 2 * math.pi / 180;
      final reach = math.min(hd, 10.0) * s;
      poly(
        g,
        [
          c,
          (
            c.$1 + math.cos(angle - half) * reach,
            c.$2 + math.sin(angle - half) * reach,
          ),
          (
            c.$1 + math.cos(angle + half) * reach,
            c.$2 + math.sin(angle + half) * reach,
          ),
        ],
        stroke: _beamLine,
        fill: _beam,
        fillOpacity: 0.14,
        width: 0.1,
        closed: true,
      );
    }
  }

  /// Los aparatos: su dibujo, girado hacia donde apuntan. Lo que cuelga
  /// mirando al suelo se ve de frente.
  void _planFixtures(PdfGraphics g, double s) {
    for (final f in d.list('fixtures')) {
      final el = d.byId[f['id']];
      if (el == null) continue;
      final pos = (f['pos'] as List).cast<num>();
      final aim = (f['aim'] as List).cast<num>();
      final dx = (aim[0] - pos[0]).toDouble();
      final dy = (aim[1] - pos[1]).toDouble();
      final dz = (aim[2] - pos[2]).toDouble();
      final hd = math.sqrt(dx * dx + dy * dy);
      final tilt = math.atan2(dz, hd) * 180 / math.pi;
      final yaw = el.rotation * math.pi / 180;
      // Sin dirección en planta, la de su giro.
      final angle = hd > 0.01
          ? math.atan2(-dy, dx)
          : math.atan2(-math.cos(yaw), math.sin(yaw));
      var (family, size) = d.shapeOf(el, fixture: f);
      final flat = switch (family) {
        RigFamily.panel ||
        RigFamily.softbox ||
        RigFamily.cyc ||
        RigFamily.tube => tilt < -55,
        _ => tilt < -70,
      };
      if (!flat && tilt.abs() > 20) {
        // Inclinado: se ve más corto desde arriba.
        final c = math.cos(tilt * math.pi / 180).abs();
        size = (
          length: size.length * math.max(c, 0.45),
          width: size.width,
          height: size.height,
        );
      }
      final c = pm(pos);
      final extent = symbol(
        g,
        c.$1,
        c.$2,
        angle,
        RigSymbols.outline(
          family,
          size,
          view: flat ? RigView.face : RigView.side,
        ),
        s,
        d.colorOf(el),
        minMm: _minSymbolMm(s),
      );
      // Hacia dónde apunta, con una flecha que se lee sin el cono. Lo que
      // mira al suelo ya se ve de frente; una práctica alumbra alrededor.
      if (!flat && family != RigFamily.practical && hd > 0.01) {
        aimArrow(g, c.$1, c.$2, angle, extent / 2, d.colorOf(el).$2);
      }
    }
  }

  /// Lo mínimo que mide un aparato en la hoja: en un set grande (a 1:250 o
  /// más) los focos se dibujan más grandes que su escala para que se vean.
  static double _minSymbolMm(double mmPerM) => mmPerM < 4.5 ? 3.6 : 2.6;

  /// Flecha de dirección: sale del borde del aparato hacia donde apunta.
  void aimArrow(
    PdfGraphics g,
    double cx,
    double cy,
    double angle,
    double from,
    PdfColor color,
  ) {
    const length = 3.6, head = 1.1;
    final ca = math.cos(angle), sa = math.sin(angle);
    final a = (cx + ca * (from + 0.4), cy + sa * (from + 0.4));
    final b = (cx + ca * (from + length), cy + sa * (from + length));
    line(g, a.$1, a.$2, b.$1, b.$2, color: color, width: 0.3);
    poly(
      g,
      [
        (b.$1 + ca * head, b.$2 + sa * head),
        (b.$1 - sa * head * 0.55, b.$2 + ca * head * 0.55),
        (b.$1 + sa * head * 0.55, b.$2 - ca * head * 0.55),
      ],
      stroke: color,
      fill: color,
      width: 0.1,
      closed: true,
    );
  }

  /// Las farolas en planta: el brazo desde la fachada (o el báculo) hasta
  /// la luminaria, para que se vea de dónde salen y hacia dónde dan.
  void _planStreetLamps(PdfGraphics g, double s) {
    for (final f in d.list('fixtures')) {
      final el = d.byId[f['id']];
      if (el == null || !StreetLamp.isOn(el)) continue;
      final c = pm(f['pos'] as List);
      final r = el.rotation * math.pi / 180;
      // Hacia fuera de la fachada, en la hoja (y hacia abajo).
      final ux = math.sin(r), uy = -math.cos(r);
      final arm = math.max(0.8 * s, 2.4);
      final base = (c.$1 - ux * arm, c.$2 - uy * arm);
      final color = d.colorOf(el).$2;
      line(g, base.$1, base.$2, c.$1, c.$2, color: color, width: 0.35);
      if (StreetLamp.isPole(el)) {
        circle(g, base.$1, base.$2, 0.7, stroke: color, fill: color);
      } else {
        // La placa en la pared.
        line(
          g,
          base.$1 - uy * 0.9,
          base.$2 + ux * 0.9,
          base.$1 + uy * 0.9,
          base.$2 - ux * 0.9,
          color: color,
          width: 0.5,
        );
      }
    }
  }

  /// Las medidas de la nave (o de todo lo dibujado): ancho abajo y fondo a
  /// la izquierda.
  ({double minX, double maxX, double minY, double maxY}) get _measured {
    final halls = d.list('halls');
    if (halls.isEmpty) return d.bounds;
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final h in halls) {
      for (final q in (h['outline'] as List).cast<List>()) {
        final x = (q[0] as num).toDouble(), y = (q[1] as num).toDouble();
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }
    return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  void _planDimensions(PdfGraphics g) {
    final m = _measured;
    if (m.maxX - m.minX < 0.5 || m.maxY - m.minY < 0.5) return;
    final a = pm([m.minX, m.minY]), b = pm([m.maxX, m.maxY]);
    final (x, y) = _dimLines;
    dimension(g, a.$1, y, b.$1, y);
    line(g, a.$1, a.$2 + 0.5, a.$1, y + 1, color: _dim, width: 0.1);
    line(g, b.$1, a.$2 + 0.5, b.$1, y + 1, color: _dim, width: 0.1);
    dimension(g, x, b.$2, x, a.$2);
    line(g, a.$1 - 0.5, b.$2, x - 1, b.$2, color: _dim, width: 0.1);
    line(g, a.$1 - 0.5, a.$2, x - 1, a.$2, color: _dim, width: 0.1);
  }

  /// Dónde van las cotas: fuera de todo lo dibujado, para no pisar focos.
  (double, double) get _dimLines {
    final out = pm([d.bounds.minX, d.bounds.minY]);
    final a = pm([_measured.minX, _measured.minY]);
    return (math.min(a.$1, out.$1) - 4, math.max(a.$2, out.$2) + 4);
  }

  void _planDimensionLabels() {
    final m = _measured;
    if (m.maxX - m.minX < 0.5 || m.maxY - m.minY < 0.5) return;
    final a = pm([m.minX, m.minY]), b = pm([m.maxX, m.maxY]);
    final (x, y) = _dimLines;
    labels
      ..add(
        _Label(
          (a.$1 + b.$1) / 2 + 12,
          y - 0.6,
          '${_m(m.maxX - m.minX)} m',
          size: 5.5,
          color: _dim,
          width: 24,
          align: pw.TextAlign.right,
        ),
      )
      ..add(
        _Label(
          x - 1,
          (a.$2 + b.$2) / 2,
          '${_m(m.maxY - m.minY)} m',
          size: 5.5,
          color: _dim,
          width: 20,
          align: pw.TextAlign.right,
        ),
      );
  }

  /// Los textos de la planta: van en la capa de texto, que se monta antes
  /// de dibujar.
  void _planLabels() {
    final box = planBox!;
    if (d.showNumbers) {
      for (final f in d.list('fixtures')) {
        final unit = d.units[d.byId[f['id']]];
        if (unit == null) continue;
        final c = pm(f['pos'] as List);
        labels.add(
          _Label(
            c.$1 + 1.8,
            c.$2 - 1.4,
            '$unit',
            size: 5,
            bold: true,
            width: 8,
          ),
        );
      }
    }
    // Rótulos de los marcos y rebotes.
    for (final gp in d.list('grip')) {
      final name = gp['name'] as String?;
      if (name == null || name.isEmpty) continue;
      final c = pm(gp['at'] as List);
      labels.add(
        _Label(c.$1 + 1.5, c.$2 + 3, name, size: 4.5, color: _dim, width: 40),
      );
    }
    _planDimensionLabels();
    final nx = box.x + box.w - 8, ny = box.y - 4;
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
      ..add(_Label(box.x + 4, box.y + box.h + 6, '0', size: 6, width: 4))
      ..add(
        _Label(
          box.x + 4 + bar * 2 - 2,
          box.y + box.h + 6,
          '10 m',
          size: 6,
          width: 10,
        ),
      );
  }

  // ── Alzados ─────────────────────────────────────────────────────────────

  double _elevationX0(PlanElevation e, _Box box, int scale) {
    final s = 1000 / scale;
    return box.x + (box.w - _dimsW - (e.right - e.left) * s) / 2;
  }

  void _elevation(PdfGraphics g, PlanElevation e, _Box box, int scale) {
    final s = 1000 / scale;
    final x0 = _elevationX0(e, box, scale);
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
            stroke: _struct,
            fill: const PdfColor.fromInt(0xFFF1F3F5),
            width: 0.2,
          );
        case ElevationKind.opening:
          rect(
            g,
            x,
            y,
            w,
            h,
            stroke: _struct,
            fill: PdfColors.white,
            width: 0.15,
          );
        case ElevationKind.drape:
          final pts = [
            for (final (across, top, _) in item.profile) at(across, top),
            for (final (across, _, bottom) in item.profile.reversed)
              at(across, bottom),
          ];
          poly(
            g,
            pts,
            stroke: const PdfColor(0.55, 0.11, 0.17),
            fill: const PdfColor(0.55, 0.11, 0.17),
            fillOpacity: 0.25,
            width: 0.15,
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
          // Encima de todo, después.
          break;
        case ElevationKind.actor when !d.options.people:
          break;
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
          if (d.options.people) rect(g, x, y, w, h, fill: _ink, width: 0.2);
        case ElevationKind.prop:
          rect(g, x, y, w, h, stroke: _decorLine, fill: _decor, width: 0.12);
      }
    }
    // Los haces, sobre paredes y telas (son claros) y bajo los aparatos.
    for (final item in e.items) {
      if (!d.options.beams) break;
      if (item.kind != ElevationKind.light) continue;
      if (PlanGrip.isGrip(item.element)) continue;
      final aim = d.aimIn(item, e.side);
      if (aim == null || item.beamDeg >= 179) continue;
      final z = d.heightOf(item);
      final c = at(item.centre, z);
      final half = item.beamDeg / 2 * math.pi / 180;
      // Cada borde del haz llega a su alcance o al suelo, lo que antes.
      (double, double) edge(double a) {
        var reach = item.reachM;
        if (math.sin(a) < -0.01) reach = math.min(reach, z / -math.sin(a));
        return (c.$1 + math.cos(a) * reach * s, c.$2 - math.sin(a) * reach * s);
      }

      poly(
        g,
        [c, edge(aim - half), edge(aim + half)],
        stroke: _beamLine,
        fill: _beam,
        fillOpacity: 0.14,
        width: 0.1,
        closed: true,
      );
    }
    // Los aparatos, por encima de telas y paredes para que se vean.
    for (final item in e.items) {
      if (item.kind == ElevationKind.light) {
        _elevationLight(g, item, at, s, e.side);
      }
    }
    // Cotas de altura en rojo, a la derecha.
    final right = x0 + (e.right - e.left) * s;
    for (final (i, z) in _heights(e).indexed) {
      final dx = right + 4 + i * _dimStep;
      final top = floor - z * s;
      dimension(g, dx, floor, dx, top);
    }
  }

  void _elevationLight(
    PdfGraphics g,
    ElevationItem item,
    (double, double) Function(double, double) at,
    double s,
    ElevationSide side,
  ) {
    final el = item.element;
    if (PlanGrip.isGrip(el)) {
      // Un marco, rebote o bandera: su tela de canto, a su altura.
      final span = PlanGrip.span(el, d.mpu);
      final a = at(item.centre, span.bottom), b = at(item.centre, span.top);
      rect(g, a.$1 - 0.5, b.$2, 1, a.$2 - b.$2, fill: _ink, width: 0.1);
      return;
    }
    final z = d.heightOf(item);
    final c = at(item.centre, z);
    if (StreetLamp.isOn(el)) {
      _elevationStreetLamp(g, item, at, s, side, z);
      return;
    }
    // En pie: el mástil y las patas hasta el suelo.
    if (d.onStand(el) && z > 0.3) {
      final foot = at(item.centre, 0);
      final knee = at(item.centre, math.min(0.6, z * 0.4));
      line(g, c.$1, c.$2, knee.$1, knee.$2, color: _muted, width: 0.2);
      for (final dx in [-0.45, 0.45]) {
        final f = at(item.centre + dx, 0);
        line(g, knee.$1, knee.$2, f.$1, foot.$2, color: _muted, width: 0.2);
      }
      line(g, knee.$1, knee.$2, foot.$1, foot.$2, color: _muted, width: 0.2);
    }
    final (family, size) = d.shapeOf(el, fixture: d.fixtureOf[el]);
    final aim = d.aimIn(item, side);
    final extent = symbol(
      g,
      c.$1,
      c.$2,
      aim == null ? 0 : -aim,
      RigSymbols.outline(
        family,
        size,
        view: aim == null ? RigView.face : RigView.side,
        elevation: true,
      ),
      s,
      d.colorOf(el),
      minMm: _minSymbolMm(s),
    );
    if (aim != null && family != RigFamily.practical) {
      aimArrow(g, c.$1, c.$2, -aim, extent / 2, d.colorOf(el).$2);
    }
  }

  /// Una farola de lado: el báculo desde el suelo o el brazo desde la
  /// fachada, y la luminaria mirando al suelo.
  void _elevationStreetLamp(
    PdfGraphics g,
    ElevationItem item,
    (double, double) Function(double, double) at,
    double s,
    ElevationSide side,
    double z,
  ) {
    final el = item.element;
    final color = d.colorOf(el);
    final r = el.rotation * math.pi / 180;
    // Hacia fuera de la fachada, en lo que se ve de este lado.
    final out = side == ElevationSide.front ? math.sin(r) : math.cos(r);
    const armM = 0.8;
    final head = at(item.centre, z);
    final elbow = at(item.centre - out * armM, z + 0.25);
    if (StreetLamp.isPole(el)) {
      final foot = at(item.centre - out * armM, 0);
      line(g, foot.$1, foot.$2, elbow.$1, elbow.$2, color: _ink, width: 0.45);
    } else {
      // La placa de la pared.
      final plate = at(item.centre - out * armM, z + 0.45);
      final low = at(item.centre - out * armM, z + 0.05);
      line(g, plate.$1, plate.$2, low.$1, low.$2, color: _ink, width: 0.6);
    }
    line(g, elbow.$1, elbow.$2, head.$1, head.$2, color: _ink, width: 0.35);
    // La luminaria: una campana que abre hacia abajo.
    final w = math.max(0.35 * s, 1.6), h = math.max(0.18 * s, 0.9);
    poly(
      g,
      [
        (head.$1 - w * 0.25, head.$2 - h * 0.5),
        (head.$1 + w * 0.25, head.$2 - h * 0.5),
        (head.$1 + w * 0.5, head.$2 + h * 0.5),
        (head.$1 - w * 0.5, head.$2 + h * 0.5),
      ],
      stroke: color.$2,
      fill: color.$1,
      width: 0.18,
      closed: true,
    );
  }

  /// Las alturas que se acotan: cada nivel de truss y cada foco, sin
  /// repetir las que están a menos de 25 cm. Como mucho 6, las más altas.
  List<double> _heights(PlanElevation e) {
    final raw = <double>[
      for (final i in e.items)
        if (i.kind == ElevationKind.truss)
          i.bottom
        else if (i.kind == ElevationKind.light && !PlanGrip.isGrip(i.element))
          d.heightOf(i),
    ]..sort();
    final out = <double>[];
    for (final z in raw) {
      if (z < 0.3) continue;
      if (out.isEmpty || z - out.last > 0.25) out.add(z);
    }
    return out.length <= 6 ? out : out.sublist(out.length - 6);
  }

  void _elevationLabels(PlanElevation e, _Box box, int scale) {
    final s = 1000 / scale;
    final floor = box.y + box.h - 6;
    final x0 = _elevationX0(e, box, scale);
    final right = x0 + (e.right - e.left) * s;
    for (final (i, z) in _heights(e).indexed) {
      final dx = right + 4 + i * _dimStep;
      labels.add(
        _Label(
          dx + 0.6,
          floor - z * s - 0.6,
          _m(z),
          size: 4.5,
          color: _dim,
          width: 10,
        ),
      );
    }
    // Rótulos de marcos y rebotes, sobre su tela.
    for (final item in e.items) {
      if (item.kind != ElevationKind.light) continue;
      if (!PlanGrip.isGrip(item.element)) continue;
      final name = item.element.customName;
      if (name == null) continue;
      final top = PlanGrip.span(item.element, d.mpu).top;
      labels.add(
        _Label(
          x0 + (item.centre - e.left) * s + 1,
          floor - top * s - 1,
          name,
          size: 4.5,
          color: _dim,
          width: 40,
        ),
      );
    }
    if (!d.showNumbers) return;
    for (final item in e.items) {
      if (item.kind != ElevationKind.light) continue;
      final unit = d.units[item.element];
      if (unit == null) continue;
      final cx = x0 + (item.centre - e.left) * s;
      final cy = floor - d.heightOf(item) * s;
      labels.add(
        _Label(cx + 1.8, cy - 1.6, '$unit', size: 4.5, bold: true, width: 8),
      );
    }
  }

  // ── Textos, leyenda y cajetín ───────────────────────────────────────────

  void _layoutTexts() {
    if (kind == _Kind.legend) {
      _fullLegend();
      _titleBlock();
      return;
    }
    if (kind == _Kind.schedule) {
      _schedule();
      _legend(16);
      _titleBlock();
      return;
    }
    void title(double x, double y, String text, int scale) => labels
      ..add(_Label(x, y, text, size: 10, bold: true, width: 160))
      ..add(
        _Label(
          x,
          y + 4,
          'ESCALA ${scaleLabel(scale)}',
          size: 6,
          color: _muted,
          width: 60,
        ),
      );
    if (planBox case final box?) {
      final b = d.bounds;
      planScale = RigSheetPdf.scaleFor(
        b.maxX - b.minX + 2,
        b.maxY - b.minY + 2,
        box.w - 12,
        box.h - 10,
      );
      title(box.x, 16, 'PLANTA DE LUZ Y RIGGING', planScale);
      _planLabels();
    }
    for (final (box, e, name, isFront) in [
      (frontBox, d.front, 'ALZADO FRONTAL', true),
      (sideBox, d.profile, 'PERFIL LATERAL', false),
    ]) {
      if (box == null) continue;
      final scale = RigSheetPdf.scaleFor(
        e.right - e.left + 1,
        e.height,
        box.w - 8 - _dimsW,
        box.h - 10,
      );
      if (isFront) {
        frontScale = scale;
      } else {
        sideScale = scale;
      }
      title(box.x, box.y - 8, name, scale);
      _elevationLabels(e, box, scale);
    }

    final y = _legend(16);
    if (kind != _Kind.elevations) _structure(y);
    _titleBlock();
  }

  /// La leyenda de la columna derecha. Devuelve dónde acaba.
  double _legend(double top) {
    var y = top;
    final x = column.x;
    labels.add(_Label(x, y, 'LEYENDA', size: 10, bold: true));
    y += 6;
    _legendHeader(x, y);
    y += 5;
    final rows = d.legend.rows;
    final shown = d.legendOverflows
        ? rows.take(_Data.legendRowsInColumn - 1).toList()
        : rows;
    for (final row in shown) {
      _legendRow(x, y, row);
      y += 8;
    }
    if (d.legendOverflows) {
      labels.add(
        _Label(
          x + 22,
          y,
          '… y ${rows.length - shown.length} modelos más: '
          'leyenda completa en la hoja $count',
          size: 5.5,
          color: _muted,
          width: 98,
        ),
      );
      y += 5;
    }
    return _legendTotal(x, y);
  }

  void _legendHeader(double x, double y) {
    labels
      ..add(_Label(x + 22, y, 'APARATO', size: 5.5, color: _muted, width: 60))
      ..add(
        _Label(
          x + 92,
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
          x + 108,
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
          width: 14,
          align: pw.TextAlign.right,
        ),
      );
  }

  void _legendRow(double x, double y, LightLegendRow row) {
    final el = _elementOf(row);
    if (el != null) _legendIcons.add((x, y - 1.2, el));
    labels
      ..add(_Label(x + 22, y, row.name, size: 6.5, bold: true, width: 66))
      ..add(
        _Label(
          x + 22,
          y + 3,
          d.showNumbers ? row.unitsLabel : (row.symbol?.label ?? ''),
          size: 5,
          color: _muted,
          width: 66,
        ),
      )
      ..add(
        _Label(
          x + 92,
          y,
          '${row.count}',
          size: 6.5,
          width: 10,
          align: pw.TextAlign.right,
        ),
      )
      ..add(
        _Label(
          x + 108,
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
          width: 14,
          align: pw.TextAlign.right,
        ),
      );
  }

  double _legendTotal(double x, double y) {
    final watts = d.legend.watts;
    final count = d.legend.rows.fold<int>(0, (a, r) => a + r.count);
    labels
      ..add(
        _Label(x + 22, y + 1, 'TOTAL · $count aparatos', size: 7, bold: true),
      )
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
          x + 22,
          y + 5,
          'unos ${(watts / 230).toStringAsFixed(0)} A en monofásica · '
          '${(watts / 3 / 230).toStringAsFixed(0)} A por fase (trifásica 400 V)',
          size: 5.5,
          color: _muted,
          width: 98,
        ),
      );
    return y + 13;
  }

  PlanElement? _elementOf(LightLegendRow row) {
    for (final el in d.units.keys) {
      if (d.modelOf(el) == row.name) return el;
    }
    return null;
  }

  /// Estructura y avisos, si caben sobre el cajetín.
  void _structure(double top) {
    var y = top;
    final x = column.x;
    final rigging = RigReport.rigging(d.elements, d.mpu);
    if (rigging.isNotEmpty && y < 200) {
      labels.add(_Label(x, y, 'ESTRUCTURA', size: 8.5, bold: true));
      y += 5;
      for (final lineItem in rigging) {
        if (y > 222) break;
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
    final warnings = RigReport.warnings(d.elements, d.mpu);
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
  }

  /// Accesorios de un foco: difusiones, gelatinas, rejillas…
  static String accessoriesOf(PlanElement el) => [
    for (final id in (el.props[PlanLight.modifiersKey] as List? ?? const []))
      if (LightModifier.byId(id?.toString()) case final m?)
        m.reference ?? m.name,
  ].join(' · ');

  /// Cómo va montado.
  String _mountOf(PlanElement el) {
    if (TrussMagnet.trussUidOf(el) != null) return 'Truss';
    if (PlanLight.isOverhead(el)) return 'Techo';
    if (LightWallMount.isOn(el)) return 'Pared';
    return 'Pie';
  }

  /// La lista de focos: uno por fila, con lo que necesita el eléctrico para
  /// montarlo.
  void _schedule() {
    labels.add(const _Label(14, 20, 'LISTA DE FOCOS', size: 12, bold: true));
    const cols = <(double, String, double, bool)>[
      (14, 'Nº', 8, true),
      (24, 'APARATO', 70, false),
      (96, 'ACCESORIOS', 84, false),
      (182, 'MONTAJE', 24, false),
      (220, 'ALTURA', 14, true),
      (246, 'CIRC.', 14, true),
      (274, 'W', 18, true),
    ];
    for (final (x, title, w, right) in cols) {
      labels.add(
        _Label(
          x,
          30,
          title,
          size: 5.5,
          color: _muted,
          width: w,
          align: right ? pw.TextAlign.right : pw.TextAlign.left,
        ),
      );
    }
    final rows = d.numbered.skip(from).take(_Data.scheduleRows);
    for (final (i, (n, el)) in rows.indexed) {
      final y = 36 + i * 6.0;
      _scheduleIcons.add((y - 1, el));
      final circuit = (el.props['circuit'] as num?)?.toInt();
      final f = d.fixtureOf[el];
      final z = f == null ? null : ((f['pos'] as List)[2] as num).toDouble();
      final watts = (el.props[PlanLight.wattsKey] as num?)?.toDouble();
      final values = [
        '$n',
        d.modelOf(el),
        accessoriesOf(el),
        _mountOf(el),
        z == null ? '' : '${_m(z)} m',
        circuit == null ? '' : 'C$circuit',
        watts == null ? '' : '${watts.round()}',
      ];
      for (final ((x, _, w, right), value) in [
        for (var c = 0; c < cols.length; c++) (cols[c], values[c]),
      ]) {
        labels.add(
          _Label(
            x,
            y,
            value,
            size: 6,
            bold: x == 14,
            width: w,
            align: right ? pw.TextAlign.right : pw.TextAlign.left,
          ),
        );
      }
    }
    final last = math.min(from + _Data.scheduleRows, d.numbered.length);
    labels.add(
      _Label(
        14,
        282,
        'Focos ${from + 1}–$last de ${d.numbered.length}. '
        'Los circuitos son los del reparto eléctrico de la planta.',
        size: 5.5,
        color: _muted,
        width: 260,
      ),
    );
  }

  final _scheduleIcons = <(double, PlanElement)>[];

  /// La leyenda entera, en tres columnas, en su propia hoja.
  void _fullLegend() {
    labels.add(
      const _Label(14, 20, 'LEYENDA DE APARATOS', size: 12, bold: true),
    );
    const colW = 130.0;
    const perColumn = 26;
    for (final (i, row) in d.legend.rows.indexed) {
      final col = i ~/ perColumn;
      if (col > 2) break;
      final x = 12 + col * colW;
      if (i % perColumn == 0) _legendHeader(x, 30);
      _legendRow(x, 36 + (i % perColumn) * 7.6, row);
    }
    _legendTotal(12, 240);
  }

  /// Los dos dibujos de un modelo: desde arriba y de lado.
  void _drawIcons(PdfGraphics g, double x, double y, PlanElement el) {
    final (family, size) = d.shapeOf(el);
    final color = d.colorOf(el);
    final top = switch (family) {
      RigFamily.panel || RigFamily.softbox || RigFamily.cyc => RigView.face,
      _ => RigView.side,
    };
    symbol(
      g,
      x + 6,
      y,
      top == RigView.face ? math.pi / 2 : 0,
      RigSymbols.outline(family, size, view: top),
      0,
      color,
      minMm: 5.4,
      maxMm: 5.4,
    );
    symbol(
      g,
      x + 15,
      y,
      math.pi / 2,
      RigSymbols.outline(family, size, elevation: true),
      0,
      color,
      minMm: 5.4,
      maxMm: 5.4,
    );
  }

  /// El marco del cajetín.
  void _titleFrame(PdfGraphics g) {
    const top = 236.0;
    rect(g, 284, top, 126, 51, width: 0.4);
    for (final y in [top + 13, top + 22, top + 31, top + 40]) {
      line(g, 284, y, 410, y, width: 0.15);
    }
    line(g, 347, top + 13, 347, 287, width: 0.15);
  }

  void _titleBlock() {
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
            value.isEmpty ? '—' : value,
            size: big ? 11 : 7,
            bold: big,
            width: big ? 100 : 60,
          ),
        );
    }

    final info = d.info;
    final scales = <String>[
      if (planBox != null) 'P ${scaleLabel(planScale)}',
      if (frontBox != null) 'A ${scaleLabel(frontScale)}',
      if (sideBox != null) 'L ${scaleLabel(sideScale)}',
    ].join(' · ');
    cell(287, top + 3, 'PROYECTO', info.project, big: true);
    cell(
      287,
      top + 16,
      'SET · LOCALIZACIÓN',
      [info.set, info.location].where((s) => s.isNotEmpty).join(' · '),
    );
    cell(350, top + 16, 'ESQUEMA DE LUZ', info.scheme);
    cell(287, top + 25, 'ESCENAS', info.scenes);
    cell(350, top + 25, 'JORNADA', info.shootDay);
    cell(287, top + 34, 'GAFFER', info.gaffer);
    cell(
      350,
      top + 34,
      'FECHA',
      '${info.date.day.toString().padLeft(2, '0')}/'
          '${info.date.month.toString().padLeft(2, '0')}/${info.date.year}',
    );
    cell(287, top + 42.5, 'ESCALAS', scales);
    cell(
      350,
      top + 42.5,
      'HOJA',
      '$index / $count · ${d.options.paper.label} · REV. ${info.revision}',
    );
    labels.add(
      const _Label(
        408,
        top + 3,
        'IRIS',
        size: 11,
        bold: true,
        width: 20,
        align: pw.TextAlign.right,
      ),
    );
  }

  static String _m(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
}
