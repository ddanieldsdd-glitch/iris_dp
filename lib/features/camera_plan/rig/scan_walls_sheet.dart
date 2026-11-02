import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'scan_walls.dart';

/// Pide el corte del escaneo a una altura, en metros del suelo; `null` si
/// el escaneo no está cargado.
typedef ScanSlicer = Future<List<(Offset, Offset)>?> Function(double heightM);

/// «Proponer paredes» (F6.20 E4): corta el escaneo a una altura, enseña
/// las paredes que salen sobre el corte y deja quitar las que no valen.
/// Devuelve las elegidas, en metros de la planta.
class ScanWallsSheet extends StatefulWidget {
  final ScanSlicer slice;

  const ScanWallsSheet({super.key, required this.slice});

  static Future<List<WallProposal>?> show(
    BuildContext context,
    ScanSlicer slice,
  ) => showDialog<List<WallProposal>>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        width: 760,
        height: 600,
        child: ScanWallsSheet(slice: slice),
      ),
    ),
  );

  @override
  State<ScanWallsSheet> createState() => _ScanWallsSheetState();
}

class _ScanWallsSheetState extends State<ScanWallsSheet> {
  double _height = 1.0;
  List<(Offset, Offset)> _cut = const [];
  List<WallProposal> _walls = const [];
  final _off = <int>{};
  bool _loading = true;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    final cut = await widget.slice(_height);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _missing = cut == null;
      _cut = cut ?? const [];
      _walls = proposeWalls(_cut);
      _off.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final caption = AppTypography.caption(
      palette,
    ).copyWith(color: palette.textTertiary);
    final chosen = [
      for (var i = 0; i < _walls.length; i++)
        if (!_off.contains(i)) _walls[i],
    ];
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Proponer paredes', style: AppTypography.titleMedium(palette)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Un corte del escaneo a ${_height.toStringAsFixed(2)} m del '
            'suelo. Toca una pared para quitarla. Calibra y nivela el escaneo '
            'antes: el corte va a su altura.',
            style: caption,
          ),
          Row(
            children: [
              Text('Altura', style: AppTypography.caption(palette)),
              Expanded(
                child: Slider(
                  value: _height,
                  min: 0.3,
                  max: 2.2,
                  divisions: 19,
                  label: '${_height.toStringAsFixed(1)} m',
                  onChanged: (v) => setState(() => _height = v),
                  onChangeEnd: (_) => _run(),
                ),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _missing
                ? Center(
                    child: Text(
                      'El escaneo aún no se ha cargado en el 3D.',
                      style: AppTypography.bodyMedium(palette),
                    ),
                  )
                : _walls.isEmpty
                ? Center(
                    child: Text(
                      'A esta altura no salen paredes. Prueba otra.',
                      style: AppTypography.bodyMedium(palette),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, box) {
                      final painter = _CutPainter(
                        cut: _cut,
                        walls: _walls,
                        off: _off,
                        cutColor: palette.textTertiary,
                        onColor: palette.accent,
                        offColor: palette.error,
                      );
                      return GestureDetector(
                        onTapUp: (e) {
                          final i = painter.hit(e.localPosition, box.biggest);
                          if (i == null) return;
                          setState(
                            () =>
                                _off.contains(i) ? _off.remove(i) : _off.add(i),
                          );
                        },
                        child: CustomPaint(size: box.biggest, painter: painter),
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${chosen.length} de ${_walls.length} paredes, '
                  '${chosen.fold(0.0, (s, w) => s + w.length).toStringAsFixed(1)} m',
                  style: AppTypography.mono(palette),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: chosen.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(chosen),
                child: Text('Añadir ${chosen.length} a la planta'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CutPainter extends CustomPainter {
  final List<(Offset, Offset)> cut;
  final List<WallProposal> walls;
  final Set<int> off;
  final Color cutColor, onColor, offColor;

  _CutPainter({
    required this.cut,
    required this.walls,
    required this.off,
    required this.cutColor,
    required this.onColor,
    required this.offColor,
  });

  /// De metros a la pantalla, con margen y sin deformar.
  (Offset Function(Offset), double) _map(Size size) {
    var lo = const Offset(double.infinity, double.infinity);
    var hi = const Offset(-double.infinity, -double.infinity);
    void grow(Offset p) {
      lo = Offset(math.min(lo.dx, p.dx), math.min(lo.dy, p.dy));
      hi = Offset(math.max(hi.dx, p.dx), math.max(hi.dy, p.dy));
    }

    for (final w in walls) {
      grow(w.start);
      grow(w.end);
    }
    for (final s in cut) {
      grow(s.$1);
      grow(s.$2);
    }
    const pad = 16.0;
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

  int? hit(Offset at, Size size) {
    final (map, _) = _map(size);
    int? best;
    var bestD = 14.0;
    for (var i = 0; i < walls.length; i++) {
      final a = map(walls[i].start), b = map(walls[i].end);
      final ab = b - a;
      final t = ab.distanceSquared == 0
          ? 0.0
          : (((at - a).dx * ab.dx + (at - a).dy * ab.dy) / ab.distanceSquared)
                .clamp(0.0, 1.0);
      final d = (a + ab * t - at).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final (map, _) = _map(size);
    final faint = Paint()
      ..color = cutColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (final s in cut) {
      canvas.drawLine(map(s.$1), map(s.$2), faint);
    }
    for (var i = 0; i < walls.length; i++) {
      final removed = off.contains(i);
      canvas.drawLine(
        map(walls[i].start),
        map(walls[i].end),
        Paint()
          ..color = removed ? offColor.withValues(alpha: 0.5) : onColor
          ..strokeWidth = removed ? 2 : 4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CutPainter old) => true;
}
