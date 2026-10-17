import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'shot_sheet_data.dart';
import 'storyboard_export_style.dart';
import 'storyboard_group_export_options.dart';
import 'storyboard_image_palette.dart';

/// Opciones de exportación para un solo plano (CLEAN / BASIC / DETAIL /
/// SHOT PLAN). Con [showImageChoice], deja elegir qué imagen lo representa.
Future<({StoryboardExportStyle style, ShotImageSource imageSource})?>
showStoryboardExportOptionsSheet(
  BuildContext context, {
  bool showImageChoice = false,
}) {
  final palette = context.palette;

  return showModalBottomSheet<
    ({StoryboardExportStyle style, ShotImageSource imageSource})
  >(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _SingleShotSheet(showImageChoice: showImageChoice),
  );
}

class _SingleShotSheet extends StatefulWidget {
  final bool showImageChoice;

  const _SingleShotSheet({required this.showImageChoice});

  @override
  State<_SingleShotSheet> createState() => _SingleShotSheetState();
}

class _SingleShotSheetState extends State<_SingleShotSheet> {
  ShotImageSource _source = ShotImageSource.storyboard;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg + bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(
              title: 'Opciones de exportación de una sola toma',
              subtitle:
                  'Revisa notas y metadata antes de exportar '
                  'para afinar la planificación del plano. Todo sale en PDF.',
              onClose: () => Navigator.pop(context),
            ),
            if (widget.showImageChoice) ...[
              const SizedBox(height: AppSpacing.md),
              _ImageSourcePicker(
                value: _source,
                onChanged: (v) => setState(() => _source = v),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 220,
              child: _ShotStylePicker(
                onSelect: (style) => Navigator.pop(context, (
                  style: style,
                  imageSource: _source,
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Imagen del plano: Storyboard | Referencia».
class _ImageSourcePicker extends StatelessWidget {
  final ShotImageSource value;
  final ValueChanged<ShotImageSource> onChanged;

  const _ImageSourcePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Text('Imagen del plano', style: AppTypography.caption(palette)),
        const SizedBox(width: AppSpacing.md),
        SegmentedButton<ShotImageSource>(
          segments: [
            for (final source in ShotImageSource.values)
              ButtonSegment(
                value: source,
                label: Text(source.label, style: const TextStyle(fontSize: 11)),
              ),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ],
    );
  }
}

/// Opciones de exportación de grupo: secuencias (STORYBOARD / SHOT LIST) o por plano.
Future<StoryboardGroupExportChoice?> showStoryboardGroupExportOptionsSheet(
  BuildContext context,
) {
  final palette = context.palette;

  return showModalBottomSheet<StoryboardGroupExportChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _GroupExportSheet(palette: palette),
  );
}

class _GroupExportSheet extends StatefulWidget {
  final AppPalette palette;

  const _GroupExportSheet({required this.palette});

  @override
  State<_GroupExportSheet> createState() => _GroupExportSheetState();
}

class _GroupExportSheetState extends State<_GroupExportSheet> {
  StoryboardGroupExportMode _mode = StoryboardGroupExportMode.sequences;
  ShotImageSource _source = ShotImageSource.storyboard;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg + bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(
              title: 'Exportar storyboard',
              subtitle: _mode == StoryboardGroupExportMode.sequences
                  ? 'Exporta la secuencia como PDF de storyboard o shot list.'
                  : 'Un PDF con una hoja por plano, en el nivel elegido.',
              onClose: () => Navigator.pop(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: SegmentedButton<StoryboardGroupExportMode>(
                segments: StoryboardGroupExportMode.values
                    .map(
                      (m) => ButtonSegment(
                        value: m,
                        label: Text(
                          m.label,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    )
                    .toList(),
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ),
            if (_mode == StoryboardGroupExportMode.asShots) ...[
              const SizedBox(height: AppSpacing.md),
              _ImageSourcePicker(
                value: _source,
                onChanged: (v) => setState(() => _source = v),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 220,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _mode == StoryboardGroupExportMode.sequences
                    ? _SequenceLayoutPicker(
                        key: const ValueKey('sequences'),
                        onSelect: (layout) => Navigator.pop(
                          context,
                          StoryboardGroupExportChoice.sequences(layout),
                        ),
                      )
                    : _ShotStylePicker(
                        key: const ValueKey('asShots'),
                        onSelect: (style) => Navigator.pop(
                          context,
                          StoryboardGroupExportChoice.asShots(
                            style,
                            imageSource: _source,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onClose;

  const _SheetHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.titleMedium(palette)),
              const SizedBox(height: 4),
              Text(subtitle, style: AppTypography.caption(palette)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cerrar',
          onPressed: onClose,
          icon: Icon(Icons.close, color: palette.textSecondary),
        ),
      ],
    );
  }
}

class _SequenceLayoutPicker extends StatelessWidget {
  final ValueChanged<StoryboardSequenceLayout> onSelect;

  const _SequenceLayoutPicker({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: StoryboardSequenceLayout.values.length,
      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
      itemBuilder: (_, index) {
        final layout = StoryboardSequenceLayout.values[index];
        return _SequenceLayoutCard(
          layout: layout,
          onTap: () => onSelect(layout),
        );
      },
    );
  }
}

class _ShotStylePicker extends StatelessWidget {
  final ValueChanged<StoryboardExportStyle> onSelect;

  const _ShotStylePicker({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: StoryboardExportStyle.values.length,
      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
      itemBuilder: (_, index) {
        final style = StoryboardExportStyle.values[index];
        return _ShotStyleCard(style: style, onTap: () => onSelect(style));
      },
    );
  }
}

class _SequenceLayoutCard extends StatelessWidget {
  final StoryboardSequenceLayout layout;
  final VoidCallback onTap;

  const _SequenceLayoutCard({required this.layout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const previewWidth = 168.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: previewWidth,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(9),
                    ),
                    child: SizedBox(
                      height: 110,
                      child: CustomPaint(
                        painter: _SequencePreviewPainter(layout: layout),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _PdfBadge(palette: palette),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        layout.title,
                        style: AppTypography.label(palette).copyWith(
                          color: palette.accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        layout.description,
                        style: AppTypography.caption(
                          palette,
                        ).copyWith(height: 1.25, fontSize: 11),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShotStyleCard extends StatelessWidget {
  final StoryboardExportStyle style;
  final VoidCallback onTap;

  const _ShotStyleCard({required this.style, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const previewWidth = 148.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: previewWidth,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(9),
                    ),
                    child: SizedBox(
                      height: 96,
                      child: CustomPaint(
                        painter: _ShotStylePreviewPainter(style: style),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _PdfBadge(palette: palette),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        style.title,
                        style: AppTypography.label(palette).copyWith(
                          color: palette.accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        style.description,
                        style: AppTypography.caption(
                          palette,
                        ).copyWith(height: 1.25, fontSize: 11),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfBadge extends StatelessWidget {
  final AppPalette palette;

  const _PdfBadge({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        shape: BoxShape.circle,
        border: Border.all(color: palette.accent.withValues(alpha: 0.5)),
      ),
      child: Icon(
        Icons.picture_as_pdf_outlined,
        size: 16,
        color: palette.accent,
      ),
    );
  }
}

class _SequencePreviewPainter extends CustomPainter {
  final StoryboardSequenceLayout layout;

  _SequencePreviewPainter({required this.layout});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF2A2A2A),
    );

    final doc = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 10, size.width - 24, size.height - 16),
      const Radius.circular(4),
    );
    canvas.drawRRect(doc, Paint()..color = const Color(0xFF3D3D3D));

    if (layout == StoryboardSequenceLayout.storyboard) {
      _drawStoryboardGrid(canvas, doc);
    } else {
      _drawShotList(canvas, doc);
    }
  }

  void _drawStoryboardGrid(Canvas canvas, RRect doc) {
    const cols = 3;
    const rows = 3;
    final inner = doc.outerRect.deflate(8);
    final cellW = inner.width / cols - 2;
    final cellH = inner.height / rows - 2;
    final cellPaint = Paint()..color = const Color(0xFF555555);

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawRect(
          Rect.fromLTWH(
            inner.left + c * (cellW + 2),
            inner.top + r * (cellH + 2),
            cellW,
            cellH,
          ),
          cellPaint,
        );
      }
    }
  }

  void _drawShotList(Canvas canvas, RRect doc) {
    final inner = doc.outerRect.deflate(8);
    const rows = 4;
    final rowH = (inner.height - (rows - 1) * 3) / rows;
    final imgW = inner.width * 0.32;

    for (var i = 0; i < rows; i++) {
      final top = inner.top + i * (rowH + 3);
      canvas.drawRect(
        Rect.fromLTWH(inner.left, top, imgW, rowH),
        Paint()..color = const Color(0xFF555555),
      );
      for (var line = 0; line < 3; line++) {
        final lineY = top + 6 + line * 7.0;
        canvas.drawRect(
          Rect.fromLTWH(
            inner.left + imgW + 6,
            lineY,
            inner.width - imgW - 10,
            4,
          ),
          Paint()..color = const Color(0xFF666666),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SequencePreviewPainter oldDelegate) =>
      oldDelegate.layout != layout;
}

class _ShotStylePreviewPainter extends CustomPainter {
  final StoryboardExportStyle style;

  _ShotStylePreviewPainter({required this.style});

  static const _image = Color(0xFF6E8A96);
  static const _paper = Color(0xFFEDEDED);
  static const _line = Color(0xFFB0B0B0);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF2A2A2A),
    );
    switch (style) {
      case StoryboardExportStyle.clean:
        canvas.drawRect(_imageRect(size, 0.5), Paint()..color = _image);
      case StoryboardExportStyle.basic:
        final img = _imageRect(size, 0.5);
        canvas.drawRect(img, Paint()..color = _image);
        _drawFramelines(canvas, img.deflate(4));
        _drawFan(canvas, Offset(img.right - 14, img.bottom - 5), 9);
      case StoryboardExportStyle.detail:
        final page = _imageRect(size, 0.5).inflate(2);
        canvas.drawRect(page, Paint()..color = _paper);
        final img = Rect.fromLTRB(
          page.left,
          page.top + 5,
          page.right,
          page.bottom - 18,
        );
        canvas.drawRect(
          Rect.fromLTRB(page.left, page.top, page.right, img.top),
          Paint()..color = Colors.black,
        );
        canvas.drawRect(img, Paint()..color = _image);
        _drawLines(
          canvas,
          Rect.fromLTWH(page.left + 4, img.bottom + 4, page.width * 0.3, 10),
        );
        _drawFan(canvas, Offset(page.center.dx, img.bottom + 12), 6);
        canvas.drawRect(
          Rect.fromLTWH(
            page.right - page.width * 0.32,
            img.bottom + 3,
            page.width * 0.3,
            12,
          ),
          Paint()
            ..color = _line
            ..style = PaintingStyle.stroke,
        );
      case StoryboardExportStyle.shotPlan:
        final h = size.height - 10;
        final page = Rect.fromCenter(
          center: size.center(Offset.zero),
          width: h * 0.72,
          height: h,
        );
        canvas.drawRect(page, Paint()..color = _paper);
        canvas.drawRect(
          Rect.fromLTWH(page.left + 3, page.top + 3, page.width - 6, 6),
          Paint()..color = Colors.black,
        );
        canvas.drawRect(
          Rect.fromLTWH(page.left + 3, page.top + 11, page.width - 6, h * 0.32),
          Paint()..color = _image,
        );
        final colTop = page.top + 14 + h * 0.36;
        final colW = (page.width - 9) / 2;
        _drawLines(canvas, Rect.fromLTWH(page.left + 3, colTop, colW, 16));
        canvas.drawRect(
          Rect.fromLTWH(page.left + 3 + colW + 3, colTop, colW, 18),
          Paint()
            ..color = _line
            ..style = PaintingStyle.stroke,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            page.left + 3 + colW + 3,
            colTop + 21,
            colW,
            page.bottom - colTop - 24,
          ),
          Paint()..color = const Color(0xFF0B1424),
        );
    }
  }

  Rect _imageRect(Size size, double heightFactor) => Rect.fromCenter(
    center: size.center(Offset.zero),
    width: size.width * 0.84,
    height: size.height * heightFactor * 1.3,
  );

  void _drawLines(Canvas canvas, Rect area) {
    final paint = Paint()..color = _line;
    for (var y = area.top; y < area.bottom; y += 4) {
      canvas.drawRect(Rect.fromLTWH(area.left, y, area.width, 1.6), paint);
    }
  }

  void _drawFan(Canvas canvas, Offset center, double radius) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFA8A8A8),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2 - 0.5,
      1.0,
      true,
      Paint()..color = kArtemisLensAccent,
    );
  }

  void _drawFramelines(Canvas canvas, Rect area) {
    const aspect = 2.39;
    final areaAspect = area.width / area.height;
    late Rect inner;
    if (areaAspect > aspect) {
      final w = area.height * aspect;
      inner = Rect.fromLTWH(
        area.left + (area.width - w) / 2,
        area.top,
        w,
        area.height,
      );
    } else {
      final h = area.width / aspect;
      inner = Rect.fromLTWH(
        area.left,
        area.top + (area.height - h) / 2,
        area.width,
        h,
      );
    }
    canvas.drawRect(
      inner,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ShotStylePreviewPainter oldDelegate) =>
      oldDelegate.style != style;
}
