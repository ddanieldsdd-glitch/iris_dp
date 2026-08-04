import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'frame_line_geometry.dart';
import 'frame_line_models.dart';
import 'optics_calculator.dart';
import 'optics_lab_samples.dart';

/// Preview estilo ARRI Frame Line con imagen de referencia dentro del sensor.
class FltFrameLinePreview extends StatefulWidget {
  final FrameLineLayout layout;
  final OpticsResult optics;
  final SensorModeSpec mode;
  final ReferenceBackground background;
  final ValueChanged<ReferenceBackground>? onBackgroundChanged;
  final GlobalKey? repaintKey;
  final List<String> samplePaths;
  final VoidCallback? onAddSample;
  final void Function(String path)? onDeleteSample;

  final bool desqueezePreview;
  final double squeezeRatio;
  final LensIlluminationGuideConfig lensGuide;
  final FrameLeaderConfig frameLeader;

  const FltFrameLinePreview({
    super.key,
    required this.layout,
    required this.optics,
    required this.mode,
    required this.background,
    this.desqueezePreview = false,
    this.squeezeRatio = 1.0,
    this.lensGuide = const LensIlluminationGuideConfig(),
    this.frameLeader = const FrameLeaderConfig(),
    this.onBackgroundChanged,
    this.repaintKey,
    this.samplePaths = const [],
    this.onAddSample,
    this.onDeleteSample,
  });

  @override
  State<FltFrameLinePreview> createState() => _FltFrameLinePreviewState();
}

class _FltFrameLinePreviewState extends State<FltFrameLinePreview> {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          color: const Color(0xFF1565C0),
          child: Text(
            'Frame Line Preview',
            style: AppTypography.titleMedium(palette).copyWith(color: Colors.white),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showSidebar = constraints.maxWidth >= 520;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, inner) {
                        return RepaintBoundary(
                          key: widget.repaintKey,
                          child: _PreviewCanvas(
                            size: Size(inner.maxWidth, inner.maxHeight),
                            layout: widget.layout,
                            optics: widget.optics,
                            background: widget.background,
                            desqueezePreview: widget.desqueezePreview,
                            squeezeRatio: widget.squeezeRatio,
                            lensGuide: widget.lensGuide,
                            frameLeader: widget.frameLeader,
                          ),
                        );
                      },
                    ),
                  ),
                  if (showSidebar)
                    SizedBox(
                      width: (constraints.maxWidth * 0.28).clamp(160, 220),
                      child: _SpecsSidebar(
                        layout: widget.layout,
                        optics: widget.optics,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        _ThumbnailStrip(
          background: widget.background,
          samplePaths: widget.samplePaths,
          onSelect: (bg) => widget.onBackgroundChanged?.call(bg),
          onAddSample: widget.onAddSample,
          onDeleteSample: widget.onDeleteSample,
        ),
      ],
    );
  }
}

class _PreviewCanvas extends StatelessWidget {
  final Size size;
  final FrameLineLayout layout;
  final OpticsResult optics;
  final ReferenceBackground background;
  final bool desqueezePreview;
  final double squeezeRatio;
  final LensIlluminationGuideConfig lensGuide;
  final FrameLeaderConfig frameLeader;

  const _PreviewCanvas({
    required this.size,
    required this.layout,
    required this.optics,
    required this.background,
    this.desqueezePreview = false,
    this.squeezeRatio = 1.0,
    this.lensGuide = const LensIlluminationGuideConfig(),
    this.frameLeader = const FrameLeaderConfig(),
  });

  Rect _px(Rect norm) => Rect.fromLTWH(
        norm.left * size.width,
        norm.top * size.height,
        norm.width * size.width,
        norm.height * size.height,
      );

