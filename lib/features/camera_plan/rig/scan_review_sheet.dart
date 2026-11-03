import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../camera_plan_constants.dart';
import 'scan_review.dart';
import 'scan_structure.dart';

/// Busca la foto de la captura que enseña una propuesta: su archivo y dónde
/// cae en ella. Null si no hay captura en este equipo.
typedef ReviewPhotoFinder =
    Future<({String path, PhotoView view})?> Function(ReviewItem item);

/// Lo que devuelve la revisión: las propuestas con lo decidido y la altura
/// del techo.
class ScanReviewResult {
  final List<ReviewItem> items;
  final double heightM;
  const ScanReviewResult(this.items, this.heightM);
}

/// Revisión del escaneo (ES.3, opción «A con la foto de B»): toda la casa
/// sobre el lienzo, lo seguro en el color de la app y lo dudoso en ámbar. Al
/// tocar algo sale su ficha y, si hay captura, la foto real del sitio.
class ScanReviewSheet extends StatefulWidget {
  final ScanStructure structure;
  final List<(Offset, Offset)> cut;
  final Uint8List? topPng;
  final Rect? topRect;
  final ReviewPhotoFinder? findPhoto;

  const ScanReviewSheet({
    super.key,
    required this.structure,
    this.cut = const [],
    this.topPng,
    this.topRect,
    this.findPhoto,
  });

  static Future<ScanReviewResult?> show(
    BuildContext context, {
    required ScanStructure structure,
    List<(Offset, Offset)> cut = const [],
    Uint8List? topPng,
    Rect? topRect,
    ReviewPhotoFinder? findPhoto,
  }) => showDialog<ScanReviewResult>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox(
        width: 1100,
        height: 720,
        child: ScanReviewSheet(
          structure: structure,
          cut: cut,
          topPng: topPng,
          topRect: topRect,
          findPhoto: findPhoto,
        ),
      ),
    ),
  );

  @override
  State<ScanReviewSheet> createState() => _ScanReviewSheetState();
}

class _ScanReviewSheetState extends State<ScanReviewSheet> {
  late final List<ReviewItem> _items = reviewItems(widget.structure);
  late double _height = widget.structure.heightM;
  ui.Image? _top;
  ReviewItem? _selected;
  ({String path, PhotoView view})? _photo;
  bool _photoLoading = false;

