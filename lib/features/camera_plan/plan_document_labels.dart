import 'dart:math' as math;
import 'dart:ui';

/// Un rótulo de una planta en papel, con lo que señala. Con varios puntos es
/// un rótulo común a varios aparatos iguales.
class DocumentLabel {
  final List<Offset> anchors;

  /// Lo que ocupa la marca alrededor de cada punto.
  final double radius;
  final Size size;

  /// Se pinta si cabe junto a su sitio; si no, se omite.
  final bool optional;

  const DocumentLabel({
    required this.anchors,
    required this.size,
    this.radius = 0,
    this.optional = false,
  });

  Offset get center {
    var sum = Offset.zero;
    for (final a in anchors) {
      sum += a;
    }
    return sum / anchors.length.toDouble();
  }
}

class PlacedDocumentLabel {
  final DocumentLabel label;
  final Rect rect;

  /// Va en una columna lateral, unido a su marca por una línea.
  final bool leader;

  const PlacedDocumentLabel(this.label, this.rect, {this.leader = false});

  /// Dónde sale la línea del rótulo.
  Offset get leaderStart =>
      label.center.dx < rect.center.dx ? rect.centerLeft : rect.centerRight;
}

/// Coloca los rótulos de una planta sin que se pisen: junto a su marca si
/// hay sitio y, si no, en columnas a los lados de la planta. [overflow] dice
/// que ni así caben y hace falta letra más pequeña.
///
/// Con [drawing], el dibujo ocupa ese hueco y los rótulos obligatorios van
/// todos a los márgenes de fuera, a [gap] del dibujo: dentro no se pisa
/// nada. Los opcionales solo entran dentro del dibujo si hay sitio.
({List<PlacedDocumentLabel> placed, bool overflow}) layoutDocumentLabels(
  List<DocumentLabel> labels,
  Size canvas, {
  List<Rect> marks = const [],
  Rect? drawing,
  double gap = 8,
}) {
  const edge = 3.0;
  final bounds = (Offset.zero & canvas).deflate(edge);
  final required = labels.where((l) => !l.optional).toList()
    ..sort((a, b) => a.center.dy.compareTo(b.center.dy));

  final demoted = <DocumentLabel>{
    for (final l in required)
      if (l.anchors.length > 1 || drawing != null) l,
  };
  var near = <PlacedDocumentLabel>[];
  var columns = <PlacedDocumentLabel>[];
  var overflow = false;

  // Una columna puede caer encima de un rótulo cercano: ese pasa también a
  // la columna y se reparte de nuevo. Solo crece, así que termina.
  while (true) {
    near = _near(required, demoted, bounds, marks);
    demoted.addAll(
      required.where((l) => !near.any((p) => identical(p.label, l))),
    );
    final result = _columns(
      demoted.toList(),
      labels,
      bounds,
      marks,
      drawing: drawing,
      gap: gap,
    );
    columns = result.placed;
    overflow = result.overflow;
    final blocked = near.where(
      (p) => columns.any((c) => c.rect.overlaps(p.rect.inflate(1))),
    );
    if (blocked.isEmpty) break;
    demoted.addAll(blocked.map((p) => p.label));
  }

  final placed = [...near, ...columns];
  for (final label in labels.where((l) => l.optional)) {
    final rect = Rect.fromCenter(
      center: label.center,
      width: label.size.width,
      height: label.size.height,
    );
    if (_free(rect, drawing?.deflate(edge) ?? bounds, placed, marks)) {
      placed.add(PlacedDocumentLabel(label, rect));
    }
  }
  return (placed: placed, overflow: overflow);
}

bool _free(
  Rect rect,
  Rect bounds,
  List<PlacedDocumentLabel> placed,
  List<Rect> marks,
) =>
    rect.left >= bounds.left &&
    rect.top >= bounds.top &&
    rect.right <= bounds.right &&
    rect.bottom <= bounds.bottom &&
    !placed.any((p) => p.rect.overlaps(rect.inflate(1))) &&
    !marks.any((m) => m.overlaps(rect));

List<PlacedDocumentLabel> _near(
  List<DocumentLabel> labels,
  Set<DocumentLabel> skip,
  Rect bounds,
  List<Rect> marks,
) {
  const gap = 1.5;
  final placed = <PlacedDocumentLabel>[];
  for (final label in labels) {
    if (skip.contains(label)) continue;
    final a = label.anchors.single;
    final w = label.size.width;
    final h = label.size.height;
    final r = label.radius + gap;
    final tops = <Offset>[
      Offset(a.dx - w / 2, a.dy + r), // debajo
      Offset(a.dx + r, a.dy - h / 2), // derecha
      Offset(a.dx - r - w, a.dy - h / 2), // izquierda
      Offset(a.dx - w / 2, a.dy - r - h), // encima
      Offset(a.dx + r, a.dy + r * 0.7),
      Offset(a.dx - r - w, a.dy + r * 0.7),
      Offset(a.dx + r, a.dy - r * 0.7 - h),
      Offset(a.dx - r - w, a.dy - r * 0.7 - h),
    ];
    for (final top in tops) {
      final rect = top & label.size;
      if (_free(rect, bounds, placed, marks)) {
        placed.add(PlacedDocumentLabel(label, rect));
        break;
      }
    }
  }
  return placed;
}