  @override
  Widget build(BuildContext context) {
    final modeActive = _px(layout.modeActiveRect);
    final scale = layout.fovImageScale;
    final squeeze = desqueezePreview ? squeezeRatio.clamp(1.0, 3.0) : 1.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF1E1E1E)),
        CustomPaint(
          size: size,
          painter: _ChipBackgroundPainter(
            layout: layout,
            size: size,
            desqueezePreview: desqueezePreview,
            squeezeRatio: squeeze,
          ),
        ),
        Positioned.fromRect(
          rect: modeActive,
          child: ClipRect(
            child: _backgroundContent(modeActive, scale, squeeze),
          ),
        ),
        CustomPaint(
          size: size,
          painter: _OverlayPainter(
            layout: layout,
            size: size,
            desqueezePreview: desqueezePreview,
            squeezeRatio: squeeze,
            lensGuide: lensGuide,
            frameLeader: frameLeader,
          ),
        ),
      ],
    );
  }

  Widget _backgroundContent(Rect sensor, double scale, double squeeze) {
    switch (background.kind) {
      case ReferenceBackgroundKind.white:
        return const ColoredBox(color: Colors.white);
      case ReferenceBackgroundKind.black:
        return const ColoredBox(color: Colors.black);
      case ReferenceBackgroundKind.image:
        final path = background.imagePath;
        if (path == null || !File(path).existsSync()) {
          return const ColoredBox(color: Color(0xFF424242));
        }
        return Transform.scale(
          scaleX: squeeze,
          scaleY: 1.0,
          alignment: Alignment.center,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: SizedBox(
              width: sensor.width,
              height: sensor.height,
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
        );
    }
  }
}

class _ChipBackgroundPainter extends CustomPainter {
  final FrameLineLayout layout;
  final Size size;
  final bool desqueezePreview;
  final double squeezeRatio;

  _ChipBackgroundPainter({
    required this.layout,
    required this.size,
    this.desqueezePreview = false,
    this.squeezeRatio = 1.0,
  });