  @override
  void initState() {
    super.initState();
    final png = widget.topPng;
    if (png != null) {
      ui.decodeImageFromList(png, (img) {
        if (mounted) setState(() => _top = img);
      });
    }
    // Empieza por lo primero dudoso: es lo que hay que mirar.
    final first = _items.where((it) => it.dubious).firstOrNull;
    if (first != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _select(first);
      });
    }
  }

  Future<void> _select(ReviewItem? item) async {
    setState(() {
      _selected = item;
      _photo = null;
      _photoLoading = item != null && widget.findPhoto != null;
    });
    final find = widget.findPhoto;
    if (item == null || find == null) return;
    final photo = await find(item);
    if (!mounted || _selected != item) return;
    setState(() {
      _photo = photo;
      _photoLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = AppTypography.caption(
      palette,
    ).copyWith(color: palette.textTertiary);
    final accepted = _items.where((it) => it.accepted).length;
    final doubts = _items.where((it) => it.dubious && it.accepted).length;
    int count(ReviewKind k) =>
        _items.where((it) => it.kind == k && it.accepted).length;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revisar el escaneo', style: AppTypography.titleMedium(palette)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Lo que IRIS ha entendido del escaneo. En ámbar lo dudoso: '
            'tócalo para ver la foto del sitio y decidir. Toca cualquier cosa '
            'para quitarla o corregir sus medidas.',
            style: caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _canvas(palette)),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 330,
                  child: _selected == null
                      ? _summary(palette, count)
                      : _detail(palette, _selected!),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  doubts == 0
                      ? '$accepted elementos aceptados'
                      : '$accepted aceptados · $doubts dudosos sin mirar',
                  style: AppTypography.mono(palette),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: accepted == 0
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(ScanReviewResult(_items, _height)),
                child: Text('Añadir $accepted a la planta'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _canvas(AppPalette palette) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: ColoredBox(
      color: const Color(0xFF1E1E1C),
      child: LayoutBuilder(
        builder: (context, box) {
          final painter = _ReviewPainter(
            s: widget.structure,
            items: _items,
            cut: widget.cut,
            top: _top,
            topRect: widget.topRect,
            selected: _selected,
            sure: palette.accent,
            doubt: palette.warning,
            off: palette.error,
            object: const Color(0xFFAFA9EC),
          );
          return GestureDetector(
            onTapUp: (e) => _select(painter.hit(e.localPosition, box.biggest)),
            child: CustomPaint(size: box.biggest, painter: painter),
          );
        },
      ),
    ),
  );

  Widget _summary(AppPalette palette, int Function(ReviewKind) count) {
    final s = widget.structure;
    Widget line(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(text, style: AppTypography.bodyMedium(palette)),
    );
    return ListView(
      children: [
        line('${count(ReviewKind.wall)} paredes'),
        line('${count(ReviewKind.door)} puertas'),
        line('${count(ReviewKind.window)} ventanas'),
        if (count(ReviewKind.passage) > 0)
          line('${count(ReviewKind.passage)} pasos'),
        line('${count(ReviewKind.object)} muebles'),
        const SizedBox(height: AppSpacing.md),
        _number(
          palette,
          s.heightEstimated ? 'Techo (estimado)' : 'Techo',
          _height,
          (v) => _height = v,
        ),
        if (s.heightEstimated)
          Text(
            'El techo no se vio en el escaneo: mídelo si puedes.',
            style: AppTypography.caption(palette),
          ),
      ],
    );
  }

  Widget _detail(AppPalette palette, ReviewItem it) {
    final caption = AppTypography.caption(palette);
    final percent = (it.confidence * 100).round();
    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(it.label, style: AppTypography.titleMedium(palette)),
            ),
            IconButton(
              tooltip: 'Cerrar',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => _select(null),
            ),
          ],
        ),
        Text(
          it.dubious
              ? 'Dudoso ($percent %): mira la foto'
              : 'Seguro ($percent %)',
          style: caption.copyWith(
            color: it.dubious ? palette.warning : palette.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _photoBox(palette),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Sí, va')),
            ButtonSegment(value: false, label: Text('No')),
          ],
          selected: {it.accepted},
          onSelectionChanged: (v) => setState(() => it.accepted = v.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._fields(palette, it),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _next,
            child: const Text('Siguiente dudoso'),
          ),
        ),
      ],
    );
  }

  void _next() {
    final doubts = _items.where((it) => it.dubious).toList();
    if (doubts.isEmpty) {
      _select(null);
      return;
    }
    final i = doubts.indexOf(_selected ?? doubts.last);
    _select(doubts[(i + 1) % doubts.length]);
  }

  List<Widget> _fields(AppPalette palette, ReviewItem it) => switch (it.kind) {
    ReviewKind.wall => [
      _number(palette, 'Grosor', it.thickness, (v) => it.thickness = v),
    ],
    ReviewKind.door || ReviewKind.passage => [
      _number(palette, 'Ancho', it.width, (v) => it.width = v),
      _number(palette, 'Alto', it.head, (v) => it.head = v),
    ],
    ReviewKind.window => [
      _number(palette, 'Ancho', it.width, (v) => it.width = v),
      _number(palette, 'Alféizar', it.sill, (v) => it.sill = v),
      _number(palette, 'Dintel', it.head, (v) => it.head = v),
    ],
    ReviewKind.object => [
      DropdownButton<PropType>(
        value: it.propType,
        isExpanded: true,
        items: const [
          DropdownMenuItem(value: PropType.rectangle, child: Text('Mueble')),
          DropdownMenuItem(value: PropType.bed, child: Text('Cama')),
          DropdownMenuItem(value: PropType.table, child: Text('Mesa')),
          DropdownMenuItem(value: PropType.sofa, child: Text('Sofá')),
          DropdownMenuItem(value: PropType.chair, child: Text('Silla')),
        ],
        onChanged: (v) => setState(() => it.propType = v ?? it.propType),
      ),
      _number(palette, 'Ancho', it.width, (v) => it.width = v),
      _number(palette, 'Fondo', it.depth, (v) => it.depth = v),
      _number(palette, 'Alto', it.height, (v) => it.height = v),
    ],
  };

  Widget _number(
    AppPalette palette,
    String label,
    double value,
    ValueChanged<double> set,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      children: [
        Expanded(child: Text(label, style: AppTypography.bodyMedium(palette))),
        SizedBox(
          width: 90,
          child: TextFormField(
            key: ValueKey('$label-${identityHashCode(_selected)}'),
            initialValue: value.toStringAsFixed(2),
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(isDense: true, suffixText: 'm'),
            onChanged: (t) {
              final v = double.tryParse(t.replaceAll(',', '.'));
              if (v != null && v >= 0 && v < 50) setState(() => set(v));
            },
          ),
        ),
      ],
    ),
  );

  Widget _photoBox(AppPalette palette) {
    if (widget.findPhoto == null) {
      return Text(
        'Sin fotos: la captura del iPhone no está en este equipo.',
        style: AppTypography.caption(palette),
      );
    }
    if (_photoLoading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final photo = _photo;
    if (photo == null) {
      return Text(
        'Ninguna foto de la captura enseña este sitio.',
        style: AppTypography.caption(palette),
      );
    }
    final f = photo.view.frame;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: f.width / f.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(photo.path), fit: BoxFit.fill),
                CustomPaint(
                  painter: _PhotoMarkPainter(photo.view, palette.warning),
                ),
              ],
            ),
          ),
        ),
        Text(f.file, style: AppTypography.caption(palette)),
      ],
    );
  }
}