({List<PlacedDocumentLabel> placed, bool overflow}) _columns(
  List<DocumentLabel> items,
  List<DocumentLabel> all,
  Rect bounds,
  List<Rect> marks, {
  Rect? drawing,
  double gap = 8,
}) {
  const spacing = 2.0;
  if (items.isEmpty) return (placed: const [], overflow: false);

  // Hasta dónde llega la planta: las columnas van por fuera.
  var left = double.infinity;
  var right = double.negativeInfinity;
  if (drawing != null) {
    left = drawing.left;
    right = drawing.right;
  } else {
    for (final label in all) {
      for (final a in label.anchors) {
        left = math.min(left, a.dx - label.radius);
        right = math.max(right, a.dx + label.radius);
      }
    }
  }
  final middle = (left + right) / 2;

  // Cuántas marcas ajenas cruza la línea de [label] hacia un lado.
  int crossings(DocumentLabel label, bool toLeft) {
    final a = label.center;
    final start = Offset(toLeft ? left : right, a.dy);
    var count = 0;
    // Lo pegado a la propia figura (sus otras posiciones y números) no
    // cuenta: la línea sale de ahí de todos modos.
    final own = math.max(label.radius * 3.5, 12.0);
    for (final m in marks) {
      if (m.contains(a) || (m.center - a).distance < own) continue;
      if (_segmentHits(start, a, m)) count++;
    }
    return count;
  }

  // Cada figura cruzada cuenta como cruzar media planta: una línea larga
  // que atraviesa el dibujo también estorba.
  bool goesLeft(DocumentLabel label) {
    final near = label.center.dx < middle;
    if (drawing == null) return near;
    final width = math.max(1.0, right - left);
    double cost(bool toLeft) =>
        crossings(label, toLeft) +
        2 * (toLeft ? label.center.dx - left : right - label.center.dx) / width;
    final toLeft = cost(true);
    final toRight = cost(false);
    if ((toLeft - toRight).abs() < 1e-9) return near;
    return toLeft < toRight;
  }

  final lefts = items.where(goesLeft).toList();
  final rights = items.where((l) => !lefts.contains(l)).toList();

  double height(List<DocumentLabel> side) =>
      side.fold<double>(0, (sum, l) => sum + l.size.height + spacing);
  int nearest(DocumentLabel a, DocumentLabel b) =>
      (a.center.dx - middle).abs().compareTo((b.center.dx - middle).abs());

  // Si un lado no cabe, lo más cercano al centro cambia de lado.
  void balance(List<DocumentLabel> from, List<DocumentLabel> to) {
    while (height(from) > bounds.height && height(to) < bounds.height) {
      from.sort(nearest);
      to.add(from.removeAt(0));
    }
  }

  balance(lefts, rights);
  balance(rights, lefts);

  var overflow = false;
  final placed = <PlacedDocumentLabel>[];
  void stack(List<DocumentLabel> side, bool isLeft) {
    side.sort((a, b) => a.center.dy.compareTo(b.center.dy));
    final tops = <double>[];
    var cursor = bounds.top;
    for (final label in side) {
      final top = math.max(label.center.dy - label.size.height / 2, cursor);
      tops.add(top);
      cursor = top + label.size.height + spacing;
    }
    var limit = bounds.bottom;
    for (var i = side.length - 1; i >= 0; i--) {
      final h = side[i].size.height;
      if (tops[i] + h > limit) tops[i] = limit - h;
      limit = tops[i] - spacing;
    }
    if (tops.isNotEmpty && tops.first < bounds.top) overflow = true;
    for (final (i, label) in side.indexed) {
      final w = label.size.width;
      final x = isLeft
          ? math.max(bounds.left, left - gap - w)
          : math.min(bounds.right - w, right + gap);
      placed.add(
        PlacedDocumentLabel(
          label,
          Offset(x, tops[i]) & label.size,
          leader: true,
        ),
      );
    }
  }

  stack(lefts, true);
  stack(rights, false);
  return (placed: placed, overflow: overflow);
}

/// Si el tramo de [a] a [b] pasa por la marca [m] (tomada como círculo).
bool _segmentHits(Offset a, Offset b, Rect m) {
  final c = m.center;
  final r = m.shortestSide / 2 * 0.9;
  final ab = b - a;
  final length = ab.distanceSquared;
  final t = length == 0
      ? 0.0
      : (((c.dx - a.dx) * ab.dx + (c.dy - a.dy) * ab.dy) / length).clamp(
          0.0,
          1.0,
        );
  return (a + ab * t - c).distance < r;
}