  Rect _px(Rect norm) {
    final squeeze = desqueezePreview ? squeezeRatio.clamp(1.0, 3.0) : 1.0;
    if (squeeze <= 1.0) {
      return Rect.fromLTWH(
        norm.left * size.width,
        norm.top * size.height,
        norm.width * size.width,
        norm.height * size.height,
      );
    }
    final cx = size.width / 2;
    final left = norm.left * size.width;
    final top = norm.top * size.height;
    final w = norm.width * size.width;
    final h = norm.height * size.height;
    final centerX = left + w / 2;
    final stretchedW = w * squeeze;
    final newLeft = cx + (centerX - cx) * squeeze - stretchedW / 2;
    return Rect.fromLTWH(newLeft, top, stretchedW, h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chip = _px(layout.fullChipRect);
    final modeActive = _px(layout.modeActiveRect);

    canvas.drawRect(chip, Paint()..color = const Color(0xFF383838));

    if (chip != modeActive) {
      final cropPath = Path()
        ..addRect(chip)
        ..addRect(modeActive)
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(cropPath, Paint()..color = const Color(0x99000000));
    }

    canvas.drawRect(
      chip,
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _ChipBackgroundPainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.size != size;
}

class _OverlayPainter extends CustomPainter {
  final FrameLineLayout layout;
  final Size size;
  final bool desqueezePreview;
  final double squeezeRatio;
  final LensIlluminationGuideConfig lensGuide;
  final FrameLeaderConfig frameLeader;

  _OverlayPainter({
    required this.layout,
    required this.size,
    this.desqueezePreview = false,
    this.squeezeRatio = 1.0,
    this.lensGuide = const LensIlluminationGuideConfig(),
    this.frameLeader = const FrameLeaderConfig(),
  });

  Rect _px(Rect norm) {
    final squeeze = desqueezePreview ? squeezeRatio.clamp(1.0, 3.0) : 1.0;
    final cx = size.width / 2;
    final left = norm.left * size.width;
    final top = norm.top * size.height;
    final w = norm.width * size.width;
    final h = norm.height * size.height;
    if (squeeze <= 1.0) {
      return Rect.fromLTWH(left, top, w, h);
    }
    final centerX = left + w / 2;
    final stretchedW = w * squeeze;
    final newLeft = cx + (centerX - cx) * squeeze - stretchedW / 2;
    return Rect.fromLTWH(newLeft, top, stretchedW, h);
  }

  bool _rectsMatch(Rect a, Rect b, {double tol = 2.0}) =>
      (a.left - b.left).abs() < tol &&
      (a.top - b.top).abs() < tol &&
      (a.width - b.width).abs() < tol &&
      (a.height - b.height).abs() < tol;

  @override
  void paint(Canvas canvas, Size size) {
    final modeActive = _px(layout.modeActiveRect);
    final circle = _px(layout.imageCircleRect);
    final gate = _px(layout.activeGateRect);

    final visibleLines = layout.frameLines.where((f) => f.config.showFrameLine).toList();

    for (final fl in visibleLines) {
      if (fl.config.shading == FrameLineShading.outsideFrameLine) {
        _dimOutsideClipped(canvas, modeActive, _px(fl.rectNorm));
      }
    }
    if (visibleLines.any((f) => f.config.shading == FrameLineShading.outsideSensor)) {
      _dimOutsideClipped(canvas, modeActive, modeActive);
    }

    if (lensGuide.showCoverageFill) {
      canvas.drawOval(
        circle,
        Paint()..color = const Color(0x184A90D9),
      );
    }

    if (lensGuide.vignetteOutsideCircle) {
      _vignetteOutsideCircleClipped(canvas, modeActive, circle);
    }

    if (lensGuide.showImageCircle) {
      canvas.drawOval(
        circle,
        Paint()
          ..color = const Color(0x884A90D9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    final gateHidden = visibleLines.any((fl) => _rectsMatch(gate, _px(fl.rectNorm)));
    if (!gateHidden) {
      canvas.drawRect(
        gate,
        Paint()
          ..color = const Color(0x2200C853)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        gate,
        Paint()
          ..color = const Color(0xFF00C853)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    canvas.drawRect(
      modeActive,
      Paint()
        ..color = const Color(0xFF00C853)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    for (final fl in visibleLines) {
      _paintFrameLine(canvas, _px(fl.rectNorm), fl.config);
    }

    if (frameLeader.enabled) {
      _paintFrameLeader(canvas, modeActive);
    }
  }

  void _vignetteOutsideCircleClipped(Canvas canvas, Rect clip, Rect circle) {
    canvas.save();
    canvas.clipRect(clip);
    final path = Path()
      ..addRect(clip)
      ..addOval(circle)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = const Color(0x55000000));
    canvas.restore();
  }

  void _dimOutsideClipped(Canvas canvas, Rect clip, Rect hole) {
    canvas.save();
    canvas.clipRect(clip);
    final path = Path()
      ..addRect(clip)
      ..addRect(hole)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = const Color(0xAA000000));
    canvas.restore();
  }

  void _paintFrameLine(Canvas canvas, Rect rect, FrameLineConfig cfg) {
    final paint = Paint()
      ..color = cfg.lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cfg.lineWidth;

    switch (cfg.style) {
      case FrameLineStyle.fullBox:
        canvas.drawRect(rect, paint);
      case FrameLineStyle.corners:
        _drawCorners(canvas, rect, paint, cfg.styleLength);
      case FrameLineStyle.crosshair:
        canvas.drawRect(rect, paint);
        _drawCenterMark(canvas, rect.center, rect.shortestSide * 0.08, FrameLineCenterMark.cross, paint);
    }

    if (cfg.style != FrameLineStyle.crosshair && cfg.centerMark != FrameLineCenterMark.none) {
      _drawCenterMark(canvas, rect.center, rect.shortestSide * 0.06, cfg.centerMark, paint);
    }
  }

  void _drawCenterMark(Canvas canvas, Offset center, double size, FrameLineCenterMark mark, Paint paint) {
    switch (mark) {
      case FrameLineCenterMark.none:
        break;
      case FrameLineCenterMark.cross:
        canvas.drawLine(Offset(center.dx - size, center.dy), Offset(center.dx + size, center.dy), paint);
        canvas.drawLine(Offset(center.dx, center.dy - size), Offset(center.dx, center.dy + size), paint);
      case FrameLineCenterMark.dot:
        canvas.drawCircle(center, size * 0.35, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
      case FrameLineCenterMark.crossDot:
        canvas.drawLine(Offset(center.dx - size, center.dy), Offset(center.dx + size, center.dy), paint);
        canvas.drawLine(Offset(center.dx, center.dy - size), Offset(center.dx, center.dy + size), paint);
        canvas.drawCircle(center, size * 0.25, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
    }
  }

  void _drawCorners(Canvas canvas, Rect rect, Paint paint, FrameLineStyleLength length) {
    final factor = length == FrameLineStyleLength.short ? 0.06 : 0.12;
    final len = math.min(rect.width, rect.height) * factor;
    void corner(Offset o, Offset dx, Offset dy) {
      canvas.drawLine(o, o + dx * len, paint);
      canvas.drawLine(o, o + dy * len, paint);
    }

    corner(rect.topLeft, const Offset(1, 0), const Offset(0, 1));
    corner(rect.topRight, const Offset(-1, 0), const Offset(0, 1));
    corner(rect.bottomLeft, const Offset(1, 0), const Offset(0, -1));
    corner(rect.bottomRight, const Offset(-1, 0), const Offset(0, -1));
  }

  void _paintFrameLeader(Canvas canvas, Rect modeActive) {
    final leaderH = modeActive.height * 0.08;
    final leaderRect = Rect.fromLTWH(
      modeActive.left,
      modeActive.top,
      modeActive.width,
      leaderH,
    );
    canvas.drawRect(
      leaderRect,
      Paint()..color = const Color(0xCC000000),
    );
    final tickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;
    for (var i = 0; i <= 20; i++) {
      final x = leaderRect.left + leaderRect.width * i / 20;
      final tickH = i % 5 == 0 ? leaderH * 0.7 : leaderH * 0.35;
      canvas.drawLine(
        Offset(x, leaderRect.top),
        Offset(x, leaderRect.top + tickH),
        tickPaint,
      );
    }
    if (frameLeader.showSafeArea) {
      final safe = leaderRect.deflate(leaderRect.width * 0.05);
      canvas.drawRect(
        safe,
        Paint()
          ..color = Colors.white54
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.size != size ||
      oldDelegate.lensGuide != lensGuide ||
      oldDelegate.frameLeader != frameLeader;
}

class _SpecsSidebar extends StatelessWidget {
  final FrameLineLayout layout;
  final OpticsResult optics;

  const _SpecsSidebar({required this.layout, required this.optics});

  @override
  Widget build(BuildContext context) {
    final pxLabel = layout.sensorWidthPx != null
        ? '${layout.sensorWidthPx} × ${layout.sensorHeightPx} px'
        : '—';
    final photosites = layout.sensorWidthPx != null && layout.sensorHeightPx != null
        ? (layout.sensorWidthPx! * layout.sensorHeightPx!).toStringAsFixed(0)
        : '—';

    return ColoredBox(
      color: const Color(0xFF111111),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _block('Sensor Active Image Area', [
            pxLabel,
            '${layout.sensorWidthMm.toStringAsFixed(2)} × ${layout.sensorHeightMm.toStringAsFixed(2)} mm',
            if (layout.cropLabel != null) layout.cropLabel!,
          ]),
          _block('Full Sensor (Open Gate)', [
            '${layout.fullChipWidthMm.toStringAsFixed(2)} × ${layout.fullChipHeightMm.toStringAsFixed(2)} mm',
          ]),
          _block('Recording File (modo)', [
            if (layout.recordingWidthPx != null)
              '${layout.recordingWidthPx} × ${layout.recordingHeightPx} px'
            else
              '—',
          ]),
          _block('Recording Gate (AR)', [
            '${optics.activeWidthMm.toStringAsFixed(2)} × ${optics.activeHeightMm.toStringAsFixed(2)} mm',
            if (optics.activeWidthPx != null)
              '${optics.activeWidthPx} × ${optics.activeHeightPx} px',
          ]),
          _block('Photosite Count', [photosites]),
          _block('Image Circle', ['${layout.imageCircleMm.toStringAsFixed(2)} mm']),
          if (optics.resolutionLabel != null)
            _block('Recording File', [optics.resolutionLabel!]),
          _block('Lens / FOV', [
            'HFOV ${optics.hFovDeg.toStringAsFixed(1)}°',
            'VFOV ${optics.vFovDeg.toStringAsFixed(1)}°',
            'DFOV ${optics.dFovDeg.toStringAsFixed(1)}°',
          ]),
          const Divider(color: Colors.white24),
          ...layout.frameLines.where((fl) => fl.config.showFrameLine).map(
            (fl) => _block(
              'Frame Line ${fl.config.id}',
              [
                if (fl.widthPx != null) '${fl.widthPx} × ${fl.heightPx} px',
                '${fl.widthMm.toStringAsFixed(2)} × ${fl.heightMm.toStringAsFixed(2)} mm',
                if (fl.config.effectiveAspectRatio != null)
                  'Aspect ${fl.config.effectiveAspectRatio!.toStringAsFixed(2)}:1',
                if (fl.pixelCount != null) 'Pixel count ${fl.pixelCount}',
              ],
              accent: fl.config.lineColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _block(String title, List<String> lines, {Color? accent}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent ?? Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          ...lines.map((l) => Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11))),
        ],
      ),
    );
  }
}

class _ThumbnailStrip extends StatelessWidget {
  final ReferenceBackground background;
  final List<String> samplePaths;
  final ValueChanged<ReferenceBackground> onSelect;
  final VoidCallback? onAddSample;
  final void Function(String path)? onDeleteSample;

  const _ThumbnailStrip({
    required this.background,
    required this.samplePaths,
    required this.onSelect,
    this.onAddSample,
    this.onDeleteSample,
  });

  bool _isSelectedSample(String path) =>
      background.kind == ReferenceBackgroundKind.image &&
      background.imagePath == path;

  @override
  Widget build(BuildContext context) {
    final atLimit = samplePaths.length >= kOpticsLabMaxSamples;

    return Container(
      height: 88,
      color: const Color(0xFFEEEEEE),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Imágenes de muestra (${samplePaths.length}/$kOpticsLabMaxSamples)',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _thumb(
                  selected: background.kind == ReferenceBackgroundKind.white,
                  onTap: () => onSelect(const ReferenceBackground.white()),
                  child: Container(
                    color: Colors.white,
                    child: const Center(
                      child: Icon(Icons.circle_outlined, size: 10, color: Colors.black26),
                    ),
                  ),
                ),
                _thumb(
                  selected: background.kind == ReferenceBackgroundKind.black,
                  onTap: () => onSelect(const ReferenceBackground.black()),
                  child: Container(color: Colors.black),
                ),
                for (final path in samplePaths)
                  _thumb(
                    selected: _isSelectedSample(path),
                    onTap: () => onSelect(ReferenceBackground.image(path)),
                    onDelete: onDeleteSample == null
                        ? null
                        : () => _confirmDelete(context, path),
                    child: File(path).existsSync()
                        ? Image.file(File(path), fit: BoxFit.cover)
                        : const Icon(Icons.broken_image_outlined),
                  ),
                if (onAddSample != null)
                  _thumb(
                    selected: false,
                    onTap: onAddSample!,
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: atLimit ? Colors.black26 : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String path) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar imagen de muestra'),
        content: const Text('¿Quieres eliminar esta imagen del laboratorio óptico?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) onDeleteSample?.call(path);
  }

  Widget _thumb({
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onDelete,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: onTap,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? Colors.black : Colors.black26,
                  width: selected ? 3 : 1,
                ),
              ),
              child: child,
            ),
          ),
          if (onDelete != null)
            Positioned(
              top: -6,
              right: -6,
              child: Material(
                color: Colors.red.shade700,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onDelete,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