/// El contorno de la propuesta sobre la foto.
class _PhotoMarkPainter extends CustomPainter {
  final PhotoView view;
  final Color color;
  _PhotoMarkPainter(this.view, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final k = Offset(
      size.width / view.frame.width,
      size.height / view.frame.height,
    );
    Offset map(Offset p) => Offset(p.dx * k.dx, p.dy * k.dy);
    final outline = view.pixels.skip(1).whereType<Offset>().map(map).toList();
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    if (outline.length >= 2) {
      canvas.drawPath(Path()..addPolygon(outline, true), paint);
    }
    final c = view.pixels.first;
    if (c != null) canvas.drawCircle(map(c), 6, paint);
  }

  @override
  bool shouldRepaint(_PhotoMarkPainter old) => old.view != view;
}

class _ReviewPainter extends CustomPainter {
  final ScanStructure s;
  final List<ReviewItem> items;
  final List<(Offset, Offset)> cut;
  final ui.Image? top;
  final Rect? topRect;
  final ReviewItem? selected;
  final Color sure, doubt, off, object;

  _ReviewPainter({
    required this.s,
    required this.items,
    required this.cut,
    required this.top,
    required this.topRect,
    required this.selected,
    required this.sure,
    required this.doubt,
    required this.off,
    required this.object,
  });

  /// De metros a la pantalla, con margen y sin deformar.
  (Offset Function(Offset), double) _map(Size size) {
    var lo = const Offset(double.infinity, double.infinity);
    var hi = const Offset(-double.infinity, -double.infinity);
    void grow(Offset p) {
      lo = Offset(math.min(lo.dx, p.dx), math.min(lo.dy, p.dy));
      hi = Offset(math.max(hi.dx, p.dx), math.max(hi.dy, p.dy));
    }

    for (final w in s.walls) {
      grow(w.start);
      grow(w.end);
    }
    for (final o in s.objects) {
      grow(o.center);
    }
    if (lo.dx == double.infinity) {
      for (final c in cut) {
        grow(c.$1);
        grow(c.$2);
      }
    }
    if (lo.dx == double.infinity) return ((p) => p, 1);
    const pad = 24.0;
    final span = hi - lo;
    final k = math.min(
      (size.width - 2 * pad) / math.max(span.dx, 0.01),
      (size.height - 2 * pad) / math.max(span.dy, 0.01),
    );
    final origin =
        const Offset(pad, pad) +
        Offset(
          (size.width - 2 * pad - span.dx * k) / 2,
          (size.height - 2 * pad - span.dy * k) / 2,
        );
    return ((Offset p) => origin + (p - lo) * k, k);
  }

  Color _colorOf(ReviewItem it) {
    if (!it.accepted) return off.withValues(alpha: 0.45);
    if (it.kind == ReviewKind.object && !it.dubious) return object;
    return it.dubious ? doubt : sure;
  }

  (Offset, Offset) _openingSpan(ReviewItem it) {
    final o = s.openings[it.index];
    final d = s.walls[o.wall].dir * (it.width / 2);
    return (o.center - d, o.center + d);
  }

  List<Offset> _box(ReviewItem it) {
    final o = s.objects[it.index];
    final r = o.rotationDeg * math.pi / 180;
    final u = Offset(math.cos(r), math.sin(r)) * (it.width / 2);
    final v = Offset(-math.sin(r), math.cos(r)) * (it.depth / 2);
    return [
      o.center - u - v,
      o.center + u - v,
      o.center + u + v,
      o.center - u + v,
    ];
  }

  ReviewItem? hit(Offset at, Size size) {
    final (map, _) = _map(size);
    double toSegment(Offset a, Offset b) {
      final ab = b - a;
      final t = ab.distanceSquared == 0
          ? 0.0
          : (((at - a).dx * ab.dx + (at - a).dy * ab.dy) / ab.distanceSquared)
                .clamp(0.0, 1.0);
      return (a + ab * t - at).distance;
    }

    // Primero los huecos, que van encima de las paredes.
    for (final kind in [
      {ReviewKind.door, ReviewKind.window, ReviewKind.passage},
      {ReviewKind.object},
      {ReviewKind.wall},
    ]) {
      ReviewItem? best;
      var bestD = 14.0;
      for (final it in items.where((it) => kind.contains(it.kind))) {
        final double d;
        if (it.kind == ReviewKind.wall) {
          final w = s.walls[it.index];
          d = toSegment(map(w.start), map(w.end));
        } else if (it.kind == ReviewKind.object) {
          final pts = _box(it).map(map).toList();
          d = (Path()..addPolygon(pts, true)).contains(at)
              ? 0
              : List.generate(
                  4,
                  (i) => toSegment(pts[i], pts[(i + 1) % 4]),
                ).reduce(math.min);
        } else {
          final (a, b) = _openingSpan(it);
          d = toSegment(map(a), map(b));
        }
        if (d < bestD) {
          bestD = d;
          best = it;
        }
      }
      if (best != null) return best;
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final (map, k) = _map(size);
    final img = top, rect = topRect;
    if (img != null && rect != null) {
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromPoints(map(rect.topLeft), map(rect.bottomRight)),
        Paint()..color = const Color(0x99FFFFFF),
      );
    }
    final faint = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 1;
    for (final c in cut) {
      canvas.drawLine(map(c.$1), map(c.$2), faint);
    }
    for (final it in items) {
      final chosen = identical(it, selected);
      final paint = Paint()
        ..color = _colorOf(it)
        ..strokeCap = StrokeCap.butt
        ..style = PaintingStyle.stroke;
      switch (it.kind) {
        case ReviewKind.wall:
          final w = s.walls[it.index];
          paint.strokeWidth = math.max(3, it.thickness * k);
          if (chosen) _halo(canvas, map(w.start), map(w.end), paint);
          canvas.drawLine(map(w.start), map(w.end), paint);
        case ReviewKind.object:
          paint.strokeWidth = chosen ? 3 : 1.5;
          canvas.drawPath(
            Path()..addPolygon(_box(it).map(map).toList(), true),
            paint,
          );
        case ReviewKind.door || ReviewKind.window || ReviewKind.passage:
          break;
      }
    }
    // Los huecos, encima: un corte en la pared y su color.
    for (final it in items.where(
      (it) => it.kind != ReviewKind.wall && it.kind != ReviewKind.object,
    )) {
      final (a, b) = _openingSpan(it);
      final w = s.walls[s.openings[it.index].wall];
      final width = math.max(4.0, w.thickness * k + 2);
      canvas.drawLine(
        map(a),
        map(b),
        Paint()
          ..color = const Color(0xFF1E1E1C)
          ..strokeWidth = width,
      );
      final paint = Paint()
        ..color = _colorOf(it)
        ..strokeWidth = it.kind == ReviewKind.window ? 2 : 3;
      if (identical(it, selected)) _halo(canvas, map(a), map(b), paint);
      canvas.drawLine(map(a), map(b), paint);
      if (it.kind == ReviewKind.door) {
        // El barrido de la hoja, como en la planta.
        final r = (map(b) - map(a)).distance;
        final ang = math.atan2(map(b).dy - map(a).dy, map(b).dx - map(a).dx);
        canvas.drawArc(
          Rect.fromCircle(center: map(a), radius: r),
          ang,
          math.pi / 2,
          false,
          Paint()
            ..color = _colorOf(it).withValues(alpha: 0.6)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  void _halo(Canvas canvas, Offset a, Offset b, Paint base) {
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = base.color.withValues(alpha: 0.3)
        ..strokeWidth = base.strokeWidth + 10
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ReviewPainter old) => true;
}
